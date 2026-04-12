FROM alpine:3.20

RUN apk add --no-cache git git-daemon

WORKDIR /git

EXPOSE 9418

CMD ["git", "daemon", "--reuseaddr", "--base-path=/git", "--export-all", "--verbose", "/git"]
