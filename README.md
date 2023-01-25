# SPARQL 1.1 formatter

Website: https://sparqling.github.io/sparql-formatter/

## Node.js
### Installation:
```
$ npm install sparql-formatter
```

### Usage:
#### format(sparql, indentDepth = 2)
* sparql: string
* indentDepth: integer (>= 0)

```
const format = require('sparql-formatter');

console.log(format('select * where {?s ?p ?o}'));
```

## CLI
```
$ npm install -g sparql-formatter
```
A symbolic link to `./bin/sparql-formatter.js` will be created as `sparql-formatter` in your path.
```
$ cat sparql11-query/02.2.rq
PREFIX foaf:   <http://xmlns.com/foaf/0.1/>
PREFIX foaf:   <http://xmlns.com/foaf/0.1/>
SELECT ?name ?mbox
WHERE
  { ?x foaf:name ?name .
    ?x foaf:mbox ?mbox }
```
### Usage:
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

## Install from GitHub

```
$ git clone https://github.com/sparqling/sparql-formatter
$ cd sparql-formatter
$ npm install
```
Now the CLI programs are under `./bin/`.

Optionally,
```
$ npm link
```
This will make a symbolic link to `./bin/*` as `sparql-formatter` and `sparql-formatter-test` in your path.

## SPARQL 1.1 query examples

* 91 SPARQL queries are extracted from the SPARQL 1.1 specification (https://www.w3.org/TR/sparql11-query/)

Test:
```
$ sparql-formatter-test sparql11-query/*.rq
true    sparql11-query/02.1.rq
true    sparql11-query/02.2.rq
...
true    sparql11-query/17.rq
```
