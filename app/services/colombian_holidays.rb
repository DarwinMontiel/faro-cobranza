# Festivos de Colombia calculados por ley, para cualquier año.
#
# - Ley 51 de 1983 ("Ley Emiliani"): siete festivos de fecha fija se trasladan al lunes siguiente
#   cuando no caen en lunes.
# - Los festivos religiosos móviles dependen del Domingo de Pascua (algoritmo anónimo gregoriano,
#   también conocido como de Meeus/Jones/Butcher); tres de ellos también se trasladan a lunes.
#
# Es el respaldo de HolidayCalendar: no depende de la red ni de una lista que haya que mantener.
module ColombianHolidays
  Holiday = Data.define(:date, :name, :moved) do
    def moved? = moved
  end

  # Festivos que se celebran el mismo día sin importar en qué día de la semana caigan.
  FIXED = {
    [ 1, 1 ] => "Año Nuevo",
    [ 5, 1 ] => "Día del Trabajo",
    [ 7, 20 ] => "Día de la Independencia",
    [ 8, 7 ] => "Batalla de Boyacá",
    [ 12, 8 ] => "Inmaculada Concepción",
    [ 12, 25 ] => "Navidad"
  }.freeze

  # Festivos de fecha fija que la Ley Emiliani traslada al lunes siguiente.
  EMILIANI = {
    [ 1, 6 ] => "Reyes Magos",
    [ 3, 19 ] => "San José",
    [ 6, 29 ] => "San Pedro y San Pablo",
    [ 8, 15 ] => "Asunción de la Virgen",
    [ 10, 12 ] => "Día de la Raza",
    [ 11, 1 ] => "Todos los Santos",
    [ 11, 11 ] => "Independencia de Cartagena"
  }.freeze

  # Desplazamiento en días desde el Domingo de Pascua; true si se traslada a lunes.
  EASTER_BASED = {
    -3 => [ "Jueves Santo", false ],
    -2 => [ "Viernes Santo", false ],
    39 => [ "Ascensión del Señor", true ],
    60 => [ "Corpus Christi", true ],
    68 => [ "Sagrado Corazón", true ]
  }.freeze

  module_function

  def for_year(year)
    holidays = FIXED.map { |(month, day), name| Holiday.new(Date.new(year, month, day), name, false) }
    holidays += EMILIANI.map { |(month, day), name| to_monday(Date.new(year, month, day), name) }
    easter = easter_sunday(year)
    holidays += EASTER_BASED.map do |offset, (name, emiliani)|
      date = easter + offset
      emiliani ? to_monday(date, name) : Holiday.new(date, name, false)
    end
    holidays.sort_by(&:date)
  end

  def dates(year)
    for_year(year).to_set(&:date)
  end

  def easter_sunday(year)
    a = year % 19
    b, c = year.divmod(100)
    d, e = b.divmod(4)
    f = (b + 8) / 25
    g = (b - f + 1) / 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = c.divmod(4)
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) / 451
    month, day = (h + l - 7 * m + 114).divmod(31)
    Date.new(year, month, day + 1)
  end

  def to_monday(date, name)
    monday = date.monday? ? date : date.next_occurring(:monday)
    Holiday.new(monday, name, monday != date)
  end
  private_class_method :to_monday
end
