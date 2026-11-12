ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Gemas del Gemfile.
require "bootsnap/setup" # Arranque más rápido con caché de operaciones costosas.
