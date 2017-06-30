globalParser = this.parser # parser is already defined

toSet = (v, stringify) ->
  if Array.isArray(v)
    new Set((v.map (x) -> if stringify then x else JSON.stringify(x)))
  else
    new Set([if stringify then v else JSON.stringify(v)])

setToArray = (s) ->
  r = []

  s.forEach (v) ->
    r.push(v)

  r

mkEvalOp = (opFn) ->
  (ast, scope) ->
    op = ast[0]

    if ast.length < 3
      throw new Error("Insufficient operands for '#{op}' operator: #{JSON.stringify(ast)}")

    operands = ast.slice(2)
    result = evalAst(ast[1], scope)

    for operand in operands
      result = opFn(result, evalAst(operand, scope))

    result

evalUnion = (ast, scope) ->
  if typeof(Set) != "function"
    return ["Sets are not supported in this JS runtime (TODO: fallback implementation)"]

  if ast.length < 3
    throw new Error("Insufficient operands for '|' operator: #{JSON.stringify(ast)}")

  operands = ast.slice(2)
  result = toSet(evalAst(ast[1], scope), true)

  for operand in operands
    otherSet = toSet(evalAst(operand, scope), true)
    result = toSet(setToArray(result).concat(setToArray(otherSet)), false)

  setToArray(result).map JSON.parse

evalUnaryMinus = (ast, scope) ->
    op = ast[0]

    if ast.length != 2
      throw new Error("Wrong number of operands for '#{op}' operator: #{JSON.stringify(ast)}")

    operands = ast.slice(2)
    -(evalAst(ast[1], scope))

flattenRecur = (arr) ->
  arr.reduce((acc, i) ->
    acc.concat if Array.isArray(i) then flatten(i) else i
  , [])

flatten = (arr) ->
  arr.reduce(((acc, i) -> acc.concat i), [])

isWildcard = (c) ->
  Array.isArray(c) && c.length == 1 && c[0] == 'wildcard'

isDeepWildcard = (c) ->
  Array.isArray(c) && c.length == 1 && c[0] == 'deepWildcard'

isPredicate = (c) ->
  Array.isArray(c) && c[0] == 'pred'

isPathExpression = (c) ->
  Array.isArray(c) && c[0] == 'expr'

resolveDeepWildcard = (topLevelScope, scope, path, acc) ->
  if Array.isArray(scope)
    for item in scope
      resolvePath(topLevelScope, item, path, acc)
      resolveDeepWildcard(topLevelScope, item, path, acc)

  else if typeof(scope) == 'object'
    for k, v of scope
      resolvePath(topLevelScope, v, path, acc)
      resolveDeepWildcard(topLevelScope, v, path, acc)

resolvePath = (topLevelScope, scope, path, acc) ->
  pathHead = path[0]
  pathTail = path.slice(1)

  if pathHead == null || pathHead == undefined
    acc.putValue(scope)
    return

  if scope == null || scope == undefined
    acc.putValue(null)
    return
  else
    if isWildcard(pathHead)
      acc.makeMultiple()

      if Array.isArray(scope)
        for item in scope
          resolvePath(topLevelScope, item, pathTail, acc)

      else if typeof(scope) == "object"
        for k, v of scope
          resolvePath(topLevelScope, v, pathTail, acc)

      else
        acc.putValue(null)
        return
    else if isDeepWildcard(pathHead)
      acc.makeMultiple()

      resolveDeepWildcard(topLevelScope, scope, pathTail, acc)
      return
    else if isPredicate(pathHead)
      acc.makeMultiple()

      if Array.isArray(scope)
        childScope = makeChildScope(topLevelScope)

        for item in scope
          childScope.this = item

          if evalAst(pathHead[1], childScope)
            resolvePath(topLevelScope, item, pathTail, acc)

      else if typeof(scope) == "object"
        childScope = makeChildScope(topLevelScope)

        for k, v of scope
          childScope.this = v

          if evalAst(pathHead[1], childScope)
            resolvePath(topLevelScope, v, pathTail, acc)

      else
        acc.putValue(null)
        return
    else if isPathExpression(pathHead)
      childScope = makeChildScope(topLevelScope)
      childScope.this = scope

      exprResult = evalAst(pathHead[1], childScope)

      console.log("resolving with ", [exprResult].concat(pathTail))
      resolvePath(topLevelScope, scope, [exprResult].concat(pathTail), acc)
    else
      if Array.isArray(scope) && !Number.isInteger(pathHead)
        acc.putValue(null)
        return
      else
        i = null

        if Array.isArray(scope) && Number.isInteger(pathHead) && pathHead < 0
          i = scope.length + pathHead
        else
          i = pathHead

        resolvePath(topLevelScope, scope[i], pathTail, acc)

class PathAccumulator
  constructor: () ->
    @result = null
    @isMultiple = false

  makeMultiple: () ->
    unless @isMultiple
      @isMultiple = true
      @result = []

  putValue: (v) ->
    if @isMultiple
      @result.push(v) if v != null && v != undefined
    else
      @result = v

evalPath = (ast, scope) ->
  components = ast.slice(1)
  acc = new PathAccumulator

  resolvePath(scope, scope, components, acc)
  return acc.result

evalCall = (ast, scope) ->
  fnName = ast[1]
  fn = scope[fnName] || HELPERS[fnName]

  if !fn
    throw new Error("Unknow function: #{fnName}")

  args = ast.slice(2).map((arg) => evalAst(arg, scope))
  result = fn.apply(scope, args)

  return result

EVAL_TABLE =
  "+": mkEvalOp((a, b) -> a + b)
  "|": evalUnion
  "-": mkEvalOp((a, b) -> a - b)
  "*": mkEvalOp((a, b) -> a * b)
  "/": mkEvalOp((a, b) -> a / b)
  "=": mkEvalOp((a, b) -> a == b)
  "&&": mkEvalOp((a, b) -> a && b)
  "||": mkEvalOp((a, b) -> a || b)
  "!=": mkEvalOp((a, b) -> a != b)
  ">": mkEvalOp((a, b) -> a > b)
  "<": mkEvalOp((a, b) -> a < b)
  ">=": mkEvalOp((a, b) -> a >= b)
  "<=": mkEvalOp((a, b) -> a <= b)
  "unary-": evalUnaryMinus
  "path": evalPath
  "call": evalCall

evalExpression = (expr, scope) ->
  ast = globalParser.parse(expr)
  evalAst(ast, scope)

evalAst = (ast, scope) ->
  # console.log "EVAL:", ast, scope

  if Array.isArray(ast)
    evalFn = EVAL_TABLE[ast[0]]
    if !evalFn
      throw new Error("Don't know how to evaluate #{ast[0]}: #{JSON.stringify(ast)}")

    evalFn(ast, scope)
  else
    ast
