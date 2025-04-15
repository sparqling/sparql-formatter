#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { program } from 'commander';
import { parse as parseSparql } from '../src/sparql-parser.js';
import { parse as parseSparqlAsCompact } from '../src/sparql-parser-compact.js';
import { formatAst } from '../src/formatter.js';
import { turtle } from '../src/turtle.js';

const opts = program
  .option('-i, --indent <DEPTH>', 'indent depth', 2)
  .option('-j, --json', 'output AST in JSON')
  .option('-t, --turtle', 'output Turtle')
  .option('-c, --compact', 'compact mode')
  .option('-d, --debug', 'debug')
  .arguments('[SPARQL_FILE]')
  .parse(process.argv)
  .opts();

if (program.args.length < 1 && process.stdin.isTTY) {
  program.help();
}

(async () => {
  let sparql;
  if (program.args[0]) {
    try {
      sparql = await fs.promises.readFile(program.args[0], "utf8");
    } catch (err) {
      console.error(`cannot open ${program.args[0]}`);
      process.exit(1);
    }
  } else {
    sparql = await readStdin();
  }
  sparql = sparql.toString();

  let ast;
  try {
    if (opts.compact) {
      ast = parseSparqlAsCompact(sparql);
    } else {
      ast = parseSparql(sparql);
    }
  } catch (err) {
    if (opts.debug) {
      console.log(JSON.stringify(err, undefined, 2));
      console.error(err.message || '');
    } else {
      printError(sparql, err);
    }
    process.exit(1);
  }

  if (opts.debug) {
    console.log(JSON.stringify(ast, undefined, 2));
  } else if (opts.json) {
    console.log(JSON.stringify(ast, selector, 2));
  } else if (opts.turtle) {
    console.log(turtle(ast));
  } else {
    console.log(formatAst(ast, opts.indent));
  }
})();

function readStdin() {
  let buf = '';
  return new Promise(resolve => {
    process.stdin.on('readable', () => {
      let chunk;
      while (chunk = process.stdin.read()) {
        buf += chunk;
      }
    });
    process.stdin.on('end', () => resolve(buf))
  });
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
      console.error(`SyntaxError at line:${startLine}(col:${startCol}-${endCol})`);
    } else {
      console.error(`SyntaxError at line:${startLine}(col:${startCol})-${endLine}(col:${endCol})`);
    }
    let message = '';
    if (err.message) {
      message = err.message;
      message = message.replace(/^Expected/, 'Expected:');
      message = message.replace(/ but .* found.$/, '');
      message = message.replace('end of input', '');
      message = message.replace('[ \\t]', '');
      message = message.replace('[\\n\\r]', '');
      message = message.replace(/\[[^\dAa]\S+\]/g, '');
      message = message.replace('"#"', '');
      message = message.replace(/"(\S+)"/g, '$1');
      message = message.replace(/'"'/, '"');
      message = message.replace(/\\"/g, '"');
      message = message.replace('or ', ', ');
      message = message.replace(/[, ]+$/g, '');
      message = message.replace(/ *(, )+/g, ' ');
    }
    console.error(message);
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
