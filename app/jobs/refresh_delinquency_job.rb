# Cierre diario de cartera: recalcula los días de mora y declara incumplidos los acuerdos con
# cuotas vencidas más allá del periodo de gracia. Es idempotente: correrlo dos veces el mismo día
# no cambia nada la segunda vez. Programado en config/recurring.yml.
class RefreshDelinquencyJob < ApplicationJob
  queue_as :default

  def perform(as_of = Date.current.iso8601)
    as_of = Date.iso8601(as_of.to_s)
    refreshed = Obligation.refresh_days_past_due!(as_of:)
    broken = PaymentAgreement.mark_broken!(as_of:)

    Rails.logger.info("[RefreshDelinquencyJob] Corte #{as_of}: #{refreshed} obligaciones con mora actualizada, " \
                      "#{broken.size} acuerdos incumplidos#{broken.any? ? " (#{broken.join(", ")})" : ""}")
    { refreshed:, broken: }
  end
end
