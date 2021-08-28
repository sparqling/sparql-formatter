#!/usr/bin/env node

const fs = require('fs');
const program = require('commander');
const parser = require('../lib/parser.js');
const formatter = require('../lib/formatter.js');
const version = require('../package.json').version;

const opts = program
  .option('-i, --indent <DEPTH>', 'indent depth', 2)
  .option('-j, --json', 'output AST in JSON')
  .option('-d, --debug', 'debug')
  .version(version)
  .arguments('[SPARQL_FILE]')
  .parse(process.argv)
  .opts();

if (program.args.length < 1) {
  program.help();
}

const sparql = fs.readFileSync(program.args[0], "utf8").toString();
let ast;
try {
  ast = new parser.parse(sparql);
} catch (err) {
  printError(sparql, err);
  process.exit(1);
}

if (opts.debug) {
  console.log(JSON.stringify(ast, undefined, 2));
} else if (opts.json) {
  console.log(JSON.stringify(ast, selector, 2));
} else {
  console.log(formatter.format(ast, opts.indent));
}

function selector(key, value) {
  if (key !== 'location') {
    return value;
  }
}

function printError(inputText, err) {
  if (err.location) {
    const startLine = err.location.start.line;
    const endLine = err.location.end.line;
    const startCol = err.location.start.column;
    const endCol = err.location.end.column;

    if (startLine == endLine) {
      console.error(`ERROR line:${startLine}(col:${startCol}-${endCol})`);
    } else {
      console.error(`ERROR line:${startLine}(col:${startCol})-${endLine}(col:${endCol})`);
    }
    console.error(err.message);
    console.error('--');

    const lines = inputText.split('\n').slice(startLine - 1, endLine);
    if (lines.length == 1) {
      const line = lines[0];
      console.error(line.substring(0, startCol - 1) + makeRed(line.substring(startCol - 1, endCol)) + line.substring(endCol));
    } else {
      lines.forEach((line, i) => {
        if (i == 0) {
          console.error(line.substring(0, startCol - 1) + makeRed(line.substring(startCol - 1)));
        } else if (i < lines.length - 1) {
          console.error(makeRed(line));
        } else {
          console.error(makeRed(line.substring(0, endCol)) + line.substring(endCol));
        }
      });
    }
  } else {
    console.error(err);
    console.error('--');
    console.error(makeRed(inputText));
  }
};

function makeRed(text) {
  const red = '\u001b[41m';
  const reset = '\u001b[0m';
  return red + text + reset;
}
