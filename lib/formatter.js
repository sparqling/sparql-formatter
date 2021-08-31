let output;
let commentsList;
let currentIndent;
let indentUnit = '  ';

exports.format = (syntaxTree, indentDepth = 2) => {
  indentUnit = ' '.repeat(indentDepth);

  output = [];
  commentsList = syntaxTree.comments;
  currentIndent = '';

  if (syntaxTree.headers.length > 0) {
    addLine(syntaxTree.headers.join(''));
  }
  if (syntaxTree.prologue.length) {
    syntaxTree.prologue.forEach((p) => {
      if (p.token === 'base') {
        addLine(`BASE <${p.value}>`);
      } else if (p.token === 'prefix') {
        addLine(`PREFIX ${p.prefix || ''}: <${p.local}>`);
      }
    });
    addLine('');
  }

  if (syntaxTree.body?.kind === 'select') {
    addSelect(syntaxTree.body);
  } else if (syntaxTree.body?.kind === 'construct') {
    addConstruct(syntaxTree.body);
  } else if (syntaxTree.body?.kind === 'ask') {
    addAsk(syntaxTree.body);
  } else if (syntaxTree.body?.kind === 'describe') {
    addDescribe(syntaxTree.body);
  } else if (syntaxTree.units) {
    syntaxTree.units.forEach((unit) => {
      addUnit(unit);
    });
  }
  if (syntaxTree.inlineData) {
    addInlineData(syntaxTree.inlineData);
  }

  addComments();

  return output.join('\n');
};

const debugPrint = (object) => {
  console.log(JSON.stringify(object, undefined, 2));
};

const increaseIndent = (depth = 1) => {
  currentIndent += indentUnit.repeat(depth);
};

const decreaseIndent = (depth = 1) => {
  currentIndent = currentIndent.substr(0, currentIndent.length - indentUnit.length * depth);
};

const addLine = (lineText, commentPtr = 0) => {
  // 0 means min ptr, so no comments will be added.
  addComments(commentPtr);
  output.push(currentIndent + lineText);
};

const addComments = (commentPtr = -1) => {
  // -1 means 'max' ptr, so all comments will be added.
  let commentAdded = false;
  while (commentsList.length > 0 && (commentsList[0].line < commentPtr || commentPtr == -1)) {
    const commentText = commentsList.shift().text;
    if (commentAdded || commentPtr == -1 || output[output.length - 1] === '') {
      // newline is necessary before comment
      output.push(commentText);
    } else {
      // newline is not necessary
      output[output.length - 1] += commentText;
    }
    commentAdded = true;
  }
};

const addAsk = (ask) => {
  addLine('ASK {');
  addGroupGraphPatternSub(ask.pattern);
  addLine('}');
}

const addDescribe = (describe) => {
  const elems = describe.value.map(getTripleElem).join(' ');
  addLine(`DESCRIBE ${elems}`);
  if (describe.pattern) {
    addLine('WHERE {');
    addGroupGraphPatternSub(describe.pattern);
    addLine('}');
  }
}

const addUnit = (unit) => {
  if (unit.kind === 'insertdata') {
    addLine('INSERT DATA');
    addQuads(unit.quads);
  } else if (unit.kind === 'deletedata') {
    addLine('DELETE DATA');
    addQuads(unit.quads);
  } else if (unit.kind === 'deletewhere') {
    addLine('DELETE WHERE {');
    addGroupGraphPatternSub(unit.pattern);
    addLine('}');
  } else if (unit.kind === 'modify') {
    if (unit.with) {
      addLine(`WITH ${getTripleElem(unit.with)}`);
    }
    if (unit.delete) {
      addLine('DELETE');
      addQuads(unit.delete.triplesblock);
    }
    if (unit.insert) {
      addLine('INSERT');
      addQuads(unit.insert.triplesblock);
    }
    addLine('WHERE {');
    addGroupGraphPatternSub(unit.pattern);
    addLine('}');
  } else if (unit.kind === 'add') {
    const g1 = getGraphOrDefault(unit.graphs[0]);
    const g2 = getGraphOrDefault(unit.graphs[1]);
    let silent = ' ';
    if (unit.silent) {
      silent = ' SILENT ';
    }
    addLine(`ADD${silent}${g1} TO ${g2}`);
  } else if (unit.kind === 'move') {
    const g1 = getGraphOrDefault(unit.graphs[0]);
    const g2 = getGraphOrDefault(unit.graphs[1]);
    let silent = ' ';
    if (unit.silent) {
      silent = ' SILENT ';
    }
    addLine(`MOVE${silent}${g1} TO ${g2}`);
  } else if (unit.kind === 'copy') {
    const g1 = getGraphOrDefault(unit.graphs[0]);
    const g2 = getGraphOrDefault(unit.graphs[1]);
    let silent = ' ';
    if (unit.silent) {
      silent = ' SILENT ';
    }
    addLine(`COPY${silent}${g1} TO ${g2}`);
  }
};

