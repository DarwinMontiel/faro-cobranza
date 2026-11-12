require "test_helper"

class PaymentAgreementTest < ActiveSupport::TestCase
  setup do
    @obligation = obligations(:laura_card) # saldo 2.450.000
  end

  def build_agreement(total:, installments: plan_attributes(total:))
    @obligation.payment_agreements.build(user: users(:agent), total_amount: total, installments_attributes: installments)
  end

  test "un acuerdo dentro de la política con cuotas en días hábiles es válido" do
    agreement = build_agreement(total: 2_000_000)
    assert agreement.valid?, agreement.errors.full_messages.to_sentence
    assert_match(/\AAC-[0-9A-F]{12}\z/, agreement.reference)
  end

  test "rechaza acuerdos por debajo del 60 % o por encima del 150 % del saldo" do
    low = build_agreement(total: 1_000_000)
    assert_not low.valid?
    assert low.errors.of_kind?(:total_amount, :below_minimum_coverage)

    high = build_agreement(total: 4_000_000)
    assert_not high.valid?
    assert high.errors.of_kind?(:total_amount, :above_maximum_coverage)
  end

  test "la suma de las cuotas debe coincidir con el total" do
    installments = plan_attributes(total: 2_000_000)
    installments.last[:amount] -= 1
    agreement = build_agreement(total: 2_000_000, installments:)
    assert_not agreement.valid?
    assert agreement.errors.of_kind?(:total_amount, :does_not_match_installments)
  end

  test "valida número de cuotas, fechas crecientes, no vencidas y en días hábiles" do
    none = build_agreement(total: 2_000_000, installments: [])
    assert none.tap(&:validate).errors.of_kind?(:installments, :count_out_of_range)

    first, second = business_day_after(Date.current, days: 10), business_day_after(Date.current, days: 3)
    unordered = build_agreement(total: 2_000_000, installments: [
      { number: 1, due_on: first, amount: 1_000_000 }, { number: 2, due_on: second, amount: 1_000_000 }
    ])
    assert unordered.tap(&:validate).errors.of_kind?(:installments, :dates_not_increasing)

    past = build_agreement(total: 2_000_000, installments: [ { number: 1, due_on: Date.yesterday, amount: 2_000_000 } ])
    assert past.tap(&:validate).errors.of_kind?(:installments, :first_due_in_past)

    sunday = Date.current.next_occurring(:sunday)
    weekend = build_agreement(total: 2_000_000, installments: [ { number: 1, due_on: sunday, amount: 2_000_000 } ])
    assert weekend.tap(&:validate).errors.of_kind?(:installments, :non_business_days)
  end

  test "rechaza un festivo según el calendario" do
    holiday = [ Date.current.year, Date.current.year + 1 ].flat_map { |year| ColombianHolidays.dates(year).to_a }
      .select { |d| d > Date.current && !d.on_weekend? }.min

    agreement = build_agreement(total: 2_000_000, installments: [ { number: 1, due_on: holiday, amount: 2_000_000 } ])
    assert agreement.tap(&:validate).errors.of_kind?(:installments, :non_business_days)
  end

  test "solo puede haber un acuerdo vigente por obligación" do
    obligation = obligations(:andres_micro)
    agreement = obligation.payment_agreements.build(user: users(:agent), total_amount: 900_000,
                                                    installments_attributes: plan_attributes(total: 900_000))
    assert_not agreement.valid?
    assert agreement.errors.of_kind?(:obligation, :already_has_active_agreement)
  end

  test "calcula lo pagado y la siguiente cuota" do
    agreement = payment_agreements(:andres_active)
    assert_equal 450_000, agreement.paid_amount
    assert_equal installments(:andres_second), agreement.next_installment
  end
end
