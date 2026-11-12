// Registra todos los controladores Stimulus de app/javascript/controllers (*_controller.js).
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
