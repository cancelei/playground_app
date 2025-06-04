class CreateLeads < ActiveRecord::Migration[8.0]
  def change
    create_table :leads do |t|
      t.string :name
      t.string :email
      t.string :company_name
      t.text :interest_details
      t.boolean :contacted

      t.timestamps
    end
    add_index :leads, :email, unique: true
  end
end
