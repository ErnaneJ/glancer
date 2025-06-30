module Glancer
  module Utils
    class ResultFormatter
      def self.normalize(rows)
        return rows if rows.empty?

        keys = rows.first.keys

        if rows.all? { |r| r.keys.sort == keys.sort }
          normalized = {}

          keys.each do |key|
            normalized[key] = rows.map { |row| row[key] }
          end

          normalized
        else
          rows
        end
      end
    end
  end
end