const getGraphOrDefault = (graph) => {
  if (graph === 'DEFAULT') {
    return 'DEFAULT';
  } else {
    return getTripleElem(graph);
  }
};

const addQuads = (quads) => {
  addLine('{');
  increaseIndent();
  addTriplesBlock(quads);
  decreaseIndent();
  addLine('}');
};

const addSelect = (select) => {
  const proj = select.projection;
  const lastLine = proj[0].value ? proj[0].value.location.start.line : proj[0].location.start.line;

  let args = '';
  if (select.modifier) {
    args += `${select.modifier.toString()} `;
  }
  args += proj.map(getProjection).join(' ');
  addLine(`SELECT ${args}`, lastLine);

  if (select.dataset) {
    select.dataset.implicit.forEach((graph) => {
      addFrom(graph);
    });
    select.dataset.named.forEach((graph) => {
      addFromNamed(graph);
    });
  }

  addLine('WHERE {', lastLine + 1);
  addGroupGraphPatternSub(select.pattern);
  addLine('}', select.pattern.location.end.line);

  addSolutionModifier(select);
};

const addSolutionModifier = (body) => {
  if (body.group) {
    addLine('GROUP BY ' + body.group.map(elem => getTripleElem(elem)).join(' '));
  }
  if (body.having) {
    addLine(`HAVING ${getExpression(body.having[0])}`);
  }
  if (body.order) {
    addLine('ORDER BY ' + getOrderConditions(body.order));
  }
  body.limitoffset?.forEach((lo) => {
    if (lo.limit) {
      addLine(`LIMIT ${lo.limit}`);
    } else if (lo.offset) {
      addLine(`OFFSET ${lo.offset}`);
    }
  });
}

const addConstruct = (body) => {
  if (body.template) {
    addLine('CONSTRUCT {');
    increaseIndent();
    addTriplesBlock(body.template.triplesblock);
    decreaseIndent();
    addLine('}');
  } else {
    addLine('CONSTRUCT');
  }

  body.dataset.implicit.forEach((graph) => {
    addFrom(graph);
  });
  body.dataset.named.forEach((graph) => {
    addFromNamed(graph);
  });

  addLine('WHERE {');
  if (body.pattern.patterns) {
    addGroupGraphPatternSub(body.pattern);
  } else {
    increaseIndent();
    addTriplesBlock(body.pattern.triplesblock);
    decreaseIndent();
  }
  addLine('}');

  addSolutionModifier(body);
};

const addFrom = (graph) => {
  const uri = getUri(graph);
  if (uri != null) {
    addLine('FROM ' + uri);
  }
};

const addFromNamed = (graph) => {
  const uri = getUri(graph);
  if (uri != null) {
    addLine('FROM NAMED ' + uri);
  }
};

const addGroupGraphPatternSub = (pattern) => {
  increaseIndent();
  pattern.patterns.forEach((p) => {
    if (p.token === 'filter') {
      addFilter(p.value)
    } else if (p.token === 'bind') {
      addLine(`BIND (${getExpression(p.expression)} AS ${getVar(p.as)})`);
    } else {
      addPattern(p)
    }
  });
  decreaseIndent();
};

