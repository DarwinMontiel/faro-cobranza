# Reinicia el servidor después de modificar este archivo.
#
# Política de seguridad de contenido (CSP) para toda la aplicación. Aún no se activa porque las
# vistas no dependen de recursos externos; la base recomendada es la siguiente.
# Guía: https://guides.rubyonrails.org/security.html#content-security-policy-header
#
# Rails.application.configure do
#   config.content_security_policy do |policy|
#     policy.default_src :self, :https
#     policy.font_src    :self, :https, :data
#     policy.img_src     :self, :https, :data
#     policy.object_src  :none
#     policy.script_src  :self, :https
#     policy.style_src   :self, :https
#   end
#
#   # Nonces por sesión para el importmap y los scripts y estilos en línea.
#   config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
#   config.content_security_policy_nonce_directives = %w(script-src style-src)
# end
