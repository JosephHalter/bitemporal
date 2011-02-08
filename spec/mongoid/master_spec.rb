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
      it("versions should be a bitemporal association"){ subject.versions.should be_a Bitemporal::Mongoid::Association }
      it("versions.scope should be a scope of the version class"){ subject.versions.scope.should == BitemporalSpec::Mongoid::Version.where(:_id.in => []) }
      it "versions= should update version_ids" do
        subject.versions = [@v1]
        subject.version_ids.should =~ [@v1.id]
      end
    end
    context "when version_ids has values" do
      before{ subject.version_ids = [@v1.id, @v2.id] }
      it("versions.scope should be a scope of these ids"){ subject.versions.scope.should == BitemporalSpec::Mongoid::Version.where(:_id.in => [@v1.id, @v2.id]) }
      it("versions.to_a should be an array of the versions with matching id"){ subject.versions.to_a.should =~ [@v1, @v2] }
    end
    context "on validation" do
      it "validates versions" do
        subject.should be_valid
        subject.versions.should_receive(:valid?).and_return false
        subject.should_not be_valid
        subject.should have(1).error
        subject.errors[:versions].should == ["are not valid"]
      end
    end
    context "on save" do
      it "saves versions" do
        subject.versions.should_receive :save
        subject.save
      end
      it "releases any lock" do
        subject.versions_lock = Time.now
        subject.save
        subject.versions_lock.should == Bitemporal::TIME_MIN
      end
    end
    context "on reload" do
      it "reloads versions" do
        subject.save!
        subject.versions.should_receive :reload
        subject.reload
      end
    end
  end
end