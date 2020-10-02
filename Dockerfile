FROM ruby:2.6-slim

COPY nefario.tar.gz /root/nefario/

RUN apt-get update \
	&& apt-get install -y build-essential git \
	&& cd /root/nefario \
	&& tar -xf nefario.tar.gz \
	&& gem install bundler \
	&& gem install git-version-bump \
	&& bundle config set without development \
	&& bundle install \
	&& apt-get purge -y build-essential git zlib1g-dev \
	&& apt-get --purge -y autoremove \
	&& rm -rf /var/lib/apt/lists/*

ARG NEFARIO_VERSION=invalid_build
ENV NEFARIO_VERSION=$NEFARIO_VERSION
ENV RUBYLIB=/root/nefario/lib

WORKDIR /root/nefario
ENTRYPOINT ["bundle", "exec", "/root/nefario/bin/nefario"]
