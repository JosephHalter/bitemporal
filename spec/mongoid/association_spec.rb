require "spec_helper"

describe Bitemporal::Mongoid::Association do
  let(:version_class) { "BitemporalSpec::Mongoid::Version" }
  let(:version_ids) { :version_ids }
  let(:master) { BitemporalSpec::Mongoid::Master.new }
  subject { Bitemporal::Mongoid::Association.new(:master => master, :version_class => version_class, :version_ids => version_ids) }
  before{ Bitemporal.now = nil }
  after{ Timecop.return }

  describe "#scope" do
    it "returns a scope based on master#versions_ids" do
      master.should_receive(:version_ids).and_return(expected = mock)
      subject.scope.should == BitemporalSpec::Mongoid::Version.where(:_id.in => expected)
    end
  end

  describe "#to_a" do
    it "is an empty array when master#versions_ids is empty" do
      BitemporalSpec::Mongoid::Version.create! :valid_from => Time.utc(2010)
      master.should_receive(:version_ids).and_return([])
      subject.to_a.should == []
    end
    it "is based on #scope" do
      subject.stub_chain(:scope, :to_a).and_return(expected = mock)
      subject.to_a.should be expected
    end
    it "is memoized" do
      expected = mock
      subject.stub_chain(:scope, :to_a).and_return(expected)
      subject.to_a
      subject.stub_chain(:scope, :to_a).and_return(mock)
      subject.to_a.should be expected
    end
  end

  describe "#assign" do
    it "updates master#version_ids" do
      versions = [mock(:id => 1)]
      master.should_receive(:version_ids=).with [1]
      subject.assign versions
    end
    it "fills #to_a" do
      versions = [mock(:id => 1)]
      subject.assign versions
      subject.should_not_receive :scope
      subject.to_a.should =~ versions
    end
  end

  describe "#<<" do
    it "fills #to_a" do
      versions = [mock(:id => 1)]
      subject.assign versions
      subject.should_not_receive :scope
      new_version = mock(:id => 2)
      subject << new_version
      subject.to_a.should =~ [*versions, new_version]
    end
  end

  describe "#at" do
    before{ Timecop.freeze Time.local(2010, 11, 1) }
    it "defaults to Bitemporal.now" do
      subject.at.should == Bitemporal.now
    end
    it "is memoized" do
      subject.at
      Timecop.freeze 1.day.since
      subject.at.should == 1.day.ago
    end
  end
  
  describe "#at=(time)" do
    before{ Timecop.freeze Time.local(2010, 11, 1) }
    it "overrides memoization" do
      subject.at
      subject.at = 1.day.ago
      subject.at.should == 1.day.ago
    end
  end

  describe "#valid_from" do
    before{ Timecop.freeze Time.local(2010, 11, 1) }
    it "defaults to #version_at" do
      subject.at = 1.day.ago
      subject.valid_from.should == 1.day.ago
    end
    it "is memoized" do
      subject.valid_from
      subject.at = 1.day.ago
      subject.valid_from.should == Bitemporal.now
    end
  end

  describe "#valid_from=(time)" do
    before{ Timecop.freeze Time.local(2010, 11, 1) }
    it "overrides memoization" do
      subject.valid_from
      subject.valid_from = 1.day.ago
      subject.valid_from.should == 1.day.ago
    end
  end

  describe "#attributes=(attrs)" do
  end

  describe "#reload" do
    it "clears #to_a memoization" do
      subject.stub_chain(:scope, :to_a).and_return(mock)
      subject.to_a
      subject.stub_chain(:scope, :to_a).and_return(expected = mock)
      subject.reload
      subject.to_a.should be expected
    end
    it "clears #at memoization" do
      subject.at = 1.day.since
      subject.reload
      subject.at.should == Bitemporal.now
    end
    it "clears #valid_from memoization" do
      subject.valid_from
      subject.reload
      subject.valid_from.should == Bitemporal.now
    end
    it "returns self" do
      subject.reload.should be subject
    end
  end

  describe "#valid?" do
  end

  describe "#save" do
  end

  # describe "version attributes assignment" do
  #   before{ Timecop.freeze Time.local(2010, 11, 1) }
  #   after{ Timecop.return }
  #   context "on initialization" do
  #     subject{ BitemporalSpec::Mongoid::Master.new :version_attributes => {:firstname => "Benoit"} }
  #     it("adds a new version"){ subject.should have(1).version }
  #     it "fills in version with given attributes" do
  #       subject.should have_versions(%Q{
  #         | firstname | valid_from | valid_to | created_at | expired_at |
  #         | Benoit    | 2010-11-01 |          |            |            |
  #       })
  #     end
  #   end
  #   context "on validation before creation" do
  #     subject{ BitemporalSpec::Mongoid::Master.new :version_attributes => {:firstname => "Benoit"} }
  #     it "validates versions" do
  #       subject.valid?
  #       should be_valid
  #       subject.versions[0].should_receive(:valid?).and_return false
  #       should_not be_valid
  #       should have(1).error
  #       subject.errors[:versions].should == ["are not valid"]
  #     end
  #   end
  #   context "on creation" do
  #     subject{ BitemporalSpec::Mongoid::Master.create :version_attributes => {:firstname => "Benoit"} }
  #     it{ should be_persisted }
  #     it("adds a new version"){ should have(1).version }
  #     it("version should be persisted too"){ subject.versions[0].should be_persisted }
  #     it "fills in version with given attributes and sets created_at" do
  #       should have_versions(%Q{
  #         | firstname | valid_from | valid_to | created_at | expired_at |
  #         | Benoit    | 2010-11-01 | MAX      | 2010-11-01 | MAX        |
  #       })
  #     end
  #   end
  #   context "on load with only one version" do
  #     before{ @id = BitemporalSpec::Master.create(:version_attributes => {:firstname => "Benoit"}).id }
  #     subject{ BitemporalSpec::Master.find @id }
  #     it("current version has persisted attributes"){ subject.current_version.firstname.should == "Benoit" }
  #   end
  #   context "on load with multiple versions v1, v2 and v3" do
  #     before do
  #       @v1 = BitemporalSpec::Mongoid::Version.create! :valid_from => Time.local(2010, 11, 1), :valid_to => Bitemporal::TIME_MAX, :created_at => Time.local(2010, 11, 1), :expired_at => Time.local(2010, 11, 2), :firstname => "Benoit"
  #       @v2 = BitemporalSpec::Mongoid::Version.create! :valid_from => Time.local(2010, 11, 1), :valid_to => Time.local(2010, 11, 3), :created_at => Time.local(2010, 11, 2), :expired_at => Bitemporal::TIME_MAX, :firstname => "Benoit"
  #       @v3 = BitemporalSpec::Mongoid::Version.create! :valid_from => Time.local(2010, 11, 3), :valid_to => Bitemporal::TIME_MAX, :created_at => Time.local(2010, 11, 2), :expired_at => Bitemporal::TIME_MAX, :firstname => "Benoit", :lastname => "David"
  #       subject.versions = [@v1, @v2, @v3]
  #     end
  #     context "when now is 2010-11-01 and version_at is 2010-11-01" do
  #       it("current_version is v1"){ subject.current_version.should == @v1 }
  #     end
  #     context "when now is 2010-11-01 and version_at is 2010-11-02" do
  #       before{ subject.version_at = 1.day.since }
  #       it("current_version is v1"){ subject.current_version.should == @v1 }
  #     end
  #     context "when now is 2010-11-02 and version_at is 2010-11-01" do
  #       before{ Timecop.freeze Time.local 2010, 11, 2 }
  #       it("expired versions should not be used"){ subject.current_version.should == @v2 }
  #     end
  #     context "when now is 2010-11-02 and version_at is 2010-11-02" do
  #       before{ Timecop.freeze Time.local(2010, 11, 2); subject.version_at = Time.local(2010, 11, 3) }
  #       it("current version should change accordingly"){ subject.current_version.should be @v3 }
  #     end
  #   end
  #   context "on validation before update" do
  #     before do
  #       @v1 = BitemporalSpec::Mongoid::Version.create! :valid_from => Time.local(2010, 10, 30), :valid_to => Bitemporal::TIME_MAX, :created_at => Time.local(2010, 10, 30), :expired_at => Time.local(2010, 10, 31), :firstname => "Benoit"
  #       @v2 = BitemporalSpec::Mongoid::Version.create! :valid_from => Time.local(2010, 10, 30), :valid_to => Bitemporal::TIME_MAX, :created_at => Time.local(2010, 10, 31), :expired_at => Bitemporal::TIME_MAX, :firstname => "Benoit", :lastname => "David"
  #       subject.versions = [@v1, @v2]
  #     end
  #     it "should not revalidate expired versions" do
  #       @v1.should_not_receive :valid?
  #       @v2.should_receive(:valid?).and_return true
  #       subject.should be_valid
  #     end
  #   end
  #   context "on update with only one version" do
  #     it "expires old version and add 2 new ones" do
  #       v = BitemporalSpec::Mongoid::Version.create! :valid_from => Time.local(2010, 10, 31), :valid_to => Bitemporal::TIME_MAX, :created_at => Time.local(2010, 10, 31), :expired_at => Bitemporal::TIME_MAX, :firstname => "Benoit"
  #       subject.versions = [v]
  #       subject.should have_versions(%Q{
  #         | firstname | lastname | valid_from | valid_to | created_at | expired_at |
  #         | Benoit    |          | 2010-10-31 | MAX      | 2010-10-31 | MAX        |
  #       })
  #       subject.version_attributes = {:lastname => "David"}
  #       subject.should have_versions(%Q{
  #         | firstname | lastname | valid_from | valid_to   | created_at | expired_at |
  #         | Benoit    |          | 2010-10-31 | 2010-11-01 | 2010-10-31 | MAX        |
  #         | Benoit    | David    | 2010-11-01 | MAX        |            |            |
  #       })
  #       subject.save!
  #       subject.should have_versions(%Q{
  #         | firstname | lastname | valid_from | valid_to   | created_at | expired_at |
  #         | Benoit    |          | 2010-10-31 | MAX        | 2010-10-31 | 2010-11-01 |
  #         | Benoit    |          | 2010-10-31 | 2010-11-01 | 2010-11-01 | MAX        |
  #         | Benoit    | David    | 2010-11-01 | MAX        | 2010-11-01 | MAX        |
  #       })
  #     end
  #     it "takes valid_from from attributes" do
  #       v = BitemporalSpec::Mongoid::Version.create! :valid_from => Time.local(2010, 10, 31), :valid_to => Bitemporal::TIME_MAX, :created_at => Time.local(2010, 10, 31), :expired_at => Bitemporal::TIME_MAX, :firstname => "David"
  #       subject.versions = [v]
  #       subject.should have_versions(%Q{
  #         | firstname | lastname | valid_from | valid_to | created_at | expired_at |
  #         | David     |          | 2010-10-31 | MAX      | 2010-10-31 | MAX        |
  #       })
  #       subject.version_attributes = {:firstname => {:valid_from => "2010-11-10", :value => "Benoit"}, :lastname => "David"}
  #       subject.should have_versions(%Q{
  #         | firstname | lastname | valid_from | valid_to   | created_at | expired_at |
  #         | David     |          | 2010-10-31 | 2010-11-01 | 2010-10-31 | MAX        |
  #         | David     | David    | 2010-11-01 | 2010-11-10 |            |            |
  #         | Benoit    | David    | 2010-11-10 | MAX        |            |            |
  #       })
  #       subject.save!
  #       subject.should have_versions(%Q{
  #         | firstname | lastname | valid_from | valid_to   | created_at | expired_at |
  #         | David     |          | 2010-10-31 | MAX        | 2010-10-31 | 2010-11-01 |
  #         | David     |          | 2010-10-31 | 2010-11-01 | 2010-11-01 | MAX        |
  #         | David     | David    | 2010-11-01 | 2010-11-10 | 2010-11-01 | MAX        |
  #         | Benoit    | David    | 2010-11-10 | MAX        | 2010-11-01 | MAX        |
  #       })
  #     end
  #   end
  # end
end