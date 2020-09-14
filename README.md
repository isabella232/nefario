Nefario keeps all your minion containers in line.


# Usage

As Nefario is designed to work with Moby, it is distributed as [a Moby image](https://hub.docker.com/r/discourse/nefario).
Thus, using it is as simple as firing it up as a container, with some configuration
provided as environment variables, and probably `docker.sock` as a bind mount:

```
docker run -v /var/run/docker.sock:/var/run/docker.sock \
    -e NEFARIO_CONFIG_DIRECTORIES=/nefario \
    discourse/nefario:latest
```

The available configuration environment variables are listed in the "[Configuration](#configuration)" section, below.

Once Nefario is up and running, it will keep an eye on the directoies specified by `NEFARIO_CONFIG_DIRECTORIES`, and any time a file is created or modified in the watched directories that has a `.yaml` extension, it will treat it as a [`moby-derp`](https://github.com/mpalmer/moby-derp) pod configuration file, and trigger a `moby-derp` run with that configuration.


## Configuration

As per the principles of the [12-factor app](https://12factor.net), Nefario is
configured entirely via environment variables.  Only the `NEFARIO_CONFIG_DIRECTORY`
variable is required.

* **`NEFARIO_CONFIG_DIRECTORIES`**: comma seperated string of directories to watch for modified configuration files.  The directories must exist before Nefario is started.

* **`NEFARIO_MOUNT_ROOT`**: (default: `/srv/docker`) The filesystem path where
  all pod volumes should be created.

* **`NEFARIO_IMAGE_REFRESH_INTERVAL`**: (default: `900`) The number of seconds
  between attempts to refresh all the images in use by containers.

* **`NEFARIO_HOST_HOSTNAME`**: (default: the actual hostname) The hostname to
  use when generating container hostnames.

* **`DOCKER_HOST`**: (default: `"unix:///var/run/docker.sock"`) A URL indicating
  the location of the Docker daemon with which Nefario should communicate.

* **`DOCKER_CONFIG`**: (default: `"$HOME/.docker"`) The directory within which
  Nefario will look for a file named `config.json`, containing authentication
  credentials (and credential helpers) for registries which Nefario may have to
  pull images from.  The format of the `config.json` file is the same as the
  Docker CLI uses, except that the only top-level keys which Nefario will
  examine are `auths` (for static credentials) and `credHelpers` (for
  credential helper definitions).



# Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md).


# Licence

Unless otherwise stated, everything in this repo is covered by the following
copyright notice:

    Copyright (C) 2020  Civilized Discourse Construction Kit, Inc.

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License version 3, as
    published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
