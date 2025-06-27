require "rails/generators"
require "rails/generators/base"

module Glancer
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      desc "Sets up Glancer: initializer, migrations, and routes"

      def copy_initializer
        template "glancer.rb", "config/initializers/glancer.rb"
      end

      def copy_migrations
        rake "glancer:install:migrations"
      end

      def mount_engine
        route %(
  # Glancer interface
  mount Glancer::Engine, at: "/glancer"
        )
      end

      def show_readme
        say <<~MSG

          ✅ Glancer installed successfully!

          ✔️ Initializer created: config/initializers/glancer.rb
          ✔️ Migrations copied to db/migrate/
          ✔️ Engine mounted at: http://localhost:3000/glancer

          🛠️  Next steps:

          1. Review the generated migrations (optional)
          2. Run:   rails db:migrate
          3. Visit: http://localhost:3000/glancer

        MSG
      end
    end
  end
end
