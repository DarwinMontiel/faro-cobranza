class ObligationsController < ApplicationController
  # Bandeja de cobro: obligaciones vencidas, las de mayor mora primero.
  def index
    @bucket = params[:bucket].presence_in(Obligation::BUCKETS.keys.drop(1))
    scope = Obligation.past_due.collectible.includes(:client, :active_agreement)
    scope = scope.in_bucket(@bucket) if @bucket
    @pagination = paginate(scope.order(days_past_due: :desc, principal_balance: :desc))
  end

  def show
    @obligation = Obligation.includes(:client).find_by!(number: params[:number])
    @activities = @obligation.collection_activities.includes(:user).limit(50)
    # El historial muestra las 50 más recientes; el contador, todas.
    @activities_count = @obligation.collection_activities.count
    @agreements = @obligation.payment_agreements.includes(:installments)
    @activity = @obligation.collection_activities.build
  end
end
