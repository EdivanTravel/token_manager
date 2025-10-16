FROM elixir:1.15.4

# Instala dependências do sistema
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    curl \
    autoconf \
    libssl-dev \
    libncurses5-dev \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get
RUN mix deps.compile --force

CMD ["mix", "phx.server"]
