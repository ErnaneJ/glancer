# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::Utils::RateLimitRetry do
  before do
    Glancer.configuration.max_llm_retries = 3
    Glancer.configuration.llm_retry_delay = 60
    allow(described_class).to receive(:sleep)
    allow(Glancer::Utils::Logger).to receive(:warn)
  end

  describe ".with_retry" do
    context "when the block succeeds on the first attempt" do
      it "returns the block result without retrying" do
        result = described_class.with_retry(context: "Test") { 42 }
        expect(result).to eq(42)
        expect(described_class).not_to have_received(:sleep)
      end
    end

    context "when the block raises a non-rate-limit error" do
      it "re-raises immediately without retrying" do
        calls = 0
        expect do
          described_class.with_retry(context: "Test") do
            calls += 1
            raise StandardError, "some other error"
          end
        end.to raise_error(StandardError, "some other error")
        expect(calls).to eq(1)
        expect(described_class).not_to have_received(:sleep)
      end
    end

    context "when the block raises a rate-limit error" do
      it "retries up to max_retries times then re-raises" do
        calls = 0
        expect do
          described_class.with_retry(context: "Test", max_retries: 2) do
            calls += 1
            raise StandardError, "You exceeded your current quota"
          end
        end.to raise_error(StandardError, "You exceeded your current quota")
        expect(calls).to eq(3) # 1 initial + 2 retries
      end

      it "logs a warning on each retry" do
        expect do
          described_class.with_retry(context: "Test", max_retries: 1) do
            raise StandardError, "rate limit exceeded"
          end
        end.to raise_error(StandardError)
        expect(Glancer::Utils::Logger).to have_received(:warn).with("Test", %r{Rate limit hit \(attempt 1/1\)})
      end

      it "sleeps for the base delay when no retry-after hint is present" do
        expect do
          described_class.with_retry(context: "Test", max_retries: 1, base_delay: 10) do
            raise StandardError, "quota exceeded"
          end
        end.to raise_error(StandardError)
        expect(described_class).to have_received(:sleep).with(10)
      end

      it "sleeps for the hint delay when a retry-after hint is present" do
        expect do
          described_class.with_retry(context: "Test", max_retries: 1, base_delay: 60) do
            raise StandardError, "quota exceeded. Please retry in 51.63s"
          end
        end.to raise_error(StandardError)
        expect(described_class).to have_received(:sleep).with(51.63)
      end

      it "uses exponential backoff when no hint is present" do
        sleep_calls = []
        allow(described_class).to receive(:sleep) { |t| sleep_calls << t }

        expect do
          described_class.with_retry(context: "Test", max_retries: 3, base_delay: 10) do
            raise StandardError, "resource exhausted"
          end
        end.to raise_error(StandardError)

        # attempt 1 → 10 * 2^0 = 10, attempt 2 → 10 * 2^1 = 20, attempt 3 → 10 * 2^2 = 40
        expect(sleep_calls).to eq([10, 20, 40])
      end

      it "succeeds if a later attempt does not raise" do
        calls = 0
        result = described_class.with_retry(context: "Test", max_retries: 2) do
          calls += 1
          raise StandardError, "too many requests" if calls < 3

          "ok"
        end
        expect(result).to eq("ok")
        expect(calls).to eq(3)
      end

      it "reads max_retries from configuration when not supplied" do
        Glancer.configuration.max_llm_retries = 1
        calls = 0
        expect do
          described_class.with_retry(context: "Test") do
            calls += 1
            raise StandardError, "quota exceeded"
          end
        end.to raise_error(StandardError)
        expect(calls).to eq(2) # 1 initial + 1 from config
      end

      it "reads base_delay from configuration when not supplied" do
        Glancer.configuration.llm_retry_delay = 5
        expect do
          described_class.with_retry(context: "Test", max_retries: 1) do
            raise StandardError, "resource exhausted"
          end
        end.to raise_error(StandardError)
        expect(described_class).to have_received(:sleep).with(5)
      end

      it "does not retry when max_retries is 0" do
        calls = 0
        expect do
          described_class.with_retry(context: "Test", max_retries: 0) do
            calls += 1
            raise StandardError, "rate limit"
          end
        end.to raise_error(StandardError)
        expect(calls).to eq(1)
        expect(described_class).not_to have_received(:sleep)
      end
    end

    context "rate limit error detection" do
      {
        "rate limit" => /rate.?limit/i,
        "quota exceeded" => /quota.?exceed/i,
        "You exceeded your current quota" => /exceeded.?your.?current.?quota/i,
        "Too Many Requests" => /too.?many.?request/i,
        "RESOURCE_EXHAUSTED" => /resource.?exhausted/i,
        "HTTP 429 error" => /\b429\b/
      }.each_key do |message|
        it "detects '#{message}' as a rate-limit error" do
          calls = 0
          expect do
            described_class.with_retry(context: "Test", max_retries: 1) do
              calls += 1
              raise StandardError, message
            end
          end.to raise_error(StandardError)
          expect(calls).to eq(2) # retried once
        end
      end

      it "detects errors whose class name contains 'rate_limit'" do
        klass = Class.new(StandardError) { def self.name = "SomeRateLimitError" }
        calls = 0
        expect do
          described_class.with_retry(context: "Test", max_retries: 1) do
            calls += 1
            raise klass, "any message"
          end
        end.to raise_error(klass)
        expect(calls).to eq(2)
      end
    end

    context "retry-after hint parsing" do
      [
        ["Please retry in 51.632812448s", 51.632812448],
        ["retry in 30s", 30.0],
        ["RETRY IN 120.5s now", 120.5],
        ["retryIn 0s — ignored", nil],
        ["no hint here", nil]
      ].each do |message, expected|
        it "parses #{expected.inspect} from '#{message}'" do
          sleep_calls = []
          allow(described_class).to receive(:sleep) { |t| sleep_calls << t }
          expect do
            described_class.with_retry(context: "Test", max_retries: 1, base_delay: 99) do
              raise StandardError, "quota exceeded. #{message}"
            end
          end.to raise_error(StandardError)

          expected_delay = expected || 99
          expect(sleep_calls.first).to eq(expected_delay)
        end
      end
    end
  end
end
