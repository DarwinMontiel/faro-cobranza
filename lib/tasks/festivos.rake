namespace :festivos do
  desc "Festivómetro: lista los festivos de Colombia de un año y marca los trasladados por Ley Emiliani"
  task :listar, [ :anio ] => :environment do |_task, args|
    year = Integer(args[:anio] || Date.current.year)
    holidays = ColombianHolidays.for_year(year)

    puts "Festivos de Colombia #{year} (Pascua: #{I18n.l(ColombianHolidays.easter_sunday(year), format: :long)})"
    holidays.each do |holiday|
      mark = holiday.moved? ? "↪ trasladado a lunes (Ley Emiliani)" : ""
      puts format("  %-12<date>s %-28<name>s %<mark>s",
                  date: I18n.l(holiday.date, format: "%a %d %b").capitalize, name: holiday.name, mark:).rstrip
    end
    puts "#{holidays.size} festivos, #{holidays.count(&:moved?)} trasladados."
  end
end
