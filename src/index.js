import { parse as parseSparql } from './sparql-parser.js';
import { parse as parseSparqlAsCompact } from './sparql-parser-compact.js';
import { formatAst } from './formatter.js';
import { turtle } from '../src/turtle.js';

const format = (sparql, formattingMode = 'default', indentDepth = 2) => {
  switch (formattingMode) {
    case 'default':
      return formatAst(parseSparql(sparql), indentDepth);
    case 'compact':
      return formatAst(parseSparqlAsCompact(sparql), indentDepth);
    case 'turtle':
      return turtle(parseSparql(sparql), indentDepth);
    case 'jsonld':
      return JSON.stringify(parseSparql(sparql), selector, indentDepth);
    default:
      throw new Error(`Unsupported formatting mode: ${formattingMode}`);
  }
};

function selector(key, value) {
  if (key !== 'location') {
    return value;
  }
}

export const spfmt = {
  parseSparql,
  parseSparqlAsCompact,
  formatAst,
  format
};

if (typeof window !== 'undefined') {
  window.spfmt = spfmt;
}
