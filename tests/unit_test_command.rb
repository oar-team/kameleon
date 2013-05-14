require 'test/unit'
require 'session'

class Kameleon_tests < Test::Unit::TestCase

  def test_debian_squeeze
    sh = Session::new
    sh.execute 'sudo ../kameleon debian_squeeze.yaml'
    assert_equal(0,sh.exit_status)
  end

  def test_debian_etch
    sh = Session::new
    sh.execute 'sudo ../kameleon debian_etch.yaml'
    assert_equal(0,sh.exit_status)
  end


  # def test_lss
  #   sh2 = Session::new
  #   sh2.execute 'lss'
  #   assert_equal(0,sh2.exit_status)
  # end

end
