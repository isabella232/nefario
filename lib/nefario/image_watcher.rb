require "docker-api"
require "json"
require "open3"
require "pathname"
require "uri"

class Nefario::ImageWatcher
  include ServiceSkeleton::LoggingHelpers

  def initialize(ultravisor:, config:, metrics:)
    @ultravisor, @config, @metrics = ultravisor, config, metrics

    @logger = @config.logger

    if (f = Pathname.new(@config.docker_config).join("config.json")).exist?
      begin
        @docker_config = JSON.parse(f.read)
      rescue JSON::ParseError => ex
        raise RuntimeError, "Error parsing #{f}: #{ex.message}"
      end
    else
      @docker_config = {}
    end
  end

  def run
    loop do
      start_time = Time.now
      refresh_all_images
      run_time = Time.now - start_time
      sleep_time = [60, @config.image_refresh_interval - run_time].max
      logger.debug(logloc) { "Took #{sprintf("%0.1f", run_time)}s to refresh all images; sleeping for #{sprintf("%0.1f", sleep_time)}s" }
      sleep sleep_time
    end
  end

  private

  attr_reader :logger

  def refresh_all_images
    image_map = Hash.new { |h, k| h[k] = ImageInfo.new(k, @docker_config, logger) }

    Pathname.new(@config.config_directory).each_child do |podfile|
      next unless podfile.basename.to_s =~ /(\A[^.]|\.yaml\z)/

      pod_name = podfile.basename(".yaml").to_s
      cfg = YAML.safe_load(podfile.read)
      logger.debug(logloc) { "Pod configuration for #{pod_name} is #{cfg.inspect}" }
      cfg["containers"].values.each { |c| image_map[c["image"]] << pod_name }
    end

    changed_pods = []

    image_map.values.each do |image|
      if image.changed?
        image.pods.each { |p| changed_pods << p }
      end
    end

    changed_pods.uniq.each do |p|
      logger.info(logloc) { "Refreshing pod #{p} due to out-of-date image" }

      @ultravisor[:moby_derp_runner].cast.refresh_pod(p)
    end
  end

  class ImageInfo
    include ServiceSkeleton::LoggingHelpers

    attr_reader :pods

    def initialize(ref, docker_config, logger)
      @ref, @docker_config, @logger = ref, docker_config, logger

      @pods = []
    end

    def <<(pod_name)
      @pods << pod_name unless @pods.include?(pod_name)
    end

    def changed?
      begin
        cur_image_id = Docker::Image.get(@ref).id
      rescue Docker::Error::NotFoundError
        # This is fine, just means the image doesn't exist locally yet, which
        # means it'll definitely be "changed" once we pull it down.
        logger.debug(logloc) { "Image #{@ref} doesn't exist locally" }
      end

      begin
        Docker::Image.create({ "fromImage" => @ref })
      rescue Docker::Error::NotFoundError => ex
        # This is not *quite* so fine, it means that the image ref given doesn't exist
        # in the remote repo, which... sucks.  But there's no point trying to trigger
        # a pod refresh, because it won't work.
        logger.warn(logloc) { "Image #{@ref} could not be pulled: #{ex.message}" }
        return false
      end

      new_image_id = Docker::Image.get(@ref).id

      cur_image_id != new_image_id
    end

    private

    attr_reader :logger
  end
end
