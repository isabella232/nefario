require "moby_derp/system_config"
require "moby_derp/pod_config"
require "moby_derp/pod"
require "docker-api"

class Nefario::MobyDerpRunner
  include ServiceSkeleton::LoggingHelpers

  def initialize(config:, metrics:)
    @config, @metrics = config, metrics

    @logger = @config.logger
  end

  def run
    process_castcall_loop
  end

  def refresh_pod(name)
    logger.debug(logloc) { "Received request to refresh pod #{name.inspect}" }

    validate_pod_name(name)

    begin
      MobyDerp::Pod.new(pod_config(name)).run
    rescue MobyDerp::Error => ex
      log_exception(ex) { "Exception while derping moby pod #{name}" }
    else
      logger.info(logloc) { "Pod #{name} has been refreshed" }
    end
  end

  private

  attr_reader :logger

  def validate_pod_name(name)
    unless name =~ /\A[A-Za-z0-9][A-Za-z0-9_-]*\z/
      raise ArgumentError,
            "Invalid pod name #{name.inspect}"
    end
  end

  def pod_config(name)
    MobyDerp::PodConfig.new(Pathname.new(@config.config_directory).join("#{name}.yaml"), system_config)
  end

  def system_config
    @system_config ||= begin
      MobyDerp::SystemConfig.new({ mount_root: @config.mount_root }, Docker.info, logger)
    end
  end
end