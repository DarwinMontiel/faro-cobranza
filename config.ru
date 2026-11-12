# Punto de entrada para servidores Rack (Puma).

require_relative "config/environment"

run Rails.application
Rails.application.load_server
