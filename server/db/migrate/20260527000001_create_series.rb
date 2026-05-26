class CreateSeries < ActiveRecord::Migration[8.1]
  def change
    create_table :series do |t|
      t.references :library, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end
    add_index :series, [:library_id, :name], unique: true
  end
end
