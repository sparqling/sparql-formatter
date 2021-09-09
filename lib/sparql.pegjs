{
  let Comments = {};
}

DOCUMENT = h:(HEADER_LINE*) WS* s:SPARQL WS*
{
  s.headers = h;
  s.comments = Object.entries(Comments).map(([loc, str]) => ({
    text: str,
    line: parseInt(loc),
  }));

  return s;
}

SPARQL = QueryUnit / UpdateUnit

// [1] QueryUnit ::= Query
QueryUnit = Query

// [2] Query ::= Prologue ( SelectQuery | ConstructQuery | DescribeQuery | AskQuery ) ValuesClause
Query = p:Prologue WS* q:( SelectQuery / ConstructQuery / DescribeQuery / AskQuery ) v:ValuesClause
{
  return {
    token: 'query',
    prologue: p,
    body: q,
    inlineData: v,
  }
}

// [3] UpdateUnit ::= Update
UpdateUnit = Update

// [4] Prologue ::= ( BaseDecl | PrefixDecl )*
Prologue = ( BaseDecl / PrefixDecl )*

// [5] BaseDecl ::= 'BASE' IRIREF
BaseDecl = WS* 'BASE'i WS* i:IRIREF
{
  return {
    token: 'base',
    value: i,
  }
}

// [6] PrefixDecl ::= 'PREFIX' PNAME_NS IRIREF
PrefixDecl = WS* 'PREFIX'i  WS* p:PNAME_NS WS* l:IRIREF
{
  return {
    token: 'prefix',
    prefix: p,
    local: l,
  }
}

// [7] SelectQuery ::= SelectClause DatasetClause* WhereClause SolutionModifier
SelectQuery = s:SelectClause WS* gs:DatasetClause* WS* w:WhereClause WS* sm:SolutionModifier
{
  const dataset = { named: [], implicit: [] };
  gs.forEach((g) => {
    if (g.kind === 'default') {
      dataset.implicit.push(g.graph);
    } else {
      dataset.named.push(g.graph);
    }
  });

  if (dataset.named.length === 0 && dataset.implicit.length === 0) {
    dataset.implicit.push({
      token:'uri',
      location: null,
      prefix: null,
      suffix: null,
    });
  }

  return {
    token: 'executableunit',
    kind: 'select',
    dataset: dataset,
    projection: s.vars,
    modifier: s.modifier,
    pattern: w,
    limitoffset: sm.limitoffset,
    group: sm.group,
    having: sm.having,
    order: sm.order,
    location: location(),
  }
}

// [8] SubSelect ::= SelectClause WhereClause SolutionModifier ValuesClause
SubSelect = s:SelectClause WS* w:WhereClause WS* sm:SolutionModifier v:ValuesClause
{
  return {
    token: 'subselect',
    kind: 'select',
    projection: s.vars,
    modifier: s.modifier,
    pattern: w,
    limitoffset: sm.limitoffset,
    group: sm.group,
    order: sm.order,
    inlineData: v,
  };
}

// [9] SelectClause ::= 'SELECT' ( 'DISTINCT' | 'REDUCED' )? ( ( Var | ( '(' Expression 'AS' Var ')' ) )+ | '*' )
SelectClause = 'SELECT'i WS* m:( 'DISTINCT'i / 'REDUCED'i )? WS*
  vs:(
    (
      ( WS* Var ) /
      ( WS* '(' WS* Expression WS* 'AS'i WS* Var WS* ')' )
    )+ /
    '*'
  )
{
  let vars;
  if (vs === '*') {
    vars = [{
      token: 'variable',
      kind: '*',
      location: location(),
    }];
  } else {
    vars = vs.map((v) => {
      if (v.length === 2) {
        return {
          token: 'variable',
          kind: 'var',
          value: v[1],
        };
      } else {
        return {
          token: 'variable',
          kind: 'aliased',
          expression: v[3],
          alias: v[7],
          location: location(),
        };
      }
    });
  }

  return {
    vars: vars,
    modifier: m?.toUpperCase(),
  };
}

// [10] ConstructQuery ::= 'CONSTRUCT' ( ConstructTemplate DatasetClause* WhereClause SolutionModifier | DatasetClause* 'WHERE' '{' TriplesTemplate? '}' SolutionModifier )
ConstructQuery = 'CONSTRUCT'i WS* t:ConstructTemplate WS* gs:DatasetClause* WS* w:WhereClause WS* sm:SolutionModifier
{
  const dataset = { named:[], implicit:[] };
  gs.forEach((g) => {
    if (g.kind === 'default') {
      dataset.implicit.push(g.graph);
    } else {
      dataset.named.push(g.graph);
    }
  });

  if (dataset.named.length === 0 && dataset.implicit.length === 0) {
    dataset.implicit.push({
      token:'uri',
      prefix:null,
      suffix:null,
    });
  }
  
  return {
    kind: 'construct',
    token: 'executableunit',
    dataset: dataset,
    template: t,
    pattern: w,
    limitoffset: sm.limitoffset,
    order: sm.order,
    location: location(),
  };
}
/ 'CONSTRUCT'i WS* gs:DatasetClause* WS* 'WHERE'i WS* '{' WS* t:TriplesTemplate? WS* '}' WS* sm:SolutionModifier
{
  let dataset = { named: [], implicit: [] };
  gs.forEach((g) => {
    if (g.kind === 'default') {
      dataset.implicit.push(g.graph);
    } else {
      dataset.named.push(g.graph)
    }
  });

  if (dataset.named.length === 0 && dataset.implicit.length === 0) {
    dataset.implicit.push({
      token:'uri',
      prefix:null,
      suffix:null,
    });
  }
  
  return {
    kind: 'construct',
    token: 'executableunit',
    dataset: dataset,
    pattern: t,
    limitoffset: sm.limitoffset,
    order: sm.order,
    location: location(),
  };
}

// [11] DescribeQuery ::= 'DESCRIBE' ( VarOrIri+ | '*' ) DatasetClause* WhereClause? SolutionModifier
DescribeQuery = 'DESCRIBE'i WS* v:( VarOrIri+ / '*' ) WS* gs:DatasetClause* WS* w:WhereClause? WS* sm:SolutionModifier
{
  let dataset = { named: [], implicit: [] };
  gs.forEach((g) => {
    if (g.kind === 'default') {
      dataset.implicit.push(g.graph);
    } else {
      dataset.named.push(g.graph)
    }
  });

  return {
    token: 'executableunit',
    kind: 'describe',
    dataset: dataset,
    value: v,
    pattern: w,
    limitoffset: sm.limitoffset,
    order: sm.order,
    location: location(),
  }
}

// [12] AskQuery ::= 'ASK' DatasetClause* WhereClause SolutionModifier
AskQuery = WS* 'ASK'i WS* gs:DatasetClause* WS* w:WhereClause WS* sm:SolutionModifier
{
  const dataset = { named: [], implicit: [] };
  gs.forEach((g) => {
    if (g.kind === 'implicit') {
      dataset.implicit.push(g.graph);
    } else {
      dataset.named.push(g.graph);
    }
  });

  if (dataset.named.length === 0 && dataset.implicit.length === 0) {
    dataset.implicit.push({
      token:'uri',
      prefix:null,
      suffix:null,
    });
  }

  return {
    kind: 'ask',
    token: 'executableunit',
    dataset: dataset,
    pattern: w,
    limitoffset: sm.limitoffset,
    group: sm.group,
    order: sm.order,
    location: location(),
  }
}

// [13] DatasetClause ::= 'FROM' ( DefaultGraphClause | NamedGraphClause )
DatasetClause = 'FROM'i WS* gs:( DefaultGraphClause / NamedGraphClause ) WS*
{
  return gs;
}

// [14] DefaultGraphClause ::= SourceSelector
DefaultGraphClause = WS* s:SourceSelector
{
  return {
    kind: 'default',
    token: 'graphClause',
    graph: s,
    location: location(),
  }
}

// [15] NamedGraphClause ::= 'NAMED' SourceSelector
NamedGraphClause = 'NAMED'i WS* s:SourceSelector
{
  return {
    token: 'graphCluase',
    kind: 'named',
    graph: s,
    location: location(),
  };
}

// [16] SourceSelector ::= IRIref
SourceSelector = IRIref

// [17] WhereClause ::= 'WHERE'? GroupGraphPattern
WhereClause = ('WHERE'i)? WS* g:GroupGraphPattern
{
  return g;
}

