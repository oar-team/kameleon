require File.expand_path("../helper", __FILE__)

describe Kameleon do

  it "must be defined" do
    Kameleon::VERSION.wont_be_nil
  end

end
