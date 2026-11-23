class Client < ApplicationRecord
  CITIES = %w[Bogotá Medellín Cali Barranquilla Bucaramanga Cartagena Pereira Manizales].freeze

  has_many :obligations, dependent: :restrict_with_error
  has_many :collection_activities, through: :obligations
  has_many :payment_agreements, through: :obligations

  enum :segment, { masivo: "masivo", preferente: "preferente", pyme: "pyme" },
    default: :masivo, validate: true

  # "9.912.345.678" o "CC 9912345678" -> "9912345678"
  normalizes :document_number, with: ->(value) { value.to_s.gsub(/\D/, "") }
  normalizes :full_name, with: ->(value) { value.squish.split.map(&:capitalize).join(" ") }
  normalizes :email, with: ->(value) { value.strip.downcase.presence }
  normalizes :phone, with: ->(value) { value.gsub(/[^\d+]/, "").presence }

  validates :document_number, presence: true, uniqueness: true, format: { with: /\A\d{6,10}\z/ }
  validates :full_name, presence: true, length: { maximum: 120 }
  validates :city, presence: true, inclusion: { in: CITIES }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :phone, format: { with: /\A\+?\d{7,13}\z/ }, allow_nil: true

  scope :search, lambda { |term|
    term = term.to_s.strip
    next all if term.blank?

    digits = term.gsub(/\D/, "")
    if digits.length >= 4 && digits.length == term.delete(".").delete(" ").length
      where("document_number LIKE ?", "#{sanitize_sql_like(digits)}%")
    else
      where("full_name ILIKE ?", "%#{sanitize_sql_like(term)}%")
    end
  }

  def total_balance
    obligations.sum(:principal_balance)
  end

  def to_param
    document_number
  end
end
