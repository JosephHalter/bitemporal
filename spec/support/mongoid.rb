Mongoid.configure do |config|
  config.master = Mongo::Connection.new.db("bitemporal_test")
  config.allow_dynamic_fields = false
  config.parameterize_keys = false
end