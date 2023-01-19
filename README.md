# SPARQL 1.1 formatter

Website: https://sparqling.github.io/sparql-formatter/

## Command line tools

### Install

```
$ git clone https://github.com/sparqling/sparql-formatter
$ cd sparql-formatter
$ npm install
```

Optional:
```
$ npm link
```

### Usage
```
$ cat sparql11-query/02.2.rq
PREFIX foaf:   <http://xmlns.com/foaf/0.1/>
PREFIX foaf:   <http://xmlns.com/foaf/0.1/>
SELECT ?name ?mbox
WHERE
  { ?x foaf:name ?name .
    ?x foaf:mbox ?mbox }
```
```
$ sparql-formatter sparql11-query/02.2.rq
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>

SELECT ?name ?mbox
WHERE {
  ?x foaf:name ?name .
  ?x foaf:mbox ?mbox .
}
```

## SPARQL 1.1 query examples

* 91 SPARQL queries are extracted from the SPARQL 1.1 specification (https://www.w3.org/TR/sparql11-query/)


### Test
```
$ sparql-formatter-test sparql11-query/*.rq
true    sparql11-query/02.1.rq
true    sparql11-query/02.2.rq
...
true    sparql11-query/17.rq
```
