module Bitemporal
  module Mongoid
    module Version
      extend ActiveSupport::Concern
      included do
        field :master_id, :type => BSON::ObjectId
        field :created_at, :type => Time
        field :expired_at, :type => Time, :default => Bitemporal::TIME_MAX
        field :valid_from, :type => Time
        field :valid_to, :type => Time, :default => Bitemporal::TIME_MAX
        validates_presence_of :valid_from
        after_initialize :set_created_at
      end
      module ClassMethods
        def at(time)
          where({
            :valid_from.lte => time,
            :valid_to.gt => time,
            :created_at.lte => Bitemporal.now,
            :expired_at.gt => Bitemporal.now,
          })
        end
      end
      module InstanceMethods
        def set_created_at
          self.created_at ||= Bitemporal.now
        end
        def at?(time)
          valid_from <= time && valid_to > time && created_at <= Bitemporal.now && expired_at > Bitemporal.now
        end
        def expired?
          expired_at && (expired_at <= Bitemporal.now)
        end
        def clone
          copy = super
          copy.created_at = Bitemporal.now
          copy.expired_at = Bitemporal.TIME_MAX
          copy
        end
      end
    end
  end
end