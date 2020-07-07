exec(*(["bundle", "exec", $PROGRAM_NAME] + ARGV)) if ENV['BUNDLE_GEMFILE'].nil?

task :default => :test

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require "git-version-bump"
require 'yard'

YARD::Rake::YardocTask.new :doc do |yardoc|
  yardoc.files = %w{lib/**/*.rb - README.md}
end

desc "Run guard"
task :guard do
  sh "guard --clear"
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new :test do |t|
  t.pattern = "spec/**/*_spec.rb"
end

docker_repo = ENV["DOCKER_REPO"] || "discourse/nefario"
docker_tag  = ENV["DOCKER_TAG"] || GVB.version

namespace :docker do
  desc "Build a new docker image"
  task :build do
    sh "docker build --pull -t #{docker_repo}:#{docker_tag} --build-arg=http_proxy=#{ENV['http_proxy']} --build-arg=NEFARIO_VERSION=#{GVB.version} ."
    ENV["DOCKER_EXTRA_TAGS"].to_s.split(',').each do |tag|
      sh "docker tag #{docker_repo}:#{docker_tag} #{docker_repo}:#{tag}"
    end
  end

  desc "Publish a new docker image"
  task publish: :build do
    sh "docker push #{docker_repo}:#{docker_tag}"
    ENV["DOCKER_EXTRA_TAGS"].to_s.split(',').each do |tag|
      sh "docker push #{docker_repo}:#{tag}"
    end
  end
end

