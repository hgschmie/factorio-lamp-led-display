FROM golang:1.26-alpine AS build
WORKDIR /src
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/factorio-display ./cmd/factorio-display

FROM alpine:3.24
COPY --from=build /out/factorio-display /factorio-display
USER 65532:65532
ENTRYPOINT ["/factorio-display"]
