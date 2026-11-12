# Indicadores del tablero con consultas agregadas en la base, sin cargar registros en memoria:
# un SELECT con SUM/COUNT ... FILTER para los saldos de la cartera y un COUNT por cada indicador
# de actividad (gestiones, acuerdos, promesas y cuotas viven en tablas distintas).
class PortfolioSummary
  Snapshot = Data.define(
    :obligations, :total_balance, :past_due_balance, :par30, :past_due_count,
    :active_agreements, :activities_today, :contacts_today, :pending_promises, :installments_due_week
  ) do
    def contact_rate_today = activities_today.zero? ? nil : contacts_today.fdiv(activities_today)
  end

  def self.call(scope: Obligation.all) = new(scope).call

  def initialize(scope)
    @scope = scope.where.not(status: %i[paid_off charged_off])
  end

  def call
    row = @scope.pick(
      Arel.sql("COUNT(*)"),
      Arel.sql("COALESCE(SUM(principal_balance), 0)"),
      Arel.sql("COALESCE(SUM(principal_balance) FILTER (WHERE days_past_due > 0), 0)"),
      Arel.sql("COALESCE(SUM(principal_balance) FILTER (WHERE days_past_due > 30), 0)"),
      Arel.sql("COUNT(*) FILTER (WHERE days_past_due > 0)")
    )
    count, total, past_due, over30, past_due_count = row
    activities = CollectionActivity.today

    Snapshot.new(
      obligations: count,
      total_balance: total,
      past_due_balance: past_due,
      par30: total.to_d.zero? ? nil : (over30.to_d / total.to_d),
      past_due_count:,
      active_agreements: PaymentAgreement.active.count,
      activities_today: activities.count,
      contacts_today: activities.contacts.count,
      pending_promises: CollectionActivity.pending_promises.count,
      installments_due_week: Installment.due_between(Date.current..6.days.from_now.to_date).count
    )
  end

  # Saldo por franja de mora para el gráfico de barras, en una sola consulta (SUM ... FILTER).
  def self.balance_by_bucket(scope: Obligation.all)
    scope = scope.where.not(status: %i[paid_off charged_off])
    sums = Obligation::BUCKETS.values.map do |range|
      condition = range.end ? [ "days_past_due BETWEEN ? AND ?", range.begin, range.end ] : [ "days_past_due >= ?", range.begin ]
      Arel.sql("COALESCE(SUM(principal_balance) FILTER (WHERE #{Obligation.sanitize_sql_array(condition)}), 0)")
    end
    Obligation::BUCKETS.keys.zip(scope.pick(*sums)).to_h
  end
end
