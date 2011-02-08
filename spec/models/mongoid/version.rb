module BitemporalSpec
  module Mongoid
    class Version
      include ::Mongoid::Document
      include Bitemporal::Mongoid::Version
      field :firstname, :type => String
      field :lastname, :type => String
    end
  end
end