// [18] SolutionModifier ::= GroupClause? HavingClause? OrderClause? LimitOffsetClauses?
SolutionModifier = gc:GroupClause? h:HavingClause? oc:OrderClause? lo:LimitOffsetClauses?
{
  return {
    group: gc,
    order: oc,
    limitoffset: lo,
    having: h,
  }
}
                             
// [19] GroupClause ::= 'GROUP' 'BY' GroupCondition+
GroupClause = 'GROUP'i WS* 'BY'i WS* conds:GroupCondition+
{
  return conds;
}

// [20] GroupCondition ::= BuiltInCall | FunctionCall | '(' Expression ( 'AS' Var )? ')' | Var
GroupCondition = WS* b:BuiltInCall WS* 
{
  return b;
}
/ WS* f:FunctionCall WS*
{
  return f;
}
/ WS* '(' WS* e:Expression WS* as:( 'AS'i WS* Var )? WS* ')' WS*
{
  if (as) {
    return {
      token: 'aliased_expression',
      expression: e,
      alias: as[2],
      location: location(),
    };
  } else {
    e.bracketted = 'true';
    return e;
  }
}
/ WS* v:Var WS*
{
  return v;
}

// [21] HavingClause ::= 'HAVING' HavingCondition+
HavingClause = 'HAVING' WS* h:HavingCondition+
{
  return h;
}

// [22] HavingCondition ::= Constraint
HavingCondition = Constraint

// [23] OrderClause ::= 'ORDER' 'BY' OrderCondition+
OrderClause = 'ORDER'i WS* 'BY'i WS* os:OrderCondition+ WS*
{
  return os;
}

// [24] OrderCondition ::= ( ( 'ASC' | 'DESC' ) BrackettedExpression ) | ( Constraint | Var )
OrderCondition = direction:( 'ASC'i / 'DESC'i ) WS* e:BrackettedExpression WS*
{
  return {
    direction: direction.toUpperCase(),
    expression: e
  };
}
/ e:( Constraint / Var ) WS*
{
  if (e.token === 'var') {
    return {
      direction: 'ASC',
      expression: {
        value: e,
        token:'expression',
        expressionType:'atomic',
        primaryexpression: 'var',
        location: location(),
      }
    };
  } else {
    return {
      direction: 'ASC',
      expression: e,
    };
  }
}

// [25] LimitOffsetClauses ::= LimitClause OffsetClause? | OffsetClause LimitClause?
LimitOffsetClauses = cls:( LimitClause OffsetClause? / OffsetClause LimitClause? )
{
  let acum = [cls[0]];
  if (cls[1]) {
    acum.push(cls[1]);
  }
  return acum;
}

// [26] LimitClause ::= 'LIMIT' INTEGER
LimitClause = 'LIMIT'i WS* i:INTEGER WS*
{
  return {
    limit: parseInt(i.value)
  };
}

// [27] OffsetClause ::= 'OFFSET' INTEGER
OffsetClause = 'OFFSET'i WS* i:INTEGER WS*
{
  return {
    offset: parseInt(i.value)
  };
}

// [28] ValuesClause ::= ( 'VALUES' DataBlock )?
ValuesClause = b:( 'VALUES'i DataBlock )?
{
  if (b != null) {
    return b[1];
  } else {
    return null;
  }
}

// [29] Update ::= Prologue ( Update1 ( ';' Update )? )?
Update = p:Prologue u:( WS* Update1 ( WS* ';' WS* Update )? )? WS*
{
  let query = {
    token: 'update',
    prologue: p,
    units: [],
  };
  
  if (u) {
    query.units = [u[1]];
    if (u[2]) {
      query.units = query.units.concat(u[2][3].units);
    }
  }

  return query;
}

// [30] Update1 ::= Load | Clear | Drop | Add | Move | Copy | Create | InsertData | DeleteData | DeleteWhere | Modify
Update1 = Load / Clear / Drop / Add / Move / Copy / Create / InsertData / DeleteData / DeleteWhere / Modify

// [31] Load ::= 'LOAD' 'SILENT'? IRIref ( 'INTO' GraphRef )?
Load = 'LOAD'i WS* s:'SILENT'i? WS* sg:IRIref WS* dg:( 'INTO'i WS* GraphRef)?
{
  let query = {
    kind: 'load',
    token: 'executableunit',
    silent: s,
    sourceGraph: sg,
  };
  if (dg != null) {
    query.destinyGraph = dg[2];
  }

  return query;
}

// [32] Clear ::= 'CLEAR' 'SILENT'? GraphRefAll
Clear = 'CLEAR'i WS* s:'SILENT'i? WS* ref:GraphRefAll
{
  return {
    token: 'executableunit',
    kind: 'clear',
    silent: s,
    destinyGraph: ref,
  }
}

// [33] Drop ::= 'DROP' 'SILENT'? GraphRefAll
Drop = 'DROP'i  WS* s:'SILENT'i? WS* ref:GraphRefAll
{
  return {
    token: 'executableunit',
    kind: 'drop',
    silent: s,
    destinyGraph: ref,
  }
}

// [34] Create ::= 'CREATE' 'SILENT'? GraphRef
Create = 'CREATE'i WS* s:'SILENT'i? WS* ref:GraphRef
{
  return {
    token: 'executableunit',
    kind: 'create',
    silent: s,
    destinyGraph: ref,
  }
}

// [35] Add ::= 'ADD' 'SILENT'? GraphOrDefault 'TO' GraphOrDefault
Add = 'ADD'i WS* s:'SILENT'i? WS* g1:GraphOrDefault WS* 'TO'i WS* g2:GraphOrDefault
{
  return {
    token: 'executableunit',
    kind: 'add',
    silent: s,
    graphs: [g1, g2],
  }
}

// [36] Move ::= 'MOVE' 'SILENT'? GraphOrDefault 'TO' GraphOrDefault
Move = 'MOVE'i WS* s:'SILENT'i? WS* g1:GraphOrDefault WS* 'TO'i WS* g2:GraphOrDefault
{
  return {
    token: 'executableunit',
    kind: 'move',
    silent: s,
    graphs: [g1, g2],
  }
}

// [37] Copy ::= 'COPY' 'SILENT'? GraphOrDefault 'TO' GraphOrDefault
Copy = 'COPY'i WS* s:'SILENT'i? WS* g1:GraphOrDefault WS* 'TO'i WS* g2:GraphOrDefault
{
  return {
    token: 'executableunit',
    kind: 'copy',
    silent: s,
    graphs: [g1, g2],
  }
}

// [38] InsertData ::= 'INSERT DATA' QuadData
InsertData = 'INSERT'i WS* 'DATA'i WS* qs:QuadData
{
  return {
    token: 'executableunit',
    kind: 'insertdata',
    quads: qs,
  }
}

// [39] DeleteData ::= 'DELETE DATA' QuadData
DeleteData = 'DELETE'i WS* 'DATA'i qs:QuadData
{
  return {
    token: 'executableunit',
    kind: 'deletedata',
    quads: qs,
  }
}

// [40] DeleteWhere ::= 'DELETE WHERE' QuadPattern
DeleteWhere = 'DELETE'i WS* 'WHERE'i WS* p:GroupGraphPattern
{
  return {
    kind: 'deletewhere',
    pattern: p,
  };
}

// [41] Modify ::= ( 'WITH' IRIref )? ( DeleteClause InsertClause? | InsertClause ) UsingClause* 'WHERE' GroupGraphPattern
Modify = w:( 'WITH'i WS* IRIref WS* )? m:( DeleteClause WS* InsertClause? / InsertClause ) WS* u:UsingClause* WS* 'WHERE'i WS* p:GroupGraphPattern WS*
{
  let query = {
    kind: 'modify',
  };

  if (w) {
    query.with = w[2];
  }

  if (m.length === 3) {
    query.delete = m[0];
    if (m[2]) {
      query.insert = m[2];
    }
  } else {
    query.insert = m;
  }

  if (u.length) {
    query.using = u;
  }

  query.pattern = p;

  return query;
}

// [42] DeleteClause ::= 'DELETE' QuadPattern
DeleteClause = 'DELETE'i q:QuadPattern
{
  return q;
}

// [43] InsertClause ::= 'INSERT' QuadPattern
InsertClause = 'INSERT'i q:QuadPattern
{
  return q;
}

// [44] UsingClause ::= 'USING' ( IRIref | 'NAMED' IRIref )
UsingClause = WS* 'USING'i WS* g:( IRIref / 'NAMED'i WS* IRIref )
{
  if (g.length != null) {
    return { kind: 'named', uri: g[2] };
  } else {
    return { kind: 'default', uri: g };
  }
}

