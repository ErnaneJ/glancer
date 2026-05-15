# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
module Glancer
  # Analyzes query result data and returns an array of Chart.js-compatible config hashes.
  # Returns [] when no meaningful chart can be produced. No data is sent to any AI.
  class ChartAnalyzer
    MIN_ROWS           = 2
    MAX_PIE_CATEGORIES = 8
    MAX_LINE_POINTS    = 500
    MAX_BAR_CATEGORIES = 60
    MAX_SCATTER_POINTS = 1000

    def self.analyze(data)
      return [] unless suitable?(data)

      keys        = data.first.keys
      date_col    = detect_date_column(data, keys)
      id_cols     = detect_id_columns(keys)
      all_numeric = detect_all_numeric(data, keys)

      measure_cols = (all_numeric - id_cols).select do |k|
        data.map { |r| r[k] }.compact.map { |v| to_f(v) }.uniq.size > 1
      end

      group_col = detect_group_column(data, keys, date_col: date_col, measure_cols: measure_cols)
      label_col = detect_label_column(data, keys, exclude: [date_col, group_col].compact + all_numeric)

      charts = []

      charts << build_multi_series(data, date_col, group_col, measure_cols.first) \
        if date_col && group_col && measure_cols.any?

      if date_col && measure_cols.any? && !group_col && data.size <= MAX_LINE_POINTS
        filled = fill_monthly_gaps(data, date_col, measure_cols)
        charts << build_line(filled, date_col, measure_cols)
      end

      if !date_col && !group_col && label_col && measure_cols.any?
        unique_labels = data.map { |r| r[label_col] }.uniq.size
        if unique_labels <= MAX_BAR_CATEGORIES
          charts << if measure_cols.size == 1 && unique_labels <= MAX_PIE_CATEGORIES
                      build_doughnut(data, label_col, measure_cols.first)
                    else
                      build_bar(data, label_col, measure_cols)
                    end
        end
      end

      if measure_cols.size >= 2 && date_col.nil? && group_col.nil? && data.size <= MAX_SCATTER_POINTS
        charts << build_scatter(data, measure_cols[0], measure_cols[1])
      end

      charts.compact
    rescue StandardError
      []
    end

    # ── Column classification ─────────────────────────────────────────────────

    def self.detect_id_columns(keys)
      keys.select { |k| k.to_s.match?(/\A\w+_id\z|\Aid\z/i) }
    end

    def self.detect_all_numeric(data, keys)
      keys.select do |k|
        vals = data.map { |r| r[k] }.compact
        vals.any? && vals.all? { |v| numeric?(v) }
      end
    end

    def self.detect_group_column(data, keys, date_col:, measure_cols:)
      return nil unless date_col

      id_like = keys.select { |k| k.to_s.match?(/\A\w+_id\z|\Aid\z/i) }
      strings = (keys - [date_col]).select { |k| data.first[k].is_a?(String) || data.first[k].is_a?(Symbol) }
      candidates = (id_like + strings) - measure_cols
      candidates.find { |k| low_cardinality?(data, k) }
    end

    def self.low_cardinality?(data, col)
      uniq = data.map { |r| r[col] }.uniq.size
      uniq <= 30 && uniq < (data.size / 2.0).ceil
    end

    def self.detect_label_column(data, keys, exclude: [])
      (keys - exclude).find { |k| data.first[k].is_a?(String) || data.first[k].is_a?(Symbol) }
    end

    # ── Date detection ────────────────────────────────────────────────────────

    def self.detect_date_column(data, keys)
      date_kw = /\A(date|time|month|year|day|week|quarter|period|created|updated|at)\z/i
      loose   = /date|time|month|year|day|week|period|created|updated/i

      named = keys.find { |k| k.to_s.match?(date_kw) } ||
              keys.find { |k| k.to_s.match?(loose) }
      return named if named && date_values?(data, named)

      keys.find { |k| date_values?(data, k) }
    end

    def self.date_values?(data, col)
      samples = data.first(5).map { |r| r[col] }.compact
      return false if samples.empty?

      samples.all? { |v| v.is_a?(Date) || v.is_a?(Time) || date_string?(v) }
    end

    def self.date_string?(val)
      return false unless val.is_a?(String)

      val.match?(%r{\A\d{4}[-/]\d{2}([-/]\d{2})?|\A\d{2}[-/]\d{2}[-/]\d{4}|\A\d{4}-\d{2}\z})
    rescue StandardError
      false
    end

    def self.monthly_period?(str)
      str.to_s.match?(/\A\d{4}-\d{2}\z/)
    end

    # ── Date gap filling ──────────────────────────────────────────────────────

    def self.fill_monthly_gaps(data, date_col, measure_cols)
      dates = data.map { |r| r[date_col].to_s }
      return data unless dates.all? { |d| monthly_period?(d) }

      by_date    = data.each_with_object({}) { |row, h| h[row[date_col].to_s] = row }
      all_months = expand_month_range(dates.min, dates.max)
      base_row   = data.first.transform_values { nil }
      zero_fill  = measure_cols.each_with_object({}) { |c, h| h[c] = 0 }

      all_months.map do |month|
        by_date[month] || base_row.merge({ date_col => month }).merge(zero_fill)
      end
    end

    def self.expand_month_range(min_str, max_str)
      current = Date.parse("#{min_str}-01")
      last    = Date.parse("#{max_str}-01")
      months  = []
      while current <= last
        months << current.strftime("%Y-%m")
        current >>= 1
      end
      months
    end

    # ── Multi-series pivot builder ────────────────────────────────────────────

    def self.build_multi_series(data, date_col, group_col, metric_col)
      raw_dates = data.map { |r| r[date_col].to_s }.uniq
      x_labels = if raw_dates.all? { |d| monthly_period?(d) }
                   expand_month_range(raw_dates.min, raw_dates.max)
                 else
                   raw_dates.sort
                 end
      group_vals = data.map { |r| r[group_col] }.uniq.sort_by(&:to_s)
      return nil if group_vals.size > MAX_BAR_CATEGORIES

      lookup   = data.each_with_object({}) { |r, h| h[[r[date_col].to_s, r[group_col]]] = to_f(r[metric_col]) }
      datasets = group_vals.map { |gv| { label: gv.to_s, data: x_labels.map { |xl| lookup[[xl, gv]] || 0 } } }

      { type: "line", labels: x_labels, datasets: datasets }
    end

    # ── Simple chart builders ─────────────────────────────────────────────────

    def self.build_line(data, date_col, measure_cols)
      sets = measure_cols.map { |col| { label: humanize(col), data: data.map { |r| to_f(r[col]) } } }
      { type: "line", labels: data.map { |r| r[date_col].to_s }, datasets: sets }
    end

    def self.build_bar(data, label_col, measure_cols)
      sets = measure_cols.map { |col| { label: humanize(col), data: data.map { |r| to_f(r[col]) } } }
      { type: "bar", labels: data.map { |r| r[label_col].to_s }, datasets: sets }
    end

    def self.build_doughnut(data, label_col, metric_col)
      {
        type: "doughnut",
        labels: data.map { |r| r[label_col].to_s },
        datasets: [{ label: humanize(metric_col), data: data.map { |r| to_f(r[metric_col]) } }]
      }
    end

    def self.build_scatter(data, x_col, y_col)
      {
        type: "scatter",
        labels: nil,
        xLabel: humanize(x_col),
        yLabel: humanize(y_col),
        datasets: [{
          label: "#{humanize(x_col)} × #{humanize(y_col)}",
          data: data.map { |r| { x: to_f(r[x_col]), y: to_f(r[y_col]) } }
        }]
      }
    end

    # ── Helpers ───────────────────────────────────────────────────────────────

    def self.suitable?(data)
      data.is_a?(Array) &&
        data.size >= MIN_ROWS &&
        data.first.is_a?(Hash) &&
        data.first.keys.size >= 2
    end

    def self.numeric?(val)
      val.is_a?(Integer) || val.is_a?(Float) ||
        (val.is_a?(String) && val.strip.match?(/\A-?\d+(\.\d+)?\z/))
    end

    def self.to_f(val)
      return val.to_f if val.is_a?(Numeric)

      val.to_s.gsub(",", ".").to_f
    end

    def self.humanize(col)
      col.to_s.tr("_", " ").split.map(&:capitalize).join(" ")
    end

    private_class_method :suitable?, :detect_id_columns, :detect_all_numeric,
                         :detect_group_column, :low_cardinality?, :detect_label_column,
                         :detect_date_column, :date_values?, :date_string?, :monthly_period?,
                         :fill_monthly_gaps, :expand_month_range, :build_multi_series,
                         :build_line, :build_bar, :build_doughnut, :build_scatter,
                         :numeric?, :to_f, :humanize
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
