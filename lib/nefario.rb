require "socket"
require "service_skeleton"

class Nefario
  include ServiceSkeleton

  url :DOCKER_HOST, default: "unix:///var/run/docker.sock"
  string :DOCKER_CONFIG, default: "~/.docker"
  string :NEFARIO_CONFIG_DIRECTORY
  string :NEFARIO_MOUNT_ROOT, default: "/srv/docker"
  string :NEFARIO_HOST_HOSTNAME, default: Socket.gethostname
  integer :NEFARIO_IMAGE_REFRESH_INTERVAL, default: 15 * 60

  gauge :pending_refresh_total, docstring: "number of pods pending refresh"
  gauge :pending_events_total, docstring: "number of inotify events left to process"

  def self.register_ultravisor_children(ultravisor, config:, metrics_registry:)
    ultravisor.add_child(
      id: :moby_derp_runner,
      klass: Nefario::MobyDerpRunner,
      method: :run,
      args: [config: config, metrics: metrics_registry],
      enable_castcall: true,
    )

    ultravisor.add_child(
      id: :image_watcher,
      klass: Nefario::ImageWatcher,
      method: :run,
      args: [ultravisor: ultravisor, config: config, metrics: metrics_registry],
    )


    ultravisor.add_child(
      id: :config_dir_watcher,
      klass: Nefario::ConfigDirWatcher,
      method: :run,
      args: [ultravisor: ultravisor, config: config, metrics: metrics_registry],
      shutdown: {
        method: :shutdown,
      }
    )
  end
end

require_relative "./nefario/moby_derp_runner"
require_relative "./nefario/image_watcher"
require_relative "./nefario/config_dir_watcher"
