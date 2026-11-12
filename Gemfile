source "https://rubygems.org"

gem "rails", "~> 8.1.4", ">= 8.1.4.1"
# Pipeline de assets moderno [https://github.com/rails/propshaft]
gem "propshaft"
# PostgreSQL para Active Record
gem "pg", "~> 1.1"
# Servidor web Puma [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# JavaScript con import maps, sin bundler de Node [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire: navegación tipo SPA con HTML del servidor [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire: controladores JavaScript pequeños [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Vistas JSON de la API [https://github.com/rails/jbuilder]
gem "jbuilder"
# Traducciones de Rails al español (fechas, números, errores)
gem "rails-i18n", "~> 8.0"

# has_secure_password de Active Model
gem "bcrypt", "~> 3.1.7"

# Windows no trae la base de zonas horarias
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Caché, cola de trabajos y Action Cable respaldados por la base de datos
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Arranque más rápido por caché; se carga en config/boot.rb
gem "bootsnap", require: false

# Despliegue con contenedores Docker [https://kamal-deploy.org]
gem "kamal", require: false

# Compresión, caché de assets y X-Sendfile delante de Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

group :development, :test do
  # Depurador [https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem]
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Gemas con vulnerabilidades conocidas (excepciones en config/bundler-audit.yml)
  gem "bundler-audit", require: false

  # Análisis estático de seguridad [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Estilo de código "omakase" [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Consola en las páginas de error de desarrollo [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Pruebas de sistema en navegador real [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
  # Ninguna prueba sale a internet: las APIs externas se simulan
  gem "webmock", "~> 3.34"
end
