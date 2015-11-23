class AddPreferencesToVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :preferences, :text
  end
end
