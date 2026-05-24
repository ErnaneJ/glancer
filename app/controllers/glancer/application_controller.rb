# frozen_string_literal: true

module Glancer
  # :nodoc:
  class ApplicationController < ::ApplicationController
    before_action :configure_locale

    # ActionController::Live runs each request in a new thread. Devise/Warden
    # signals unauthenticated access via `throw :warden`, which Rack's middleware
    # normally catches. Inside a Live thread that throw escapes as an
    # UncaughtThrowError. Rescue it here so controllers that include Live (e.g.
    # MessagesController) return a proper response instead of a 500.
    rescue_from UncaughtThrowError do |e|
      raise e unless defined?(::Warden) && e.tag == :warden

      login_path = begin
        main_app.new_user_session_path
      rescue NoMethodError
        "/"
      end
      request.format.html? ? redirect_to(login_path) : head(:unauthorized)
    end

    private

    def configure_locale
      lang = Glancer::Setting.get("ui_language", default: "en")
      I18n.locale = lang.to_sym
    rescue StandardError
      I18n.locale = :en
    end
  end
end
