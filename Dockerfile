# ---- UI Build Stage ----
FROM node:20-alpine AS ui-builder

WORKDIR /src

# Copy only package manifests first for better caching
COPY web/app/package*.json ./web/app/
WORKDIR /src/web/app
RUN npm ci

# Now copy the rest of the UI sources
WORKDIR /src
COPY web/app ./web/app
COPY web/static ./web/static

# Build UI -> outputs into /src/web/static (per your existing setup)
WORKDIR /src/web/app
RUN npm run build

# ---- Go Build Stage ----
FROM golang:1.22-alpine AS builder
RUN apk add --no-cache ca-certificates

WORKDIR /app

# Copy Go sources
COPY . ./

# Bring in the freshly built static assets
COPY --from=ui-builder /src/web/static ./web/static

RUN go mod tidy -diff

# Build the binary (Buildx will set GOARCH automatically per platform)
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o /out/gatus .

# ---- Runtime Stage ----
FROM scratch
COPY --from=builder /out/gatus /gatus
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

ENV GATUS_CONFIG_PATH=""
ENV GATUS_LOG_LEVEL="INFO"
ENV PORT="8080"

EXPOSE 8080
ENTRYPOINT ["/gatus"]