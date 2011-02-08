module Bitemporal
  module Mongoid
    module Master
      extend ActiveSupport::Concern
      module ClassMethods
        def bitemporal(versions, opts = {})
          version = versions.to_s.singularize
          self.class_eval <<-eos
            field :#{version}_ids, :type => Array, :default => []
            field :#{versions}_lock, :type => Time
            validate :validate_#{versions}
            before_save :save_#{versions}
            def #{versions}
              @#{versions} ||= Bitemporal::Mongoid::Association.new({
                :master => self,
                :version_class => "#{opts[:class_name] || versions.to_s.classify}",
                :version_ids => :#{version}_ids,
              })
            end
            def #{versions}=(versions)
              self.#{versions}.assign versions
            end
            def reload
              super
              #{versions}.reload
              self
            end
          private
            def validate_#{versions}
              errors.add(:#{versions}, "are not valid") unless #{versions}.valid?
            end
            def save_#{versions}
              #{versions}.save
              self.#{versions}_lock = Bitemporal::TIME_MIN
            end
          eos
        end
      end
    end
  end
end