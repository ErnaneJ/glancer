require "rails/generators"
require "rails/generators/base"

module Glancer
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      desc "Installs Glancer: initializer, migrations, and mounts engine"

      def copy_initializer
        template "glancer.rb", "config/initializers/glancer.rb"
      end

      def copy_context_file
        template "llm_context.glancer.md", "config/glancer/llm_context.glancer.md"
      end

      def mount_engine
        inject_into_file "config/routes.rb", after: "Rails.application.routes.draw do\n" do
          "  mount Glancer::Engine => '/glancer'\n"
        end
      end

      def show_readme
        say <<~MSG

          Glancer was successfully installed in your application.

          Next steps:

          1. Review and customize the configuration:
             - File: config/initializers/glancer.rb
             - You can set adapter, read-only DB, LLM provider, and logging options.

          2. Edit the context file (optional but recommended):
             - File: config/llm_context.glancer.md
             - This file is currently ignored (first line is '--glancer-ignore')
             - Remove or change the first line to enable indexing.
             - Use it to describe business rules, table usage, or domain logic.

          3. Apply the database migrations:
             - Run: rails db:migrate

          4. Index your schema, models, and context:
             - Run: rails glancer:index:schema
             - Run: rails glancer:index:context
             - Run: rails glancer:index:models

             - Or, to rebuild all indexes at once:
              - Run: rails glancer:index:all
        MSG
      end
    end
  end
end
