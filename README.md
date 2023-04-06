# SPARQL 1.1 formatter

Website: https://sparqling.github.io/sparql-formatter/

npm: https://www.npmjs.com/package/sparql-formatter

Docker: https://hub.docker.com/r/sparqling/sparql-formatter

## Usage in web pages
Read the following file:
```
<script src='https://cdn.jsdelivr.net/gh/sparqling/sparql-formatter@v0.7.2/dist/main.js'></script>
```
Use the following function:
### spfmt(query, indentDepth = 2)
* query: string
* indentDepth: integer (>= 0)
* return value: string

## Usage in Node.js

Example:
```
const spfmt = require('sparql-formatter');

console.log(spfmt('select * where {?s ?p ?o}'));
```

Output:
```
SELECT *
WHERE {
  ?s ?p ?o .
}
```

## Command line interface
```
$ npm install -g sparql-formatter
```
A symbolic link to `./bin/sparql-formatter.js` will be created as `sparql-formatter` in your path.

Examples:

`$ sparql-formatter sparql11-query/02.2.rq` 

or `$ cat sparql11-query/02.2.rq | sparql-formatter`

or use Docker `$ cat sparql11-query/02.2.rq | docker run -i --rm sparqling/sparql-formatter`

or `$ docker run --rm -v $(pwd):/work sparqling/sparql-formatter sparql11-query/02.2.rq`

Input:
```
PREFIX foaf:   <http://xmlns.com/foaf/0.1/>
PREFIX foaf:   <http://xmlns.com/foaf/0.1/>
SELECT ?name ?mbox
WHERE
  { ?x foaf:name ?name .
    ?x foaf:mbox ?mbox }
```

Output:
```
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
$ npm ci
```
Now the CLI programs are under `./bin/`.

Optional: `$ npm link`

will make a symbolic link to `./bin/*` as `sparql-formatter` and `sparql-formatter-test` in your path.

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
* The `sparql-formatter` output for `*.rq` is compared with `*.txt`.
