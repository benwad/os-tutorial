FROM alpine:3.7

RUN apk add nasm gcc make

WORKDIR /app
COPY ./src /app

RUN chmod a+x assemble.sh
ENTRYPOINT ./assemble.sh
