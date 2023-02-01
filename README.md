# SPARQL 1.1 formatter

Website: https://sparqling.github.io/sparql-formatter/

npm: https://www.npmjs.com/package/sparql-formatter

Docker: https://hub.docker.com/r/sparqling/sparql-formatter

## Usage in Node.js

### format(query, indentDepth = 2)
* query: string
* indentDepth: integer (>= 0)

Example:
```
const format = require('sparql-formatter');

console.log(format('select * where {?s ?p ?o}'));
```

Output:
```
SELECT *
WHERE {
  ?s ?p ?o .
}
```

## CLI
```
$ npm install -g sparql-formatter
```
A symbolic link to `./bin/sparql-formatter.js` will be created as `sparql-formatter` in your path.

Example:

`$ sparql-formatter sparql11-query/02.2.rq` or
`$ cat sparql11-query/02.2.rq | sparql-formatter`

Input:
```
$ cat sparql11-query/02.2.rq
PREFIX foaf:   <http://xmlns.com/foaf/0.1/>
PREFIX foaf:   <http://xmlns.com/foaf/0.1/>
SELECT ?name ?mbox
WHERE
  { ?x foaf:name ?name .
    ?x foaf:mbox ?mbox }
```

Output:
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

## Usage in web page
Read the following file:
```
<script src='https://cdn.jsdelivr.net/gh/sparqling/sparql-formatter@main/dist/main.js'></script>
```
Use the following function:
### spfmt(query, indentDepth = 2)

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
