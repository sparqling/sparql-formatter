const parser = require('lib/parser');
const formatter = require('lib/formatter.js');

module.exports = (sparql, indentDepth = 2) => {
  return formatter.format(parser.parse(sparql), indentDepth);
};
