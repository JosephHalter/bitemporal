require "spec_helper"

describe Bitemporal do
  it("defines TIME_MIN"){ Bitemporal::TIME_MIN.should == Time.utc(0) }
  it("defines TIME_MAX"){ Bitemporal::TIME_MAX.should == Time.utc(9999) }
  describe ".now" do
    before do
      Bitemporal.now = nil
      @now = Timecop.freeze Time.now
    end
    it "defaults to Time.now" do
      Bitemporal.now.should == @now
    end
    it "is memoized" do
      Bitemporal.now
      Timecop.freeze 1.minute.since
      Bitemporal.now.should == @now
    end
    it "can be assigned" do
      Bitemporal.now
      Timecop.freeze 1.minute.since
      Bitemporal.now = Time.now
      Bitemporal.now.should == Time.now
    end
  end
end