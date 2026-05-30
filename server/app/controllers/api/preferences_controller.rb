# frozen_string_literal: true

module Api
  class PreferencesController < BaseController
    def show
      render json: serialize_preferences
    end

    def update
      pref = Current.user.preference || Current.user.build_preference
      pref.reader_defaults = preference_params.fetch(:reader_defaults, {}).to_h
      pref.save!
      render json: serialize_preferences
    end

    private

    def preference_params
      params.permit(reader_defaults: %i[
        spread direction scale preload_ahead
        font_size theme writing_mode
      ])
    end

    def serialize_preferences
      {reader_defaults: Current.user.reader_defaults}
    end
  end
end