// [45] GraphOrDefault ::= 'DEFAULT' | 'GRAPH'? IRIref
GraphOrDefault = 'DEFAULT' / 'GRAPH'i? WS* i:IRIref
{
  return i;
}

// [46] GraphRef ::= 'GRAPH' IRIref
GraphRef = 'GRAPH'i WS* i:IRIref
{
  return i;
}

// [47] GraphRefAll ::= GraphRef | 'DEFAULT' | 'NAMED' | 'ALL'
GraphRefAll = g:GraphRef
{
  return g;
}
/ 'DEFAULT'i
{
  return 'default';
}
/ 'NAMED'i
{
  return 'named';
}
/ 'ALL'i
{
  return 'all';
}

// [48] QuadPattern ::= '{' Quads '}'
QuadPattern = WS* '{' WS* q:Quads WS* '}' WS*
{
  return q;
}

// [49] QuadData ::= '{' Quads '}'
QuadData = WS* '{' WS* q:Quads WS* '}' WS*
{
  return q;
}

// [50] Quads ::= TriplesTemplate? ( QuadsNotTriples '.'? TriplesTemplate? )*
Quads = ts:TriplesTemplate? qs:( QuadsNotTriples '.'? TriplesTemplate? )*
{
  let quads = [];
  if (ts) {
    quads = quads.concat(ts);
  }
  qs.forEach((q) => {
    quads = quads.concat(q[0]);
    if (q[2]) {
      quads = quads.concat(q[2]);
    }
  });

  return {
    token:'quads',
    triplesblock: quads,
    location: location(),
  }
}

// [51] QuadsNotTriples ::= 'GRAPH' VarOrIri '{' TriplesTemplate? '}'
QuadsNotTriples = WS* 'GRAPH'i WS* g:VarOrIri WS* '{' WS* ts:TriplesTemplate? WS* '}' WS*
{
  ts.graph = g;
  return ts;
}

// [52] TriplesTemplate ::= TriplesSameSubject ( '.' TriplesTemplate? )?
TriplesTemplate = b:TriplesSameSubject bs:( WS* '.' WS* TriplesTemplate? )?
{
  let triplesblock = [b];
  if (bs && bs[3]) {
    triplesblock = triplesblock.concat(bs[3].triplesblock);
  }

  return {
    token:'triplestemplate',
    triplesblock: triplesblock,
    location: location(),
  };
}

// [53] GroupGraphPattern ::= '{' ( SubSelect | GroupGraphPatternSub ) '}'
GroupGraphPattern = '{' WS* p:( SubSelect / GroupGraphPatternSub )  WS* '}'
{
  return p;
}

// [54] GroupGraphPatternSub ::= TriplesBlock? ( GraphPatternNotTriples '.'? TriplesBlock? )*
GroupGraphPatternSub = tb:TriplesBlock? WS* tbs:( GraphPatternNotTriples WS* '.'? WS* TriplesBlock? )*
{
  let patterns = [];

  if (tb) {
    patterns.push(tb);
  }
  tbs.forEach((b) => {
    patterns.push(b[0]);
    if (b[4]) {
      patterns.push(b[4]);
    }
  });

  return {
    token: 'ggp',
    patterns: patterns,
    location: location(),
  }
}

// [55] TriplesBlock ::= TriplesSameSubjectPath ( '.' TriplesBlock? )?
TriplesBlock = a:TriplesSameSubjectPath b:( WS* '.' WS* TriplesBlock? )?
{
  let triplesblock = [a];
  if (b && b[3]) {
    triplesblock = triplesblock.concat(b[3].triplesblock);
  }

  return {
    token: 'triplesblock',
    triplesblock: triplesblock,
    location: location(),
  }
}

// [56] GraphPatternNotTriples ::= GroupOrUnionGraphPattern | OptionalGraphPattern | MinusGraphPattern | GraphGraphPattern | ServiceGraphPattern | Filter | Bind | InlineData
GraphPatternNotTriples = GroupOrUnionGraphPattern / OptionalGraphPattern / MinusGraphPattern / GraphGraphPattern / ServiceGraphPattern / Filter / Bind / InlineData

// [57] OptionalGraphPattern ::= 'OPTIONAL' GroupGraphPattern
OptionalGraphPattern = WS* 'OPTIONAL'i WS* v:GroupGraphPattern
{
  return {
    token: 'optionalgraphpattern',
    value: v,
    location: location(),
  }
}

// [58] GraphGraphPattern ::= 'GRAPH' VarOrIri GroupGraphPattern
GraphGraphPattern = WS* 'GRAPH'i WS* g:VarOrIri WS* gg:GroupGraphPattern
{
  return {
    token: 'graphgraphpattern',
    graph: g,
    value: gg,
  }
}

// [59] ServiceGraphPattern ::= 'SERVICE' 'SILENT'? VarOrIri GroupGraphPattern
ServiceGraphPattern = 'SERVICE' WS* s:'SILENT'i? WS* v:VarOrIri WS* ggp:GroupGraphPattern
{
  return {
    token: 'servicegraphpattern',
    value: [v, ggp],
    silent: s,
    location: location(),
  }
}

// [60] Bind ::= 'BIND' '(' Expression 'AS' Var ')'
Bind = WS* 'BIND'i WS* '(' WS* ex:Expression WS* 'AS'i WS* v:Var WS* ')'
{
  return {
    token: 'bind',
    expression: ex,
    as: v,
    location: location(),
  };
}

// [61] InlineData ::= 'VALUES' DataBlock
InlineData = WS* 'VALUES'i WS* d:DataBlock
{
  return d;
}

// [62] DataBlock ::= InlineDataOneVar | InlineDataFull
DataBlock = InlineDataOneVar / InlineDataFull

// [63] InlineDataOneVar ::= Var '{' DataBlockValue* '}'
InlineDataOneVar = WS* v:Var WS* '{' WS* d:DataBlockValue* '}'
{
  return {
    token: 'inlineData',
    var: v,
    values: d,
    location: location(),
  };
}

// [64] InlineDataFull ::= ( NIL | '(' Var* ')' ) '{' ( '(' DataBlockValue* ')' | NIL )* '}'
InlineDataFull = WS*  '(' WS* vars:Var* ')' WS* '{' WS* vals:DataBlockTuple* '}'
{
  return {
    token: 'inlineDataFull',
    variables: vars,
    values: vals,
    location: location(),
  };
}

DataBlockTuple = '(' WS* vs:DataBlockValue* ')' WS*
{
  return vs;
}

// [65] DataBlockValue ::= iri | RDFLiteral | NumericLiteral | BooleanLiteral | 'UNDEF'
DataBlockValue = v:(IRIref / RDFLiteral / NumericLiteral / BooleanLiteral / 'UNDEF') WS*
{
  return v;
}

// [66] MinusGraphPattern ::= 'MINUS' GroupGraphPattern
MinusGraphPattern = 'MINUS'i WS* ggp:GroupGraphPattern
{
  return {
    token: 'minusgraphpattern',
    value: ggp,
    location: location(),
  }
}

// [67] GroupOrUnionGraphPattern ::= GroupGraphPattern ( 'UNION' GroupGraphPattern )*
GroupOrUnionGraphPattern = a:GroupGraphPattern b:( WS* 'UNION'i WS* GroupGraphPattern )*
{
  if (b.length === 0) {
    return a;
  }

  let lastToken = {
    token: 'graphunionpattern',
    location: location(),
    value: [a],
  };

  for (let i = 0; i < b.length; i++) {
    lastToken.value.push(b[i][3]);
  }

  return lastToken;
}

// [68] Filter ::= 'FILTER' Constraint
Filter = WS* 'FILTER'i WS* c:Constraint
{
  return {
    token: 'filter',
    value: c,
    location: location(),
  }
}

// [69] Constraint ::= BrackettedExpression | BuiltInCall | FunctionCall
Constraint = BrackettedExpression / BuiltInCall / FunctionCall

// [70] FunctionCall ::= IRIref ArgList
FunctionCall = i:IRIref WS* args:ArgList
{
  return {
    token: 'expression',
    expressionType: 'functioncall',
    iriref: i,
    args: args.value,
    location: location(),
  }
}

