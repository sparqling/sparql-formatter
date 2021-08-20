#!/usr/bin/env node

const fs = require('fs');
const program = require('commander');
const parser = require('../lib/parser');
const formatter = require('../lib/formatter.js');
const version = require('../package.json').version;

const opts = program
  .option('-i, --indent <DEPTH>', 'indent depth', 2)
  .option('-d, --debug', 'debug')
  .version(version)
  .arguments('[SPARQL_FILE]')
  .parse(process.argv)
  .opts();

if (program.args.length < 1) {
  program.help();
}

const sparql = fs.readFileSync(program.args[0], "utf8").toString();
const ast = parser.parse(sparql);
if (opts.debug) {
  console.log(JSON.stringify(ast, undefined, 2));
} else {
  console.log(formatter.format(ast, opts.indent));
}
