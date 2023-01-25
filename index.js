const parser = require('./lib/parser.js');
const formatter = require('./lib/formatter.js');

module.exports = (sparql, indentDepth = 2) => {
  return formatter.format(parser.parse(sparql), indentDepth);
};
