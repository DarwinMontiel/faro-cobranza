require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "genera un token con prefijo y guarda solo su huella" do
    token = users(:agent).api_tokens.create!(name: "Integración")
    assert token.plain_token.start_with?(ApiToken::PREFIX)
    assert_equal ApiToken.digest(token.plain_token), token.token_digest
    assert_not_includes token.attributes.values.map(&:to_s), token.plain_token
  end

  test "autentica tokens vigentes y registra el último uso" do
    token = ApiToken.authenticate(ApiTestHelper::VALID_TOKEN)
    assert_equal api_tokens(:bot), token
    assert_not_nil token.reload.last_used_at
  end

  test "rechaza tokens revocados, desconocidos o sin prefijo" do
    assert_nil ApiToken.authenticate("faro_test_token_revoked")
    assert_nil ApiToken.authenticate("faro_no_existe")
    assert_nil ApiToken.authenticate("sin-prefijo")
    assert_nil ApiToken.authenticate(nil)
  end

  test "los tokens emitidos con el prefijo anterior siguen funcionando" do
    assert_equal api_tokens(:legacy), ApiToken.authenticate("crm_test_token_legacy")
    assert users(:agent).api_tokens.create!(name: "Nuevo").plain_token.start_with?("faro_")
  end

  test "revocar deja el token inutilizable" do
    api_tokens(:bot).revoke!
    assert_nil ApiToken.authenticate(ApiTestHelper::VALID_TOKEN)
  end
end
