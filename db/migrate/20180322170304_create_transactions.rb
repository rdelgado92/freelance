class CreateTransactions < ActiveRecord::Migration
  def change
    create_table :transactions do |t|
      t.string :company
      t.string :amount
      t.string :status

      t.timestamps null: false
    end
  end
end
