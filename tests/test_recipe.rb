require File.expand_path("../helper", __FILE__)


class TestRecipe < Minitest::Unit::TestCase

  def setup
    Kameleon.ui.level = "silent"
    @recipe = Kameleon::Recipe.new File.join(File.dirname(__FILE__), "recipes/dummy_recipe.yaml")
  end

  def test_dummy_recipe_name
    assert_equal @recipe.name, "dummy_recipe"
  end

end
