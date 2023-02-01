let output;
let comments;
let currentIndent;
let indentUnit = '  ';

exports.format = (syntaxTree, indentDepth = 2) => {
  indentUnit = ' '.repeat(indentDepth);

  output = [];
  comments = syntaxTree.comments;
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
    for (let i = 0; i < syntaxTree.units.length; i++) {
      if (i > 0) {
        output[output.length - 1] += " ;\n";
      }
      addUnit(syntaxTree.units[i]);
    }
  }
  if (syntaxTree.inlineData) {
    addInlineData(syntaxTree.inlineData);
  }

  while (comments.length > 0) {
    output[output.length - 1] += comments.shift().text;
  }

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

const addLine = (line) => {
  output.push(currentIndent + line);
};

const addLineWithComment = (line, pos) => {
  while (comments.length && comments[0].pos < pos) {
    output[output.length - 1] += comments.shift().text;
  }
  addLine(line);
};

const addAsk = (ask) => {
  addLine('ASK {');
  addGroupGraphPatternSub(ask.pattern);
  addLine('}');
  addSolutionModifier(ask);
}

const addDescribe = (describe) => {
  const elems = describe.value.map(getTripleElem).join(' ');
  addLine(`DESCRIBE ${elems}`);
  addDataset(describe.dataset);
  if (describe.pattern) {
    addLine('WHERE {');
    addGroupGraphPatternSub(describe.pattern);
    addLine('}');
  }
  addSolutionModifier(describe);
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
    if (unit.using) {
      addLine(`USING ${getUsing(unit.using[0])}`);
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
  } else if (unit.kind === 'load') {
    let silent = ' ';
    if (unit.silent) {
      silent = ' SILENT ';
    }
    addLine(`LOAD${silent}${getUri(unit.sourceGraph)}`);
  } else if (unit.kind === 'clear') {
    let silent = ' ';
    if (unit.silent) {
      silent = ' SILENT ';
    }
    addLine(`CLEAR${silent}${getGraphRefAll(unit.destinyGraph)}`);
  } else if (unit.kind === 'drop') {
    let silent = ' ';
    if (unit.silent) {
      silent = ' SILENT ';
    }
    addLine(`DROP${silent}${getGraphRefAll(unit.destinyGraph)}`);
  } else if (unit.kind === 'create') {
    let silent = ' ';
    if (unit.silent) {
      silent = ' SILENT ';
    }
    addLine(`CREATE${silent}GRAPH ${getUri(unit.destinyGraph)}`);
  }
};

const getUsing = (graph) => {
  if (graph.kind === 'default') {
    return getUri(graph.uri);
  } else if (graph.kind === 'named') {
    return `NAMED ${getUri(graph.uri)}`;
  }
};

const getGraphOrDefault = (graph) => {
  if (graph === 'default') {
    return 'DEFAULT';
  } else {
    return getUri(graph);
  }
};

const getGraphRefAll = (graph) => {
  if (graph === 'default') {
    return 'DEFAULT';
  } else if (graph === 'named') {
    return 'NAMED';
  } else if (graph === 'all') {
    return 'ALL';
  } else {
    return `GRAPH ${getUri(graph)}`;
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
  const lastProj = proj[proj.length-1];
  const pos = proj[0].value ? proj[0].value.location.start.offset : proj[0].location.start.offset;
  let endPos = lastProj.value ? lastProj.value.location.end.offset : lastProj.location.end.offset;

  let args = '';
  if (select.modifier) {
    args += `${select.modifier.toString()} `;
  }
  args += proj.map(getProjection).join(' ');
  addLineWithComment(`SELECT ${args}`, pos);

  const datasetEndPos= addDataset(select.dataset);
  if (datasetEndPos > endPos) {
    endPos = datasetEndPos;
  }

  addLineWithComment('WHERE {', endPos+1);
  addGroupGraphPatternSub(select.pattern);
  addLineWithComment('}', select.pattern.location.end.offset);

  addSolutionModifier(select);
};

const addDataset = (dataset) => {
  let endPos;
  if (dataset) {
    dataset.implicit.forEach((graph) => {
      endPos = addFrom(graph);
    });
    dataset.named.forEach((graph) => {
      endPos = addFromNamed(graph);
    });
    return endPos;
  }
}

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
    addLineWithComment('CONSTRUCT {', body.location.start.offset);
    increaseIndent();
    addTriplesBlock(body.template.triplesblock);
    decreaseIndent();
    addLine('}');
  } else {
    addLine('CONSTRUCT');
  }

  addDataset(body.dataset);

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
    const pos = graph.location.start.offset;
    const endPos = graph.location.end.offset;
    addLineWithComment('FROM ' + uri, pos);
    return endPos;
  }
};

const addFromNamed = (graph) => {
  const uri = getUri(graph);
  if (uri != null) {
    const pos = graph.location.start.offset;
    const endPos = graph.location.end.offset;
    addLineWithComment('FROM NAMED ' + uri, pos);
    return endPos;
  }
};

