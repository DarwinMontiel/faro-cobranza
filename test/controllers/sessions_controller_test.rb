require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:agent) }

  test "muestra el inicio de sesión" do
    get new_session_path
    assert_response :success
  end

  test "inicia sesión con credenciales válidas" do
    post session_path, params: { email_address: @user.email_address, password: "password-de-prueba" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "rechaza credenciales inválidas" do
    post session_path, params: { email_address: @user.email_address, password: "incorrecta" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "cierra la sesión" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
