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
        info = "\e[32m"
        warn = "\e[33m"
        debug = "\e[36m"
        error = "\e[31m"
        reset = "\e[0m"

        say <<~MSG

          #{info}╔════════════════════════════════════════════════════════════════════╗
          ║                 ✔ Glancer installed successfully! ✔                ║
          ╚════════════════════════════════════════════════════════════════════╝#{reset}

          #{debug}Next steps:#{reset}

          #{warn}1. Review and customize the configuration:#{reset}
             ├── File: #{debug}config/initializers/glancer.rb#{reset}
             └── You can set:
                 ✔ Adapter
                 ✔ Read-only DB
                 ✔ LLM provider
                 ✔ Logging options
                 ✔ ...

          #{warn}2. Edit the context file (optional but recommended):#{reset}
             ├── File: #{debug}config/glancer/llm_context.glancer.md#{reset}
             ├── Currently ignored (first line is '#{error}--glancer-ignore#{reset}')
             └── Remove or modify first line to enable indexing.
                 Use it to describe:
                 ✔ Business rules
                 ✔ Table usage
                 ✔ Domain logic
                 ✔ ...

          #{warn}3. Apply the database migrations:#{reset}
             └── Run: #{info}rails db:migrate#{reset}

          #{warn}4. Index your schema, models, and context:#{reset}
             ├── Run: #{info}rails glancer:index:all#{reset}
             └── #{info}✱#{reset} Or do it separately
                 ├── Run: #{info}rails glancer:index:schema#{reset}
                 ├── Run: #{info}rails glancer:index:context#{reset}
                 └── Run: #{info}rails glancer:index:models#{reset}

        MSG
      end
    end
  end
end
