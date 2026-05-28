# frozen_string_literal: true

# Attaches a placeholder cover to a Book in specs. The bytes are fake: cover
# URL/variant helpers only build signed paths (no image processing), so a
# stub blob is enough for serializer-level assertions.
module CoverAttachmentHelper
  def attach_cover(book, filename: "cover.jpg")
    book.cover.attach(
      io: StringIO.new("fake-jpg-bytes"),
      filename: filename,
      content_type: "image/jpeg"
    )
    book
  end
end
