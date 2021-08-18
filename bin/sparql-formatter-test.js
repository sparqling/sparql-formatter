#!/usr/bin/env node

const fs = require('fs');
const program = require('commander');
const { spawnSync } = require('child_process');
const csvWriter = require('csv-write-stream');
const ls = require('ls');
const path = require('path');

const readFile = (path) => fs.readFileSync(path, 'utf8').toString();

const opts = program
  .option('-c, --command <COMMAND>', 'command', 'sparql-formatter')
  .option('-d, --delimiter <DELIMITER>', 'delimiter of output', '\t')
  .option('-p, --pattern <REGEX>', 'extra constraint for file pattern specified in regex')
  .option('--exclude <REGEX>', 'extra constraint for file pattern to be excluded specified in regex')
  .option('--output-error', 'output to stderr')
  .option('-H, --header', 'output header')
  .arguments('[json_or_queries]')
  .parse(process.argv)
  .opts();

if (program.args.length < 1) {
  program.help();
}

let benchmarks = [];
for (let arg of program.args) {
  if (arg.endsWith('.json')) {
    benchmarks = benchmarks.concat(JSON.parse(readFile(arg)));
    process.chdir(path.dirname(arg));
  } else {
    benchmarks.push({ query: arg });
  }
}

const pattern = opts.pattern ? new RegExp(opts.pattern) : null;
const exclude = opts.exclude ? new RegExp(opts.exclude) : null;

let header = [];
header.push('valid');
header.push('name');

let writer = csvWriter({
  separator: opts.delimiter,
  newline: '\n',
  headers: header,
  sendHeaders: Boolean(opts.header)
});
writer.pipe(process.stdout);

for (let benchmark of benchmarks) {
  const queries = ls(benchmark.query);
  if (queries.length === 0) {
    console.error(`Warning: Query "${benchmark.query}" is specified but no matched files are found.`);
  }
  for (let file of queries) {
    if (pattern && !file.full.match(pattern)) {
      continue;
    }
    if (exclude && file.full.match(exclude)) {
      continue;
    }
    let expected = null;
    const defaultExpectedName = file.full.replace(/\.[^/.]+$/, '') + '.txt';
    if (!benchmark.expected && fs.existsSync(defaultExpectedName)) {
      expected = readFile(defaultExpectedName);
    } else if (benchmark.expected) {
      let files = ls(benchmark.expected);
      const basename = path.basename(defaultExpectedName);
      if (files.length == 1) {
        expected = readFile(files[0].full);
      } else {
        const matched = files.find((file) => file.file === basename);
        if (matched) {
          expected = readFile(matched.full);
        }
      }
    }
    measureQuery(file.full, expected);
  }
}
writer.end();

function measureQuery(queryPath, expected) {
  let row = { name: queryPath };

  let validations = [];
  let arguments = [queryPath];
  let result = spawnSync(opts.command, arguments, { maxBuffer: Infinity });
  if (result.status) {
    // error
    console.error(result.stderr.toString());
    validations.push('null');
  } else {
    if (expected == null) {
      validations.push('null');
    } else {
      let actual = result.stdout.toString();
      if (actual === expected) {
        validations.push('true');
      } else {
        validations.push('false');
        if (opts.outputError) {
          console.error(result.stdout.toString());
        }
      }
    }
  }
  row['valid'] = validations.join(',');

  writer.write(row);
}
