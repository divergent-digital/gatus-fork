# syntax=docker/dockerfile:1.6

FROM --platform=$BUILDPLATFORM golang:alpine AS builder
RUN apk --no-cache add ca-certificates
WORKDIR /app

COPY . ./

ARG TARGETOS
ARG TARGETARCH

RUN go mod tidy -diff

# Drop "-a -installsuffix cgo" (it forces rebuilding stdlib and makes builds slower)
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -o /out/gatus .

FROM scratch
COPY --from=builder /out/gatus /gatus
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
ENV GATUS_LOG_LEVEL="INFO"
ENV PORT="8080"
EXPOSE 8080
ENTRYPOINT ["/gatus"]