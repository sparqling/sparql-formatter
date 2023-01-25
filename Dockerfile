FROM alpine:3.14

RUN apk --no-cache add npm git

WORKDIR /opt
RUN cd /opt \
 && git clone https://github.com/sparqling/sparql-formatter \
 && cd /opt/sparql-formatter \
 && npm install && npm link

WORKDIR /work

CMD ["sparql-formatter"]
