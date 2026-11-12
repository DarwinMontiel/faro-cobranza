ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require_relative "test_helpers/session_test_helper"

# Ninguna prueba sale a internet: las integraciones externas se simulan con WebMock.
WebMock.disable_net_connect!(allow_localhost: true)

# Calendario determinístico: fines de semana + festivos calculados por ley (sin red).
class FakeCalendar
  def initialize(holidays = nil)
    @holidays = holidays&.to_set
    @by_year = Hash.new { |memo, year| memo[year] = ColombianHolidays.dates(year) }
  end

  def holiday?(date) = (@holidays || @by_year[date.year]).include?(date)
  def business_day?(date) = !date.saturday? && !date.sunday? && !holiday?(date)

  def next_business_day(date)
    date += 1 until business_day?(date)
    date
  end
end

# Se fija una sola vez, antes de que los procesos de prueba en paralelo se bifurquen.
PaymentAgreement.calendar_override = FakeCalendar.new

module ActiveSupport
  class TestCase
    # Procesos en Linux/CI; en Windows (sin fork) las pruebas corren en serie.
    parallelize(workers: Gem.win_platform? ? 1 : :number_of_processors)
    fixtures :all

    def business_day_after(date, days: 1)
      PaymentAgreement.calendar.next_business_day(date + days)
    end

    # Plan de cuotas válido (días hábiles, montos que suman el total) como atributos anidados.
    def plan_attributes(total:, count: 2, from: Date.current + 7)
      PaymentPlanBuilder.new(total:, count:, first_due_on: from).call.map(&:to_h)
    end
  end
end

module ApiTestHelper
  VALID_TOKEN = "crm_test_token_valid".freeze

  def api_headers(token = VALID_TOKEN)
    { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }
  end

  def json
    JSON.parse(response.body)
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include ApiTestHelper
end
