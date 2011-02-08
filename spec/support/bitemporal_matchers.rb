RSpec::Matchers.define :have_versions do |versions_str|
  @table = have_versions_parse_table versions_str
  @last_index = nil
  @last_version = nil
  match do |master|
    master.versions.size == @table.size && @table.each.with_index.all? do |version, index|
      @last_index = index
      @last_version = version
      master_version = master.versions[index]
      valid = true
      valid &&= if version["firstname"].present?
        master_version.firstname == version["firstname"]
      else
        master_version.firstname.blank?
      end
      valid &&= if version["lastname"].present?
        master_version.lastname == version["lastname"]
      else
        master_version.lastname.blank?
      end
      valid &&= master_version.valid_from == have_versions_parse_time(version["valid_from"])
      valid &&= master_version.valid_to   == have_versions_parse_time(version["valid_to"])
      valid &&= master_version.created_at == have_versions_parse_time(version["created_at"])
      valid &&= master_version.expired_at == have_versions_parse_time(version["expired_at"])
      valid
    end
  end
  failure_message_for_should do |master|
    if master.versions.size != @table.size
      "Expected #{master.class} to have #{@table.size} versions but found #{master.versions.size}"
    else
      "Expected #{master.class}.versions[#{@last_index}] to match #{@last_version.inspect} but found #{master.versions[@last_index].inspect}"
    end
  end
end

def have_versions_parse_table(str)
  rows = str.strip.split("\n")
  rows.collect!{|row| row[/^\s*\|(.+)\|\s*$/, 1].split("|").collect(&:strip)}
  headers = rows.shift
  rows.collect{|row| Hash[headers.zip row]}
end

def have_versions_parse_time(str)
  case str
  when "" then nil
  when "MIN" then Bitemporal::TIME_MIN
  when "MAX" then Bitemporal::TIME_MAX
  else
    Time.parse str
  end
end