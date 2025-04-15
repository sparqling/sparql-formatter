let output;
let comments;
let currentIndent;
let indentUnit = '  ';
let offset = 0;

export function formatAst(ast, indentDepth = 2) {
  indentUnit = ' '.repeat(indentDepth);

  output = [];
  comments = ast.comments;
  currentIndent = '';

  if (ast.headers) {
    addLine(ast.headers.join(''));
  }
  if (ast.prologue?.decl.length) {
    ast.prologue.decl.forEach((p) => {
      if (p.type === 'BaseDecl') {
        addLine(`BASE <${p.iriref}>`);
      } else {
        addLine(`PREFIX ${p.pn_prefix || ''}: <${p.iriref}>`);
      }
    });
    addLine('');
  }

  if (ast.selectQuery) {
    addSelect(ast.selectQuery);
  } else if (ast.constructQuery) {
    addConstruct(ast.constructQuery);
  } else if (ast.askQuery) {
    addAsk(ast.askQuery);
  } else if (ast.describeQuery) {
    addDescribe(ast.describeQuery);
  } else if (ast.update) {
    for (let i = 0; i < ast.update.length; i++) {
      if (i > 0) {
        output[output.length - 1] += " ;\n";
      }
      addUnit(ast.update[i]);
    }
  }
  if (ast.values) {
    addInlineData(ast.values);
  }

  while (comments && comments.length) {
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
  while (comments && comments.length && comments[0].pos < pos) {
    output[output.length - 1] += comments.shift().text;
  }
  addLine(line);
};

const addAsk = (query) => {
  addLine('ASK {');
  const endPos = addPatterns(query.where);
  addLineWithComment('}', endPos+1);
  addSolutionModifier(query);
}

const addDescribe = (query) => {
  const elems = query.describe.map(getElem).join(' ');
  addLine(`DESCRIBE ${elems}`);
  addDataset(query.from);
  if (query.where) {
    addLine('WHERE {');
    const endPos = addPatterns(query.where);
    addLineWithComment('}', endPos+1);
  }
  addSolutionModifier(query);
}

const addUnit = (unit) => {
  if (unit.type === 'insertdata') {
    addLine('INSERT DATA {');
    increaseIndent();
    addTriples(unit.insert);
    decreaseIndent();
    addLine('}');
  } else if (unit.type === 'deletedata') {
    addLine('DELETE DATA {');
    increaseIndent();
    addTriples(unit.delete);
    decreaseIndent();
    addLine('}');
  } else if (unit.type === 'deletewhere') {
    addLine('DELETE WHERE {');
    increaseIndent();
    addTriples(unit.delete);
    decreaseIndent();
    addLine('}');
  } else if (unit.type === 'modify') {
    if (unit.with) {
      addLine(`WITH ${getElem(unit.with)}`);
    }
    if (unit.delete) {
      addLine('DELETE {');
      increaseIndent();
      addTriples(unit.delete);
      decreaseIndent();
      addLine('}');
    }
    if (unit.insert) {
      addLine('INSERT {');
      increaseIndent();
      addTriples(unit.insert);
      decreaseIndent();
      addLine('}');
    }
    if (unit.using) {
      unit.using.forEach((u) => {
        addLine(`USING ${getUsing(u)}`);
      });
    }
    addLine('WHERE {');
    const endPos = addPatterns(unit.where);
    addLineWithComment('}', endPos+1);
  } else if (unit.type === 'add') {
    const g1 = getGraphOrDefault(unit.graphs[0]);
    const g2 = getGraphOrDefault(unit.graphs[1]);
    let silent = ' ';
    if (unit.silent) {
      silent = ' SILENT ';
    }
    addLine(`ADD${silent}${g1} TO ${g2}`);
  } else if (unit.type === 'move') {
    const g1 = getGraphOrDefault(unit.graphs[0]);
    const g2 = getGraphOrDefault(unit.graphs[1]);
    let silent = ' ';
    if (unit.silent) {
      silent = ' SILENT ';
    }
    addLine(`MOVE${silent}${g1} TO ${g2}`);
  } else if (unit.type === 'copy') {
    const g1 = getGraphOrDefault(unit.graphs[0]);
    const g2 = getGraphOrDefault(unit.graphs[1]);
    let silent = ' ';
    if (unit.silent) {
      silent = ' SILENT ';
    }
    addLine(`COPY${silent}${g1} TO ${g2}`);
  } else if (unit.type === 'load') {
    let silent = ' ';
    if (unit.silent) {
      silent = ' SILENT ';
    }
    addLine(`LOAD${silent}${getUri(unit.sourceGraph)}`);
  } else if (unit.type === 'clear') {
    let silent = ' ';
    if (unit.silent) {
      silent = ' SILENT ';
    }
    addLine(`CLEAR${silent}${getGraphRefAll(unit.destinyGraph)}`);
  } else if (unit.type === 'drop') {
    let silent = ' ';
    if (unit.silent) {
      silent = ' SILENT ';
    }
    addLine(`DROP${silent}${getGraphRefAll(unit.destinyGraph)}`);
  } else if (unit.type === 'create') {
    let silent = ' ';
    if (unit.silent) {
      silent = ' SILENT ';
    }
    addLine(`CREATE${silent}GRAPH ${getUri(unit.destinyGraph)}`);
  }
};

const getUsing = (graph) => {
  if (graph.named) {
    return `NAMED ${getUri(graph.iri)}`;
  } else {
    return getUri(graph.iri);
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

const addPatterns = (where, endPos = 0) => {
  increaseIndent();
  if (where.type === 'SubSelect') {
    addSubSelect(where);
    endPos = where.location.end.offset;
  } else if (where.graphPattern) {
    where.graphPattern.forEach((pattern) => {
      addPattern(pattern);
      endPos = pattern.location.end.offset;
    });
  } else {
    where.forEach((pattern) => {
      addPattern(pattern);
      endPos = pattern.location.end.offset;
    });
  }
  decreaseIndent();

  return endPos;
};

const addSelect = (query) => {
  const pos = query.selectClause.location.start.offset;
  addLineWithComment(getSelectClause(query.selectClause), pos);

  let endPos = query.selectClause.location.end.offset;
  const datasetEndPos= addDataset(query.selectClause.from);
  if (datasetEndPos > endPos) {
    endPos = datasetEndPos;
  }

  addLineWithComment('WHERE {', endPos+1);
  endPos = addPatterns(query.whereClause, endPos);
  addLineWithComment('}', endPos+1);

  addSolutionModifier(query);
};

const addSubSelect = (query) => {
  const pos = query.selectClause.location.start.offset;
  let endPos = query.selectClause.location.end.offset;

  addLineWithComment(getSelectClause(query.selectClause), pos);
  addLineWithComment('WHERE {', endPos+1);
  endPos = addPatterns(query.whereClause, endPos);
  addLineWithComment('}', endPos+1);

  if (query.values) {
    addInlineData(query.values);
  }

  addSolutionModifier(query);
};

const addDataset = (dataset) => {
  if (dataset) {
    let endPos;
    dataset.forEach((d) => {
      if (d.graph) {
        endPos = addFrom(d.graph);
      } else if (d.namedGraph) {
        endPos = addFromNamed(d.namedGraph);
      }
    });
    return endPos;
  }
}

const addSolutionModifier = (query) => {
  if (query.group) {
    addLine(getGroupClause(query.group));
  }
  if (query.having) {
    addLine(`HAVING ${getExpression(query.having[0])}`);
  }
  if (query.orderBy) {
    addLine('ORDER BY ' + getOrderClause(query.orderBy));
  }
  query.limitOffset?.forEach((lo) => {
    if (lo.limit) {
      addLine(`LIMIT ${lo.limit}`);
    } else if (lo.offset) {
      addLine(`OFFSET ${lo.offset}`);
    }
  });
}

const addConstruct = (query) => {
  if (query.template) {
    addLineWithComment('CONSTRUCT {', query.location.start.offset);
    increaseIndent();
    addTriples(query.template.triplePattern);
    decreaseIndent();
    addLine('}');
  } else {
    addLine('CONSTRUCT');
  }

  addDataset(query.from);

  addLine('WHERE {');
  const endPos = addPatterns(query.where);
  addLineWithComment('}', endPos+1);

  addSolutionModifier(query);
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

const addPattern = (pattern) => {
  offset = pattern.location.start.offset;
  if (pattern.type === 'SubSelect') {
    addLine('{');
    increaseIndent();
    addSubSelect(pattern);
    decreaseIndent();
    addLine('}');
    return;
  }
  if (pattern.graphPattern && pattern.graph) {
    addLineWithComment(`GRAPH ${getElem(pattern.graph)} {`, offset);
    const endPos = addPatterns(pattern);
    addLineWithComment('}', endPos+1);
    return;
  }
  if (pattern.graphPattern) {
    addLine('{');
    const endPos = addPatterns(pattern);
    addLineWithComment('}', endPos+1);
    return;
  }
  if (pattern.data) {
    addInlineData(pattern);
    return;
  }
  if (pattern.triplePattern) {
    addTriples(pattern.triplePattern);
    return;
  }
  if (pattern.union) {
    for (let i = 0; i < pattern.union.length; i++) {
      if (i > 0) {
        addLine('UNION');
      }
      addLine('{');
      addPatterns(pattern.union[i]);
      addLineWithComment('}', pattern.union[i].location.end.offset + 2);
    }
    return;
  }
  if (pattern.optional) {
    addLineWithComment('OPTIONAL {', offset);
    const endPos = addPatterns(pattern.optional);
    addLineWithComment('}', endPos+1);
    return;
  }
  if (pattern.minus) {
    addLineWithComment('MINUS {', offset);
    const endPos = addPatterns(pattern.minus);
    addLineWithComment('}', endPos+1);
    return;
  }
  if (pattern.filter) {
    addFilter(pattern);
    return;
  }
  if (pattern.bind) {
    addLine(`BIND (${getExpression(pattern.bind)} AS ${getVar(pattern.as)})`);
    return;
  }
  if (pattern.type === 'ServiceGraphPattern') {
    let silent = ' ';
    if (pattern.silent) {
      silent = ' SILENT ';
    }
    addLine(`SERVICE${silent}${getElem(pattern.service)} {`);
    if (pattern.pattern.type === 'SubSelect') {
      increaseIndent();
      addSubSelect(pattern.pattern);
      decreaseIndent();
    } else {
      addPatterns(pattern.pattern);
    }
    addLine('}');
    return;
  }
  if (pattern.functionRef) {
    const args = pattern.args.map(getExpression).join(', ');
    addLine(getUri(pattern.functionRef) + `(${args})`);
  }
};

const getGroupClause = (args) => {
  let lines = ['GROUP BY'];
  let i = 0;
  args.forEach((elem) => {
    if (lines[i].length > 80) {
      i++;
      lines[i] = '  ';
    } else {
      lines[i] += ' ';
    }
    lines[i] += getElem(elem);
  });
  return lines.join('\n');
}

const getOrderClause = (conditions) => {
  let orderConditions = [];
  conditions.forEach((condition) => {
    let oc;
    if (condition.type === 'Var') {
      oc = getVar(condition);
    } else {
      oc = getExpression(condition);
    }
    if (condition.asc) {
      orderConditions.push(`ASC${oc}`);
    } else if (condition.desc) {
      orderConditions.push(`DESC${oc}`);
    } else {
      orderConditions.push(oc);
    }
  });

  return orderConditions.join(' ');
};

const getSelectClause = (query) => {
  let select = [];
  select[0] = 'SELECT';
  if (query.distinct) {
    select[0] += ' DISTINCT';
  }
  if (query.reduced) {
    select[0] += ' REDUCED';
  }

  let i = 0;
  query.var.forEach((v) => {
    if (select[i].length > 80) {
      i++;
      select[i] = '  ';
    } else {
      select[i] += ' ';
    }
    select[i] += getSelectVar(v);
  });

  return select.join('\n');
};

const getSelectVar = (v) => {
  if (v.varname) {
    return getVar(v);
  }
  if (v.as) {
    return `(${getExpression(v.expression)} AS ${getVar(v.as)})`;
  }
  if (v === '*') {
    return '*';
  }
};

const addFilter = (filter) => {
  if (filter.filter.notexists) {
    addLine(`FILTER NOT EXISTS {`);
    const endPos = addPatterns(filter.filter.notexists);
    addLineWithComment('}', endPos+1);
  } else if (filter.filter.exists) {
    addLine(`FILTER EXISTS {`);
    const endPos = addPatterns(filter.filter.exists);
    addLineWithComment('}', endPos+1);
  } else {
    addLineWithComment(`FILTER ${getExpression(filter.filter)}`, filter.location.start.offset);
  }
};

const addTriples = (triples) => {
  triples.forEach((t) => {
    if (t.graph) {
      addLineWithComment(`GRAPH ${getElem(t.graph)} {`, t.graph.location.start.offset);
      increaseIndent();
      addTriples(t.triplePattern);
      decreaseIndent();
      addLine('}');
    } else if (t.triplePattern) {
      addTriples(t.triplePattern);
    } else {
      addTriple(t);
    }
  });
};

const addTriple = (triplepath) => {
  const s = getElem(triplepath.subject);
  let out;
  let outPos;
  triplepath.properties.forEach((prop) => {
    if (out) {
      addLineWithComment(`${out} ;`, outPos);
      out = ' '.repeat(s.length) + ` ${getElem(prop.predicate)} ${getElem(prop.objects)}`;
      if (prop.predicate.location) {
        outPos = prop.predicate.location.start.offset;
      } else {
        outPos = prop.predicate.value.location.start.offset;
      }
    } else {
      out = `${s} ${getElem(prop.predicate)} ${getElem(prop.objects)}`;
      outPos = triplepath.subject.location.start.offset;
    }
  });
  addLineWithComment(`${out} .`, outPos);
};

const getTriples = (triples) => {
  let out = '';
  triples.forEach((t) => {
    if (out) {
      out += ' ';
    }
    if (t.graph) {
      out += `GRAPH ${getElem(t.graph)} { `;
      out += getTriples(t.triplePattern);
      out += ' }';
    } else if (t.triplePattern) {
      out += getTriples(t.triplePattern);
    } else {
      out += getTriple(t);
      if (triples.length > 1 || t.properties.length > 1) {
        out += ' .';
      }
    }
  });
  return out;
};

const getTriple = (triplepath) => {
  const s = getElem(triplepath.subject);
  let out;
  triplepath.properties.forEach((prop) => {
    if (out) {
      out += ` ; ${getElem(prop.predicate)} ${getElem(prop.objects)}`;
    } else {
      out = `${s} ${getElem(prop.predicate)} ${getElem(prop.objects)}`;
    }
  });
  return out;
};

const getProperties = (properties, nested) => {
  if (properties.length === 1 && !nested) {
    const prop = properties[0];
    return ` ${getElem(prop.predicate)} ${getElem(prop.objects)}`;
  }
  increaseIndent();
  let ret = '';
  const indent = currentIndent + ' '.repeat(2);
  properties.forEach((prop) => {
    if (ret) {
      ret += ` ;\n`;
      ret += `${indent} ${getElem(prop.predicate)} ${getElem(prop.objects, true)}`;
    } else {
      ret += `\n${indent}`;
      ret += ` ${getElem(prop.predicate)} ${getElem(prop.objects, true)}`;
    }
  });
  ret += `\n${currentIndent}`;
  decreaseIndent();
  return ret;
};

const getAggregate = (expr) => {
  let distinct = expr.distinct ? 'DISTINCT ' : '';
  if (expr.aggregateType === 'count') {
    let expression;
    if (expr.expression === '*') {
      expression = '*'
    } else {
      expression = getExpression(expr.expression);
    }
    return `COUNT(${distinct}${expression})`;
  } else if (expr.aggregateType === 'sum') {
    return `sum(${distinct}${getExpression(expr.expression)})`;
  } else if (expr.aggregateType === 'min') {
    return `MIN(${distinct}${getExpression(expr.expression)})`;
  } else if (expr.aggregateType === 'max') {
    return `MAX(${distinct}${getExpression(expr.expression)})`;
  } else if (expr.aggregateType === 'avg') {
    return `AVG(${distinct}${getExpression(expr.expression)})`;
  } else if (expr.aggregateType === 'sample') {
    return `SAMPLE(${distinct}${getExpression(expr.expression)})`;
  } else if (expr.aggregateType === 'group_concat') {
    let separator = '';
    if (expr.separator) {
      separator = `; SEPARATOR = ${getLiteral(expr.separator)}`;
    }
    return `GROUP_CONCAT(${distinct}${getExpression(expr.expression)}${separator})`;
  }
};

const getExpression = (expr) => {
  if (expr.functionRef) {
    return getUri(expr.functionRef) + '(' + expr.args.map(getExpression).join(', ') + ')';
  }
  if (expr.exists) {
    const triples = getTriples(expr.exists);
    return `EXISTS { ${triples} }`;
  }
  if (expr.notexists) {
    const triples = getTriples(expr.notexists);
    return `NOT EXISTS { ${triples} }`;
  }
  switch (expr.expressionType) {
    case 'atomic':
      return getBracketted(getElem(expr.value), expr.bracketted);
    case 'irireforfunction':
      let iri = getUri(expr.iriref);
      if (expr.args) {
        iri += '(' + expr.args.map(getExpression).join(', ') + ')';
      }
      return getBracketted(iri, expr.bracketted);
    case 'builtincall':
      let args = '';
      if (expr.args) {
        args = expr.args.map(getElem).join(', ');
      }
      return getBracketted(`${expr.builtincall}(${args})`, expr.bracketted);
    case 'unaryexpression':
      let ex = expr.unaryexpression + getExpression(expr.expression);
      return getBracketted(ex, expr.bracketted);
    case 'aggregate':
      return getAggregate(expr);
    case 'multiplicativeexpression':
      let multi = getExpression(expr.first);
      expr.rest.forEach((elem) => {
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
        relation += '(' + expr.op2.map(getElem).join(', ') + ')';
      } else {
        relation += getExpression(expr.op2);
      }
      return getBracketted(relation, expr.bracketted);
    case 'aliasedexpression':
      let ret = getExpression(expr.expression);
      if (expr.as) {
        ret += ` AS ${getVar(expr.as)}`;
      }
      return getBracketted(ret, expr.bracketted);
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
  if (inline.oneVar) {
    const v = getElem(inline.oneVar);
    const vals = inline.data.map(getElem).join(' ');
    addLine(`VALUES ${v} { ${vals} }`);
  } else if (inline.variables) {
    const vars = inline.variables.map(getVar).join(' ');
    if (inline.variables.length === 1) {
      const vals = inline.data.map((tuple) => {
        return '(' + tuple.map(getElem).join(' ') + ')';
      }).join(' ');
      addLine(`VALUES (${vars}) { ${vals} }`);
    } else {
      addLine(`VALUES (${vars}) {`);
      increaseIndent();
      inline.data.map((tuple) => {
        addLine('(' + tuple.map(getElem).join(' ') + ')');
      });
      decreaseIndent();
      addLine('}');
    }
  }
};

const getElem = (elem, nested = false) => {
  if (elem === 'UNDEF') {
    return elem;
  }
  if (Array.isArray(elem)) {
    return elem.map((e) => getElem(e, nested)).join(', ');
  }
  if (elem.varname) {
    return getVar(elem);
  }
  if (elem.collection) {
    const collection = elem.collection.map((c) => {
      return getElem(c)
    }).join(' ');
    return `( ${collection} )`;
  }

  if (elem.hasOwnProperty('literal')) {
    return getLiteral(elem);
  }
  if (elem.blankNode) {
    return elem.blankNode;
  }
  if (elem.expressionType) {
    return getExpression(elem);
  }

  if (elem.blankNodeProperties) {
    return `[${getProperties(elem.blankNodeProperties, nested)} ]`;
  }

  // Path
  let ret = '';
  if (elem.inverse) {
    ret += '^';
  }

  if (elem.pn_prefix || elem.pn_local || elem.iriref || elem.a) {
    ret += getUri(elem);
  }
  if (elem.alternative) {
    ret += elem.alternative.map((e) => getElem(e)).join('|');
  } else if (elem.sequence) {
    ret += elem.sequence.map((e) => getElem(e)).join('/');
  }

  if (elem.bracketted) {
    ret = `(${ret})`;
  }
  if (elem.modifier) {
    ret += elem.modifier;
  }
  return ret;
};

const getLiteral = (elem) => {
  if (elem.dataType === 'http://www.w3.org/2001/XMLSchema#decimal') {
    return elem.literal;
  } else if (elem.dataType === 'http://www.w3.org/2001/XMLSchema#double') {
    return elem.literal;
  } else if (elem.dataType === 'http://www.w3.org/2001/XMLSchema#integer') {
    return elem.literal;
  } else if (elem.dataType === 'http://www.w3.org/2001/XMLSchema#boolean') {
    return elem.literal;
  }

  let literal = elem.quote + elem.literal + elem.quote;
  if (elem.dataType) {
    literal += `^^${getUri(elem.dataType)}`;
  } else if (elem.lang) {
    literal += '@' + elem.lang;
  }

  return literal;
};

const getUri = (uri) => {
  if (uri.iriref) {
    return `<${uri.iriref}>`;
  } else if (uri.pn_prefix && uri.pn_local) {
    return `${uri.pn_prefix}:${uri.pn_local}`;
  } else if (uri.pn_prefix) {
    return `${uri.pn_prefix}:`;
  } else if (uri.pn_local) {
    return `:${uri.pn_local}`;
  } else if (uri.a) {
    return 'a';
  }
};

const getVar = (variable) => {
  if (variable.varType === 'VAR2') {
    return '$' + variable.varname;
  } else {
    return '?' + variable.varname;
  }
};
