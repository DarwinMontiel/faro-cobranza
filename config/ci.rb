# CI local: bin/ci ejecuta los mismos pasos que GitHub Actions.

CI.run do
  step "Preparación", "bin/setup --skip-server"

  step "Estilo: RuboCop", "bin/rubocop"

  step "Seguridad: auditoría de gemas", "bin/bundler-audit"
  step "Seguridad: auditoría de importmap", "bin/importmap audit"
  step "Seguridad: Brakeman", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Pruebas: Rails", "bin/rails test"
  step "Pruebas: sistema (Chrome headless)", "bin/rails test:system"
  step "Pruebas: datos de demostración", "env RAILS_ENV=test bin/rails db:seed:replant"
end
