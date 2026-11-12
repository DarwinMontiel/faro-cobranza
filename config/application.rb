require_relative "boot"

require "rails"
# Solo los frameworks que usa la aplicación (sin Active Storage, Action Mailbox ni Action Text).
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Carga las gemas del Gemfile del grupo del entorno actual.
Bundler.require(*Rails.groups)

module FaroCobranza
  class Application < Rails::Application
    # Valores por defecto de Rails 8.1.
    config.load_defaults 8.1

    # lib/ se carga automáticamente, salvo los subdirectorios sin código Ruby.
    config.autoload_lib(ignore: %w[assets tasks])

    # Colombia: zona horaria de Bogotá e interfaz solo en español.
    config.time_zone = "America/Bogota"
    config.i18n.default_locale = :es
    config.i18n.available_locales = [ :es ]
    config.i18n.raise_on_missing_translations = :strict if Rails.env.test?
  end
end
