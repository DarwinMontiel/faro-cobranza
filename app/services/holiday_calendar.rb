require "net/http"

# Calendario de días hábiles de Colombia.
#
# Consulta la API pública de festivos de Nager.Date (https://date.nager.at) con timeouts cortos y
# cachea la respuesta por año. Si la API no responde, usa ColombianHolidays, que calcula los
# festivos por ley para cualquier año. Un problema de red nunca impide registrar un acuerdo de pago.
#
# El respaldo se recuerda solo durante FALLBACK_TTL: pasado ese tiempo se vuelve a intentar la API,
# para que un corte momentáneo no deje al proceso usando el respaldo hasta el próximo reinicio.
class HolidayCalendar
  API_URL = "https://date.nager.at/api/v3/PublicHolidays/%<year>d/CO".freeze
  CACHE_TTL = 30.days
  FALLBACK_TTL = 10.minutes

  class FetchError < StandardError; end

  Entry = Data.define(:dates, :expires_at) do
    def fresh?(now) = expires_at.nil? || now < expires_at
  end

  def self.default
    @default ||= new
  end

  def initialize(cache: Rails.cache, timeout: 3, logger: Rails.logger, clock: -> { Time.current })
    @cache = cache
    @timeout = timeout
    @logger = logger
    @clock = clock
    @memo = Concurrent::Map.new
  end

  def holidays(year)
    entry = @memo[year]
    return entry.dates if entry&.fresh?(@clock.call)

    @memo[year] = load(year)
    @memo[year].dates
  end

  def holiday?(date)
    holidays(date.year).include?(date)
  end

  def business_day?(date)
    !date.saturday? && !date.sunday? && !holiday?(date)
  end

  def next_business_day(date)
    date += 1 until business_day?(date)
    date
  end

  private
    def load(year)
      dates = @cache.fetch("holiday_calendar/co/#{year}", expires_in: CACHE_TTL) { fetch(year) }
      Entry.new(dates:, expires_at: nil)
    rescue FetchError, Timeout::Error, SystemCallError, SocketError, OpenSSL::SSL::SSLError, JSON::ParserError,
           KeyError, TypeError, Date::Error => e
      @logger.warn("[HolidayCalendar] API de festivos no disponible para #{year} (#{e.class}: #{e.message}); " \
                   "se usan los festivos calculados por ley durante #{FALLBACK_TTL.in_minutes.to_i} minutos")
      Entry.new(dates: ColombianHolidays.dates(year), expires_at: @clock.call + FALLBACK_TTL)
    end

    def fetch(year)
      uri = URI(format(API_URL, year: year))
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                                 open_timeout: @timeout, read_timeout: @timeout) do |http|
        http.get(uri.request_uri, "Accept" => "application/json")
      end
      raise FetchError, "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      dates = JSON.parse(response.body).map { |holiday| Date.iso8601(holiday.fetch("date")) }.to_set
      raise FetchError, "respuesta sin festivos" if dates.empty?

      dates
    end
end
