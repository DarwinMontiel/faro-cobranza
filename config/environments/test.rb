# Entorno exclusivo para la suite de pruebas. Su base de datos se borra y se recrea en cada
# corrida: no guardes nada ahí.

Rails.application.configure do
  # Esta configuración tiene prioridad sobre config/application.rb.

  # Durante las pruebas no se vigilan archivos: no hace falta recargar.
  config.enable_reloading = false

  # En CI se carga toda la aplicación para detectar errores de carga antes de desplegar;
  # localmente no, para que una sola prueba arranque rápido.
  config.eager_load = ENV["CI"].present?

  # Archivos públicos con cache-control para acelerar las pruebas.
  config.public_file_server.headers = { "cache-control" => "public, max-age=3600" }

  # Reportes de error completos.
  config.consider_all_requests_local = true
  config.cache_store = :null_store

  # Renderiza las páginas de error de excepciones manejables y lanza las demás.
  config.action_dispatch.show_exceptions = :rescuable

  # Sin protección CSRF en pruebas.
  config.action_controller.allow_forgery_protection = false

  # Los correos no salen: se acumulan en ActionMailer::Base.deliveries.
  config.action_mailer.delivery_method = :test

  # Host de los enlaces de los correos.
  config.action_mailer.default_url_options = { host: "example.com" }

  # Avisos de obsolescencia en stderr.
  config.active_support.deprecation = :stderr

  # Error si falta una traducción (se activa en config/application.rb).
  # config.i18n.raise_on_missing_translations = true

  # Anota en el HTML el archivo de cada vista renderizada.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Error si un before_action con only/except menciona acciones inexistentes.
  config.action_controller.raise_on_missing_callback_actions = true
end
