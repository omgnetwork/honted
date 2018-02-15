FROM elixir:1.5

RUN set -xe && \
    wget -q https://redirector.gvt1.com/edgedl/go/go1.9.2.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.9.2.linux-amd64.tar.gz

ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/gopath"
ENV PATH="$GOPATH/bin:${PATH}"

RUN set -xe && \
    go version

RUN set -xe && \
    go get github.com/Masterminds/glide

RUN set -xe && \
    go get github.com/tendermint/tendermint/cmd/tendermint

# TODO: need to force a particular version of tendermint, remove after a TM release > 0.15.0
RUN set -xe && \
    cd $GOPATH/src/github.com/tendermint/tendermint && \
    git remote add omisego https://github.com/omisego/tendermint && \
    git fetch omisego && \
    git checkout v0.15.0_dirty_no_val_check && \
    glide install && \
    go install ./cmd/tendermint

RUN set -xe && \
    tendermint version

RUN set -xe && \
    go get github.com/tendermint/tools/tm-bench || \
    cd $GOPATH/src/github.com/tendermint/tools/tm-bench && \
    glide install && \
    go install .

RUN set -xe && \
    which tm-bench

# geth
# NOTE: getting from ppa doesn't work, so building from source
# NOTE: fixed version
RUN set -xe && \
    git clone https://github.com/ethereum/go-ethereum && \
    cd go-ethereum && \
    git checkout v1.7.3 && \
    make geth

ENV PATH="/go-ethereum/build/bin/:${PATH}"

RUN set -xe && \
    geth version

RUN set -xe && \
    mix local.hex --force && \
    mix local.rebar --force && \
    mix hex.info

COPY . /app
WORKDIR /app

RUN set -xe && \
    mix deps.get

# TODO: establish the most robust/useful option with respect to compiling the Mix project
RUN set -xe && \
    MIX_ENV=test mix compile

CMD ["mix", "run", "--no-halt"]