// [71] ArgList ::= NIL | '(' 'DISTINCT'? Expression ( ',' Expression )* ')'
ArgList = NIL
{
  return {
    token: 'args',
    value: [],
  }
}
/ '(' WS* d:'DISTINCT'i? WS* e:Expression WS* es:( ',' WS* Expression)* ')'
{
  return {
    token: 'args',
    distinct: Boolean(d),
    value: [e].concat(es.map((e) => e[2])),
  }
}

// [72] ExpressionList ::= NIL | '(' Expression ( ',' Expression )* ')'
ExpressionList = NIL
{
  return [];
}
/ '(' WS* e:(IRIref / Expression) WS* es:( ',' WS* (IRIref / Expression))* ')'
{
  return [e].concat(es.map((e) => e[2]));
}

// [73] ConstructTemplate ::= '{' ConstructTriples? '}'
ConstructTemplate = '{' WS* ts:ConstructTriples? WS* '}'
{
  return ts;
}

// [74] ConstructTriples ::= TriplesSameSubject ( '.' ConstructTriples? )?
ConstructTriples = b:TriplesSameSubject bs:( WS* '.' WS* ConstructTriples? )?
{
  let triplesblock = [b];
  if (bs && bs[3]) {
    triplesblock = triplesblock.concat(bs[3].triplesblock);
  }

  return {
    token:'triplestemplate',
    triplesblock: triplesblock,
    location: location(),
  }
}

// [75] TriplesSameSubject ::= VarOrTerm PropertyListNotEmpty | TriplesNode PropertyList
TriplesSameSubject = s:VarOrTerm WS* pairs:PropertyListNotEmpty
{
  return {
    token: 'triplessamesubject',
    chainSubject: s,
    propertylist: pairs,
  }
}
/ WS* tn:TriplesNode WS* pairs:PropertyList
{
  return {
    token: 'triplessamesubject',
    chainSubject: tn,
    propertylist: pairs,
  }
}

// [76] PropertyList ::= PropertyListNotEmpty?
PropertyList = PropertyListNotEmpty?

// [77] PropertyListNotEmpty ::= Verb ObjectList ( ';' ( Verb ObjectList )? )*
PropertyListNotEmpty = v:Verb WS* ol:ObjectList rest:( WS* ';' WS* ( Verb WS* ObjectList )? )*
{
  let pairs = [];
  pairs.push([v, ol]);
  rest.forEach((r) => {
    if (r[3]) {
      pairs.push([r[3][0], r[3][2]]);
    }
  });

  return {
    token: 'propertylist',
    pairs: pairs,
  };
}

// [78] Verb ::= VarOrIri | 'a'
Verb = VarOrIri
/ 'a'
{
  return {
    token: 'uri',
    prefix: null,
    suffix: null,
    value: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
    location: location(),
  }
}

// [79] ObjectList ::= Object ( ',' Object )*
ObjectList = o:Object os:( WS* ',' WS* Object )*
{
  let ret = [o];

  os.forEach((oi) => {
    ret.push(oi[3]);
  });

  return ret;
}

// [80] Object ::= GraphNode
Object = GraphNode

// [81] TriplesSameSubjectPath ::= VarOrTerm PropertyListPathNotEmpty | TriplesNodePath PropertyListPath
TriplesSameSubjectPath = s:VarOrTerm WS* list:PropertyListPathNotEmpty
{
  return {
    token: 'triplessamesubject',
    chainSubject: s,
    propertylist: list,
  }
}
/ WS* tn:TriplesNodePath WS* pairs:PropertyListPath
{
  return {
    token: 'triplessamesubject',
    chainSubject: tn,
    propertylist: pairs,
  };
}

// [82] PropertyListPath ::= PropertyListPathNotEmpty?
PropertyListPath = PropertyListPathNotEmpty?

// [83] PropertyListPathNotEmpty ::= ( VerbPath | VerbSimple ) ObjectListPath ( ';' ( ( VerbPath | VerbSimple ) ObjectList )? )*
PropertyListPathNotEmpty = v:( VerbPath / VerbSimple ) WS* ol:ObjectListPath rest:( WS* ';' WS* ( ( VerbPath / VerbSimple ) WS* ObjectList )? )*
{
  let pairs = [];
  pairs.push([v, ol]);
  rest.forEach((r) => {
    if (r[3]) {
      pairs.push([r[3][0], r[3][2]]);
    }
  });

  return {
    token: 'propertylist',
    pairs: pairs,
  };
}

// [84] VerbPath ::= Path
VerbPath = Path

// [85] VerbSimple ::= Var
VerbSimple = Var

// [86] ObjectListPath ::= ObjectPath ( ',' ObjectPath )*
ObjectListPath = o:ObjectPath os:( WS* ',' WS* ObjectPath )*
{
  let ret = [o];

  os.forEach((oi) => {
    ret.push(oi[3]);
  });

  return ret;
}

// [87] ObjectPath ::= GraphNodePath
ObjectPath = GraphNodePath

// [88] Path ::= PathAlternative
Path = PathAlternative

// [89] PathAlternative ::= PathSequence ( '|' PathSequence )*
PathAlternative = first:PathSequence rest:( WS* '|' WS* PathSequence )*
{
  if (rest.length) {
    let arr = [first];
    for (let i = 0; i < rest.length; i++) {
      arr.push(rest[i][3]);
    }

    return {
      token: 'path',
      kind: 'alternative',
      value: arr,
      location: location(),
    };
  } else {
    return first;
  }
}

// [90] PathSequence ::= PathEltOrInverse ( '/' PathEltOrInverse )*
PathSequence = first:PathEltOrInverse rest:( WS* '/' WS* PathEltOrInverse )*
{
  if (rest.length) {
    let arr = [first];
    for (let i = 0; i < rest.length; i++) {
      arr.push(rest[i][3]);
    }

    return {
      token: 'path',
      kind: 'sequence',
      value: arr,
      location: location(),
    };
  } else {
    return first;
  }
}

// [91] PathElt ::= PathPrimary PathMod?
PathElt = p:PathPrimary mod:PathMod?
{
  if (p.token && p.token != 'path' && mod == '') {
    p.kind = 'primary' // for debug
    return p;
  }
  if (p.token && p.token != 'path' && mod != '') {
    return {
      token: 'path',
      kind: 'element',
      value: p,
      modifier: mod,
    }
  } else {
    p.modifier = mod;
    return p;
  }
}

// [92] PathEltOrInverse ::= PathElt | '^' PathElt
PathEltOrInverse = PathElt
/ '^' elt:PathElt
{
  return {
    token: 'path',
    kind: 'inversePath',
    value: elt,
  };
}

// [93] PathMod ::= '?' | '*' | '+'
// PathMod = ( '*' / '?' / '+' / '{' ( Integer ( ',' ( '}' / Integer '}' ) / '}' ) / ',' Integer '}' ) )
PathMod = m:('?' / '*' / '+')
{
  return m;
}

// [94] PathPrimary ::= IRIref | 'a' | '!' PathNegatedPropertySet | '(' Path ')'
PathPrimary = IRIref
/ 'a'
{
  return {
    token: 'uri',
    prefix: null,
    suffix: null,
    value: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',
    location: location(),
  }
}
/ '!' PathNegatedPropertySet
/ '(' p:Path ')'
{
  p.bracketted = true;
  return p;
}

// [95] PathNegatedPropertySet ::= PathOneInPropertySet | '(' ( PathOneInPropertySet ( '|' PathOneInPropertySet )* )? ')'
PathNegatedPropertySet    = ( PathOneInPropertySet / '(' ( PathOneInPropertySet        ('|' PathOneInPropertySet)* )? ')' )

// [96] PathOneInPropertySet ::= IRIref | 'a' | '^' ( IRIref | 'a' )
PathOneInPropertySet = ( IRIref / 'a' / '^' (IRIref / 'a') )

// [97] Integer ::= INTEGER
Integer = INTEGER

// [98] TriplesNode ::= Collection | BlankNodePropertyList
TriplesNode = c:Collection
{
  return {
    token: 'triplesnodecollection',
    collection: c,
    location: location(),
  };
}
/ BlankNodePropertyList

// [99] BlankNodePropertyList ::= '[' PropertyListNotEmpty ']'
BlankNodePropertyList = WS* '[' WS* pl:PropertyListNotEmpty WS* ']' WS*
{
  return {
    token: 'triplesnode',
    pairs: pl,
    location: location(),
  };
}

// [100] TriplesNodePath ::= CollectionPath | BlankNodePropertyListPath
TriplesNodePath = c:CollectionPath
{
  return {
    token: 'triplesnodecollection',
    collection: c,
    location: location(),
  };
}
/ BlankNodePropertyListPath

