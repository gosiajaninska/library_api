class CreateReaders < ActiveRecord::Migration[8.1]
  def change
    enable_extension "citext"

    create_table :readers do |t|
      t.string :card_number, null: false
      t.citext :email, null: false
      t.string :full_name, null: false

      t.timestamps
    end

    add_index :readers, :card_number, unique: true
    add_index :readers, :email, unique: true

    add_check_constraint :readers, "card_number ~ '^[0-9]{6}$'", name: "readers_card_number_format"
    add_check_constraint :readers, "btrim(email) <> ''", name: "readers_email_not_blank"
    add_check_constraint :readers, "btrim(full_name) <> ''", name: "readers_full_name_not_blank"
  end
end
