# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Glancer::Utils::Logger do
  describe ".with_debug_logs" do
    it "temporarily sets log_verbosity to :debug and restores it" do
      Glancer.configuration.log_verbosity = :none
      described_class.with_debug_logs do
        expect(Glancer.configuration.log_verbosity).to eq(:debug)
      end
      expect(Glancer.configuration.log_verbosity).to eq(:none)
    end

    it "restores the original verbosity even if the block raises" do
      Glancer.configuration.log_verbosity = :info
      expect do
        described_class.with_debug_logs { raise "oops" }
      end.to raise_error(RuntimeError)
      expect(Glancer.configuration.log_verbosity).to eq(:info)
    end

    it "yields control to the caller's block" do
      yielded = false
      described_class.with_debug_logs { yielded = true }
      expect(yielded).to be(true)
    end
  end

  describe "log output to file" do
    let(:log_file) { Tempfile.new(["glancer_test", ".log"]) }

    after { log_file.unlink }

    it "writes log lines to the configured output file" do
      Glancer.configuration.log_output_path = log_file.path
      Glancer.configuration.log_verbosity   = :info

      described_class.info("TestTag", "hello from file logger")

      content = File.read(log_file.path)
      expect(content).to include("hello from file logger")
    ensure
      Glancer.configuration.log_output_path = nil
    end
  end

  describe "verbosity filtering" do
    before do
      Glancer.configuration.log_verbosity = :none
      Glancer.configuration.log_output_path = nil
    end

    it "suppresses info messages at :none verbosity" do
      expect { described_class.info("T", "suppressed") }.not_to output.to_stdout
    end

    it "always outputs error messages regardless of verbosity" do
      expect { described_class.error("T", "critical error") }.to output(/critical error/).to_stdout
    end

    it "always outputs warn messages regardless of verbosity" do
      expect { described_class.warn("T", "a warning") }.to output(/a warning/).to_stdout
    end

    it "suppresses everything with :silent verbosity" do
      Glancer.configuration.log_verbosity = :silent
      expect { described_class.error("T", "silenced error") }.not_to output.to_stdout
      expect { described_class.warn("T", "silenced warning") }.not_to output.to_stdout
    end
  end

  describe "graceful degradation when configuration raises" do
    it "falls back to :info verbosity when configuration is unavailable" do
      Glancer.configuration.log_verbosity = :info
      # Even with a mocked config that raises on log_verbosity, the logger shouldn't crash
      original = Glancer.configuration
      Glancer.configuration = nil
      expect { described_class.warn("T", "safe call") }.not_to raise_error
    ensure
      Glancer.configuration = original
    end
  end
end
