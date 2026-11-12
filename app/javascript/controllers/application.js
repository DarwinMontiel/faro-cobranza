import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Modo de depuración de Stimulus (mensajes en la consola del navegador).
application.debug = false
window.Stimulus   = application

export { application }