const addPattern = (pattern) => {
  switch (pattern.token) {
    case 'ggps':
      addLine('{');
      addGroupGraphPatternSub(pattern);
      addLine('}');
      break;
    case 'graphgraphpattern':
      addLine(`GRAPH ${getTripleElem(pattern.graph)} {`);
      addGroupGraphPatternSub(pattern.value);
      addLine('}');
      break;
    case 'graphunionpattern':
      addLine('{');
      addGroupGraphPatternSub(pattern.value[0]);
      addLine('}');
      for (let i = 1; i < pattern.value.length; i++) {
        addLine('UNION');
        addLine('{');
        addGroupGraphPatternSub(pattern.value[i]);
        addLine('}');
      }
      break;
    case 'optionalgraphpattern':
      addLine('OPTIONAL {');
      addGroupGraphPatternSub(pattern.value);
      addLine('}');
      break;
    case 'servicegraphpattern':
      addLine(`SERVICE ${getTripleElem(pattern.value[0])}`);
      addPattern(pattern.value[1]);
      break;
    case 'minusgraphpattern':
      addLine('MINUS {');
      addGroupGraphPatternSub(pattern.value);
      addLine('}');
      break;
    case 'triplesblock':
      addTriplesBlock(pattern.triplesblock);
      break;
    case 'inlineData':
      addInlineData(pattern);
      break;
    case 'inlineDataFull':
      addInlineData(pattern);
      break;
    case 'expression':
      if (pattern.expressionType === 'functioncall') {
        const args = pattern.args.map(getExpression).join(', ');
        addLine(getUri(pattern.iriref) + `(${args})`);
      } else {
        debugPrint(pattern);
      }
      break;
    case 'subselect':
      addLine('{');
      increaseIndent();
      addSelect(pattern);
      decreaseIndent();
      addLine('}');
      break;
    default:
      debugPrint(pattern);
  }
};

const getOrderConditions = (conditions) => {
  let orderConditions = [];
  conditions.forEach((condition) => {
    const oc = getVar(condition.expression.value);
    if (condition.direction == 'DESC') {
      orderConditions.push(`DESC(${oc})`);
    } else {
      orderConditions.push(oc);
    }
  });

  return orderConditions.join(' ');
};

const getProjection = (projection) => {
  switch (projection.kind) {
    case '*':
      return '*';
    case 'var':
      if (projection.value.prefix === '$') {
        return '$' + projection.value.value;
      } else {
        return '?' + projection.value.value;
      }
    case 'aliased':
      return `(${getExpression(projection.expression)} AS ?${projection.alias.value})`;
    default:
      throw new Error('unknown projection.kind: ' + projection.kind);
  }
};

const getRelationalExpression = (exp) => {
  let op1 = getExpression(exp.op1);
  if (exp.op1.bracketted) {
    op1 = `(${op1})`;
  }

  let op2;
  if (Array.isArray(exp.op2)) {
    op2 = exp.op2.map(getTripleElem).join(', ');
    op2 = `(${op2})`;
  } else {
    op2 = getExpression(exp.op2);
  }

  if (exp.bracketted) {
    return `(${op1} ${exp.operator} ${op2})`;
  } else {
    return `${op1} ${exp.operator} ${op2}`;
  }
}

const addFilter = (filter) => {
  if (filter.expressionType === 'builtincall' && filter.builtincall === 'notexists') {
    addLine(`FILTER NOT EXISTS`);
    filter.args.forEach((pattern) => {
      addPattern(pattern);
    });
  } else if (filter.expressionType === 'builtincall' && filter.builtincall === 'exists') {
    addLine(`FILTER EXISTS`);
    filter.args.forEach((pattern) => {
      addPattern(pattern);
    });
  } else {
    addLine(`FILTER ${getExpression(filter)}`);
  }
};

