require "test_helper"

class BrandingTest < ActionDispatch::IntegrationTest
  test "el manifiesto PWA tiene el nombre, la descripción y los colores de la app" do
    get pwa_manifest_path(format: :json)
    assert_response :success

    manifest = JSON.parse(response.body)
    assert_equal "Faro Cobranza", manifest["name"]
    assert_match(/cobranza/i, manifest["description"])
    assert_equal "#0f1f2e", manifest["theme_color"]
    assert_equal [ "/icon.png", "/icon.svg" ], manifest["icons"].pluck("src")
  end

  test "el ícono es propio y las páginas de error están en español" do
    assert_no_match(/fill="red"/, Rails.public_path.join("icon.svg").read)

    %w[400 404 406-unsupported-browser 422 500].each do |page|
      html = Rails.public_path.join("#{page}.html").read
      assert_match(/<html lang="es">/, html, page)
      assert_no_match(/We're sorry|doesn't exist|Your browser is not supported/i, html, page)
    end
  end
end
