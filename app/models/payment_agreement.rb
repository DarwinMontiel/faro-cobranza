class PaymentAgreement < ApplicationRecord
  MIN_COVERAGE = BigDecimal("0.6")   # el acuerdo debe cubrir al menos el 60 % del saldo
  MAX_COVERAGE = BigDecimal("1.5")   # y no más del 150 % (capital + intereses de mora)
  MAX_INSTALLMENTS = 36
  GRACE_DAYS = 5 # días de gracia después del vencimiento de una cuota antes de declarar el incumplimiento

  # Calendario de días hábiles inyectable (en pruebas se reemplaza por uno sin red).
  class_attribute :calendar_override, instance_accessor: false

  def self.calendar
    calendar_override || HolidayCalendar.default
  end

  belongs_to :obligation
  belongs_to :user
  has_many :installments, -> { order(:number) }, dependent: :destroy, inverse_of: :payment_agreement

  accepts_nested_attributes_for :installments, allow_destroy: true,
    reject_if: ->(attrs) { attrs["amount"].blank? && attrs["due_on"].blank? }

  enum :status, { active: "active", fulfilled: "fulfilled", broken: "broken", cancelled: "cancelled" },
    default: :active, validate: true

  attribute :reference, default: -> { "AC-#{SecureRandom.hex(6).upcase}" }

  validates :total_amount, numericality: { greater_than: 0 }
  validates :reference, presence: true, uniqueness: true, length: { maximum: 64 }
  validates :notes, length: { maximum: 2_000 }
  validate :installments_count_in_range
  validate :installments_add_up_to_total
  validate :coverage_within_policy, if: -> { obligation && total_amount }
  validate :due_dates_are_valid, on: :create
  validate :single_active_agreement, if: :active?

  # Acuerdos vigentes con alguna cuota impaga vencida hace más de GRACE_DAYS días.
  scope :overdue_beyond_grace, ->(as_of = Date.current) {
    active.where(id: Installment.where(paid_at: nil).where(due_on: ...(as_of - GRACE_DAYS)).select(:payment_agreement_id))
  }

  # Marca como incumplidos los acuerdos vencidos y devuelve sus obligaciones a "en mora".
  # Devuelve las referencias afectadas (para el log del job).
  def self.mark_broken!(as_of: Date.current)
    transaction do
      agreements = overdue_beyond_grace(as_of).lock.pluck(:id, :obligation_id, :reference)
      return [] if agreements.empty?

      ids, obligation_ids, references = agreements.transpose
      now = Time.current
      where(id: ids).update_all(status: "broken", updated_at: now)
      Obligation.in_agreement.where(id: obligation_ids).update_all(status: "delinquent", updated_at: now)
      references
    end
  end

  def paid_amount
    installments.select(&:paid?).sum(&:amount)
  end

  def next_installment
    installments.reject(&:paid?).min_by(&:due_on)
  end

  def to_param
    reference
  end

  private
    def live_installments
      installments.reject(&:marked_for_destruction?)
    end

    def installments_count_in_range
      count = live_installments.size
      return if count.between?(1, MAX_INSTALLMENTS)

      errors.add(:installments, :count_out_of_range, max: MAX_INSTALLMENTS)
    end

    def installments_add_up_to_total
      return if total_amount.blank? || live_installments.empty?

      sum = live_installments.sum { |i| i.amount.to_d }
      return if sum == total_amount.to_d

      errors.add(:total_amount, :does_not_match_installments,
        sum: ActiveSupport::NumberHelper.number_to_currency(sum, precision: 0))
    end

    def coverage_within_policy
      balance = obligation.principal_balance
      return if balance.zero?

      if total_amount < balance * MIN_COVERAGE
        errors.add(:total_amount, :below_minimum_coverage, percent: (MIN_COVERAGE * 100).to_i)
      elsif total_amount > balance * MAX_COVERAGE
        errors.add(:total_amount, :above_maximum_coverage, percent: (MAX_COVERAGE * 100).to_i)
      end
    end

    def due_dates_are_valid
      dates = live_installments.sort_by { |i| i.number.to_i }.map(&:due_on)
      return if dates.any?(&:nil?)

      errors.add(:installments, :first_due_in_past) if dates.first && dates.first < Date.current
      errors.add(:installments, :dates_not_increasing) unless dates.each_cons(2).all? { |a, b| b > a }
      non_business = dates.reject { |d| self.class.calendar.business_day?(d) }
      return if non_business.empty?

      errors.add(:installments, :non_business_days, dates: non_business.map { |d| I18n.l(d) }.join(", "))
    end

    def single_active_agreement
      scope = PaymentAgreement.active.where(obligation_id: obligation_id)
      scope = scope.where.not(id: id) if persisted?
      errors.add(:obligation, :already_has_active_agreement) if scope.exists?
    end
end
