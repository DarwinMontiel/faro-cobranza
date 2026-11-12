require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Esta configuración tiene prioridad sobre config/application.rb.

  # Los cambios de código se aplican sin reiniciar el servidor.
  config.enable_reloading = true

  # No se carga todo el código al arrancar.
  config.eager_load = false

  # Reportes de error completos.
  config.consider_all_requests_local = true

  # Cabecera Server-Timing.
  config.server_timing = true

  # Caché de controladores desactivada por defecto; in/rails dev:cache la alterna.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.public_file_server.headers = { "cache-control" => "public, max-age=#{2.days.to_i}" }
  else
    config.action_controller.perform_caching = false
  end

  # Usa :null_store para desactivar toda caché.
  config.cache_store = :memory_store

  # En desarrollo no importa si un correo no se puede enviar.
  config.action_mailer.raise_delivery_errors = false

  # Los cambios en plantillas de correo se ven de inmediato.
  config.action_mailer.perform_caching = false

  # Host de los enlaces de los correos (vista previa en /rails/mailers).
  config.action_mailer.default_url_options = { host: "localhost", port: 3000 }

  # Avisos de obsolescencia en el log.
  config.active_support.deprecation = :log

  # Error al cargar una página si hay migraciones pendientes.
  config.active_record.migration_error = :page_load

  # Señala en el log qué código originó cada consulta.
  config.active_record.verbose_query_logs = true

  # Agrega etiquetas de contexto a las consultas SQL del log.
  config.active_record.query_log_tags_enabled = true

  # Señala en el log qué código encoló cada job.
  config.active_job.verbose_enqueue_logs = true

  # Señala en el log qué código originó cada redirección.
  config.action_dispatch.verbose_redirect_logs = true

  # No registra las solicitudes de assets.
  config.assets.quiet = true

  # Error si falta una traducción.
  # config.i18n.raise_on_missing_translations = true

  # Anota en el HTML el archivo de cada vista renderizada.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Descomentar para permitir Action Cable desde cualquier origen.
  # config.action_cable.disable_request_forgery_protection = true

  # Error si un before_action con only/except menciona acciones inexistentes.
  config.action_controller.raise_on_missing_callback_actions = true

  # Autocorrige con RuboCop los archivos de `bin/rails generate`.
  # config.generators.apply_rubocop_autocorrect_after_generate!
end
