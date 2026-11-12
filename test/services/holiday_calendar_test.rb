require "test_helper"

class HolidayCalendarTest < ActiveSupport::TestCase
  API = "https://date.nager.at/api/v3/PublicHolidays/2026/CO".freeze

  setup do
    @now = Time.zone.local(2026, 11, 12, 9)
    @calendar = HolidayCalendar.new(cache: ActiveSupport::Cache::MemoryStore.new, logger: Logger.new(nil),
                                    clock: -> { @now })
  end

  test "consulta la API de festivos y cachea el resultado por año" do
    stub = stub_request(:get, API).to_return(
      status: 200, headers: { "Content-Type" => "application/json" },
      body: [ { date: "2026-12-08", localName: "Inmaculada Concepción" }, { date: "2026-12-25", localName: "Navidad" } ].to_json
    )

    assert @calendar.holiday?(Date.new(2026, 12, 25))
    assert_not @calendar.business_day?(Date.new(2026, 12, 8))
    assert @calendar.business_day?(Date.new(2026, 12, 9))
    assert_requested stub, times: 1
  end

  test "salta fines de semana y festivos al buscar el siguiente día hábil" do
    stub_request(:get, API).to_return(status: 200, body: [ { date: "2026-12-07" } ].to_json)
    # Sábado 5 → domingo 6 → lunes 7 festivo → martes 8.
    assert_equal Date.new(2026, 12, 8), @calendar.next_business_day(Date.new(2026, 12, 5))
  end

  test "si la API falla usa los festivos calculados por ley" do
    stub_request(:get, API).to_return(status: 503)
    assert @calendar.holiday?(Date.new(2026, 12, 25)), "Navidad viene del cálculo por ley"
    assert @calendar.holiday?(Date.new(2026, 11, 16)), "Independencia de Cartagena trasladada a lunes"
  end

  test "si la API no responde a tiempo usa el respaldo" do
    stub_request(:get, API).to_timeout
    assert @calendar.holiday?(Date.new(2026, 1, 1))
  end

  test "una respuesta malformada o vacía también activa el respaldo" do
    stub_request(:get, API).to_return(status: 200, body: [ { fecha: "2026-12-25" } ].to_json)
    assert @calendar.holiday?(Date.new(2026, 12, 25))

    calendar = HolidayCalendar.new(cache: ActiveSupport::Cache::MemoryStore.new, logger: Logger.new(nil))
    stub_request(:get, API).to_return(status: 200, body: "[]")
    assert calendar.holiday?(Date.new(2026, 12, 25))
  end

  test "cubre años fuera de cualquier lista: un acuerdo a 36 cuotas puede llegar a 2029" do
    api_2029 = stub_request(:get, "https://date.nager.at/api/v3/PublicHolidays/2029/CO").to_return(status: 500)
    assert @calendar.holiday?(Date.new(2029, 3, 29)), "Jueves Santo de 2029"
    assert_requested api_2029, times: 1
  end

  test "no memoriza el respaldo para siempre: reintenta la API cuando vence" do
    stub = stub_request(:get, API).to_return({ status: 503 }, { status: 200, body: [ { date: "2026-12-24" } ].to_json })

    assert_not @calendar.holiday?(Date.new(2026, 12, 24)), "respaldo por ley: el 24 no es festivo"
    @calendar.holiday?(Date.new(2026, 12, 25))
    assert_requested stub, times: 1

    @now += HolidayCalendar::FALLBACK_TTL + 1.second
    assert @calendar.holiday?(Date.new(2026, 12, 24)), "pasado el TTL vuelve a la API, que ya responde"
    assert_requested stub, times: 2
  end
end