// [101] BlankNodePropertyListPath ::= '[' PropertyListPathNotEmpty ']'
BlankNodePropertyListPath = WS* '[' WS* pl:PropertyListPathNotEmpty WS* ']' WS*
{
  return {
    token: 'triplesnode',
    pairs: pl,
    location: location(),
  };
}

// [102] Collection ::= '(' GraphNode+ ')'
Collection = WS* '(' WS* gn:GraphNode+ WS* ')' WS*
{
  return gn;
}

// [103] CollectionPath ::= '(' GraphNodePath+ ')'
CollectionPath = WS* '(' WS* gn:GraphNodePath+ WS* ')' WS*
{
  return gn;
}

// [104] GraphNode ::= VarOrTerm | TriplesNode
GraphNode = WS* gn:( VarOrTerm / TriplesNode )
{
  return gn;
}

// [105] GraphNodePath ::= VarOrTerm | TriplesNodePath
GraphNodePath = WS* gn:( VarOrTerm / TriplesNodePath )
{
  return gn;
}

// [106] VarOrTerm ::= Var | GraphTerm
VarOrTerm = Var / GraphTerm

// [107] VarOrIri ::= Var | IRIref
VarOrIri = Var / IRIref

// [108] Var ::= VAR1 | VAR2
Var = WS* v:( VAR1 / VAR2 ) WS*
{
  return {
    token: 'var',
    prefix: v.prefix,
    value: v.value,
    location: location(),
  }
}

// [109] GraphTerm ::= IRIref | RDFLiteral | NumericLiteral | BooleanLiteral | BlankNode | NIL
GraphTerm = IRIref / RDFLiteral / NumericLiteral / BooleanLiteral / BlankNode / NIL

// [110] Expression ::= ConditionalOrExpression
Expression = ConditionalOrExpression

// [111] ConditionalOrExpression ::= ConditionalAndExpression ( '||' ConditionalAndExpression )*
ConditionalOrExpression = v:ConditionalAndExpression vs:( WS* '||' WS* ConditionalAndExpression )*
{
  if (vs.length) {
    return {
      token: 'expression',
      expressionType: 'conditionalor',
      operands: [v].concat(vs.map(op => op[3])),
    };
  } else {
    return v;
  }
}

// [112] ConditionalAndExpression ::= ValueLogical ( '&&' ValueLogical )*
ConditionalAndExpression = v:ValueLogical vs:( WS* '&&' WS* ValueLogical )*
{
  if (vs.length) {
    return {
      token: 'expression',
      expressionType: 'conditionaland',
      operands: [v].concat(vs.map(op => op[3])),
    };
  } else {
    return v;
  }
}

// [113] ValueLogical ::= RelationalExpression
ValueLogical = RelationalExpression

// [114] RelationalExpression ::= NumericExpression ( '=' NumericExpression | '!=' NumericExpression | '<' NumericExpression | '>' NumericExpression | '<=' NumericExpression | '>=' NumericExpression | 'IN' ExpressionList | 'NOT' 'IN' ExpressionList )?
RelationalExpression = e1:NumericExpression e2:(
                       WS* '=' WS* NumericExpression /
                       WS* '!=' WS* NumericExpression /
                       WS* '<' WS* NumericExpression /
                       WS* '>' WS* NumericExpression /
                       WS* '<=' WS* NumericExpression /
                       WS* '>=' WS* NumericExpression /
                       WS* 'IN'i WS* ExpressionList /
                       WS* 'NOT'i WS* 'IN'i WS* ExpressionList
                     )*
{
  if (e2.length) {
    const o1 = e1;
    let op = e2[0][1].toUpperCase();
    let o2 = e2[0][3];
    if (op === 'NOT') {
      op += ' ' + e2[0][3].toUpperCase();
      o2 = e2[0][5];
    }

    return {
      token: 'expression',
      expressionType: 'relationalexpression',
      operator: op,
      op1: o1,
      op2: o2,
    }
  } else {
    return e1;
  }
}

// [115] NumericExpression ::= AdditiveExpression
NumericExpression = AdditiveExpression

// [116] AdditiveExpression ::= MultiplicativeExpression ( '+' MultiplicativeExpression | '-' MultiplicativeExpression | ( NumericLiteralPositive | NumericLiteralNegative ) ( ( '*' UnaryExpression ) | ( '/' UnaryExpression ) )* )*
AdditiveExpression = op1:MultiplicativeExpression ops:( WS* '+' WS* MultiplicativeExpression / WS* '-' WS* MultiplicativeExpression / ( NumericLiteralPositive / NumericLiteralNegative ) ( (WS* '*' WS* UnaryExpression) / (WS* '/' WS* UnaryExpression))* )*
{
  if (ops.length === 0) {
    return op1;
  }

  let arr = [];
  ops.forEach((op) => {
    if (op.length == 4) {
      arr.push({
        operator: op[1],
        expression: op[3],
      });
    }
  });

  return {
    token: 'expression',
    expressionType: 'additiveexpression',
    op1: op1,
    ops: arr,
  };
}

// [117] MultiplicativeExpression ::= UnaryExpression ( '*' UnaryExpression | '/' UnaryExpression )*
MultiplicativeExpression = e1:UnaryExpression es:( WS* '*' WS* UnaryExpression / WS* '/' WS* UnaryExpression )*
{
  if (es.length) {
    return {
      token: 'expression',
      expressionType: 'multiplicativeexpression',
      factor: e1,
      factors: es.map((e) => ({ operator: e[1], expression: e[3] })),
    };
  } else {
    return e1;
  }
}

// [118] UnaryExpression ::= '!' PrimaryExpression | '+' PrimaryExpression | '-' PrimaryExpression | PrimaryExpression
UnaryExpression = '!' WS* e:PrimaryExpression
{
  return {
    token: 'expression',
    expressionType: 'unaryexpression',
    unaryexpression: '!',
    expression: e,
  }
}
/ '+' WS* v:PrimaryExpression
{
  return {
    token: 'expression',
    expressionType: 'unaryexpression',
    unaryexpression: '+',
    expression: v,
  }
}
/ '-' WS* v:PrimaryExpression
{
  return {
    token: 'expression',
    expressionType: 'unaryexpression',
    unaryexpression: '-',
    expression: v,
  }
}
/ PrimaryExpression

// [119] PrimaryExpression ::= BrackettedExpression | BuiltInCall | IRIrefOrFunction | RDFLiteral | NumericLiteral | BooleanLiteral | Var
PrimaryExpression = BrackettedExpression / BuiltInCall / IRIrefOrFunction / v:RDFLiteral
{
  return {
    token: 'expression',
    expressionType: 'atomic',
    primaryexpression: 'rdfliteral',
    value: v,
  }
}
/ v:NumericLiteral
{
  return {
    token: 'expression',
    expressionType: 'atomic',
    primaryexpression: 'numericliteral',
    value: v,
  }
}
/ v:BooleanLiteral
{
  return {
    token: 'expression',
    expressionType: 'atomic',
    primaryexpression: 'booleanliteral',
    value: v,
  }
}
/ v:Var
{
  return {
    token: 'expression',
    expressionType: 'atomic',
    primaryexpression: 'var',
    value: v,
  }
}

// [120] BrackettedExpression ::= '(' Expression ')'
BrackettedExpression = '(' WS* e:Expression WS* ')'
{
  e.bracketted = 'true';
  return e;
}

