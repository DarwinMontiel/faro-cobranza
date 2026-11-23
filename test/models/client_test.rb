require "test_helper"

class ClientTest < ActiveSupport::TestCase
  test "normaliza documento, nombre, correo y teléfono" do
    client = Client.new(document_number: "9.998.765.432", full_name: "  LAURA   gómez ",
                        email: " Laura@Correo.TEST ", phone: "(399) 000-1234")
    assert_equal "9998765432", client.document_number
    assert_equal "Laura Gómez", client.full_name
    assert_equal "laura@correo.test", client.email
    assert_equal "3990001234", client.phone
  end

  test "valida formato de documento, ciudad del catálogo y unicidad" do
    client = Client.new(document_number: "123", full_name: "X Y", city: "Atlántida")
    assert_not client.valid?
    assert client.errors.added?(:document_number, :invalid, value: "123")
    assert client.errors.of_kind?(:city, :inclusion)

    duplicate = Client.new(document_number: clients(:laura).document_number, full_name: "Otra", city: "Cali")
    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:document_number, :taken)
  end

  test "busca por prefijo de documento o por nombre sin importar mayúsculas" do
    assert_equal [ clients(:laura) ], Client.search("9912").to_a
    assert_equal [ clients(:laura) ], Client.search("9.912.345").to_a
    assert_equal [ clients(:andres) ], Client.search("pérez").to_a
    assert_equal Client.count, Client.search("").count
  end

  test "usa el documento como parámetro de URL" do
    assert_equal "9912345678", clients(:laura).to_param
  end
end
