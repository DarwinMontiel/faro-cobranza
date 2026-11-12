require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:agent) }

  test "muestra el formulario" do
    get new_password_path
    assert_response :success
  end

  test "envía el correo de restablecimiento" do
    post passwords_path, params: { email_address: @user.email_address }
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ]
    assert_redirected_to new_session_path

    follow_redirect!
    assert_notice "enviamos las instrucciones"
  end

  test "con un correo desconocido responde igual pero no envía nada" do
    post passwords_path, params: { email_address: "missing-user@example.com" }
    assert_enqueued_emails 0
    assert_redirected_to new_session_path

    follow_redirect!
    assert_notice "enviamos las instrucciones"
  end

  test "abre el formulario con un token válido" do
    get edit_password_path(@user.password_reset_token)
    assert_response :success
  end

  test "rechaza un token de restablecimiento inválido" do
    get edit_password_path("invalid token")
    assert_redirected_to new_password_path

    follow_redirect!
    assert_notice "no es válido"
  end

  test "cambia la contraseña" do
    assert_changes -> { @user.reload.password_digest } do
      put password_path(@user.password_reset_token), params: { password: "una-clave-nueva-larga", password_confirmation: "una-clave-nueva-larga" }
      assert_redirected_to new_session_path
    end

    follow_redirect!
    assert_notice "fue restablecida"
  end

  test "no cambia la contraseña si la confirmación no coincide" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(token), params: { password: "no", password_confirmation: "match" }
      assert_redirected_to edit_password_path(token)
    end

    follow_redirect!
    assert_notice "verifica que las contraseñas coincidan"
  end

  private
    def assert_notice(text)
      assert_select "div", /#{text}/
    end
end
