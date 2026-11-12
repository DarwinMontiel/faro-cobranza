# syntax=docker/dockerfile:1
# check=error=true

# Imagen de PRODUCCIÓN (no de desarrollo). Se usa con Kamal o a mano:
#   docker build -t faro-cobranza .
#   docker run -d -p 80:80 -e RAILS_MASTER_KEY=<valor de config/master.key> --name faro-cobranza faro-cobranza

# RUBY_VERSION debe coincidir con .ruby-version
ARG RUBY_VERSION=3.4.11
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Directorio de la aplicación
WORKDIR /rails

# Paquetes base de ejecución
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Variables de producción y jemalloc para reducir memoria y latencia.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Etapa de compilación desechable: la imagen final no lleva compiladores
FROM base AS build

# Paquetes necesarios para compilar gemas nativas
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Gemas de la aplicación
COPY vendor/* ./vendor/
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 evita un error de QEMU al compilar en paralelo: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Código de la aplicación
COPY . .

# Precompila bootsnap para arrancar más rápido (-j 1 por el mismo error de QEMU).
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Garantiza binstubs ejecutables con finales de línea Unix
RUN chmod +x bin/* && \
    sed -i "s/\r$//g" bin/* && \
    sed -i 's/ruby\.exe$/ruby/' bin/*

# Precompila los assets sin necesitar RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Etapa final: imagen de ejecución
FROM base

# Se ejecuta con un usuario sin privilegios dueño solo de los archivos de ejecución
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copia las gemas y la aplicación ya compiladas
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# El entrypoint prepara la base de datos (db:prepare) antes de arrancar.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Servidor detrás de Thruster (compresión, caché de assets); se puede reemplazar al ejecutar
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
