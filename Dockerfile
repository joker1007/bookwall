# syntax=docker/dockerfile:1
# check=error=true

# Bookwall production image. Build context must be the repository root so
# both client/ and server/ are available:
#
#   docker build -t bookwall .
#   docker run -d -p 80:80 -e RAILS_MASTER_KEY=$(cat server/config/master.key) bookwall
#
# Thruster listens on $PORT (80) and proxies to Falcon on TARGET_PORT (3000).

ARG RUBY_VERSION=4.0.3

# -------- Stage 1: build the React client --------
FROM node:22-slim AS client_build
WORKDIR /client
COPY client/package*.json ./
RUN npm ci
COPY client/ ./
RUN npm run build

# -------- Stage 2: prepare Rails server --------
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS server_base
WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl libjemalloc2 libvips sqlite3 poppler-utils && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

FROM server_base AS server_build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential git libvips libyaml-dev libssl-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY server/Gemfile server/Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

COPY server/ ./

# Mount the React build under public/ui so Thruster serves the static
# assets and the SpaController fallback finds public/ui/index.html.
COPY --from=client_build /client/dist /rails/public/ui

RUN bundle exec bootsnap precompile -j 1 app/ lib/

# -------- Stage 3: final image --------
FROM server_base

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=server_build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=server_build /rails /rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

ENV TARGET_PORT="3000"
EXPOSE 80
CMD ["./bin/thrust", "bundle", "exec", "falcon", "serve", "--bind", "http://0.0.0.0:3000"]
