require "rb-inotify"

class Nefario::ConfigDirWatcher
  include ServiceSkeleton::LoggingHelpers

  def initialize(ultravisor:, config:, metrics:)
    @ultravisor, @config, @metrics = ultravisor, config, metrics

    @logger = @config.logger

    @sd_r, @sd_w = IO.pipe

    @inotify_queue = Queue.new
    @processing_thread = create_processing_thread
  end

  def run
    notifier = INotify::Notifier.new
    notifier.watch(@config.config_directory, :move, :close_write, :delete) do |event|
      @metrics.pending_events_total.set(@inotify_queue.length)
      @inotify_queue << event
    end


    logger.info(logloc) { "Refreshing all pods" }
    Pathname.new(@config.config_directory).each_child do |f|
      next unless f.basename.to_s =~ /(\A[^.]|\.yaml\z)/

      pod_name = f.basename(".yaml").to_s
      @ultravisor[:moby_derp_runner].call.refresh_pod(pod_name)
    end

    loop do
      readables = IO.select([notifier.to_io, @sd_r])&.first

      if readables.include?(notifier.to_io)
        logger.debug(logloc) { "Processing pending inotify events" }
        notifier.process
      end

      if readables.include?(@sd_r)
        c = @sd_r.getc
        if c == "!"
          logger.debug(logloc) { "Terminating cleanly" }
          break
        end
      end
    end

    notifier.close
  end

  def shutdown
    logger.debug(logloc) { "Received polite request to shutdown" }
    @inotify_queue.close
    @processing_thread.join
    @sd_w.putc("!")
  end

  private

  attr_reader :logger

  def create_processing_thread
    Thread.new do
      while true
        begin

          break if @inotify_queue.closed?
          event = @inotify_queue.pop
          break if @inotify_queue.closed?

          process_inotify_event(event)
          @metrics.pending_events_total.set(@inotify_queue.length)
        rescue => e
          logger.warn(logloc) { "Failed to process inotify event: #{e}" }
        end
      end
    end
  end

  def process_inotify_event(event)
    logger.debug(logloc) { "Processing inotify event: #{event.flags} => #{event.name}" }

    return unless event.name =~ /\A[A-Za-z0-9][A-Za-z0-9_-]*\.yaml\z/

    if event.flags.include?(:delete) || event.flags.include?(:moved_from)
      pod_deleted(File.basename(event.name, ".yaml"))
    elsif event.flags.include?(:moved_to) || event.flags.include?(:close_write)
      pod_changed(File.basename(event.name, ".yaml"))
    else
      logger.debug(logloc) { "Ignoring event; no interesting looking flags" }
    end
  end

  def pod_deleted(pod_name)
    logger.info(logloc) { "Removing pod #{pod_name}" }

    # Nuking the containers from longest name to shortest just ensures that the
    # pod "core" container gets whacked last.
    Docker::Container.all(all: true)
      .select { |c| c.info["Labels"]["org.hezmatt.moby-derp.pod-name"] == pod_name }
      .sort_by { |c| (c.info["Name"] || c.info["Names"].first).length }
      .reverse
      .each { |c| logger.debug(logloc) { "Deleting container #{c.id}" }; c.stop; c.delete }
  end

  def pod_changed(pod_name)
    logger.info(logloc) { "Triggering refresh on #{pod_name}" }

    begin
      @ultravisor[:moby_derp_runner].call.refresh_pod(pod_name)
    rescue Ultravisor::ChildExitedError
      retry
    end
  end
end
