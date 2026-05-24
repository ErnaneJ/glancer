# frozen_string_literal: true

module Glancer
  module ApplicationHelper
    # Returns the list of indexed table names once per request (memoized).
    def glancer_table_names
      @glancer_table_names ||= Glancer::Embedding
                               .where(source_type: "schema")
                               .pluck(:source_path)
                               .filter_map { |p| p.split("#").last if p.include?("#") }
                               .reject { |n| n == "foreign_keys" }
                               .uniq
    rescue StandardError
      []
    end
  end
end
