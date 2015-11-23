class AddPreferencesToVariants < ActiveRecord::Migration
  def change
    add_column :variants, :preferences, :text
  end
end