// [121] BuiltInCall ::= Aggregate
//       | 'STR' '(' Expression ')'
//       | 'LANG' '(' Expression ')'
//       | 'LANGMATCHES' '(' Expression ',' Expression ')'
//       | 'DATATYPE' '(' Expression ')'
//       | 'BOUND' '(' Var ')'
//       | 'IRI' '(' Expression ')'
//       | 'URI' '(' Expression ')'
//       | 'BNODE' ( '(' Expression ')' | NIL )
//       | 'RAND' NIL
//       | 'ABS' '(' Expression ')'
//       | 'CEIL' '(' Expression ')'
//       | 'FLOOR' '(' Expression ')'
//       | 'ROUND' '(' Expression ')'
//       | 'CONCAT' ExpressionList
//       |  SubstringExpression
//       | 'STRLEN' '(' Expression ')'
//       |  StrReplaceExpression
//       | 'UCASE' '(' Expression ')'
//       | 'LCASE' '(' Expression ')'
//       | 'ENCODE_FOR_URI' '(' Expression ')'
//       | 'CONTAINS' '(' Expression ',' Expression ')'
//       | 'STRSTARTS' '(' Expression ',' Expression ')'
//       | 'STRENDS' '(' Expression ',' Expression ')'
//       | 'STRBEFORE' '(' Expression ',' Expression ')'
//       | 'STRAFTER' '(' Expression ',' Expression ')'
//       | 'YEAR' '(' Expression ')'
//       | 'MONTH' '(' Expression ')'
//       | 'DAY' '(' Expression ')'
//       | 'HOURS' '(' Expression ')'
//       | 'MINUTES' '(' Expression ')'
//       | 'SECONDS' '(' Expression ')'
//       | 'TIMEZONE' '(' Expression ')'
//       | 'TZ' '(' Expression ')'
//       | 'NOW' NIL
//       | 'UUID' NIL
//       | 'STRUUID' NIL
//       | 'MD5' '(' Expression ')'
//       | 'SHA1' '(' Expression ')'
//       | 'SHA256' '(' Expression ')'
//       | 'SHA384' '(' Expression ')'
//       | 'SHA512' '(' Expression ')'
//       | 'COALESCE' ExpressionList
//       | 'IF' '(' Expression ',' Expression ',' Expression ')'
//       | 'STRLANG' '(' Expression ',' Expression ')'
//       | 'STRDT' '(' Expression ',' Expression ')'
//       | 'sameTerm' '(' Expression ',' Expression ')'
//       | 'isIRI' '(' Expression ')'
//       | 'isURI' '(' Expression ')'
//       | 'isBLANK' '(' Expression ')'
//       | 'isLITERAL' '(' Expression ')'
//       | 'isNUMERIC' '(' Expression ')'
//       |  RegexExpression
//       |  ExistsFunc
//       |  NotExistsFunc
BuiltInCall = Aggregate
/ 'STR'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'str',
    args: [e],
  }
}
/ 'LANG'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'lang',
    args: [e],
  }
}
/ 'LANGMATCHES'i WS* '(' WS* e1:Expression WS* ',' WS* e2:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'langMatches',
    args: [e1, e2],
  }
}
/ 'DATATYPE'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'datatype',
    args: [e],
  }
}
/ 'BOUND'i WS* '(' WS* v:Var WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'bound',
    args: [v],
  }
}
/ 'IRI'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'IRI',
    args: [e],
  }
}
/ 'URI'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'URI',
    args: [e],
  }
}
/ 'BNODE'i WS* arg:('(' WS* e:Expression WS* ')' / NIL)
{
  const ret = {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'BNODE',
    args: null,
  };
  if (arg.length === 5) {
    ret.args = [arg[2]];
  }

  return ret;
}
/ 'RAND'i WS* NIL
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'rand',
  }
}
/ 'ABS'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'abs',
    args: [e],
  }
}
/ 'CEIL'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'ceil',
    args: [e],
  }
}
/ 'FLOOR'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'floor',
    args: [e],
  }
}
/ 'ROUND'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'round',
    args: [e],
  }
}
/ 'CONCAT'i WS* args:ExpressionList
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'CONCAT',
    args: args,
  }
}
/ SubstringExpression
/ 'STRLEN'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'STRLEN',
    args: [e],
  }
}
/ StrReplaceExpression
/ 'UCASE'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'UCASE',
    args: [e],
  }
}
/ 'LCASE'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'LCASE',
    args: [e],
  }
}
/ 'ENCODE_FOR_URI'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'ENCODE_FOR_URI',
    args: [e],
  }
}
/ 'CONTAINS'i WS* '(' WS* e1:Expression WS* ',' WS* e2:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'CONTAINS',
    args: [e1, e2],
  }
}
/ 'STRBEFORE'i WS* '(' WS* e1:Expression WS* ',' WS* e2:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'STRBEFORE',
    args: [e1, e2],
  }
}
/ 'STRSTARTS'i WS* '(' WS* e1:Expression WS* ',' WS* e2:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'STRSTARTS',
    args: [e1, e2],
  }
}
/ 'STRENDS'i WS* '(' WS* e1:Expression WS* ',' WS* e2:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'STRENDS',
    args: [e1, e2],
  }
}
/ 'STRAFTER'i WS* '(' WS* e1:Expression WS* ',' WS* e2:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'STRAFTER',
    args: [e1, e2],
  }
}
/ 'YEAR'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'year',
    args: [e],
  }
}
/ 'MONTH'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'month',
    args: [e],
  }
}
/ 'DAY'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'day',
    args: [e],
  }
}
/ 'HOURS'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'hours',
    args: [e],
  }
}
/ 'MINUTES'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'minutes',
    args: [e],
  }
}
/ 'SECONDS'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'seconds',
    args: [e],
  }
}
/ 'TIMEZONE'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'timezone',
    args: [e],
  }
}
/ 'TZ'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'tz',
    args: [e],
  }
}
/ 'NOW'i WS* NIL
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'now',
  }
}
/ 'UUID'i WS* NIL
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'UUID',
  }
}
/ 'STRUUID'i WS* NIL
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'STRUUID',
  }
}
/ 'MD5'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'MD5',
    args: [e],
  }
}
/ 'SHA1'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'SHA1',
    args: [e],
  }
}
/ 'SHA256'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'SHA256',
    args: [e],
  }
}
/ 'SHA384'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'SHA384',
    args: [e],
  }
}
/ 'SHA512'i WS* '(' WS* e:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'SHA512',
    args: [e],
  }
}
/ 'COALESCE'i WS* args:ExpressionList
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'COALESCE',
    args: args,
  }
}
/ 'IF'i WS* '(' WS* test:Expression WS* ',' WS* trueCond:Expression WS* ',' WS* falseCond:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'IF',
    args: [test, trueCond, falseCond],
  }
}
/ 'STRLANG'i WS*  '(' WS* e1:Expression WS* ',' WS* e2:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'STRLANG',
    args: [e1, e2],
  }
}
/ 'STRDT'i WS*  '(' WS* e1:Expression WS* ',' WS* e2:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'STRDT',
    args: [e1, e2],
  }
}
/ 'sameTerm'i WS*  '(' WS* e1:Expression WS* ',' WS* e2:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'sameTerm',
    args: [e1, e2],
  }
}
/ ('isURI'i/'isIRI'i) WS* '(' WS* arg:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'isURI',
    args: [arg],
  }
}
/ 'isBLANK'i WS* '(' WS* arg:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'isBlank',
    args: [arg],
  }
}
/ 'isLITERAL'i WS* '(' WS* arg:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'isLiteral',
    args: [arg],
  }
}
/ 'isNUMERIC'i WS* '(' WS* arg:Expression WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'isNumeric',
    args: [arg],
  }
}
/ RegexExpression
/ ExistsFunc
/ NotExistsFunc

// [122] RegexExpression ::= 'REGEX' '(' Expression ',' Expression ( ',' Expression )? ')'
RegexExpression = 'REGEX'i WS* '(' WS* e1:Expression WS* ',' WS* e2:Expression WS* e3:(',' WS* Expression)?  WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'regex',
    text: e1,
    pattern: e2,
    flags: e3 ? e3[2] : null,
  }
}

// [123] SubstringExpression ::= 'SUBSTR' '(' Expression ',' Expression ( ',' Expression )? ')'
SubstringExpression = 'SUBSTR'i WS* '(' WS* e1:Expression WS* ',' WS* e2:Expression WS* e3:(',' WS* Expression)? WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'substr',
    args: [
      e1,
      e2,
      e3 ? e3[2] : null
    ]
  }
}

// [124] StrReplaceExpression ::= 'REPLACE' '(' Expression ',' Expression ',' Expression ( ',' Expression )? ')'
StrReplaceExpression = 'REPLACE'i WS* '(' WS* e1:Expression WS* ',' WS* e2:Expression WS* ',' WS* e3:Expression WS* e4:(',' WS* Expression)? WS* ')'
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'replace',
    args: [
      e1,
      e2,
      e3,
      e4 ? e4[2] : null
    ]
  }
}

// [125] ExistsFunc ::= 'EXISTS' GroupGraphPattern
ExistsFunc = 'EXISTS'i WS* ggp:GroupGraphPattern
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'exists',
    args: [ggp],
  }
}

// [126] NotExistsFunc ::= 'NOT' 'EXISTS' GroupGraphPattern
NotExistsFunc = 'NOT'i WS* 'EXISTS'i WS* ggp:GroupGraphPattern
{
  return {
    token: 'expression',
    expressionType: 'builtincall',
    builtincall: 'notexists',
    args: [ggp],
  }
}

