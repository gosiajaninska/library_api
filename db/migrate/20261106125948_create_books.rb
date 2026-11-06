class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.string :serial_number, null: false
      t.string :title, null: false
      t.string :author, null: false
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :books, :serial_number, unique: true
    add_index :books, :discarded_at

    add_check_constraint :books, "serial_number ~ '^[0-9]{6}$'", name: "books_serial_number_format"
    add_check_constraint :books, "btrim(title) <> ''", name: "books_title_not_blank"
    add_check_constraint :books, "btrim(author) <> ''", name: "books_author_not_blank"
  end
end
