const parser = require('./parser.js');
const formatter = require('./formatter.js');

spfmt = (sparql, indentDepth = 2) => {
  return formatter.format(parser.parse(sparql), indentDepth);
};

module.exports = spfmt;
