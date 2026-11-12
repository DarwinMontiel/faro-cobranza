require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Esta configuración tiene prioridad sobre config/application.rb.

  # El código no se recarga entre solicitudes y se carga completo al arrancar.
  config.enable_reloading = false
  config.eager_load = true

  # Sin reportes de error detallados para el usuario final.
  config.consider_all_requests_local = false

  # Caché de fragmentos en las vistas.
  config.action_controller.perform_caching = true

  # Los assets llevan huella digital: se pueden cachear por un año.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # La app corre detrás de un proxy que termina TLS (kamal-proxy): SSL forzado, HSTS y cookies seguras.
  config.assume_ssl = true
  config.force_ssl = true

  # El chequeo de salud /up no se redirige a HTTPS.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Logs a STDOUT etiquetados con el id de la solicitud.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # "debug" registra todo, incluidos datos personales: úsese solo para diagnosticar.
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # El chequeo de salud no llena los logs.
  config.silence_healthcheck_path = "/up"

  # No se registran avisos de obsolescencia.
  config.active_support.report_deprecations = false

  # Caché y cola de trabajos durables en PostgreSQL (Solid Cache y Solid Queue).
  config.cache_store = :solid_cache_store
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Correo (restablecimiento de contraseña). Todo se configura por variables de entorno;
  # ver docs/deployment.md, sección "Correo".
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "localhost"), protocol: "https" }
  if ENV["SMTP_ADDRESS"].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.smtp_settings = {
      address: ENV["SMTP_ADDRESS"],
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
      authentication: ENV["SMTP_USERNAME"].present? ? :plain : nil,
      enable_starttls_auto: true,
      open_timeout: 5,
      read_timeout: 10
    }.compact
  else
    # Sin SMTP configurado no se envían correos (la recuperación de contraseña queda deshabilitada
    # en la práctica); el intento queda en el log.
    config.action_mailer.perform_deliveries = false
  end

  # Si falta una traducción se usa el idioma por defecto.
  config.i18n.fallbacks = true

  # No se vuelca el esquema después de migrar.
  config.active_record.dump_schema_after_migration = false

  # En producción, inspect solo muestra el id (evita filtrar datos personales en logs).
  config.active_record.attributes_for_inspect = [ :id ]

  # Protección contra DNS rebinding: solo se aceptan solicitudes al dominio configurado.
  config.hosts << ENV["APP_HOST"] if ENV["APP_HOST"].present?
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
