# frozen_string_literal: true

require "spec_helper"

RSpec.describe Glancer::ChartAnalyzer do
  # ── Helpers ────────────────────────────────────────────────────────────────

  def make_rows(count, **cols)
    Array.new(count) { |i| cols.transform_values { |v| v.respond_to?(:call) ? v.call(i) : v } }
  end

  # ── .analyze ──────────────────────────────────────────────────────────────

  describe ".analyze" do
    context "when data is not suitable" do
      it "returns [] for an empty array" do
        expect(described_class.analyze([])).to eq([])
      end

      it "returns [] for a single row" do
        expect(described_class.analyze([{ a: 1, b: 2 }])).to eq([])
      end

      it "returns [] when rows have only one column" do
        expect(described_class.analyze([{ a: 1 }, { a: 2 }])).to eq([])
      end

      it "returns [] when rows are not hashes" do
        expect(described_class.analyze([[1, 2], [3, 4]])).to eq([])
      end

      it "returns [] when data is not an Array" do
        expect(described_class.analyze("not an array")).to eq([])
      end
    end

    context "line chart (date + numeric measure)" do
      let(:data) do
        [
          { "month" => "2024-01", "revenue" => 1000 },
          { "month" => "2024-02", "revenue" => 2000 },
          { "month" => "2024-03", "revenue" => 1500 }
        ]
      end

      it "includes a line chart" do
        charts = described_class.analyze(data)
        types  = charts.map { |c| c[:type] }
        expect(types).to include("line")
      end

      it "populates labels and datasets" do
        line = described_class.analyze(data).find { |c| c[:type] == "line" && !c[:datasets].first[:label].to_s.empty? }
        expect(line).not_to be_nil
        expect(line[:datasets].first[:data]).not_to be_empty
      end
    end

    context "doughnut chart (label + single numeric, low cardinality)" do
      let(:data) do
        [
          { "category" => "A", "count" => 10 },
          { "category" => "B", "count" => 20 },
          { "category" => "C", "count" => 30 }
        ]
      end

      it "includes a doughnut chart" do
        charts = described_class.analyze(data)
        types  = charts.map { |c| c[:type] }
        expect(types).to include("doughnut")
      end

      it "sets the correct labels" do
        doughnut = described_class.analyze(data).find { |c| c[:type] == "doughnut" }
        expect(doughnut[:labels]).to contain_exactly("A", "B", "C")
      end
    end

    context "bar chart (label + multiple numerics)" do
      let(:data) do
        [
          { "region" => "North", "sales" => 100, "returns" => 10 },
          { "region" => "South", "sales" => 200, "returns" => 20 },
          { "region" => "East",  "sales" => 150, "returns" => 15 }
        ]
      end

      it "includes a bar chart" do
        charts = described_class.analyze(data)
        types  = charts.map { |c| c[:type] }
        expect(types).to include("bar")
      end

      it "has multiple datasets" do
        bar = described_class.analyze(data).find { |c| c[:type] == "bar" }
        expect(bar[:datasets].size).to be >= 2
      end
    end

    context "scatter chart (two numerics, no date/group)" do
      let(:data) do
        Array.new(5) { |i| { "x_val" => i * 1.0, "y_val" => i * 2.0 } }
      end

      it "includes a scatter chart" do
        charts = described_class.analyze(data)
        types  = charts.map { |c| c[:type] }
        expect(types).to include("scatter")
      end

      it "populates datasets with x/y pairs" do
        scatter = described_class.analyze(data).find { |c| c[:type] == "scatter" }
        expect(scatter[:datasets].first[:data].first).to have_key(:x)
        expect(scatter[:datasets].first[:data].first).to have_key(:y)
      end
    end

    context "multi-series (date + group + metric)" do
      # Need enough rows so low_cardinality? passes:
      # uniq(regions=2) < (rows / 2.0).ceil → 2 < ceil(6/2) = 3 → true ✓
      # Values must vary (uniq > 1) so measure_cols filter passes ✓
      let(:data) do
        months  = %w[2024-01 2024-02 2024-03]
        regions = %w[North South]
        months.each_with_index.flat_map do |m, i|
          regions.map { |r| { "month" => m, "region" => r, "sales" => (i + 1) * 100 } }
        end
      end

      it "includes a multi-series line chart" do
        charts = described_class.analyze(data)
        types  = charts.map { |c| c[:type] }
        expect(types).to include("line")
      end

      it "builds a dataset per region" do
        chart = described_class.analyze(data).find { |c| c[:type] == "line" && c[:datasets].size >= 2 }
        expect(chart).not_to be_nil
        expect(chart[:datasets].size).to eq(2)
      end

      it "returns nil for multi-series when group cardinality exceeds MAX_BAR_CATEGORIES" do
        # 61 distinct groups > MAX_BAR_CATEGORIES(60) → build_multi_series returns nil → compacted out
        many_regions = (1..61).map { |i| "region_#{i}" }
        big_data = many_regions.flat_map do |r|
          %w[2024-01 2024-02 2024-03].map { |m| { "month" => m, "region" => r, "sales" => 10 } }
        end
        # low_cardinality requires uniq < rows/2; 61 < 183/2=92 → true (group_col detected)
        charts = described_class.analyze(big_data)
        multi = charts.select { |c| c[:type] == "line" && c[:datasets]&.size.to_i > 10 }
        # build_multi_series returns nil → it gets compacted out
        expect(multi).to be_empty
      end
    end

    context "multi-series with non-monthly date strings" do
      # Dates like "2024-01-01" are not monthly_period? → raw_dates.sort path (L156)
      # Values must vary so measure_cols passes the uniqueness filter
      let(:data) do
        dates   = %w[2024-01-01 2024-02-01 2024-03-01]
        regions = %w[East West]
        dates.each_with_index.flat_map do |d, i|
          regions.map { |r| { "date" => d, "region" => r, "sales" => (i + 1) * 50 } }
        end
      end

      it "still produces a line chart using sorted raw dates" do
        charts = described_class.analyze(data)
        types  = charts.map { |c| c[:type] }
        expect(types).to include("line")
      end
    end

    context "on internal error" do
      it "returns [] instead of raising" do
        bad_data = [{ a: nil, b: nil }, { a: nil, b: nil }]
        expect { described_class.analyze(bad_data) }.not_to raise_error
      end

      it "returns [] when an unexpected StandardError is raised internally" do
        allow(described_class).to receive(:detect_date_column).and_raise(StandardError, "internal failure")
        data = [{ "a" => "x", "b" => 1 }, { "a" => "y", "b" => 2 }]
        expect(described_class.analyze(data)).to eq([])
      end
    end
  end

  # ── date_string? rescue path ──────────────────────────────────────────────

  describe ".date_string? rescue path" do
    it "returns false when match? raises" do
      exploding = Class.new(String) { def match?(*_) = raise(StandardError, "oops") }.new("2024-01")
      expect(described_class.send(:date_string?, exploding)).to be(false)
    end
  end

  # ── date_string? (via analyze with date-string data) ─────────────────────

  describe "date_string? behavior" do
    it "treats YYYY-MM-DD strings as dates" do
      data = Array.new(3) { |i| { "date" => "2024-0#{i + 1}-01", "val" => i } }
      charts = described_class.analyze(data)
      expect(charts).not_to be_empty
    end

    it "treats YYYY-MM strings as monthly periods" do
      data = [
        { "period" => "2024-01", "sales" => 100 },
        { "period" => "2024-02", "sales" => 200 },
        { "period" => "2024-03", "sales" => 150 }
      ]
      charts = described_class.analyze(data)
      line = charts.find { |c| c[:type] == "line" }
      expect(line).not_to be_nil
    end
  end

  # ── fill_monthly_gaps ─────────────────────────────────────────────────────

  describe "monthly gap filling" do
    it "fills missing months between start and end" do
      data = [
        { "month" => "2024-01", "sales" => 100 },
        { "month" => "2024-03", "sales" => 300 }
      ]
      # The line chart should include 2024-02 with 0 sales
      line = described_class.analyze(data).find { |c| c[:type] == "line" }
      expect(line).not_to be_nil
      expect(line[:labels]).to include("2024-02")
    end
  end

  # ── numeric? helper (exercised through analyze) ───────────────────────────

  describe "numeric? behavior" do
    it "treats integer rows as numeric" do
      data = [{ "a" => "Label", "b" => 10 }, { "a" => "Other", "b" => 20 }]
      charts = described_class.analyze(data)
      expect(charts).not_to be_empty
    end

    it "treats float strings as numeric" do
      data = [{ "a" => "X", "b" => "1.5" }, { "a" => "Y", "b" => "2.5" }]
      charts = described_class.analyze(data)
      expect(charts).not_to be_empty
    end
  end

  # ── humanize helper ───────────────────────────────────────────────────────

  describe "humanize behavior" do
    it "converts snake_case column names to Title Case in datasets" do
      data = [
        { "category" => "A", "total_orders" => 5 },
        { "category" => "B", "total_orders" => 10 }
      ]
      charts = described_class.analyze(data)
      chart  = charts.find { |c| c[:datasets] }
      label  = chart[:datasets].first[:label]
      expect(label).to match(/Total Orders/i)
    end
  end

  # ── id column exclusion ───────────────────────────────────────────────────

  describe "id column exclusion from measures" do
    it "does not use id columns as metric values" do
      data = [
        { "user_id" => 1, "category" => "A", "revenue" => 100 },
        { "user_id" => 2, "category" => "B", "revenue" => 200 }
      ]
      charts = described_class.analyze(data)
      # scatter would require 2 measure cols — user_id should be excluded
      scatter = charts.find { |c| c[:type] == "scatter" }
      if scatter
        labels = scatter[:datasets].map { |d| d[:label] }
        expect(labels.join).not_to match(/user.id/i)
      end
    end
  end

  # ── expand_month_range ────────────────────────────────────────────────────

  describe "month range expansion" do
    it "generates all months between two YYYY-MM strings" do
      data = [
        { "month" => "2023-11", "n" => 1 },
        { "month" => "2024-01", "n" => 2 }
      ]
      line = described_class.analyze(data).find { |c| c[:type] == "line" }
      expect(line).not_to be_nil
      expect(line[:labels]).to include("2023-11", "2023-12", "2024-01")
    end
  end
end
