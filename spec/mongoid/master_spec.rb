require "spec_helper"

describe Bitemporal::Mongoid::Master do
  subject{ BitemporalSpec::Mongoid::Master.new }
  before{ Bitemporal.now = nil }
  describe "versions pseudo association" do
    before do
      @v1 = BitemporalSpec::Mongoid::Version.create! :valid_from => Time.utc(2010), :valid_to => Bitemporal::TIME_MAX
      @v2 = BitemporalSpec::Mongoid::Version.create! :valid_from => Time.utc(2010), :valid_to => Bitemporal::TIME_MAX
      @v3 = BitemporalSpec::Mongoid::Version.create! :valid_from => Time.utc(2010), :valid_to => Bitemporal::TIME_MAX
    end
    should_have_field :version_ids, :type => Array
    should_have_field :versions_lock, :type => Time
    context "when initialized" do
      it("version_ids should be empty"){ subject.version_ids.should =~ [] }
      it("versions_scope should be a scope without id"){ subject.versions_scope.should == BitemporalSpec::Mongoid::Version.where(:_id.in => []) }
      it("versions should be empty"){ subject.versions.should =~ [] }
      it "versions should be memoized" do
        subject.versions
        subject.update_attribute :version_ids, [@v1.id]
        subject.versions.should =~ []
      end
      it "versions memoization should be cleared on reload" do
        subject.versions
        subject.update_attribute :version_ids, [@v1.id]
        subject.reload.should be subject
        subject.versions.should =~ [@v1]
      end
      it "versions= should update version_ids" do
        subject.versions = [@v1]
        subject.version_ids.should =~ [@v1.id]
      end
      it "versions= should bypass versions memoization" do
        subject.versions
        subject.versions = [@v1]
        subject.versions.should =~ [@v1]
      end
    end
    context "when version_ids has values" do
      before{ subject.version_ids = [@v1.id, @v2.id] }
      it("versions_scope should be a scope of these ids"){ subject.versions_scope.should == BitemporalSpec::Mongoid::Version.where(:_id.in => [@v1.id, @v2.id]) }
      it("versions should be an array of the versions with matching id"){ subject.versions.should =~ [@v1, @v2] }
    end
  end
  describe "moving on timeline" do
    before{ Timecop.freeze Time.local(2010, 11, 1) }
    after{ Timecop.return }
    it "version_at should default to Bitemporal.now" do
      subject.version_at.should == Bitemporal.now
    end
    it "version_valid_at should be memoized" do
      subject.version_at.should == Bitemporal.now
      Timecop.freeze 1.day.since
      subject.version_at.should == 1.day.ago
    end
    it "version_at= should override memoization" do
      subject.version_at
      subject.version_at = 1.day.ago
      subject.version_at.should == 1.day.ago
    end
    it "version_valid_from should default to version_at" do
      subject.version_at = 1.day.ago
      subject.version_valid_from.should == 1.day.ago
    end
    it "version_valid_from should be memoized" do
      subject.version_valid_from
      subject.version_at = 1.day.ago
      subject.version_valid_from.should == Bitemporal.now
    end
    it "version_valid_from= should override memoization" do
      subject.version_valid_from
      subject.version_valid_from = 1.day.ago
      subject.version_valid_from.should == 1.day.ago
    end
  end
  describe "version attributes assignment" do
    before{ Timecop.freeze Time.local(2010, 11, 1) }
    after{ Timecop.return }
    context "on initialization" do
      subject{ BitemporalSpec::Mongoid::Master.new :version_attributes => {:firstname => "Benoit"} }
      it("adds a new version"){ subject.should have(1).version }
      it "fills in version with given attributes" do
        subject.should have_versions(%Q{
          | firstname | valid_from | valid_to | created_at | expired_at |
          | Benoit    | 2010-11-01 |          |            |            |
        })
      end
    end
    context "on validation before creation" do
      subject{ BitemporalSpec::Mongoid::Master.new :version_attributes => {:firstname => "Benoit"} }
      it "validates versions" do
        subject.valid?
        should be_valid
        subject.versions[0].should_receive(:valid?).and_return false
        should_not be_valid
        should have(1).error
        subject.errors[:versions].should == ["are not valid"]
      end
    end
    context "on creation" do
      subject{ BitemporalSpec::Mongoid::Master.create :version_attributes => {:firstname => "Benoit"} }
      it{ should be_persisted }
      it("adds a new version"){ should have(1).version }
      it("version should be persisted too"){ subject.versions[0].should be_persisted }
      it "fills in version with given attributes and sets created_at" do
        should have_versions(%Q{
          | firstname | valid_from | valid_to | created_at | expired_at |
          | Benoit    | 2010-11-01 | MAX      | 2010-11-01 | MAX        |
        })
      end
    end
    context "on load with only one version" do
      before{ @id = BitemporalSpec::Master.create(:version_attributes => {:firstname => "Benoit"}).id }
      subject{ BitemporalSpec::Master.find @id }
      it("current version has persisted attributes"){ subject.current_version.firstname.should == "Benoit" }
    end
    context "on load with multiple versions v1, v2 and v3" do
      before do
        @v1 = BitemporalSpec::Mongoid::Version.create! :valid_from => Time.local(2010, 11, 1), :valid_to => Bitemporal::TIME_MAX, :created_at => Time.local(2010, 11, 1), :expired_at => Time.local(2010, 11, 2), :firstname => "Benoit"
        @v2 = BitemporalSpec::Mongoid::Version.create! :valid_from => Time.local(2010, 11, 1), :valid_to => Time.local(2010, 11, 3), :created_at => Time.local(2010, 11, 2), :expired_at => Bitemporal::TIME_MAX, :firstname => "Benoit"
        @v3 = BitemporalSpec::Mongoid::Version.create! :valid_from => Time.local(2010, 11, 3), :valid_to => Bitemporal::TIME_MAX, :created_at => Time.local(2010, 11, 2), :expired_at => Bitemporal::TIME_MAX, :firstname => "Benoit", :lastname => "David"
        subject.versions = [@v1, @v2, @v3]
      end
      context "when now is 2010-11-01 and version_at is 2010-11-01" do
        it("current_version is v1"){ subject.current_version.should == @v1 }
      end
      context "when now is 2010-11-01 and version_at is 2010-11-02" do
        before{ subject.version_at = 1.day.since }
        it("current_version is v1"){ subject.current_version.should == @v1 }
      end
      context "when now is 2010-11-02 and version_at is 2010-11-01" do
        before{ Timecop.freeze Time.local 2010, 11, 2 }
        it("expired versions should not be used"){ subject.current_version.should == @v2 }
      end
      context "when now is 2010-11-02 and version_at is 2010-11-02" do
        before{ Timecop.freeze Time.local(2010, 11, 2); subject.version_at = Time.local(2010, 11, 3) }
        it("current version should change accordingly"){ subject.current_version.should be @v3 }
      end
    end
    context "on validation before update" do
      before do
        @v1 = BitemporalSpec::Mongoid::Version.create! :valid_from => Time.local(2010, 10, 30), :valid_to => Bitemporal::TIME_MAX, :created_at => Time.local(2010, 10, 30), :expired_at => Time.local(2010, 10, 31), :firstname => "Benoit"
        @v2 = BitemporalSpec::Mongoid::Version.create! :valid_from => Time.local(2010, 10, 30), :valid_to => Bitemporal::TIME_MAX, :created_at => Time.local(2010, 10, 31), :expired_at => Bitemporal::TIME_MAX, :firstname => "Benoit", :lastname => "David"
        subject.versions = [@v1, @v2]
      end
      it "should not revalidate expired versions" do
        @v1.should_not_receive :valid?
        @v2.should_receive(:valid?).and_return true
        subject.should be_valid
      end
    end
    context "on update with only one version" do
      it "expires old version and add 2 new ones" do
        v = BitemporalSpec::Mongoid::Version.create! :valid_from => Time.local(2010, 10, 31), :valid_to => Bitemporal::TIME_MAX, :created_at => Time.local(2010, 10, 31), :expired_at => Bitemporal::TIME_MAX, :firstname => "Benoit"
        subject.versions = [v]
        subject.should have_versions(%Q{
          | firstname | lastname | valid_from | valid_to | created_at | expired_at |
          | Benoit    |          | 2010-10-31 | MAX      | 2010-10-31 | MAX        |
        })
        subject.version_attributes = {:lastname => "David"}
        subject.should have_versions(%Q{
          | firstname | lastname | valid_from | valid_to   | created_at | expired_at |
          | Benoit    |          | 2010-10-31 | 2010-11-01 | 2010-10-31 | MAX        |
          | Benoit    | David    | 2010-11-01 | MAX        |            |            |
        })
        subject.save!
        subject.should have_versions(%Q{
          | firstname | lastname | valid_from | valid_to   | created_at | expired_at |
          | Benoit    |          | 2010-10-31 | MAX        | 2010-10-31 | 2010-11-01 |
          | Benoit    |          | 2010-10-31 | 2010-11-01 | 2010-11-01 | MAX        |
          | Benoit    | David    | 2010-11-01 | MAX        | 2010-11-01 | MAX        |
        })
      end
      it "takes valid_from from attributes" do
        v = BitemporalSpec::Mongoid::Version.create! :valid_from => Time.local(2010, 10, 31), :valid_to => Bitemporal::TIME_MAX, :created_at => Time.local(2010, 10, 31), :expired_at => Bitemporal::TIME_MAX, :firstname => "David"
        subject.versions = [v]
        subject.should have_versions(%Q{
          | firstname | lastname | valid_from | valid_to | created_at | expired_at |
          | David     |          | 2010-10-31 | MAX      | 2010-10-31 | MAX        |
        })
        subject.version_attributes = {:firstname => {:valid_from => "2010-11-10", :value => "Benoit"}, :lastname => "David"}
        subject.should have_versions(%Q{
          | firstname | lastname | valid_from | valid_to   | created_at | expired_at |
          | David     |          | 2010-10-31 | 2010-11-01 | 2010-10-31 | MAX        |
          | David     | David    | 2010-11-01 | 2010-11-10 |            |            |
          | Benoit    | David    | 2010-11-10 | MAX        |            |            |
        })
        subject.save!
        subject.should have_versions(%Q{
          | firstname | lastname | valid_from | valid_to   | created_at | expired_at |
          | David     |          | 2010-10-31 | MAX        | 2010-10-31 | 2010-11-01 |
          | David     |          | 2010-10-31 | 2010-11-01 | 2010-11-01 | MAX        |
          | David     | David    | 2010-11-01 | 2010-11-10 | 2010-11-01 | MAX        |
          | Benoit    | David    | 2010-11-10 | MAX        | 2010-11-01 | MAX        |
        })
      end
    end
  end
end