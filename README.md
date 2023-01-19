# SPARQL 1.1 formatter

Website: https://sparqling.github.io/sparql-formatter/

## Install command line tools

```
$ git clone https://github.com/sparqling/sparql-formatter
$ cd sparql-formatter
$ npm install
```

Optional:
```
$ npm link
```

## SPARQL 1.1 query examples

* 91 SPARQL queries are extracted from the SPARQL 1.1 specification (https://www.w3.org/TR/sparql11-query/)

Example:
```
$ cat sparql11-query/02.2.rq
PREFIX foaf:   <http://xmlns.com/foaf/0.1/>
PREFIX foaf:   <http://xmlns.com/foaf/0.1/>
SELECT ?name ?mbox
WHERE
  { ?x foaf:name ?name .
    ?x foaf:mbox ?mbox }
$ sparql-formatter sparql11-query/02.2.rq
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>

SELECT ?name ?mbox
WHERE {
  ?x foaf:name ?name .
  ?x foaf:mbox ?mbox .
}
```

Test:
```
$ sparql11-query/*.rq
true    sparql11-query/02.1.rq
true    sparql11-query/02.2.rq
...
true    sparql11-query/17.rq
```
