import { parse } from './parser.js';
import { parse as parseCompact } from './parser-compact.js';
import { format as formatAst } from './formatter.js';
import { turtle } from '../src/turtle.js';

const format = (sparql, indentDepth = 2) => {
  return formatAst(parse(sparql), indentDepth);
};

const compactFormat = (sparql, indentDepth = 2) => {
  return formatAst(parseCompact(sparql), indentDepth);
};

const sparql2Turtle = (sparql, indentDepth = 2) => {
  return turtle(parse(sparql), indentDepth);
};

const sparql2Jsonld = (sparql, indentDepth = 2) => {
  return JSON.stringify(parse(sparql), selector, indentDepth);
};

function selector(key, value) {
  if (key !== 'location') {
    return value;
  }
}

export const spfmt = {
  format,
  compactFormat,
  sparql2Turtle,
  sparql2Jsonld
};

if (typeof window !== 'undefined') {
  window.spfmt = spfmt;
}
