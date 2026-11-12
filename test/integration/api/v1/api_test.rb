require "test_helper"

module Api
  module V1
    class ApiTest < ActionDispatch::IntegrationTest
      test "exige un token válido y vigente" do
        get api_v1_clients_path
        assert_response :unauthorized
        assert_equal "unauthorized", json.dig("error", "code")
        assert_match(/Bearer/, response.headers["WWW-Authenticate"])

        get api_v1_clients_path, headers: api_headers("faro_test_token_revoked")
        assert_response :unauthorized
      end

      test "lista y busca clientes con paginación" do
        get api_v1_clients_path, headers: api_headers, params: { q: "laura", per_page: 1 }
        assert_response :success
        assert_equal [ "1012345678" ], json["data"].pluck("document_number")
        assert_equal({ "page" => 1, "per_page" => 1, "total" => 1, "pages" => 1 }, json["meta"])
      end

      test "detalle de cliente incluye obligaciones" do
        get api_v1_client_path(clients(:laura)), headers: api_headers
        assert_response :success
        assert_equal %w[OB-0000001 OB-0000002].sort, json.dig("data", "obligations").pluck("number").sort
      end

      test "recurso inexistente responde 404 con formato uniforme" do
        get api_v1_obligation_path("OB-9999999"), headers: api_headers
        assert_response :not_found
        assert_equal "not_found", json.dig("error", "code")
      end

      test "obligaciones filtradas por franja y detalle con acuerdo vigente" do
        get api_v1_obligations_path, headers: api_headers, params: { bucket: "91-180" }
        assert_equal [ "OB-0000003" ], json["data"].pluck("number")

        get api_v1_obligation_path(obligations(:andres_micro)), headers: api_headers
        assert_equal "AC-ANDRES0001", json.dig("data", "active_agreement", "reference")
        assert_equal 2, json.dig("data", "active_agreement", "installments").size
      end

      test "un bot registra una gestión" do
        assert_difference -> { CollectionActivity.from_api.count } do
          post api_v1_collection_activities_path, headers: api_headers, as: :json, params: {
            obligation_number: "OB-0000001", channel: "call", outcome: "promise_to_pay",
            promise_date: 3.days.from_now.to_date.iso8601, promise_amount: 350_000, notes: "Registrado por bot"
          }
        end
        assert_response :created
        assert_equal "api", json.dig("data", "source")
        assert_equal users(:admin).name, json.dig("data", "registered_by")
      end

      test "gestión inválida responde 422 con detalle por campo" do
        post api_v1_collection_activities_path, headers: api_headers, as: :json,
          params: { obligation_number: "OB-0000001", channel: "fax", outcome: "promise_to_pay" }
        assert_response :unprocessable_entity
        assert_equal "validation_failed", json.dig("error", "code")
        assert json.dig("error", "details", "channel").present?
        assert json.dig("error", "details", "promise_date").present?
      end

      test "falta un parámetro obligatorio responde 400" do
        post api_v1_collection_activities_path, headers: api_headers, as: :json, params: { channel: "call" }
        assert_response :bad_request
        assert_equal "parameter_missing", json.dig("error", "code")
      end

      test "registro idempotente de acuerdos de pago" do
        body = {
          obligation_number: "OB-0000001", reference: "RPA-7f3c", total_amount: 2_000_000,
          installments: plan_attributes(total: 2_000_000, count: 2).map { |i| i.merge(due_on: i[:due_on].iso8601) }
        }
        post api_v1_payment_agreements_path, headers: api_headers, as: :json, params: body
        assert_response :created
        assert_equal "RPA-7f3c", json.dig("data", "reference")

        assert_no_difference -> { PaymentAgreement.count } do
          post api_v1_payment_agreements_path, headers: api_headers, as: :json, params: body
        end
        assert_response :ok

        get api_v1_payment_agreement_path("RPA-7f3c"), headers: api_headers
        assert_equal "active", json.dig("data", "status")
      end
    end
  end
end
