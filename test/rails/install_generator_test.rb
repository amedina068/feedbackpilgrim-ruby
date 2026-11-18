require "rails_helper"
require "rails/generators"
require "rails/generators/test_case"
require "generators/feedbackpilgrim/install/install_generator"

class FeedbackPilgrim::InstallGeneratorTest < Rails::Generators::TestCase
  tests FeedbackPilgrim::Generators::InstallGenerator
  destination File.expand_path("../../tmp/generator", __dir__)
  setup :prepare_destination

  test "writes the initializer" do
    output = run_generator

    assert_file "config/initializers/feedbackpilgrim.rb" do |initializer|
      assert_match "FeedbackPilgrim.configure do |config|", initializer
      assert_match "Rails.application.credentials.feedbackpilgrim", initializer
    end
    assert_match "bin/rails credentials:edit", output
  end

  test "the initializer is valid Ruby" do
    run_generator

    assert RubyVM::InstructionSequence.compile_file(File.join(destination_root, "config/initializers/feedbackpilgrim.rb"))
  end

  test "bin/rails generate finds the generator by the gem name" do
    assert_equal FeedbackPilgrim::Generators::InstallGenerator, Rails::Generators.find_by_namespace("feedbackpilgrim:install")
  end
end
