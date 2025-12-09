ARG GO_IMAGE=rancher/hardened-build-base:v1.22.12b1

# Image that provides cross compilation tooling.
FROM --platform=$BUILDPLATFORM rancher/mirrored-tonistiigi-xx:1.6.1 AS xx

FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS base-builder
# copy xx scripts to your build stage
COPY --from=xx / /
RUN apk add file make git clang lld patch
ARG TARGETPLATFORM
RUN set -x && \
    xx-apk --no-cache add musl-dev gcc lld 

# Build the multus-dynamics-networks-controller project
FROM base-builder AS multus-builder
ARG TAG=v0.3.7
ARG SRC=github.com/k8snetworkplumbingwg/multus-dynamic-networks-controller
ARG PKG=github.com/k8snetworkplumbingwg/multus-dynamic-networks-controller
RUN git clone --depth=1 https://${SRC}.git $GOPATH/src/${PKG}
WORKDIR $GOPATH/src/${PKG}
RUN git fetch --all --tags --prune && \
    git checkout tags/${TAG} -b ${TAG}
RUN go mod download
# cross-compilation setup
ARG TARGETARCH

RUN xx-go --wrap && \
    CGO_ENABLED=0 go build -o /dynamic-networks-controller ./cmd/dynamic-networks-controller
RUN xx-verify --static /dynamic-networks-controller

FROM ${GO_IMAGE} AS strip_binary
#strip needs to run on TARGETPLATFORM, not BUILDPLATFORM
COPY --from=multus-builder /dynamic-networks-controller /dynamic-networks-controller
RUN strip /dynamic-networks-controller

# Create the final image
FROM scratch AS multus-run
COPY --from=strip_binary /dynamic-networks-controller /dynamic-networks-controller
