# ---------- UI build ----------
FROM node:20-alpine AS ui-builder
WORKDIR /app

# Build deps for node-gyp/native modules (safe even if you don't need them)
RUN apk add --no-cache python3 make g++ git

# If a build is memory-hungry, this prevents random OOM failures
ENV NODE_OPTIONS=--max_old_space_size=4096

# Copy lockfiles first for better caching
COPY web/app/package.json web/app/package-lock.json ./web/app/
WORKDIR /app/web/app
RUN npm ci

# Copy full UI sources and build
COPY web/app ./web/app
RUN npm run build --loglevel verbose

# ---------- Go build ----------
FROM golang:1.22-alpine AS builder
RUN apk add --no-cache ca-certificates
WORKDIR /app

COPY . ./

# Replace web/static with freshly built assets from ui-builder
COPY --from=ui-builder /app/web/static ./web/static

RUN go mod download
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