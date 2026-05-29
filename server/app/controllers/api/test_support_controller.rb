# frozen_string_literal: true

module Api
  class TestSupportController < BaseController
    allow_unauthenticated_access only: %i[reset]

    # POST /api/test_support/reset
    # Truncates application tables and clears Active Storage blobs so that
    # E2E tests can run against a known empty state. Routes are mounted only
    # when ENV["BOOKWALL_E2E_RESET"] == "1", so production never exposes it.
    def reset
      ActiveRecord::Base.transaction do
        Favorite.delete_all
        CollectionBook.delete_all
        Collection.delete_all
        ReadingProgress.delete_all
        UserPreference.delete_all
        LibraryShare.delete_all
        BookAuthor.delete_all
        BookTag.delete_all
        ActiveStorage::Attachment.delete_all
        ActiveStorage::VariantRecord.delete_all
        ActiveStorage::Blob.delete_all
        Book.delete_all
        ScanLog.delete_all
        Series.delete_all
        Tag.delete_all
        Author.delete_all
        Library.delete_all
        ApiToken.delete_all
        Session.delete_all
        User.delete_all
        ScheduledTaskSetting.delete_all
        ActiveRecord::Base.connection.execute("DELETE FROM books_fts")
      end
      cookies.delete(:session_id)
      head :no_content
    end
  end
end
