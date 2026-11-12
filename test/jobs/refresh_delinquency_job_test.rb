require "test_helper"
require "fugit"

class RefreshDelinquencyJobTest < ActiveJob::TestCase
  test "la mora avanza con los días sin tocar la columna a mano" do
    laura = obligations(:laura_card) # vencida hace 45 días
    al_dia = obligations(:laura_loan)

    result = RefreshDelinquencyJob.perform_now((Date.current + 10).iso8601)

    assert_equal 55, laura.reload.days_past_due
    assert_equal "31-60", laura.bucket
    assert_equal 0, al_dia.reload.days_past_due
    assert_equal 2, result[:refreshed], "solo cambian las obligaciones con fecha de vencimiento"
  end

  test "es idempotente: una segunda corrida el mismo día no cambia nada" do
    as_of = (Date.current + 1).iso8601
    RefreshDelinquencyJob.perform_now(as_of)
    assert_equal 0, RefreshDelinquencyJob.perform_now(as_of)[:refreshed]
  end

  test "una obligación al día que vence pasa a 'en mora' y entra en la franja 1-30" do
    obligation = obligations(:laura_loan)
    obligation.update_column(:past_due_since, Date.current)

    RefreshDelinquencyJob.perform_now((Date.current + 3).iso8601)

    obligation.reload
    assert obligation.delinquent?
    assert_equal 3, obligation.days_past_due
    assert_includes Obligation.in_bucket("1-30"), obligation
  end

  test "declara incumplido el acuerdo con cuotas vencidas más allá de la gracia" do
    agreement = payment_agreements(:andres_active)
    second_due = installments(:andres_second).due_on

    within_grace = (second_due + PaymentAgreement::GRACE_DAYS).iso8601
    assert_empty RefreshDelinquencyJob.perform_now(within_grace)[:broken]
    assert agreement.reload.active?

    after_grace = (second_due + PaymentAgreement::GRACE_DAYS + 1).iso8601
    assert_equal [ agreement.reference ], RefreshDelinquencyJob.perform_now(after_grace)[:broken]
    assert agreement.reload.broken?
    assert agreement.obligation.reload.delinquent?, "la obligación vuelve a la bandeja de cobro"
  end

  test "un acuerdo con todas las cuotas vencidas pagadas sigue vigente" do
    installments(:andres_second).update!(paid_at: Time.current)
    assert_empty RefreshDelinquencyJob.perform_now((Date.current + 60).iso8601)[:broken]
    assert payment_agreements(:andres_active).reload.active?
  end

  test "está programado como tarea recurrente de producción" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"))
    task = recurring.dig("production", "refresh_delinquency")
    assert_equal "RefreshDelinquencyJob", task["class"]
    assert Fugit.parse_cron(task["schedule"]), "horario cron válido"
  end
end
