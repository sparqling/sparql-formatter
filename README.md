# SPARQL 1.1 formatter

Website: https://sparql-formatter.dbcls.jp/

npm: https://www.npmjs.com/package/sparql-formatter

Docker: https://hub.docker.com/r/sparqling/sparql-formatter

## Usage in web pages
```
<script src='https://cdn.jsdelivr.net/gh/sparqling/sparql-formatter@v0.9.3/dist/main.js'></script>
```
Use spfmt functions:

```
spfmt.formatSparql(query)
spfmt.formatSparql(query, 'compact')
spfmt.formatSparql(query, 'jsonld')
spfmt.formatSparql(query, 'turtle', 4)
```
* `query`: *string*
* `formattingMode`: *string* (`default`, `compact`, `turtle`, `jsonld`), optional (default: `default`)
* `indentDepth`: *integer* (>= 0), optional (default: `2`)
* return value: *string*

## Usage in Node.js

Example:
```
import { spfmt } from 'sparql-formatter';

console.log(spfmt.formatSparql('select * where {?s ?p ?o}'));
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

Examples:

`$ sparql-formatter sparql11-query/02.2.rq` 

or

`$ cat sparql11-query/02.2.rq | sparql-formatter`

or use Docker

`$ cat sparql11-query/02.2.rq | docker run -i --rm sparqling/sparql-formatter`

or

`$ docker run --rm -v $(pwd):/work sparqling/sparql-formatter sparql11-query/02.2.rq`

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
* Commands are in `sparql-formatter/bin/*`.

Optional: `$ npm link`
* Symbolic links to `sparql-formatter/bin/*` are created (as `sparql-formatter` and `sparql-formatter-test` in your path).

## SPARQL 1.1 examples

* 91 SPARQL examples are extracted from the SPARQL 1.1 Query Language specification (https://www.w3.org/TR/sparql11-query/)
* 16 SPARQL examples are extracted from the SPARQL 1.1 Update specification (https://www.w3.org/TR/sparql11-update/)
* Other queries are added under test/ directory.

Test:
```
$ sparql-formatter-test sparql11-query/*.rq
true    sparql11-query/02.1.rq
true    sparql11-query/02.2.rq
...
true    sparql11-query/17.rq
```
* The `sparql-formatter` output for `*.rq` is compared with `*.txt`.
