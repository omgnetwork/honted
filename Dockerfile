FROM elixir:1.5

RUN set -xe && \
    mix local.hex --force && \
    mix local.rebar --force && \
    mix hex.info

COPY . /app
WORKDIR /app

RUN set -xe && \
    mix deps.get && \
    MIX_ENV=prod mix compile

CMD ["mix", "run", "--no-halt"]
