FROM alpine:3.14

RUN apk --no-cache add npm git

RUN cd /opt \
 && git clone https://github.com/sparqling/sparql-formatter \
 && cd sparql-formatter \
 && npm install && npm link

WORKDIR /work

ENTRYPOINT ["sparql-formatter"]
