# frozen_string_literal: true

require "commonmarker"
module Glancer
  module Utils
    class MarkdownHelper
      def self.markdown_to_html(markdown_text, schema_base: nil, valid_tables: nil)
        content = Commonmarker.to_html(highlight_mentions(markdown_text, schema_base: schema_base, valid_tables: valid_tables),
                                       options: {
                                         parse: { smart: true },
                                         render: { unsafe: true, github_pre_lang: true }
                                       },
                                       plugins: { syntax_highlighter: { theme: "InspiredGitHub" } })

        content.gsub!(%r{<table.*?</table>}m) do |table_html|
          %(<div class="table-scroll-wrapper"><div class="table-scroll-inner">#{table_html}</div></div>)
        end

        content
      end

      # Wraps @word tokens with a highlight span. Applied before markdown so that
      # the renderer preserves the inline HTML. Skips content inside backtick spans
      # and fenced code blocks so code examples are not affected.
      def self.highlight_mentions(text, schema_base: nil, valid_tables: nil)
        valid_set = valid_tables&.to_set
        # Split on fenced code blocks and inline backtick spans to skip them.
        parts = text.split(/(```[\s\S]*?```|`[^`]*`)/)
        parts.map.with_index do |part, idx|
          if idx.odd?
            part
          else
            # Negative lookbehind prevents matching @ inside emails or identifiers.
            part.gsub(/(?<![a-zA-Z0-9._])@([a-zA-Z]\w*)/) do
              table = Regexp.last_match(1)
              next "@#{table}" if valid_set && !valid_set.include?(table)

              if schema_base
                href = "#{schema_base}?table=#{table}"
                attrs = %( href="#{href}" target="_blank" rel="noopener noreferrer" tabindex="0")
                %(<a class="glancer-mention" data-table="#{table}"#{attrs}>@#{table}</a>)
              else
                %(<a class="glancer-mention" data-table="#{table}" href="#" tabindex="0">@#{table}</a>)
              end
            end
          end
        end.join
      end

      def self.extract_sql_from_markdown(markdown)
        match = markdown.match(/```sql\n(.+?)\n```/m)
        match ? match[1].strip : ""
      end
    end
  end
end
