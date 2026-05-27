module Api
  # Per-user preferences (currently just reader defaults). Used by the
  # reader UI to apply a sensible starting state for books that haven't
  # been opened before.
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
      params.permit(reader_defaults: %i[spread direction scale])
    end

    def serialize_preferences
      {reader_defaults: Current.user.reader_defaults}
    end
  end
end