const addTriplesBlock = (triplesblock) => {
  if (triplesblock.triplesblock) {
    addTriplesBlock(triplesblock.triplesblock);
  } else {
    triplesblock.forEach((t) => {
      if (t.graph) {
        addLine(`GRAPH ${getTripleElem(t.graph)} {`);
        increaseIndent();
        addTriplesBlock(t.triplesblock);
        decreaseIndent();
        addLine('}');
      } else if (t.triplesblock) {
        addTriplesBlock(t.triplesblock);
      } else {
        addTriplePath(t);
      }
    });
  }
};

const addTriplePath = (triplepath) => {
  const s = getTripleElem(triplepath.chainSubject);
  const props = getPropertyList(triplepath.propertylist, s?.length);
  addLine(`${s}${props} .`);
};

const getPropertyList = (propertylist, sLen = 4) => {
  let ret = '';
  propertylist.pairs.forEach((pair) => {
    const p = getTripleElem(pair[0]);
    const o = getTripleElem(pair[1]);
    if (ret) {
      ret += ` ;\n`;
      ret += currentIndent + ' '.repeat(sLen) + ` ${p} ${o}`;
    } else {
      ret += ` ${p} ${o}`;
    }
  });
  return ret;
};

const getAggregate = (expr) => {
  if (expr.aggregateType === 'count') {
    let distinct = expr.distinct ? 'DISTINCT ' : '';
    return `COUNT(${distinct}${getExpression(expr.expression)})`;
  } else if (expr.aggregateType === 'sum') {
    return `sum(?${expr.expression.value.value})`;
  } else if (expr.aggregateType === 'min') {
    return `MIN(?${expr.expression.value.value})`;
  } else if (expr.aggregateType === 'max') {
    return `MAX(?${expr.expression.value.value})`;
  } else if (expr.aggregateType === 'avg') {
    return `AVG(${getExpression(expr.expression)})`;
  } else if (expr.aggregateType === 'sample') {
    return `SAMPLE(?${expr.expression.value.value})`;
  } else if (expr.aggregateType === 'group_concat') {
    let distinct = expr.distinct ? 'DISTINCT ' : '';
    let separator = '';
    if (expr.separator) {
      separator = `; SEPARATOR = "${expr.separator.value}"`;
    }
    return `GROUP_CONCAT(${distinct}${getExpression(expr.expression)}${separator})`;
  }
};

const getExpression = (expr) => {
  switch (expr.expressionType) {
    case 'atomic':
      return getTripleElem(expr.value);
    case 'irireforfunction':
      let iri = getUri(expr.iriref);
      if (expr.args) {
        iri += '(' + expr.args.map(getExpression).join(', ') + ')';
      }
      return getBracketted(iri, expr.bracketted);
    case 'builtincall':
      let args = '';
      if (expr.args) {
        args = expr.args.map(getTripleElem).join(', ');
      }
      const ret = expr.builtincall + '(' + args + ')';
      return getBracketted(ret, expr.bracketted);
    case 'unaryexpression':
      let ex = expr.unaryexpression + getExpression(expr.expression);
      return getBracketted(ex, expr.bracketted);
    case 'aggregate':
      return getAggregate(expr);
    case 'multiplicativeexpression':
      let multi = getFactor(expr.factor) + ' ' + getFactors(expr.factors);
      return getBracketted(multi, expr.bracketted);
    case 'additiveexpression':
      return getFactor(expr);
    case 'relationalexpression':
      return getRelationalExpression(expr);
    case 'conditionaland':
      return getBracketted(expr.operands.map(getExpression).join(' && '), expr.bracketted);
    case 'conditionalor':
      return getBracketted(expr.operands.map(getExpression).join(' || '), expr.bracketted);
    case 'regex':
      let op = getExpression(expr.text);
      op += ', ' + getExpression(expr.pattern);
      if (expr.flags) {
        op += ', ' + getExpression(expr.flags);
      }
      return `regex(${op})`;
  }
};

const getBracketted = (ret, bracketted) => {
  if (bracketted) {
    return `(${ret})`;
  } else {
    return ret;
  }
};

