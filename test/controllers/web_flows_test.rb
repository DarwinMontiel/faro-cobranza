require "test_helper"

# Flujos de la interfaz web (HTML y Turbo Streams).
class WebFlowsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:agent) }

  test "sin sesión redirige al inicio de sesión" do
    sign_out
    get root_path
    assert_redirected_to new_session_path
  end

  test "el tablero muestra los indicadores" do
    get root_path
    assert_response :success
    assert_select "h1", "Tablero"
    assert_select ".kpi", 6
    assert_select ".bars li", Obligation::BUCKETS.size
  end

  test "búsqueda de clientes por documento" do
    get clients_path, params: { q: "9912" }
    assert_response :success
    assert_select "turbo-frame#clients td", text: "Laura Gómez Ríos"
    assert_select "turbo-frame#clients td", text: "Andrés Pérez Duarte", count: 0
  end

  test "crear cliente normaliza el documento y valida" do
    post clients_path, params: { client: { document_number: "99.123.456", full_name: "nuevo cliente", city: "Cali", segment: "pyme" } }
    client = Client.find_by!(document_number: "99123456")
    assert_redirected_to client_path(client)
    assert_equal "Nuevo Cliente", client.full_name

    post clients_path, params: { client: { document_number: "1", full_name: "", city: "" } }
    assert_response :unprocessable_entity
    assert_select ".form-errors li", minimum: 2
  end

  test "bandeja de cobro filtra por franja" do
    get obligations_path, params: { bucket: "91-180" }
    assert_response :success
    assert_select "td a", text: "OB-0000003"
    assert_select "td a", text: "OB-0000001", count: 0
  end

  test "registrar gestión responde con Turbo Stream" do
    obligation = obligations(:laura_card)
    assert_difference -> { obligation.collection_activities.count } do
      post obligation_collection_activities_path(obligation), as: :turbo_stream, params: {
        collection_activity: { channel: "call", outcome: "promise_to_pay", promise_date: 2.days.from_now.to_date, promise_amount: 300_000 }
      }
    end
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match(/turbo-stream action="prepend" target="activities"/, response.body)
    assert obligation.collection_activities.first.from_web?
  end

  test "una gestión inválida reemplaza el formulario con los errores" do
    post obligation_collection_activities_path(obligations(:laura_card)), as: :turbo_stream,
      params: { collection_activity: { channel: "call", outcome: "promise_to_pay" } }
    assert_response :unprocessable_entity
    assert_match(/turbo-stream action="replace" target="activity_form"/, response.body)
  end

  test "nuevo acuerdo propone un plan y lo registra" do
    obligation = obligations(:laura_card)
    get new_obligation_payment_agreement_path(obligation)
    assert_response :success
    assert_select "tbody tr.installment-row", 3
    assert_select "template tr.installment-row", 1 # fila modelo para "Agregar cuota"

    installments = plan_attributes(total: 2_000_000, count: 4).each_with_index.to_h { |row, i| [ i.to_s, row ] }
    post obligation_payment_agreements_path(obligation), params: { payment_agreement: { total_amount: 2_000_000, installments_attributes: installments } }
    agreement = obligation.payment_agreements.first
    assert_redirected_to payment_agreement_path(agreement)
    assert_equal 4, agreement.installments.count
    assert obligation.reload.in_agreement?
  end

  test "generar plan devuelve las cuotas por Turbo Stream" do
    post plan_obligation_payment_agreements_path(obligations(:laura_card)), as: :turbo_stream,
      params: { payment_agreement: { total_amount: "1500000" }, plan_count: 5, plan_first_due_on: (Date.current + 10).iso8601 }
    assert_response :success
    assert_match(/turbo-stream action="replace" target="installments"/, response.body)
    # 5 cuotas + la fila modelo del <template> de "Agregar cuota".
    assert_equal 6, response.body.scan(/class="installment-row"/).size
  end

  test "un acuerdo fuera de política se rechaza con 422" do
    obligation = obligations(:laura_card)
    installments = plan_attributes(total: 100_000, count: 1).each_with_index.to_h { |row, i| [ i.to_s, row ] }
    post obligation_payment_agreements_path(obligation), params: { payment_agreement: { total_amount: 100_000, installments_attributes: installments } }
    assert_response :unprocessable_entity
    assert_select ".form-errors", /al menos el 60/
  end

  test "detalle e índice de acuerdos" do
    get payment_agreements_path
    assert_select "td a", text: "AC-ANDRES0001"
    get payment_agreement_path(payment_agreements(:andres_active))
    assert_response :success
    assert_select ".badge", text: /Pagada/
  end

  test "crear token de API lo muestra una sola vez" do
    post api_tokens_path, params: { api_token: { name: "Bot de pruebas" } }
    assert_response :created
    token = users(:agent).api_tokens.order(:created_at).last
    plain = css_select("[data-clipboard-target=source]").text.strip
    assert_equal token.token_digest, ApiToken.digest(plain)

    get api_tokens_path
    assert_select "[data-clipboard-target=source]", count: 0
  end
end
