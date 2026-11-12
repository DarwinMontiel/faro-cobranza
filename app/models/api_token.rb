# Token de acceso a la API para integraciones (p. ej. bots RPA que registran gestiones).
# Se muestra una sola vez al crearlo; en la base solo queda su SHA-256.
class ApiToken < ApplicationRecord
  PREFIX = "faro_".freeze
  # Prefijo de los tokens emitidos antes del cambio de nombre (Cartera CRM): siguen funcionando
  # hasta que se revoquen, para no romper integraciones existentes.
  LEGACY_PREFIXES = [ "crm_" ].freeze

  belongs_to :user

  attr_reader :plain_token

  validates :name, presence: true, length: { maximum: 60 }
  validates :token_digest, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  scope :usable, -> { where(revoked_at: nil) }

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  def self.authenticate(token)
    return if token.blank? || !token.start_with?(PREFIX, *LEGACY_PREFIXES)

    usable.find_by(token_digest: digest(token))&.tap do |api_token|
      # Evita una escritura por request: actualiza como máximo una vez por minuto.
      api_token.update_column(:last_used_at, Time.current) if api_token.last_used_at.nil? ||
        api_token.last_used_at < 1.minute.ago
    end
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  private
    def generate_token
      @plain_token = "#{PREFIX}#{SecureRandom.base58(32)}"
      self.token_digest = self.class.digest(@plain_token)
    end
end
