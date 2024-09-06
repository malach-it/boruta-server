# syntax = docker/dockerfile:experimental
# Builder image to build the app
ARG USER=redirector

FROM --platform=$BUILDPLATFORM golang:1.23.0-bookworm@sha256:31dc846dd1bcca84d2fa231bcd16c09ff271bcc1a5ae2c48ff10f13b039688f3 as builder
ARG USER
ARG TARGETARCH

LABEL maintainer=dadrus@gmx.de

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN useradd -l -M -U -s "/usr/sbin/nologin" -d "/nonexistent" -u 10001 ${USER}

WORKDIR /build

COPY . .
RUN go mod download && go mod verify &&\
    CGO_ENABLED=0 GOOS=linux GOARCH=${TARGETARCH} go build -trimpath -ldflags="-buildid= -w -s"

# The actual image of the app
FROM scratch
ARG USER
LABEL maintainer=dadrus@gmx.de

WORKDIR /opt/redirector

COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group
COPY --from=builder /build/closedredirector .

USER ${USER}:${USER}

ENTRYPOINT ["/opt/redirector/closedredirector"]
