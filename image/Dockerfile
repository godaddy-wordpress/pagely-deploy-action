FROM alpine:3.18

RUN apk add --no-cache tar curl ca-certificates bash httpie

COPY pipe.sh /

ENTRYPOINT ["/pipe.sh"]
