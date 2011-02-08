describe Bitemporal::Mongoid::Version do
  subject{ BitemporalSpec::Mongoid::Version.new }
  before{ Bitemporal.now = nil }
  should_have_field :master_id, :type => BSON::ObjectId
  should_have_field :created_at, :type => Time
  should_have_field :expired_at, :type => Time
  should_have_field :valid_from, :type => Time
  should_have_field :valid_to, :type => Time
  should_validate_presence_of :valid_from
  it do
    time = Time.local 2010, 11, 01
    Bitemporal.now = Time.local 2010, 11, 02
    subject = BitemporalSpec::Mongoid::Version
    subject.at(time).should == subject.where({
      :valid_from.lte => time,
      :valid_to.gt => time,
      :created_at.lte => Bitemporal.now,
      :expired_at.gt => Bitemporal.now,
    })
  end
  describe "#at?(time)" do
    subject { BitemporalSpec::Mongoid::Version.new :valid_from => valid_from, :valid_to => valid_to, :created_at => 1.day.ago, :expired_at => expired_at }
    let(:time) { Time.utc 2011 }
    context "not expired" do
      let(:expired_at) { Bitemporal::TIME_MAX }
      context "and time is in validity interval" do
        let(:valid_from) { time.ago(1.day) }
        let(:valid_to) { time.since(1.day) }
        it { subject.at?(time).should be_true }
      end
      context "and time is in validity interval without upper bound" do
        let(:valid_from) { time.ago(1.day) }
        let(:valid_to) { Bitemporal::TIME_MAX }
        it { subject.at?(time).should be_true }
      end
      context "and time is before validity interval" do
        let(:valid_from) { time.since(1.day) }
        let(:valid_to) { time.since(2.day) }
        it { subject.at?(time).should be_false }
      end
      context "and time is equal to start of the validity interval" do
        let(:valid_from) { time }
        let(:valid_to) { time.since(1.day) }
        it { subject.at?(time).should be_true }
      end
      context "and time is after validity interval" do
        let(:valid_from) { time.ago(2.day) }
        let(:valid_to) { time.ago(1.day) }
        it { subject.at?(time).should be_false }
      end
      context "and time is equal to end of the validity interval" do
        let(:valid_from) { time.ago(1.day) }
        let(:valid_to) { time }
        it { subject.at?(time).should be_false }
      end
      context "and validity interval lenght is zero" do
        let(:valid_from) { time }
        let(:valid_to) { time }
        it { subject.at?(time).should be_false }
      end
    end
    context "expired" do
      let(:expired_at) { time }
      let(:valid_from) { time.ago(1.day) }
      let(:valid_to) { time.since(1.day) }
      it { subject.at?(time).should be_false }
    end
  end
end