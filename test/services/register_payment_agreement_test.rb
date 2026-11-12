require "test_helper"

class RegisterPaymentAgreementTest < ActiveSupport::TestCase
  setup do
    @obligation = obligations(:laura_card)
    @params = { total_amount: 2_000_000, reference: "BOT-TASK-123", installments_attributes: plan_attributes(total: 2_000_000) }
  end

  test "crea el acuerdo con sus cuotas y pasa la obligación a 'en acuerdo'" do
    result = nil
    assert_difference -> { PaymentAgreement.count } => 1, -> { Installment.count } => 2 do
      result = RegisterPaymentAgreement.call(obligation: @obligation, user: users(:agent), params: @params)
    end
    assert result.success?
    assert result.created
    assert @obligation.reload.in_agreement?
  end

  test "es idempotente por referencia" do
    first = RegisterPaymentAgreement.call(obligation: @obligation, user: users(:agent), params: @params)
    assert_no_difference -> { PaymentAgreement.count } do
      again = RegisterPaymentAgreement.call(obligation: @obligation, user: users(:agent), params: @params)
      assert again.success?
      assert_not again.created
      assert_equal first.agreement, again.agreement
    end
  end

  # Simula que la búsqueda inicial ocurrió antes de que la otra solicitud confirmara su transacción.
  class LateRetry < RegisterPaymentAgreement
    private
      def existing_agreement
        @lookups = (@lookups || 0) + 1
        @lookups == 1 ? nil : super
      end
  end

  class LateRetryHittingIndex < LateRetry
    private
      def persist(_agreement) = raise(ActiveRecord::RecordNotUnique, "index_payment_agreements_on_reference")
  end

  test "carrera de reintentos con la misma referencia: el perdedor recibe el acuerdo del ganador" do
    winner = RegisterPaymentAgreement.call(obligation: @obligation, user: users(:agent), params: @params)

    assert_no_difference -> { PaymentAgreement.count } do
      [ LateRetry, LateRetryHittingIndex ].each do |racer|
        result = racer.call(obligation: @obligation, user: users(:agent), params: @params)
        assert result.success?, "#{racer}: #{result.agreement.errors.full_messages.to_sentence}"
        assert_not result.created
        assert_equal winner.agreement, result.agreement
      end
    end
  end

  test "una violación de unicidad sin la misma referencia sigue siendo un conflicto" do
    result = LateRetryHittingIndex.call(obligation: @obligation, user: users(:agent),
                                        params: @params.merge(reference: "OTRA-REFERENCIA"))
    assert_not result.success?
    assert result.agreement.errors.of_kind?(:obligation, :already_has_active_agreement)
  end

  test "si el acuerdo es inválido no cambia el estado de la obligación" do
    result = RegisterPaymentAgreement.call(obligation: @obligation, user: users(:agent),
                                           params: @params.merge(total_amount: 10))
    assert_not result.success?
    assert @obligation.reload.delinquent?
    assert result.agreement.errors.any?
  end
end
