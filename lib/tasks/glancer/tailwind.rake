namespace :glancer do
  desc "Install Tailwind CSS"
  task :install do
    system "#{RbConfig.ruby} ./bin/rails app:tailwindcss:install"
  end
end
