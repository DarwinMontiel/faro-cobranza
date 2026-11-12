# Configuración de Puma (https://puma.io/puma/Puma/DSL.html).
#
# Cada proceso atiende las solicitudes con un grupo de hilos. Más hilos aumentan el rendimiento
# hasta cierto punto, pero por el GVL de CRuby también aumentan la latencia: 3 es un buen
# equilibrio para una app Rails típica. Todo pool de conexiones (como max_connections en
# config/database.yml) debe tener al menos tantas conexiones como hilos.
#
# WEB_CONCURRENCY controla el número de procesos (por defecto 1; "auto" = uno por CPU).
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Puerto de escucha (3000 por defecto).
port ENV.fetch("PORT", 3000)

# Permite reiniciar con `bin/rails restart`.
plugin :tmp_restart

# En despliegues de un solo servidor, Solid Queue puede correr dentro de Puma.
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]

# Archivo PID solo si se pide explícitamente (en desarrollo: tmp/pids/server.pid).
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
