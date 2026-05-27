# frozen_string_literal: true

# `Book#file_path` historically held an absolute on-disk path, which
# baked the host's mount layout into the database. Switch to a path
# relative to the owning library's root so libraries can be moved /
# remounted without rewriting every row, and so two libraries can hold
# files with the same basename.
class MakeBookFilePathRelative < ActiveRecord::Migration[8.1]
  def up
    # Two libraries can legitimately hold the same relative file_path
    # (e.g. "foo.cbz" in library A and library B), so the unique scope
    # has to include library_id once paths are relative.
    remove_index :books, :file_path if index_exists?(:books, :file_path)
    add_index :books, %i[library_id file_path], unique: true

    # Convert any existing absolute path to its relative form.
    say_with_time "Rewriting Book.file_path to library-relative" do
      ActiveRecord::Base.connection.exec_query(<<~SQL).rows.each do |id, file_path, library_path|
        SELECT books.id, books.file_path, libraries.path
        FROM books
        JOIN libraries ON libraries.id = books.library_id
      SQL
        next if library_path.blank?
        next unless file_path.start_with?(library_path)

        stripped = file_path[library_path.length..]
        relative = stripped.sub(%r{\A/+}, "")
        next if relative.empty? || relative == file_path

        ActiveRecord::Base.connection.exec_update(
          "UPDATE books SET file_path = ? WHERE id = ?",
          "MakeBookFilePathRelative",
          [relative, id]
        )
      end
    end
  end

  def down
    say_with_time "Re-absolutising Book.file_path" do
      ActiveRecord::Base.connection.exec_query(<<~SQL).rows.each do |id, file_path, library_path|
        SELECT books.id, books.file_path, libraries.path
        FROM books
        JOIN libraries ON libraries.id = books.library_id
      SQL
        next if library_path.blank?
        next if file_path.start_with?("/")

        absolute = File.expand_path(File.join(library_path, file_path))
        ActiveRecord::Base.connection.exec_update(
          "UPDATE books SET file_path = ? WHERE id = ?",
          "MakeBookFilePathRelative",
          [absolute, id]
        )
      end
    end

    remove_index :books, %i[library_id file_path] if index_exists?(:books, %i[library_id file_path], unique: true)
    add_index :books, :file_path, unique: true
  end
end
