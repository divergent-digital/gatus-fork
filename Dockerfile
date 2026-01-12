# ---------- UI build ----------
FROM node:20-alpine AS ui-builder
WORKDIR /app

# Copy only what the UI build needs first (better caching)
COPY web/app/package.json web/app/package-lock.json ./web/app/
WORKDIR /app/web/app
RUN npm ci

# Now copy the full UI sources and build
COPY web/app ./web/app
RUN npm run build

# The Vue build should output into /app/web/static in your repo layout.
# If your build outputs somewhere else, adjust the COPY below accordingly.

# ---------- Go build ----------
FROM golang:1.22-alpine AS builder
RUN apk add --no-cache ca-certificates
WORKDIR /app

COPY . ./

# Replace repo web/static with freshly built assets
COPY --from=ui-builder /app/web/static ./web/static

# Do NOT run `go mod tidy -diff` inside Docker; it will fail if anything differs
# and it can vary by Go version. Keep Docker builds deterministic.
RUN go mod download

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -o /out/gatus .

# ---------- Runtime ----------
FROM scratch
COPY --from=builder /out/gatus /gatus
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

ENV GATUS_CONFIG_PATH="/config"
ENV GATUS_LOG_LEVEL="INFO"
ENV PORT="8080"
EXPOSE 8080

ENTRYPOINT ["/gatus"]