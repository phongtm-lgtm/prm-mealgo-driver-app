FROM golang:1.24.2-bookworm AS build
ARG MC_VERSION=RELEASE.2025-04-16T18-13-26Z
RUN go install github.com/minio/mc@${MC_VERSION}

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build /go/bin/mc /usr/local/bin/mc
ENTRYPOINT ["mc"]
