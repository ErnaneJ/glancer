module Glancer
  class SettingsController < ApplicationController
    layout "glancer/application"

    def show
      @chats = Glancer::Chat.order(created_at: :desc)
      @settings = {
        ui_language: Glancer::Setting.get("ui_language", default: "en"),
        speech_language: Glancer::Setting.get("speech_language", default: "auto"),
        custom_instructions: Glancer::Setting.get("custom_instructions", default: "")
      }
      @glancer_config = Glancer.configuration
    end

    def update
      allowed = params.require(:settings).permit(:ui_language, :speech_language, :custom_instructions)
      Glancer::Setting.set_many(allowed.to_h)
      redirect_to glancer.settings_path, notice: t("glancer.settings.saved")
    end
  end
end
