{
  let comments = {};
}

DOCUMENT = h:(HEADER_LINE*) WS* s:SPARQL WS*
{
  let ret = {};
  if (h.length) {
    ret = {
      headers: h,
      ...s,
    };
  } else {
    ret = s;
  }

  const commentsArr = Object.entries(comments).map(([pos, text]) => ({
    pos: parseInt(pos),
    text: text,
  }));
  if (commentsArr.length) {
    ret.comments = commentsArr;
  }

  return ret;
}

SPARQL = QueryUnit / UpdateUnit

// [1] QueryUnit ::= Query
QueryUnit = Query

// [2] Query ::= Prologue ( SelectQuery | ConstructQuery | DescribeQuery | AskQuery ) ValuesClause
Query = p:Prologue WS* q:( SelectQuery / ConstructQuery / DescribeQuery / AskQuery ) v:ValuesClause
{
  let ret = {};
  if (p.length) {
    ret.prologue = p;
  }
  ret.queryBody = q;
  if (v) {
    ret.values = v;
  }

  return ret;
}

// [3] UpdateUnit ::= Update
UpdateUnit = Update

// [4] Prologue ::= ( BaseDecl | PrefixDecl )*
Prologue = ( BaseDecl / PrefixDecl )*

// [5] BaseDecl ::= 'BASE' IRIREF
BaseDecl = WS* 'BASE'i WS* i:IRIREF
{
  return {
    base: i,
  }
}

// [6] PrefixDecl ::= 'PREFIX' PNAME_NS IRIREF
PrefixDecl = WS* 'PREFIX'i WS* p:PNAME_NS WS* i:IRIREF
{
  return {
    prefix: p,
    iri: i,
  }
}

// [7] SelectQuery ::= SelectClause DatasetClause* WhereClause SolutionModifier
SelectQuery = s:SelectClause WS* gs:DatasetClause* WS* w:WhereClause WS* sm:SolutionModifier
{
  let ret = {};
  if (gs.length) {
    ret.from = gs;
  }

  ret = {
    ...ret,
    select: s.vars,
    modifier: s.modifier,
    where: w,
    ...sm,
    location: location(),
  };

  return ret;
}