// [127] Aggregate ::= 'COUNT' '(' 'DISTINCT'? ( '*' | Expression ) ')'
//       | 'SUM' '(' 'DISTINCT'? Expression ')'
//       | 'MIN' '(' 'DISTINCT'? Expression ')'
//       | 'MAX' '(' 'DISTINCT'? Expression ')'
//       | 'AVG' '(' 'DISTINCT'? Expression ')'
//       | 'SAMPLE' '(' 'DISTINCT'? Expression ')'
//       | 'GROUP_CONCAT' '(' 'DISTINCT'? Expression ( ';' 'SEPARATOR' '=' String )? ')'
Aggregate = 'COUNT'i WS* '(' WS* d:('DISTINCT'i)? WS* e:('*'/Expression) WS* ')' WS*
{
  return {
    token: 'expression',
    expressionType: 'aggregate',
    aggregateType: 'count',
    distinct: Boolean(d),
    expression: e,
  }
}
/ 'SUM'i WS* '(' WS* d:('DISTINCT'i)? WS*  e:Expression WS* ')' WS*
{
  return {
    token: 'expression',
    expressionType: 'aggregate',
    aggregateType: 'sum',
    distinct: Boolean(d),
    expression: e,
  }
}
/ 'MIN'i WS* '(' WS* d:('DISTINCT'i)? WS* e:Expression WS* ')' WS*
{
  return {
    token: 'expression',
    expressionType: 'aggregate',
    aggregateType: 'min',
    distinct: Boolean(d),
    expression: e,
  }
}
/ 'MAX'i WS* '(' WS* d:('DISTINCT'i)? WS* e:Expression WS* ')' WS*
{
  return {
    token: 'expression',
    expressionType: 'aggregate',
    aggregateType: 'max',
    distinct: Boolean(d),
    expression: e,
  }
}
/ 'AVG'i WS* '(' WS* d:('DISTINCT'i)? WS* e:Expression WS* ')' WS*
{
  return {
    token: 'expression',
    expressionType: 'aggregate',
    aggregateType: 'avg',
    distinct: Boolean(d),
    expression: e,
  }
}
/ 'SAMPLE'i WS* '(' WS* d:('DISTINCT'i)? WS*  e:Expression WS* ')' WS*
{
  return {
    token: 'expression',
    expressionType: 'aggregate',
    aggregateType: 'sample',
    distinct: Boolean(d),
    expression: e,
  }
}
/ 'GROUP_CONCAT'i WS* '(' WS* d:('DISTINCT'i)? WS* e:Expression s:( WS* ';' WS* 'SEPARATOR'i WS* '=' WS* String)? WS* ')' WS*
{
  let sep = null;
  if (s.length) {
    sep = s[7];
  }

  return {
    token: 'expression',
    expressionType: 'aggregate',
    aggregateType: 'group_concat',
    expression: e,
    separator: sep,
    distinct: Boolean(d),
  }
}

// [128] IRIrefOrFunction ::= IRIref ArgList?
IRIrefOrFunction = i:IRIref WS* args:ArgList?
{
  return {
    token: 'expression',
    expressionType: 'irireforfunction',
    iriref: i,
    args: (args != null ? args.value : args),
  };
}

// [129] RDFLiteral ::= String ( LANGTAG | ( '^^' IRIref ) )?
RDFLiteral = s:String e:( LANGTAG / ( '^^' IRIref ) )?
{
  let ret = {
    token:'literal',
    quote: s.quote,
    value: s.value,
  };

  if (typeof(e) === 'string') {
    ret.lang = e;
  } else if (e) {
    ret.type = e[1];
  }

  ret.location = location();
  return ret;
}

// [130] NumericLiteral ::= NumericLiteralUnsigned | NumericLiteralPositive | NumericLiteralNegative
NumericLiteral = NumericLiteralUnsigned / NumericLiteralPositive / NumericLiteralNegative

// [131] NumericLiteralUnsigned ::= INTEGER | DECIMAL | DOUBLE
NumericLiteralUnsigned = DOUBLE / DECIMAL / INTEGER

// [132] NumericLiteralPositive ::= INTEGER_POSITIVE | DECIMAL_POSITIVE | DOUBLE_POSITIVE
NumericLiteralPositive = DOUBLE_POSITIVE / DECIMAL_POSITIVE / INTEGER_POSITIVE

// [133] NumericLiteralNegative ::= INTEGER_NEGATIVE | DECIMAL_NEGATIVE | DOUBLE_NEGATIVE
NumericLiteralNegative = DOUBLE_NEGATIVE / DECIMAL_NEGATIVE / INTEGER_NEGATIVE

// [134] BooleanLiteral ::= 'true' | 'false'
BooleanLiteral = 'TRUE'i
{
  return {
    token: 'literal',
    value: true,
    type: 'http://www.w3.org/2001/XMLSchema#boolean',
  }
}
/ 'FALSE'i
{
  return {
    token: 'literal',
    value: false,
    type: 'http://www.w3.org/2001/XMLSchema#boolean',
  }
}

// [135] String ::= STRING_LITERAL1 | STRING_LITERAL2 | STRING_LITERAL_LONG1 | STRING_LITERAL_LONG2
String = STRING_LITERAL_LONG1 / STRING_LITERAL_LONG2 / STRING_LITERAL1 / STRING_LITERAL2

// [136] IRIref ::= IRIREF | PrefixedName
IRIref = iri:IRIREF
{
  return {
    token: 'uri',
    prefix: null,
    suffix: null,
    value: iri,
    location: location(),
  }
}
/ p:PrefixedName
{
  return p
}

// [137] PrefixedName ::= PNAME_LN | PNAME_NS
PrefixedName = p:PNAME_LN 
{
  return {
    token: 'uri',
    prefix: p[0],
    suffix: p[1],
    value: null,
    location: location(),
  }
}
/ p:PNAME_NS 
{
  return {
    token: 'uri',
    prefix: p,
    suffix: '',
    value: null,
    location: location(),
  }
}

// [138] BlankNode ::= BLANK_NODE_LABEL | ANON
BlankNode = l:BLANK_NODE_LABEL
{
  return {
    token: 'blank',
    value: l,
    location: location(),
  }
}
/ ANON
{ 
  return {
    token: 'blank',
    location: location(),
  }
}

