import { parse } from './parser.js';
import { parse as parseCompact } from './parser-compact.js';
import { format } from './formatter.js';
import { turtle } from '../src/turtle.js';

const reformat = (sparql, indentDepth = 2, compactMode = false) => {
  if (compactMode) {
    return format(parseCompact(sparql), indentDepth);
  } else {
    return format(parse(sparql), indentDepth);
  }
};

const sparql2Turtle = (sparql, compactMode = false) => {
  if (compactMode) {
    return turtle(parseCompact(sparql));
  } else {
    return turtle(parse(sparql));
  }
};

const sparql2Jsonld = (sparql, compactMode = false) => {
  if (compactMode) {
    return JSON.stringify(parseCompact(sparql), selector, 2);
  } else {
    return JSON.stringify(parse(sparql), selector, 2);
  }
};

function selector(key, value) {
  if (key !== 'location') {
    return value;
  }
}

export const spfmt = {
  reformat,
  sparql2Turtle,
  sparql2Jsonld
};

if (typeof window !== 'undefined') {
  window.spfmt = spfmt;
}