// [8] SubSelect ::= SelectClause WhereClause SolutionModifier ValuesClause
SubSelect = s:SelectClause WS* w:WhereClause WS* sm:SolutionModifier v:ValuesClause
{
  let ret = {
    select: s.vars,
    modifier: s.modifier,
    where: w,
    ...sm,
  };
  if (v) {
    ret.values = v;
  }
  ret.location = location();

  return ret;
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
      kind: '*',
      location: location(),
    }];
  } else {
    vars = vs.map((v) => {
      if (v.length === 2) {
        return v[1];
      } else {
        return {
          expression: v[3],
          as: v[7],
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
  let ret = { type: 'construct' };
  if (gs.length) {
    ret.from = gs;
  }

  ret = {
    ...ret,
    template: t,
    where: w,
    ...sm,
    location: location(),
  };

  return ret;
}
/ 'CONSTRUCT'i WS* gs:DatasetClause* WS* 'WHERE'i WS* '{' WS* t:TriplesTemplate? WS* '}' WS* sm:SolutionModifier
{
  let ret = { type: 'construct' };
  if (gs.length) {
    ret.from = gs;
  }

  ret = {
    ...ret,
    where: { graphPattern: [ t ] },
    ...sm,
    location: location(),
  };

  return ret;
}

// [11] DescribeQuery ::= 'DESCRIBE' ( VarOrIri+ | '*' ) DatasetClause* WhereClause? SolutionModifier
DescribeQuery = 'DESCRIBE'i WS* v:( VarOrIri+ / '*' ) WS* gs:DatasetClause* WS* w:WhereClause? WS* sm:SolutionModifier
{
  let ret = { type: 'describe' };
  if (gs.length) {
    ret.from = gs;
  }
  ret.describe = v;
  if (w) {
    ret.where = w;
  }

  ret = {
    ...ret,
    ...sm,
    location: location(),
  };

  return ret;
}

// [12] AskQuery ::= 'ASK' DatasetClause* WhereClause SolutionModifier
AskQuery = WS* 'ASK'i WS* gs:DatasetClause* WS* w:WhereClause WS* sm:SolutionModifier
{
  let ret = { type: 'ask' };
  if (gs.length) {
    ret.from = gs;
  }

  ret = {
    ...ret,
    where: w,
    ...sm,
    location: location(),
  };

  return ret;
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
    graph: s,
    location: location(),
  }
}

// [15] NamedGraphClause ::= 'NAMED' SourceSelector
NamedGraphClause = 'NAMED'i WS* s:SourceSelector
{
  return {
    namedGraph: s,
    location: location(),
  };
}

// [16] SourceSelector ::= IRIref
SourceSelector = IRIref

// [17] WhereClause ::= 'WHERE'? GroupGraphPattern
WhereClause = 'WHERE'i? WS* ggp:GroupGraphPattern
{
  return ggp;
}

// [18] SolutionModifier ::= GroupClause? HavingClause? OrderClause? LimitOffsetClauses?
SolutionModifier = g:GroupClause? h:HavingClause? o:OrderClause? l:LimitOffsetClauses?
{
  let ret = {};
  if (g) {
    ret.group = g;
  }
  if (h) {
    ret.having = h;
  }
  if (o) {
    ret.orderBy = o;
  }
  if (l) {
    ret.limitOffset = l;
  }

  return ret;
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
HavingClause = 'HAVING'i WS* h:HavingCondition+
{
  return h;
}

// [22] HavingCondition ::= Constraint
HavingCondition = h:Constraint WS*
{
  return h;
}

// [23] OrderClause ::= 'ORDER' 'BY' OrderCondition+
OrderClause = 'ORDER'i WS* 'BY'i WS* os:OrderCondition+ WS*
{
  return os;
}

// [24] OrderCondition ::= ( ( 'ASC' | 'DESC' ) BrackettedExpression ) | ( Constraint | Var )
OrderCondition = o:( 'ASC'i / 'DESC'i ) WS* e:BrackettedExpression WS*
{
  return {
    order: o.toUpperCase(),
    by: e
  };
}
/ e:( Constraint / Var ) WS*
{
  return {
    by: e,
  };
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
    limit: parseInt(i.literal)
  };
}

// [27] OffsetClause ::= 'OFFSET' INTEGER
OffsetClause = 'OFFSET'i WS* i:INTEGER WS*
{
  return {
    offset: parseInt(i.literal)
  };
}

// [28] ValuesClause ::= ( 'VALUES' DataBlock )?
ValuesClause = b:( 'VALUES'i DataBlock )?
{
  if (b) {
    return b[1];
  } else {
    return null;
  }
}

// [29] Update ::= Prologue ( Update1 ( ';' Update )? )?
Update = p:Prologue u:( WS* Update1 ( WS* ';' WS* Update )? )? WS*
{
  let query = {
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
Load = 'LOAD'i WS* s:'SILENT'i? WS* sg:IRIref WS* dg:( 'INTO'i WS* GraphRef )?
{
  let query = {
    type: 'load',
    silent: s,
    sourceGraph: sg,
  };
  if (dg) {
    query.destinyGraph = dg[2];
  }

  return query;
}

// [32] Clear ::= 'CLEAR' 'SILENT'? GraphRefAll
Clear = 'CLEAR'i WS* s:'SILENT'i? WS* ref:GraphRefAll
{
  return {
    type: 'clear',
    silent: s,
    destinyGraph: ref,
  }
}

// [33] Drop ::= 'DROP' 'SILENT'? GraphRefAll
Drop = 'DROP'i  WS* s:'SILENT'i? WS* ref:GraphRefAll
{
  return {
    type: 'drop',
    silent: s,
    destinyGraph: ref,
  }
}

// [34] Create ::= 'CREATE' 'SILENT'? GraphRef
Create = 'CREATE'i WS* s:'SILENT'i? WS* ref:GraphRef
{
  return {
    type: 'create',
    silent: s,
    destinyGraph: ref,
  }
}

// [35] Add ::= 'ADD' 'SILENT'? GraphOrDefault 'TO' GraphOrDefault
Add = 'ADD'i WS* s:'SILENT'i? WS* g1:GraphOrDefault WS* 'TO'i WS* g2:GraphOrDefault
{
  return {
    type: 'add',
    silent: s,
    graphs: [g1, g2],
  }
}

// [36] Move ::= 'MOVE' 'SILENT'? GraphOrDefault 'TO' GraphOrDefault
Move = 'MOVE'i WS* s:'SILENT'i? WS* g1:GraphOrDefault WS* 'TO'i WS* g2:GraphOrDefault
{
  return {
    type: 'move',
    silent: s,
    graphs: [g1, g2],
  }
}

// [37] Copy ::= 'COPY' 'SILENT'? GraphOrDefault 'TO' GraphOrDefault
Copy = 'COPY'i WS* s:'SILENT'i? WS* g1:GraphOrDefault WS* 'TO'i WS* g2:GraphOrDefault
{
  return {
    type: 'copy',
    silent: s,
    graphs: [g1, g2],
  }
}

// [38] InsertData ::= 'INSERT DATA' QuadData
InsertData = 'INSERT'i WS* 'DATA'i WS* qs:QuadData
{
  return {
    type: 'insertdata',
    insert: qs,
  };
}

// [39] DeleteData ::= 'DELETE DATA' QuadData
DeleteData = 'DELETE'i WS* 'DATA'i qs:QuadData
{
  return {
    type: 'deletedata',
    delete: qs,
  };
}

// [40] DeleteWhere ::= 'DELETE WHERE' QuadPattern
DeleteWhere = 'DELETE'i WS* 'WHERE'i WS* qs:QuadPattern
{
  return {
    type: 'deletewhere',
    delete: qs,
  };
}

// [41] Modify ::= ( 'WITH' IRIref )? ( DeleteClause InsertClause? | InsertClause ) UsingClause* 'WHERE' GroupGraphPattern
Modify = w:( 'WITH'i WS* IRIref WS* )? m:( DeleteClause WS* InsertClause? / InsertClause ) WS* u:UsingClause* WS* 'WHERE'i WS* p:GroupGraphPattern WS*
{
  let query = {
    type: 'modify',
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

  query.where = p;

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
GraphOrDefault = 'DEFAULT'i
{
  return 'default';
}
/ 'GRAPH'i? WS* i:IRIref
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

  return quads;
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
  let triples = [b];
  if (bs && bs[3]) {
    triples = triples.concat(bs[3].triplePattern);
  }

  return {
    triplePattern: triples,
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
    graphPattern: patterns,
    location: location(),
  }
}

// [55] TriplesBlock ::= TriplesSameSubjectPath ( '.' TriplesBlock? )?
TriplesBlock = a:TriplesSameSubjectPath b:( WS* '.' WS* TriplesBlock? )?
{
  let triples = [a];
  if (b && b[3]) {
    triples = triples.concat(b[3].triplePattern);
  }

  return {
    triplePattern: triples,
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
    location: location(),
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
    oneVar: v,
    data: d,
    location: location(),
  };
}

// [64] InlineDataFull ::= ( NIL | '(' Var* ')' ) '{' ( '(' DataBlockValue* ')' | NIL )* '}'
InlineDataFull = WS* '(' WS* vars:Var* ')' WS* '{' WS* vals:DataBlockTuple* '}'
{
  return {
    variables: vars,
    data: vals,
    location: location(),
  };
}

DataBlockTuple = '(' WS* vs:DataBlockValue* ')' WS*
{
  return vs;
}

// [65] DataBlockValue ::= IRIref | RDFLiteral | NumericLiteral | BooleanLiteral | 'UNDEF'
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
  if (b.length) {
    return {
      token: 'unionpattern',
      value: [a].concat(b.map((elem) => elem[3])),
      location: location(),
    };
  } else {
    return a;
  }
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
    token: 'functioncall',
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
  let triples = [b];
  if (bs && bs[3]) {
    triples = triples.concat(bs[3].triplePattern);
  }

  return {
    triplePattern: triples,
    location: location(),
  }
}

// [75] TriplesSameSubject ::= VarOrTerm PropertyListNotEmpty | TriplesNode PropertyList
TriplesSameSubject = s:VarOrTerm WS* pairs:PropertyListNotEmpty
{
  return {
    subject: s,
    properties: pairs,
  }
}
/ WS* tn:TriplesNode WS* pairs:PropertyList
{
  return {
    subject: tn,
    properties: pairs,
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

  return pairs;
}

// [78] Verb ::= VarOrIri | 'a'
Verb = VarOrIri
/ 'a'
{
  return {
    'a': true,
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
    subject: s,
    properties: list,
  }
}
/ WS* tn:TriplesNodePath WS* pairs:PropertyListPath
{
  return {
    subject: tn,
    properties: pairs,
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

  return pairs;
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
      alternative: arr,
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
      sequence: arr,
      location: location(),
    };
  } else {
    return first;
  }
}

// [91] PathElt ::= PathPrimary PathMod?
PathElt = p:PathPrimary m:PathMod?
{
  if (m) {
    p.modifier = m;
  }

  return p;
}

// [92] PathEltOrInverse ::= PathElt | '^' PathElt
PathEltOrInverse = PathElt
/ '^' elt:PathElt
{
  elt.kind = 'inversePath';
  return elt;
}

// [93] PathMod ::= '?' | '*' | '+'
PathMod = '?' / '*' / '+'

// [94] PathPrimary ::= IRIref | 'a' | '!' PathNegatedPropertySet | '(' Path ')'
PathPrimary = IRIref
/ 'a'
{
  return {
    'a': true,
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
    properties: pl,
    location: location(),
  };
}

// [100] TriplesNodePath ::= CollectionPath | BlankNodePropertyListPath
TriplesNodePath = c:CollectionPath
{
  return {
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
    properties: pl,
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
    ...v,
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
    value: v,
  }
}
/ v:NumericLiteral
{
  return {
    token: 'expression',
    expressionType: 'atomic',
    value: v,
  }
}
/ v:BooleanLiteral
{
  return {
    token: 'expression',
    expressionType: 'atomic',
    value: v,
  }
}
/ v:Var
{
  return {
    token: 'expression',
    expressionType: 'atomic',
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
  let ret = {
    token: 'expression',
    expressionType: 'regex',
    text: e1,
    pattern: e2,
  }
  if (e3) {
    ret.flags = e3[2];
  }

  return ret;
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
  if (s?.length) {
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
  let ret = {
    token: 'expression',
    expressionType: 'irireforfunction',
    iriref: i,
  };
  if (args) {
    ret.args = args.value;
  }
  return ret;
}

// [129] RDFLiteral ::= String ( LANGTAG | ( '^^' IRIref ) )?
RDFLiteral = s:String e:( LANGTAG / ( '^^' IRIref ) )?
{
  if (typeof(e) === 'string') {
    s.lang = e;
  } else if (e) {
    s.dataType = e[1];
  }

  s.location = location();
  return s;
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
BooleanLiteral = 'true'i
{
  return {
    dataType: 'http://www.w3.org/2001/XMLSchema#boolean',
    literal: true,
  }
}
/ 'false'i
{
  return {
    dataType: 'http://www.w3.org/2001/XMLSchema#boolean',
    literal: false,
  }
}

// [135] String ::= STRING_LITERAL1 | STRING_LITERAL2 | STRING_LITERAL_LONG1 | STRING_LITERAL_LONG2
String = STRING_LITERAL_LONG1 / STRING_LITERAL_LONG2 / STRING_LITERAL1 / STRING_LITERAL2

// [136] IRIref ::= IRIREF | PrefixedName
IRIref = iri:IRIREF
{
  return {
    iri: iri,
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
    iriPrefix: p[0],
    iriLocal: p[1],
    location: location(),
  }
}
/ p:PNAME_NS 
{
  return {
    iriPrefix: p,
    iriLocal: '',
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
// abobe notation is set difference in EBNF
IRIREF = '<' i:[^<>"{}|^`\\\x00-\x20]* '>'
{
  return i.join('')
}

// [140] PNAME_NS ::= PN_PREFIX? ':'
PNAME_NS = p:PN_PREFIX? ':'
{
  return p || '';
}

// [141] PNAME_LN ::= PNAME_NS PN_LOCAL
PNAME_LN = p:PNAME_NS s:PN_LOCAL
{
  return [p, s]
}

// [142] BLANK_NODE_LABEL ::= '_:' ( PN_CHARS_U | [0-9] ) ((PN_CHARS|'.')* PN_CHARS)?
// BLANK_NODE_LABEL = '_:' ( PN_CHARS_U / [0-9] ) ((PN_CHARS / '.')* PN_CHARS)?
// above does not work for pegjs
BLANK_NODE_LABEL = '_:' ( PN_CHARS_U / [0-9] ) (PN_CHARS / '.' PN_CHARS)*
{
  return text();
}

// [143] VAR1 ::= '?' VARNAME
VAR1 = '?' v:VARNAME 
{
  return {
    variable: v,
  }
}

// [144] VAR2 ::= '$' VARNAME
VAR2 = '$' v:VARNAME 
{
  return {
    varType: '$',
    variable: v,
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
    dataType: 'http://www.w3.org/2001/XMLSchema#integer',
    literal: text(),
  }
}

// [147] DECIMAL ::= [0-9]* '.' [0-9]+
DECIMAL = [0-9]* '.' [0-9]+
{
  return {
    dataType: 'http://www.w3.org/2001/XMLSchema#decimal',
    literal: text(),
  }
}

// [148] DOUBLE ::= [0-9]+ '.' [0-9]* EXPONENT | '.' ([0-9])+ EXPONENT | ([0-9])+ EXPONENT
DOUBLE = [0-9]+ '.' [0-9]* EXPONENT
{
  return {
    dataType: 'http://www.w3.org/2001/XMLSchema#double',
    literal: text(),
  }
}
/ '.' [0-9]+ EXPONENT
{
  return {
    dataType: 'http://www.w3.org/2001/XMLSchema#double',
    literal: text(),
  }
}
/ [0-9]+ EXPONENT
{
  return {
    dataType: 'http://www.w3.org/2001/XMLSchema#double',
    literal: text(),
  }
}

// [149] INTEGER_POSITIVE ::= '+' INTEGER
INTEGER_POSITIVE = '+' d:INTEGER
{
  d.literal = '+' + d.literal;
  return d;
}

// [150] DECIMAL_POSITIVE ::= '+' DECIMAL
DECIMAL_POSITIVE = '+' d:DECIMAL
{
  d.literal = '+' + d.literal;
  return d;
}

// [151] DOUBLE_POSITIVE ::= '+' DOUBLE
DOUBLE_POSITIVE = '+' d:DOUBLE
{
  d.literal = '+' + d.literal;
  return d;
}

// [152] INTEGER_NEGATIVE ::= '-' INTEGER
INTEGER_NEGATIVE = '-' d:INTEGER
{
  d.literal = '-' + d.literal;
  return d;
}

// [153] DECIMAL_NEGATIVE ::= '-' DECIMAL
DECIMAL_NEGATIVE = '-' d:DECIMAL
{
  d.literal = '-' + d.literal;
  return d;
}

// [154] DOUBLE_NEGATIVE ::= '-' DOUBLE
DOUBLE_NEGATIVE = '-' d:DOUBLE
{
  d.literal = '-' + d.literal;
  return d;
}

// [155] EXPONENT ::= [eE] [+-]? [0-9]+
EXPONENT = [eE] [+-]? [0-9]+

// [156] STRING_LITERAL1 ::= "'" ( ([^#x27#x5C#xA#xD]) | ECHAR )* "'"
STRING_LITERAL1 = "'" s:( [^\x27\x5C\x0A\x0D] / ECHAR )* "'"
{
  return {
    quote: "'",
    literal: s.join(''), // except ' \ LF CR
  };
}

// [157] STRING_LITERAL2 ::= '"' ( ([^#x22#x5C#xA#xD]) | ECHAR )* '"'
STRING_LITERAL2 = '"' s:( [^\x22\x5C\x0A\x0D] / ECHAR )* '"'
{
  return {
    quote: '"',
    literal: s.join(''), // except " \ LF CR
  };
}

// [158] STRING_LITERAL_LONG1 ::= "'''" ( ( "'" | "''" )? ( [^'\] | ECHAR ) )* "'''"
STRING_LITERAL_LONG1 = "'''" s:( ( "''" / "'" )? ( [^\'\\] / ECHAR ) )* "'''"
{
  return {
    quote: "'''",
    literal: s.map((c) => {
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
    quote: '"""',
    literal: s.map((c) => {
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

// [162] WS ::= #x20 | #x9 | #xD | #xA
// add COMMENT
WS = COMMENT / SPACE_OR_TAB / NEW_LINE

SPACE_OR_TAB = [\x20\x09]
NEW_LINE = [\x0D\x0A]
NON_NEW_LINE = [^\x0D\x0A]

HEADER_LINE = '#' NON_NEW_LINE* NEW_LINE
{
  return text();
}

COMMENT = NEW_LINE? SPACE_OR_TAB* '#' NON_NEW_LINE*
{
  comments[location().start.offset] = text();

  return '';
}

// [163] ANON ::= '[' WS* ']'
ANON = '[' WS* ']'

// [164] PN_CHARS_BASE ::= [A-Z] | [a-z] | [#x00C0-#x00D6] | [#x00D8-#x00F6] | [#x00F8-#x02FF] | [#x0370-#x037D] | [#x037F-#x1FFF] | [#x200C-#x200D] | [#x2070-#x218F] | [#x2C00-#x2FEF] | [#x3001-#xD7FF] | [#xF900-#xFDCF] | [#xFDF0-#xFFFD] | [#x10000-#xEFFFF]
// omit surrogate pairs [#x10000-#xEFFFF] because [\u{10000}-\u{EFFFF}] does not work in pegjs
PN_CHARS_BASE = [A-Z] / [a-z] / [\u00C0-\u00D6] / [\u00D8-\u00F6] / [\u00F8-\u02FF] / [\u0370-\u037D] / [\u037F-\u1FFF] / [\u200C-\u200D] / [\u2070-\u218F] / [\u2C00-\u2FEF] / [\u3001-\uD7FF] / [\uF900-\uFDCF] / [\uFDF0-\uFFFD]

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
// PN_PREFIX = PN_CHARS_BASE ((PN_CHARS / '.')* PN_CHARS)?
// above does not work for pegjs
PN_PREFIX = PN_CHARS_BASE (PN_CHARS / '.' PN_CHARS)*
{
  return text();
}

// [169] PN_LOCAL ::= (PN_CHARS_U | ':' | [0-9] | PLX ) ((PN_CHARS | '.' | ':' | PLX)* (PN_CHARS | ':' | PLX) )?
// PN_LOCAL = (PN_CHARS_U / ':' / [0-9] / PLX ) ((PN_CHARS / '.' / ':' / PLX)* (PN_CHARS / ':' / PLX) )?
// above does not work for pegjs
PN_LOCAL = (PN_CHARS_U / ':' / [0-9] / PLX ) ((PN_CHARS / ':' / PLX) / '.' (PN_CHARS / ':' / PLX) )*
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
