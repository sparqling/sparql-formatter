const parser = require('./lib/parser.js');
const formatter = require('./lib/formatter.js');

const spfmt = (sparql, indentDepth = 2) => {
  return formatter.format(parser.parse(sparql), indentDepth);
};

module.exports = spfmt;
