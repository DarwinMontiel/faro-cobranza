require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  test "el correo de restablecimiento está en español y trae un enlace válido" do
    user = users(:agent)
    mail = PasswordsMailer.reset(user)

    assert_equal "Restablece tu contraseña de Faro Cobranza", mail.subject
    assert_equal [ user.email_address ], mail.to
    assert_equal [ "no-responder@faro-cobranza.test" ], mail.from

    html = mail.html_part.body.decoded
    text = mail.text_part.body.decoded
    assert_includes html, "Crear una contraseña nueva"
    assert_match %r{http://example\.com/passwords/[^/\s"]+/edit}, text
    assert_match(/vence en 15 minutos/, text)
    assert_no_match(/password|reset/i, text.gsub(%r{https?://\S+}, ""), "sin restos del texto en inglés")
  end

  test "el remitente se configura por variable de entorno" do
    previous = ENV["MAILER_FROM"]
    ENV["MAILER_FROM"] = "Cobranza <avisos@ejemplo.test>"
    assert_equal [ "avisos@ejemplo.test" ], PasswordsMailer.reset(users(:agent)).from
  ensure
    ENV["MAILER_FROM"] = previous
  end
end
