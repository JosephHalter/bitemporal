module Bitemporal
  TIME_MIN = Time.utc(0)
  TIME_MAX = Time.utc(9999)
  def self.now=(time)
    Thread.current[:now] = time
  end
  def self.now
    Thread.current[:now] ||= Time.now
  end
  module Mongoid
    autoload :Master, "bitemporal/mongoid/master"
    autoload :Version, "bitemporal/mongoid/version"
    autoload :Association, "bitemporal/mongoid/association"
  end
end