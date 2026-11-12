require "test_helper"

class ColombianHolidaysTest < ActiveSupport::TestCase
  # Calendarios oficiales publicados (verificados contra los decretos de cada año).
  OFFICIAL = {
    2026 => %w[2026-01-01 2026-01-12 2026-03-23 2026-04-02 2026-04-03 2026-05-01 2026-05-18 2026-06-08 2026-06-15
               2026-06-29 2026-07-20 2026-08-07 2026-08-17 2026-10-12 2026-11-02 2026-11-16 2026-12-08 2026-12-25],
    2027 => %w[2027-01-01 2027-01-11 2027-03-22 2027-03-25 2027-03-26 2027-05-01 2027-05-10 2027-05-31 2027-06-07
               2027-07-05 2027-07-20 2027-08-07 2027-08-16 2027-10-18 2027-11-01 2027-11-15 2027-12-08 2027-12-25]
  }.freeze

  test "coincide con el calendario oficial de 2026 y 2027" do
    OFFICIAL.each do |year, dates|
      assert_equal dates.map { |d| Date.iso8601(d) }.to_set, ColombianHolidays.dates(year), "año #{year}"
    end
  end

  test "calcula el Domingo de Pascua" do
    { 2024 => [ 3, 31 ], 2025 => [ 4, 20 ], 2026 => [ 4, 5 ], 2028 => [ 4, 16 ], 2030 => [ 4, 21 ], 2038 => [ 4, 25 ] }
      .each { |year, (month, day)| assert_equal Date.new(year, month, day), ColombianHolidays.easter_sunday(year) }
  end

  test "la Ley Emiliani traslada a lunes y marca el traslado" do
    holidays = ColombianHolidays.for_year(2026).index_by(&:name)

    assert_equal Date.new(2026, 1, 12), holidays["Reyes Magos"].date
    assert holidays["Reyes Magos"].moved?
    assert_equal Date.new(2026, 10, 12), holidays["Día de la Raza"].date, "el 12 de octubre de 2026 ya es lunes"
    assert_not holidays["Día de la Raza"].moved?
    assert_not holidays["Navidad"].moved?, "los festivos fijos no se trasladan"
  end

  test "siempre hay 18 festivos y los trasladados caen en lunes" do
    (2020..2040).each do |year|
      holidays = ColombianHolidays.for_year(year)
      assert_equal 18, holidays.size, "año #{year}"
      assert holidays.select(&:moved?).all? { |h| h.date.monday? }, "año #{year}"
    end
  end
end
