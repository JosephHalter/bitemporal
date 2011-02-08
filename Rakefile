require "bundler"
require "rspec/core/rake_task"
Bundler::GemHelper.install_tasks
RSpec::Core::RakeTask.new("spec").tap do |config|
  config.rspec_opts = "--color"
end
task :default => :spec