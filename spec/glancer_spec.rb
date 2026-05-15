# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer do
  describe "::VERSION" do
    it "is defined and non-nil" do
      expect(Glancer::VERSION).not_to be_nil
    end

    it "is a String" do
      expect(Glancer::VERSION).to be_a(String)
    end

    it "follows semantic versioning format" do
      expect(Glancer::VERSION).to match(/\A\d+\.\d+\.\d+/)
    end
  end

  describe "::Error" do
    it "is a subclass of StandardError" do
      expect(Glancer::Error.ancestors).to include(StandardError)
    end

    it "can be raised and rescued" do
      expect { raise Glancer::Error, "test" }.to raise_error(Glancer::Error, "test")
    end
  end

  describe ".configure" do
    it "yields the configuration object" do
      Glancer.configure do |c|
        expect(c).to be_a(Glancer::Configuration)
      end
    end

    it "persists changes made inside the block" do
      Glancer.configure { |c| c.k = 42 }
      expect(Glancer.configuration.k).to eq(42)
    end

    it "re-uses the existing configuration on repeated calls" do
      Glancer.configure { |c| c.k = 7 }
      Glancer.configure { |c| c.min_score = 0.5 }
      expect(Glancer.configuration.k).to eq(7)
      expect(Glancer.configuration.min_score).to eq(0.5)
    end
  end

  describe ".configuration" do
    it "is accessible after configure" do
      expect(Glancer.configuration).to be_a(Glancer::Configuration)
    end

    it "can be replaced by assignment" do
      new_config = Glancer::Configuration.new
      new_config.k = 99
      Glancer.configuration = new_config
      expect(Glancer.configuration.k).to eq(99)
    end
  end
end
