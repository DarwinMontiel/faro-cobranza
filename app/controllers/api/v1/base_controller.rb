module Api
  module V1
    # Base de la API REST: autenticación por token Bearer, límite de solicitudes y un formato
    # de error uniforme: { "error": { "code": "...", "message": "...", "details": {...} } }.
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate!

      rate_limit to: 300, within: 1.minute, by: -> { request.authorization.to_s },
        with: -> { render_error(:too_many_requests, "rate_limited", "Demasiadas solicitudes, intente en un minuto") }

      rescue_from ActiveRecord::RecordNotFound do
        render_error(:not_found, "not_found", "Recurso no encontrado")
      end
      rescue_from ActionController::ParameterMissing do |error|
        render_error(:bad_request, "parameter_missing", error.message)
      end

      private
        attr_reader :current_api_token

        def current_user
          current_api_token.user
        end

        def authenticate!
          @current_api_token = authenticate_with_http_token { |token, _options| ApiToken.authenticate(token) }
          return if @current_api_token

          response.headers["WWW-Authenticate"] = 'Bearer realm="faro-cobranza"'
          render_error(:unauthorized, "unauthorized", "Token de API inválido, revocado o ausente")
        end

        def render_error(status, code, message, details: nil)
          render json: { error: { code:, message:, details: }.compact }, status:
        end

        def render_validation_errors(record)
          render_error(:unprocessable_entity, "validation_failed", "La solicitud tiene datos inválidos",
            details: record.errors.to_hash(true))
        end

        def paginate(scope, per: 50)
          per = params[:per_page].to_i.clamp(1, 200) if params[:per_page].present?
          Pagination.new(scope, page: params[:page], per:)
        end
    end
  end
end
