FROM alpine:3.7

WORKDIR /app
COPY ./src /app

RUN apk add nasm gcc make
RUN chmod a+x assemble.sh
ENTRYPOINT ./assemble.sh
