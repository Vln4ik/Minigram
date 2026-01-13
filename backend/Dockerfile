FROM golang:1.22 AS builder

WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /bin/server ./cmd/server

FROM gcr.io/distroless/base-debian12
WORKDIR /app
COPY --from=builder /bin/server /app/server
COPY migrations /app/migrations
EXPOSE 8080
ENTRYPOINT ["/app/server"]
