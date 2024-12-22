import { parse } from './parser.js';
import { parse as parseCompact } from './parser-compact.js';
import { format } from './formatter.js';

export const spfmt = (sparql, indentDepth = 2, compactMode = false) => {
  if (compactMode) {
    return format(parseCompact(sparql), indentDepth);
  } else {
    return format(parse(sparql), indentDepth);
  }
};

if (typeof window !== 'undefined') {
  window.spfmt = spfmt;
}
