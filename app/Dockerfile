# ─── Build stage ────────────────────────────────────────────
FROM golang:1.25-alpine AS builder

WORKDIR /app

# Кешуємо залежності окремо від коду
COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o /app/server ./cmd/server

# ─── Final stage ─────────────────────────────────────────────
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app

COPY --from=builder /app/server .

# Non-root user (distroless nonroot = UID 65532)
USER nonroot:nonroot

EXPOSE 8080 8081

ENTRYPOINT ["/app/server"]
