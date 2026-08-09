# Data table for the "database" storage backend. Deliberately separate
# from the blobs metadata table, per the storage design: metadata and
# payload never share a table.
class CreateBlobContents < ActiveRecord::Migration[6.1]
  def change
    create_table :blob_contents do |t|
      t.string :blob_id, null: false
      t.binary :data,    null: false
      t.timestamps
    end
    add_index :blob_contents, :blob_id, unique: true
  end
end
