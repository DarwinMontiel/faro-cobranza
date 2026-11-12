class ApplicationMailer < ActionMailer::Base
  # Remitente configurable por entorno (ver docs/deployment.md, sección "Correo").
  default from: -> { ENV.fetch("MAILER_FROM", "Faro Cobranza <no-responder@faro-cobranza.test>") }
  layout "mailer"
end
