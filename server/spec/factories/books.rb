# frozen_string_literal: true

FactoryBot.define do
  factory :book do
    library
    sequence(:title) { |n| "Book #{n}" }
    sequence(:file_path) { |n| "/mnt/books/library-1/book-#{n}.cbz" }
    file_format { :cbz }
    file_size { 1024 }
  end
end
