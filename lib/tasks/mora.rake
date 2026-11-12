namespace :mora do
  desc "Ejecuta el cierre diario de cartera ahora: recalcula días de mora y marca acuerdos incumplidos"
  task :recalcular, [ :fecha ] => :environment do |_task, args|
    result = RefreshDelinquencyJob.perform_now(args[:fecha] || Date.current.iso8601)
    puts "Mora actualizada en #{result[:refreshed]} obligaciones; #{result[:broken].size} acuerdos incumplidos."
  end
end
