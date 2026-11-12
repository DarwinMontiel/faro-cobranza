require "test_helper"

class PortfolioSummaryTest < ActiveSupport::TestCase
  test "calcula saldos, PAR30 y actividad del día con consultas agregadas" do
    summary = PortfolioSummary.call

    assert_equal 3, summary.obligations
    assert_equal 11_450_000, summary.total_balance
    assert_equal 3_450_000, summary.past_due_balance
    assert_in_delta 3_450_000.0 / 11_450_000, summary.par30, 1e-9
    assert_equal 2, summary.past_due_count
    assert_equal 1, summary.active_agreements
    assert_equal 1, summary.pending_promises
    assert_equal 1, summary.installments_due_week
  end

  test "excluye obligaciones canceladas o castigadas" do
    obligations(:laura_loan).update!(status: :paid_off)
    assert_equal 3_450_000, PortfolioSummary.call.total_balance
  end

  test "agrupa el saldo por franja de mora en una sola consulta" do
    buckets = assert_queries_count(1) { PortfolioSummary.balance_by_bucket }
    assert_equal Obligation::BUCKETS.keys, buckets.keys
    assert_equal 2_450_000, buckets["31-60"]
    assert_equal 1_000_000, buckets["91-180"]
    assert_equal 8_000_000, buckets["Al día"]
    assert_equal 0, buckets[">180"]
  end
end
