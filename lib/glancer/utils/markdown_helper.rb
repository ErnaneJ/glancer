require "commonmarker"
module Glancer
  module Utils
    class MarkdownHelper
      def self.markdown_to_html(markdown_text)
        content = Commonmarker.to_html(markdown_text, options: {
                                         parse: { smart: true },
                                         render: { unsafe: true, escape: false, github_pre_lang: true,
                                                   ignore_empty_links: true },
                                         plugins: { syntax_highlighter: { theme: "InspiredGitHub" } }
                                       })

        content.gsub!(%r{<table.*?</table>}m) do |table_html|
          %(<div class="table-scroll-wrapper"><div class="table-scroll-inner">#{table_html}</div></div>)
        end

        content
      end

      def self.extract_sql_from_markdown(markdown)
        match = markdown.match(/```sql\n(.+?)\n```/m)
        match ? match[1].strip : ""
      end
    end
  end
end
