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
    go get github.com/tendermint/tendermint/cmd/tendermint || \
    cd $GOPATH/src/github.com/tendermint/tendermint && \
    glide install && \
    go install ./cmd/tendermint

# TODO: need to force an old version of tendermint, fix after T474 is resolved
RUN set -xe && \
    git -C $GOPATH/src/github.com/tendermint/tendermint checkout v0.11.1 && \
    cd $GOPATH/src/github.com/tendermint/tendermint && \
    glide install && \
    go install ./cmd/tendermint

RUN set -xe && \
    tendermint version

RUN set -xe && \
    go get github.com/tendermint/tools/tm-bench || \
    cd $GOPATH/src/github.com/tendermint/tools/tm-bench && \
    glide install && \
    go install .

# TODO: need to force an old version of tm-bench, fix after T474 is resolved
RUN set -xe && \
    git -C $GOPATH/src/github.com/tendermint/tools checkout v1.0.0 && \
    cd $GOPATH/src/github.com/tendermint/tools/tm-bench && \
    glide install && \
    go install .

RUN set -xe && \
    which tm-bench

RUN set -xe && \
    mix local.hex --force && \
    mix local.rebar --force && \
    mix hex.info

COPY . /app
WORKDIR /app

RUN set -xe && \
    mix deps.get

CMD ["mix", "run", "--no-halt"]
