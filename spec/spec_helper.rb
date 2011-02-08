require "bundler/setup"
Bundler.require
require "bitemporal"

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].each {|f| require f}
Dir[File.join(File.dirname(__FILE__), "models/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
end