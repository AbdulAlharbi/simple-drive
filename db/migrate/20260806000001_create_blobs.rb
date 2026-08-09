# Metadata tracking table. Stores information *about* every blob the
# service has accepted -- never the data itself (see Storage backends).
class CreateBlobs < ActiveRecord::Migration[6.1]
  def change
    create_table :blobs do |t|
      t.string  :blob_id, null: false           # user-supplied identifier (opaque string)
      t.bigint  :size,    null: false           # decoded size in bytes
      t.string  :backend, null: false           # storage backend the data was written to
      t.timestamps
    end
    add_index :blobs, :blob_id, unique: true
  end
end
