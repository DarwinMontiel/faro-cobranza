class ApplicationController < ActionController::Base
  include Authentication
  # Solo navegadores modernos (webp, web push, import maps, CSS nesting y :has).
  allow_browser versions: :modern

  # Un cambio en el importmap invalida el ETag de las respuestas HTML.
  stale_when_importmap_changes

  helper_method :current_user

  private
    def current_user
      Current.user
    end

    def paginate(scope, per: 20)
      Pagination.new(scope, page: params[:page], per:)
    end
end
