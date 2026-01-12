FROM golang:alpine AS builder
RUN apk --no-cache add ca-certificates
WORKDIR /app

COPY . ./

ARG TARGETOS
ARG TARGETARCH

RUN go mod tidy -diff
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -a -installsuffix cgo -o gatus .

FROM scratch
COPY --from=builder /app/gatus /gatus
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

ENV GATUS_LOG_LEVEL="INFO"
ENV PORT="8080"

EXPOSE 8080
ENTRYPOINT ["/gatus"]