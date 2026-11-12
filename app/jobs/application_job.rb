class ApplicationJob < ActiveJob::Base
  # Reintenta automáticamente los jobs que chocan en un bloqueo mutuo de la base.
  retry_on ActiveRecord::Deadlocked

  # Si el registro ya no existe, no tiene sentido reintentar.
  discard_on ActiveJob::DeserializationError
end
