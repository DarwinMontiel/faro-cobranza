class Obligation < ApplicationRecord
  # Franjas de mora (aging): mismas definiciones que el pipeline de analítica de cartera.
  BUCKETS = {
    "Al día" => 0..0,
    "1-30" => 1..30,
    "31-60" => 31..60,
    "61-90" => 61..90,
    "91-180" => 91..180,
    ">180" => 181..
  }.freeze

  belongs_to :client
  has_many :collection_activities, -> { order(occurred_at: :desc) }, dependent: :destroy
  has_many :payment_agreements, -> { order(created_at: :desc) }, dependent: :destroy
  has_one :active_agreement, -> { where(status: :active) }, class_name: "PaymentAgreement"

  enum :product, {
    credit_card: "credit_card",
    personal_loan: "personal_loan",
    microcredit: "microcredit",
    vehicle: "vehicle"
  }, validate: true

  enum :status, {
    current: "current",
    delinquent: "delinquent",
    in_agreement: "in_agreement",
    paid_off: "paid_off",
    charged_off: "charged_off"
  }, default: :current, validate: true

  validates :number, presence: true, uniqueness: true, format: { with: /\AOB-\d{7}\z/ }
  validates :principal_balance, numericality: { greater_than_or_equal_to: 0 }
  validates :days_past_due, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :disbursed_on, presence: true

  # Los días de mora se derivan de past_due_since (vencimiento impago más antiguo); la columna
  # days_past_due es un valor materializado para ordenar e indexar, que RefreshDelinquencyJob
  # recalcula cada día.
  before_validation :derive_days_past_due

  scope :past_due, -> { where("days_past_due > 0") }
  scope :in_bucket, ->(bucket) { BUCKETS.key?(bucket) ? where(days_past_due: BUCKETS[bucket]) : none }
  scope :collectible, -> { where(status: %i[delinquent in_agreement]) }

  def self.days_past_due_on(past_due_since, as_of = Date.current)
    past_due_since && past_due_since < as_of ? (as_of - past_due_since).to_i : 0
  end

  # Recalcula la mora de toda la cartera con un solo UPDATE (solo toca filas que cambian) y pasa
  # a "en mora" las obligaciones al día que acaban de vencer. Devuelve cuántas filas cambiaron.
  def self.refresh_days_past_due!(as_of: Date.current)
    days = sanitize_sql_array([ <<~SQL.squish, { as_of: } ])
      CASE WHEN past_due_since IS NULL OR past_due_since >= CAST(:as_of AS date) THEN 0
           ELSE CAST(:as_of AS date) - past_due_since END
    SQL
    now = Time.current
    transaction do
      refreshed = where("days_past_due <> #{days}").update_all([ "days_past_due = #{days}, updated_at = ?", now ])
      current.where("days_past_due > 0").update_all(status: "delinquent", updated_at: now)
      refreshed
    end
  end

  def bucket
    BUCKETS.find { |_, range| range.cover?(days_past_due) }&.first
  end

  def past_due?
    days_past_due.positive?
  end

  # Saldo mínimo que debe cubrir un acuerdo de pago (política de negociación).
  def minimum_agreement_amount
    (principal_balance * PaymentAgreement::MIN_COVERAGE).round(2)
  end

  def to_param
    number
  end

  private
    def derive_days_past_due
      self.days_past_due = self.class.days_past_due_on(past_due_since)
    end
end
