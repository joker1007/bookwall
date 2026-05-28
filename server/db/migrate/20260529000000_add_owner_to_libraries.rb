# frozen_string_literal: true

class AddOwnerToLibraries < ActiveRecord::Migration[8.1]
  def up
    # Nullable first so existing rows can be backfilled before the NOT NULL flip.
    add_reference :libraries, :owner, foreign_key: {to_table: :users}

    # Existing libraries become owned by the earliest-registered user (the admin).
    first_user_id = select_value("SELECT id FROM users ORDER BY id ASC LIMIT 1")
    if first_user_id
      execute("UPDATE libraries SET owner_id = #{first_user_id.to_i} WHERE owner_id IS NULL")
    end

    change_column_null :libraries, :owner_id, false
  end

  def down
    remove_reference :libraries, :owner
  end
end
