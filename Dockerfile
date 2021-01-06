FROM golang:1.15.6-alpine3.12
RUN apk add --no-cache \
    git=2.26.2-r0 \
    bash=5.0.17-r0 \
    && rm -rf /var/cache/apk
RUN go get -u github.com/mgechev/revive