const getFactor = (factor) => {
  let out;
  if (factor.summand) {
    out = getExpression(factor.summand) + ' ' + getFactors(factor.summands);
  } else {
    out = getExpression(factor);
  }
  if (factor.bracketted) {
    return `(${out})`;
  } else {
    return out;
  }
};

const getFactors = (factors) => {
  return factors.map((factor) => {
    return factor.operator + ' ' + getExpression(factor.expression);
  }).join(' ');
};

const addInlineData = (inline) => {
  switch (inline.token) {
    case 'inlineData':
      const v = getTripleElem(inline.var);
      const vals = inline.values.map(getTripleElem).join(' ');
      addLine(`VALUES ${v} { ${vals} }`);
      break;
    case 'inlineDataFull':
      const varlist = inline.variables.map(getVar).join(' ');
      if (inline.variables.length === 1) {
        const vals = inline.values.map((tuple) => {
          return '(' + tuple.map(getTripleElem).join(' ') + ')';
        }).join(' ');
        addLine(`VALUES (${varlist}) { ${vals} }`);
      } else {
        addLine(`VALUES (${varlist}) {`);
        increaseIndent();
        inline.values.map((tuple) => {
          addLine('(' + tuple.map(getTripleElem).join(' ') + ')');
        });
        decreaseIndent();
        addLine('}');
      }
      break;
  }
};

const getTripleElem = (elem) => {
  if (elem === 'UNDEF') {
    return elem;
  }
  if (Array.isArray(elem)) {
    return elem.map((e) => getTripleElem(e)).join(', ');
  }
  switch (elem.token) {
    case 'uri':
      return getUri(elem);
    case 'var':
      return getVar(elem);
    case 'literal':
      if (elem.type === 'http://www.w3.org/2001/XMLSchema#decimal') {
        return elem.value;
      } else if (elem.type === 'http://www.w3.org/2001/XMLSchema#double') {
        return elem.value;
      } else if (elem.type === 'http://www.w3.org/2001/XMLSchema#integer') {
        return elem.value;
      }
      let literal = elem.quote + elem.value + elem.quote;
      if (elem.type?.prefix && elem.type?.suffix) {
        literal += `^^${elem.type.prefix}:${elem.type.suffix}`;
      } else if (elem.type) {
        literal += `^^<${elem.type.value}>`;
      } else if (elem.lang) {
        literal += '@' + elem.lang;
      }
      return literal;
    case 'path':
      if (elem.kind === 'alternative') {
        let path = elem.value.map((e) => getPredicate(e)).join('|');
        if (elem.bracketted) {
          path = `(${path})`;
        }
        return path;
      } else if (elem.kind === 'sequence') {
        return elem.value.map((e) => getPredicate(e)).join('/');
      } else {
        return getPredicate(elem);
      }
    case 'blank':
      return '[]';
    case 'triplesnode':
      return `[${getPropertyList(elem.pairs)} ]`;
    case 'triplesnodecollection':
      const collection = elem.collection.map((c) => {
        return getTripleElem(c)
      }).join(' ');
      return `( ${collection} )`;
    default:
      return getExpression(elem);
  }
};

const getPredicate = (elem) => {
  let ret = '';
  if (elem.kind === 'inversePath') {
    ret += '^';
  }
  ret += getTripleElem(elem.value);
  if (elem.modifier) {
    ret += elem.modifier;
  }
  return ret;
};

const getUri = (uri) => {
  if (uri.prefix && uri.suffix) {
    return `${uri.prefix}:${uri.suffix}`;
  } else if (uri.prefix) {
    return `${uri.prefix}:`;
  } else if (uri.suffix) {
    return `:${uri.suffix}`;
  } else if (uri.value === 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type') {
    return 'a';
  } else if (uri.value != null) {
    return `<${uri.value}>`;
  } else {
    return null;
  }
};

const getVar = (variable) => {
  if (variable.prefix === '?') {
    return '?' + variable.value;
  } else if (variable.prefix === '$') {
    return '$' + variable.value;
  } else {
    return '{{' + variable.value + '}}';
  }
};
