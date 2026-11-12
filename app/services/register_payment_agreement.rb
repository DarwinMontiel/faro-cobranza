# Caso de uso: registrar un acuerdo de pago sobre una obligación.
#
# - Transaccional: el acuerdo, sus cuotas y el cambio de estado de la obligación se guardan
#   juntos o no se guarda nada.
# - Idempotente por referencia: si un integrador (p. ej. un bot RPA) reintenta con la misma
#   referencia, se devuelve el acuerdo existente en lugar de crear uno duplicado. Esto se cumple
#   también cuando dos reintentos llegan al mismo tiempo: el que pierde la carrera (por validación
#   o por el índice único de la base) vuelve a buscar la referencia y responde con el ganador.
class RegisterPaymentAgreement
  Result = Data.define(:agreement, :created) do
    def success? = agreement.persisted? && agreement.errors.empty?
  end

  def self.call(...) = new(...).call

  def initialize(obligation:, user:, params:)
    @obligation = obligation
    @user = user
    @params = params
  end

  def call
    existing = existing_agreement
    return Result.new(agreement: existing, created: false) if existing

    agreement = @obligation.payment_agreements.build(@params.merge(user: @user))
    return Result.new(agreement:, created: true) if persist(agreement)

    resolve_race(agreement) || Result.new(agreement:, created: false)
  rescue ActiveRecord::RecordNotUnique
    # Carrera entre dos solicitudes simultáneas: el índice único de la base gana.
    resolve_race(agreement) || begin
      agreement.errors.add(:obligation, :already_has_active_agreement)
      Result.new(agreement:, created: false)
    end
  end

  private
    def persist(agreement)
      ActiveRecord::Base.transaction do
        raise ActiveRecord::Rollback unless agreement.save

        @obligation.update!(status: :in_agreement)
      end
      agreement.persisted?
    end

    # Si otra solicitud con la misma referencia ganó la carrera, la respuesta es idempotente.
    def resolve_race(agreement)
      existing = existing_agreement
      return unless existing

      Result.new(agreement: existing, created: false)
    end

    def existing_agreement
      reference.present? ? @obligation.payment_agreements.find_by(reference:) : nil
    end

    def reference
      @params[:reference].presence || @params["reference"].presence
    end
end
