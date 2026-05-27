# frozen_string_literal: true

# Computes a 0..1 reading progress fraction for a Book given its
# ReadingProgress. Returns nil when no usable signal is available so
# the UI can hide the progress bar instead of pretending.
module ReadingProgressFraction
  module_function

  def call(book, progress)
    return nil if progress.nil?

    case book.file_format.to_s
    when "epub"
      # We don't currently persist the foliate-js fraction. Until that
      # lands, EPUB progress is "started or not" — no fine-grained bar.
      nil
    else
      total = book.page_count.to_i
      return nil if total <= 1
      raw = progress.current_page.to_f / (total - 1)
      [[raw, 0.0].max, 1.0].min
    end
  end
end
