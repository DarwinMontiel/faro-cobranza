# Reinicia el servidor después de modificar este archivo.

# Parámetros que se filtran de los logs por coincidencia parcial (p. ej. "passw" filtra "password").
# Limita la exposición de datos sensibles: contraseñas, tokens de API, correos y llaves.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]
