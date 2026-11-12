# Los días de mora dejan de ser un dato estático: se derivan de la fecha desde la que la obligación
# está vencida (cuota impaga más antigua) y un job diario los recalcula.
class AddPastDueSinceToObligations < ActiveRecord::Migration[8.1]
  def up
    add_column :obligations, :past_due_since, :date
    execute <<~SQL
      UPDATE obligations
         SET past_due_since = CURRENT_DATE - days_past_due
       WHERE days_past_due > 0
    SQL
    add_index :obligations, :past_due_since, where: "past_due_since IS NOT NULL"
  end

  def down
    remove_column :obligations, :past_due_since
  end
end
