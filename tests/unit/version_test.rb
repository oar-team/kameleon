require File.expand_path("../../unit_helper", __FILE__)


describe Kameleon do

  it "must be defined" do
    expect(Kameleon::VERSION).to eq("2.0.0.dev")
    # expect(order.total).to eq(Money.new(5.55, :USD))
  end

end
