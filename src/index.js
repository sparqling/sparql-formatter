import { parse } from './parser.js';
import { format } from './formatter.js';

export const spfmt = (sparql, indentDepth = 2) => {
  return format(parse(sparql), indentDepth);
};

if (typeof window !== 'undefined') {
  window.spfmt = spfmt;
}
