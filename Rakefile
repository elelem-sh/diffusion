# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

desc "Build the vendored stable-diffusion.cpp extension (the same build `gem install` runs)"
task :compile do
  ruby "ext/elelem/diffusion/extconf.rb"
end

task default: %i[spec]
