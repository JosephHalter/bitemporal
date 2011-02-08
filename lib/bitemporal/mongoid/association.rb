module Bitemporal
  module Mongoid
    class Association
      attr_writer :at, :valid_from
      def initialize(opts = {})
        @master = opts[:master]
        @version_class = opts[:version_class].constantize
        @version_ids = opts[:version_ids]
      end
      def scope
        @version_class.where :_id.in => @master.send(@version_ids)
      end
      def to_a(reload = false)
        @to_a = scope.to_a if reload || @to_a.nil?
        @to_a
      end
      def assign(versions)
        @master.send "#{@version_ids}=", versions.collect(&:id)
        @to_a = versions.dup
      end
      def <<(new_version)
        to_a.push new_version
      end
      def at
        @at ||= Bitemporal.now
      end
      def valid_from
        @valid_from ||= at
      end
      def attributes=(attrs)
        initial_at = @at
        attrs.inject(Hash.new{|h,k| h[k]=[]}) do |hash, (key, value)|
          value = {:value => value} unless value.is_a? Hash
          value[:valid_from] = parse_time_or value[:valid_from], valid_from
          value[:key] = key
          hash[value[:valid_from]] << value
          hash
        end.sort.each do |valid_from, values|
          @at = valid_from
          version_old = current
          if version_old.nil?
            version_new = @version_class.new
            version_new.valid_from = valid_from
            values.each{|value| version_new.send "#{value[:key]}=", value[:value] }
            self << version_new
          elsif version_old.valid_from==valid_from
            values.each{|value| version_old.send "#{value[:key]}=", value[:value] }
          else
            version_new = version_old.clone
            version_new.valid_from = valid_from
            version_new.valid_to = version_old.valid_to
            values.each{|value| version_new.send "#{value[:key]}=", value[:value] }
            self << version_new
            version_old.valid_to = valid_from
          end
        end
        @at = initial_at
      end
      def reload
        @to_a = nil
        @at = nil
        @valid_from = nil
        self
      end
      def current
        to_a.detect{|version| version.at?(at)}
      end
      def valid?
        to_a.all?{|version| version.expired? || version.valid?}
      end
      def save
        new_versions = []
        changed = false
        to_a.each do |version|
          if !version.persisted?
            new_versions << version
            changed = true
          elsif version.changed?
            expired = version.clone
            expired.changes.each{|k,_| expired.reset_attribute! k}
            expired.expired_at = Bitemporal.now
            new_versions << expired
            modified = version.clone
            modified.save!
            new_versions << modified
            changed = true
          else
            new_versions << version
          end
        end
        return unless changed
        new_versions.all? do |version|
          version.master_id = id
          version.persisted? || version.safely.save
        end
        assign new_versions
      end
    private
      def parse_time_or(str, time)
        return time unless str.present?
        Time.parse str
      rescue ArgumentError
        time
      end
    end
  end
end