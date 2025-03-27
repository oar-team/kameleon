require File.expand_path("../helper", __FILE__)


class TestLocalContext < Minitest::Unit::TestCase
  def setup
    @local = Kameleon::LocalContext.new
  end

  def test_echo_cmd
    out = capture_io{ @local.exec "echo mymessage" }.join ''
    assert_equal "mymessage\n", out
    out = capture_io{ @local.exec "echo >&2 myerror" }.join ''
    assert_equal "myerror\n", out
  end

end
