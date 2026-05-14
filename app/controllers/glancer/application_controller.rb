module Glancer
  class ApplicationController < ::ApplicationController
    before_action :set_glancer_locale

    private

    def set_glancer_locale
      lang = Glancer::Setting.get("ui_language", default: "en")
      I18n.locale = lang.to_sym
    rescue StandardError
      I18n.locale = :en
    end
  end
end