const addGGP = (pattern) => {
  addLine('{');
  switch (pattern.token) {
    case 'ggp':
      addGroupGraphPatternSub(pattern);
      break;
    case 'subselect':
      increaseIndent();
      addSelect(pattern);
      if (pattern.inlineData) {
        addInlineData(pattern.inlineData);
      }
      decreaseIndent();
      break;
  }
  addLine('}');
};

const addGroupGraphPatternSub = (pattern) => {
  increaseIndent();
  pattern.patterns.forEach(addPattern);
  decreaseIndent();
};

const addPattern = (pattern) => {
  switch (pattern.token) {
    case 'triplesblock':
      addTriplesBlock(pattern.triplesblock);
      break;
    case 'ggp':
      addGGP(pattern);
      break;
    case 'subselect':
      addGGP(pattern);
      break;
    case 'filter':
      addFilter(pattern);
      break;
    case 'bind':
      addLine(`BIND (${getExpression(pattern.expression)} AS ${getVar(pattern.as)})`);
      break;
    case 'graphgraphpattern':
      addLine(`GRAPH ${getTripleElem(pattern.graph)} {`);
      addGroupGraphPatternSub(pattern.value);
      addLine('}');
      break;
    case 'unionpattern':
      for (let i = 0; i < pattern.value.length; i++) {
        if (i > 0) {
          addLine('UNION');
        }
        addGGP(pattern.value[i]);
      }
      break;
    case 'optionalgraphpattern':
      addLine('OPTIONAL {');
      addGroupGraphPatternSub(pattern.value);
      addLine('}');
      break;
    case 'servicegraphpattern':
      addLine(`SERVICE ${getTripleElem(pattern.value[0])}`);
      addGGP(pattern.value[1]);
      break;
    case 'minusgraphpattern':
      addLine('MINUS {');
      addGroupGraphPatternSub(pattern.value);
      addLine('}');
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

const addFilter = (filter) => {
  if (filter.value.expressionType === 'builtincall' && filter.value.builtincall === 'notexists') {
    addLine(`FILTER NOT EXISTS`);
    filter.value.args.forEach(addGGP);
  } else if (filter.value.expressionType === 'builtincall' && filter.value.builtincall === 'exists') {
    addLine(`FILTER EXISTS`);
    filter.value.args.forEach(addGGP);
  } else {
    addLineWithComment(`FILTER ${getExpression(filter.value)}`, filter.location.start.offset);
  }
};

const addTriplesBlock = (triplesblock) => {
  if (triplesblock.triplesblock) {
    addTriplesBlock(triplesblock.triplesblock);
  } else {
    triplesblock.forEach((t) => {
      if (t.graph) {
        addLineWithComment(`GRAPH ${getTripleElem(t.graph)} {`, t.graph.location.start.offset);
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
  let out;
  let outPos;
  triplepath.propertylist.pairs.forEach((pair) => {
    const p = getTripleElem(pair[0]);
    const o = getTripleElem(pair[1]);
    if (out) {
      addLineWithComment(`${out} ;`, outPos);
      out = ' '.repeat(s.length) + ` ${p} ${o}`;
      if (pair[0].location) {
        outPos = pair[0].location.start.offset;
      } else {
        outPos = pair[1][0].location.start.offset;
      }
    } else {
      out = `${s} ${p} ${o}`;
      outPos = triplepath.chainSubject.location.start.offset;
    }
  });
  addLineWithComment(`${out} .`, outPos);
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
    let expression;
    if (expr.expression === '*') {
      expression = '*'
    } else {
      expression = getExpression(expr.expression);
    }
    return `COUNT(${distinct}${expression})`;
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
      let multi = getExpression(expr.factor);
      expr.factors.forEach((elem) => {
        multi += ' ' + elem.operator + ' ' + getExpression(elem.expression);
      });
      return getBracketted(multi, expr.bracketted);
    case 'additiveexpression':
      let additive = getExpression(expr.op1);
      expr.ops.forEach((elem) => {
        additive += ' ' + elem.operator + ' ' + getExpression(elem.expression);
      });
      return getBracketted(additive, expr.bracketted);
    case 'relationalexpression':
      let relation = getExpression(expr.op1) + ' ' + expr.operator + ' ';
      if (Array.isArray(expr.op2)) {
        relation += '(' + expr.op2.map(getTripleElem).join(', ') + ')';
      } else {
        relation += getExpression(expr.op2);
      }
      return getBracketted(relation, expr.bracketted);
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
        let path = elem.value.map((e) => getTripleElem(e)).join('|');
        if (elem.bracketted) {
          path = `(${path})`;
        }
        if (elem.modifier) {
          path += elem.modifier;
        }
        return path;
      } else if (elem.kind === 'sequence') {
        return elem.value.map((e) => getPredicate(e)).join('/');
      } else {
        return getPredicate(elem);
      }
    case 'blank':
      return elem.value || '[]';
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
