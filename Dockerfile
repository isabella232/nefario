FROM ruby:2.6-slim

COPY Gemfile Gemfile.lock /tmp/

RUN apt-get update \
	&& apt-get install -y build-essential \
	&& cd /tmp \
	&& gem install bundler \
	&& bundle config set deployment true \
	&& bundle config set without development \
	&& bundle install \
	&& apt-get purge -y build-essential \
	&& apt-get --purge -y autoremove \
	&& rm -rf /tmp/* /var/lib/apt/lists/*

COPY bin/* /usr/local/bin/
COPY lib/* /usr/local/lib/ruby/site_ruby/

ARG NEFARIO_VERSION=invalid_build
ENV NEFARIO_VERSION=$NEFARIO_VERSION

ENTRYPOINT ["/usr/local/bin/nefario"]