// [139] IRIREF ::= '<' ([^<>"{}|^`\]-[#x00-#x20])* '>'
// check
IRIREF = '<' i:[^<>\"\{\}|^`\\]* '>'
{
  return i.join('')
}

// [140] PNAME_NS ::= PN_PREFIX? ':'
PNAME_NS = p:PN_PREFIX? ':'
{
  return p
}

// [141] PNAME_LN ::= PNAME_NS PN_LOCAL
PNAME_LN = p:PNAME_NS s:PN_LOCAL
{
  return [p, s]
}

// [142] BLANK_NODE_LABEL ::= '_:' ( PN_CHARS_U | [0-9] ) ((PN_CHARS|'.')* PN_CHARS)?
BLANK_NODE_LABEL = '_:' ( PN_CHARS_U / [0-9] ) ((PN_CHARS/'.')* PN_CHARS)?
{
  return text();
}

// [143] VAR1 ::= '?' VARNAME
VAR1 = '?' v:VARNAME 
{
  return {
    prefix: '?',
    value: v,
  }
}

// [144] VAR2 ::= '$' VARNAME
VAR2 = '$' v:VARNAME 
{
  return {
    prefix: '$',
    value: v,
  }
}

// [145] LANGTAG ::= '@' [a-zA-Z]+ ('-' [a-zA-Z0-9]+)*
LANGTAG = '@' a:[a-zA-Z]+ b:('-' [a-zA-Z0-9]+)*
{
  let lang = a.join('');

  if (b.length) {
    lang += '-' + b[0][1].join('');
  }

  return lang.toLowerCase();
}

// [146] INTEGER ::= [0-9]+
INTEGER = [0-9]+
{
  return {
    token: 'literal',
    value: text(),
    type: 'http://www.w3.org/2001/XMLSchema#integer',
  }
}

// [147] DECIMAL ::= [0-9]* '.' [0-9]+
DECIMAL = [0-9]* '.' [0-9]+
{
  return {
    token: 'literal',
    value: text(),
    type: 'http://www.w3.org/2001/XMLSchema#decimal',
  }
}

// [148] DOUBLE ::= [0-9]+ '.' [0-9]* EXPONENT | '.' ([0-9])+ EXPONENT | ([0-9])+ EXPONENT
DOUBLE = [0-9]+ '.' [0-9]* EXPONENT
{
  return {
    token: 'literal',
    value: text(),
    type: 'http://www.w3.org/2001/XMLSchema#double',
  }
}
/ '.' [0-9]+ EXPONENT
{
  return {
    token: 'literal',
    value: text(),
    type: 'http://www.w3.org/2001/XMLSchema#double',
  }
}
/ [0-9]+ EXPONENT
{
  return {
    token: 'literal',
    value: text(),
    type: 'http://www.w3.org/2001/XMLSchema#double',
  }
}

// [149] INTEGER_POSITIVE ::= '+' INTEGER
INTEGER_POSITIVE = '+' d:INTEGER
{
  d.value = '+' + d.value;
  return d;
}

// [150] DECIMAL_POSITIVE ::= '+' DECIMAL
DECIMAL_POSITIVE = '+' d:DECIMAL
{
  d.value = '+' + d.value;
  return d;
}

// [151] DOUBLE_POSITIVE ::= '+' DOUBLE
DOUBLE_POSITIVE = '+' d:DOUBLE
{
  d.value = '+' + d.value;
  return d;
}

// [152] INTEGER_NEGATIVE ::= '-' INTEGER
INTEGER_NEGATIVE = '-' d:INTEGER
{
  d.value = '-' + d.value;
  return d;
}

// [153] DECIMAL_NEGATIVE ::= '-' DECIMAL
DECIMAL_NEGATIVE = '-' d:DECIMAL
{
  d.value = '-' + d.value;
  return d;
}

// [154] DOUBLE_NEGATIVE ::= '-' DOUBLE
DOUBLE_NEGATIVE = '-' d:DOUBLE
{
  d.value = '-' + d.value;
  return d;
}

// [155] EXPONENT ::= [eE] [+-]? [0-9]+
EXPONENT = [eE] [+-]? [0-9]+

// [156] STRING_LITERAL1 ::= "'" ( ([^#x27#x5C#xA#xD]) | ECHAR )* "'"
STRING_LITERAL1 = "'" s:( [^\u0027\u005C\u000A\u000D] / ECHAR )* "'"
{
  return {
    token: 'string',
    quote: "'",
    value: s.join(''), // except ' \ LF CR
  };
}

// [157] STRING_LITERAL2 ::= '"' ( ([^#x22#x5C#xA#xD]) | ECHAR )* '"'
STRING_LITERAL2 = '"' s:( [^\u0022\u005C\u000A\u000D] / ECHAR )* '"'
{
  return {
    token: 'string',
    quote: '"',
    value: s.join(''), // except " \ LF CR
  };
}

// [158] STRING_LITERAL_LONG1 ::= "'''" ( ( "'" | "''" )? ( [^'\] | ECHAR ) )* "'''"
STRING_LITERAL_LONG1 = "'''" s:( ( "''" / "'" )? ( [^\'\\] / ECHAR ) )* "'''"
{
  return {
    token: 'string',
    quote: "'''",
    value: s.map((c) => {
      if (c[0]) {
        return c[0] + c[1];
      } else {
        return c[1];
      }
    }).join(''),
  };
}

// [159] STRING_LITERAL_LONG2 ::= '"""' ( ( '"' | '""' )? ( [^"\] | ECHAR ) )* '"""'
STRING_LITERAL_LONG2 = '"""' s:( ( '""' / '"' )? ( [^\"\\] / ECHAR ) )* '"""'
{

  return {
    token: 'string',
    quote: '"""',
    value: s.map((c) => {
      if (c[0]) {
        return c[0] + c[1];
      } else {
        return c[1];
      }
    }).join(''),
  }
}

// [160] ECHAR ::= '\' [tbnrf\"']
ECHAR = '\\' [tbnrf\\\"\']
{
  return text();
}

// [161] NIL ::= '(' WS* ')'
NIL = '(' WS* ')'
{
  return {
    token: 'triplesnodecollection',
    chainSubject: [{
      token: 'uri',
      value: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#nil',
    }],
    location: location(),
  };
}

// [162] WS ::= #x20 | #x9 | #xD | #xA
// add COMMENT
WS = COMMENT / SPACE_OR_TAB / NEW_LINE

SPACE_OR_TAB = [\u0020\u0009]
NEW_LINE = [\u000A\u000D]
NON_NEW_LINE = [^\u000A\u000D]

HEADER_LINE = '#' NON_NEW_LINE* NEW_LINE
{
  return text();
}

COMMENT = SPACE_OR_TAB* '#' NON_NEW_LINE*
{
  const line = location().start.line;
  Comments[line] = text();

  return '';
}

// [163] ANON ::= '[' WS* ']'
ANON = '[' WS* ']'

// [164] PN_CHARS_BASE ::= [A-Z] | [a-z] | [#x00C0-#x00D6] | [#x00D8-#x00F6] | [#x00F8-#x02FF] | [#x0370-#x037D] | [#x037F-#x1FFF] | [#x200C-#x200D] | [#x2070-#x218F] | [#x2C00-#x2FEF] | [#x3001-#xD7FF] | [#xF900-#xFDCF] | [#xFDF0-#xFFFD] | [#x10000-#xEFFFF]
PN_CHARS_BASE = [A-Z] / [a-z] / [\u00C0-\u00D6] / [\u00D8-\u00F6] / [\u00F8-\u02FF] / [\u0370-\u037D] / [\u037F-\u1FFF] / [\u200C-\u200D] / [\u2070-\u218F] / [\u2C00-\u2FEF] / [\u3001-\uD7FF] / [\uF900-\uFDCF] / [\uFDF0-\uFFFD] / [\u1000-\uEFFF]

// [165] PN_CHARS_U ::= PN_CHARS_BASE | '_'
PN_CHARS_U = PN_CHARS_BASE / '_'

// [166] VARNAME ::= ( PN_CHARS_U | [0-9] ) ( PN_CHARS_U | [0-9] | #x00B7 | [#x0300-#x036F] | [#x203F-#x2040] )*
VARNAME = ( PN_CHARS_U / [0-9] ) ( PN_CHARS_U / [0-9] / [\u00B7] / [\u0300-\u036F] / [\u203F-\u2040] )*
{
  return text();
}

// [167] PN_CHARS ::= PN_CHARS_U | '-' | [0-9] | #x00B7 | [#x0300-#x036F] | [#x203F-#x2040]
PN_CHARS = PN_CHARS_U / '-' / [0-9] / [\u00B7] / [\u0300-\u036F] / [\u203F-\u2040]

// [168] PN_PREFIX ::= PN_CHARS_BASE ((PN_CHARS|'.')* PN_CHARS)?
// PN_PREFIX = PN_CHARS_BASE ((PN_CHARS/'.')* PN_CHARS)?
PN_PREFIX = PN_CHARS_U (PN_CHARS / '.')*
{ 
  return text();
}

// [169] PN_LOCAL ::= (PN_CHARS_U | ':' | [0-9] | PLX ) ((PN_CHARS | '.' | ':' | PLX)* (PN_CHARS | ':' | PLX) )?
// PN_LOCAL = (PN_CHARS_U / ':' / [0-9] / PLX ) ((PN_CHARS / '.' / ':' / PLX)* (PN_CHARS / ':' / PLX))?
PN_LOCAL = ( PN_CHARS_U / ':' / [0-9] / PLX) (PN_CHARS / '.' / ':' / PLX)*
{
  return text();
}

// [170] PLX ::= PERCENT | PN_LOCAL_ESC
PLX = PERCENT / PN_LOCAL_ESC

// [171] PERCENT ::= '%' HEX HEX
PERCENT = '%' HEX HEX

// [172] HEX ::= [0-9] | [A-F] | [a-f]
HEX = [0-9] / [A-F] / [a-f]

// [173] PN_LOCAL_ESC ::= '\' ( '_' | '~' | '.' | '-' | '!' | '$' | '&' | "'" | '(' | ')' | '*' | '+' | ',' | ';' | '=' | '/' | '?' | '#' | '@' | '%' )
PN_LOCAL_ESC = '\\' ( '_' / '~' / '.' / '-' / '!' / '$' / '&' / "'" / '(' / ')' / '*' / '+' / ',' / ';' / ':' / '=' / '/' / '?' / '#' / '@' / '%' )
