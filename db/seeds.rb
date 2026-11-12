# Datos de demostración (sintéticos y reproducibles). Uso: bin/rails db:seed
# Ningún dato corresponde a personas reales.

DEMO_PASSWORD = ENV.fetch("DEMO_PASSWORD", "Faro-Demo-2026")

if Client.exists?
  puts "La base ya tiene datos: se omiten los seeds (usa bin/rails db:seed:replant para recrearlos)."
  return
end

rng = Random.new(2026)
pick = ->(options) { options[rng.rand(options.size)] }

FIRST_NAMES = %w[Laura Andrés María Juan Valentina Santiago Camila Carlos Daniela Felipe Natalia Sebastián
                 Paola Julián Sara Diego Juliana Mateo Carolina Alejandro Luisa David Manuela Jorge].freeze
LAST_NAMES = %w[Gómez Rodríguez Martínez García López Hernández Pérez Sánchez Ramírez Torres Díaz Vargas
                Castro Rojas Moreno Jiménez Muñoz Ortiz Rincón Suárez Herrera Medina Restrepo Cárdenas].freeze

ActiveRecord::Base.transaction do
  admin = User.create!(name: "Administradora Demo", email_address: "admin@faro.test",
                       password: DEMO_PASSWORD, role: :admin)
  agents = [ "Ana Lucía Ríos", "Hernán Quintero", "Mónica Arango" ].each_with_index.map do |name, i|
    User.create!(name:, email_address: "gestor#{i + 1}@faro.test", password: DEMO_PASSWORD, role: :agent)
  end

  documents = Set.new
  clients = 120.times.map do
    document = loop do
      candidate = rng.rand(1_000_000_000..1_199_999_999).to_s
      break candidate if documents.add?(candidate)
    end
    Client.create!(
      document_number: document,
      full_name: "#{pick.(FIRST_NAMES)} #{pick.(LAST_NAMES)} #{pick.(LAST_NAMES)}",
      email: rng.rand < 0.8 ? "cliente#{document[-4..]}@correo.test" : nil,
      phone: rng.rand < 0.9 ? "3#{rng.rand(100_000_000..199_999_999)}" : nil,
      city: Client::CITIES[[ 0, 0, 0, 1, 1, 2, 3, 4, 5, 6, 7 ].sample(random: rng)],
      segment: %w[masivo masivo masivo preferente pyme].sample(random: rng)
    )
  end

  sequence = 0
  obligations = clients.flat_map do |client|
    (rng.rand < 0.25 ? 2 : 1).times.map do
      sequence += 1
      days = rng.rand < 0.55 ? 0 : [ rng.rand(1..30), rng.rand(31..90), rng.rand(91..240) ].sample(random: rng)
      Obligation.create!(
        client:,
        number: format("OB-%07d", sequence),
        product: Obligation.products.keys.sample(random: rng),
        principal_balance: (rng.rand(800_000..25_000_000) / 1000) * 1000,
        past_due_since: days.positive? ? Date.current - days : nil,
        status: days.positive? ? :delinquent : :current,
        disbursed_on: Date.current - rng.rand(120..1_200)
      )
    end
  end

  delinquent = obligations.select(&:past_due?)
  outcomes = %w[no_answer no_answer voicemail wrong_number contact_holder contact_third_party refused promise_to_pay promise_to_pay]
  delinquent.each do |obligation|
    rng.rand(1..5).times do
      occurred_at = [ rng.rand(0..29).days.ago.change(hour: rng.rand(8..18), min: rng.rand(0..59)),
                      rng.rand(5..90).minutes.ago ].min # nunca en el futuro
      outcome = outcomes.sample(random: rng)
      promise = outcome == "promise_to_pay"
      CollectionActivity.create!(
        obligation:, user: agents.sample(random: rng), occurred_at:, outcome:,
        channel: %w[call call call whatsapp visit].sample(random: rng),
        source: rng.rand < 0.2 ? :api : :web,
        promise_date: promise ? occurred_at.to_date + rng.rand(1..10) : nil,
        promise_amount: promise ? (obligation.principal_balance * 0.1).round(-3) : nil,
        notes: promise ? "Cliente se compromete a pagar en la fecha acordada." : nil
      )
    end
  end

  calendar = PaymentAgreement.calendar
  delinquent.sample(18, random: rng).each do |obligation|
    total = (obligation.principal_balance * [ 0.7, 0.8, 0.9, 1.0 ].sample(random: rng)).round(-3)
    plan = PaymentPlanBuilder.new(total:, count: rng.rand(2..8), first_due_on: Date.current + rng.rand(3..20), calendar:).call
    result = RegisterPaymentAgreement.call(
      obligation:, user: agents.sample(random: rng),
      params: { total_amount: total, installments_attributes: plan.map(&:to_h) }
    )
    raise "No se pudo crear el acuerdo: #{result.agreement.errors.full_messages}" unless result.success?
  end

  token = admin.api_tokens.create!(name: "Bot RPA de acuerdos (demo)")
  puts "Usuarios: admin@faro.test y gestor1..3@faro.test · contraseña: #{DEMO_PASSWORD}"
  puts "Token de API de demostración (solo se muestra ahora): #{token.plain_token}"
end

puts "Seeds: #{Client.count} clientes, #{Obligation.count} obligaciones, " \
     "#{CollectionActivity.count} gestiones, #{PaymentAgreement.count} acuerdos."
