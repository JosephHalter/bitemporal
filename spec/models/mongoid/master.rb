module BitemporalSpec
  module Mongoid
    class Master
      include ::Mongoid::Document
      include Bitemporal::Mongoid::Master
      bitemporal :versions, :class_name => "BitemporalSpec::Mongoid::Version"
    end
  end
end
