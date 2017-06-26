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

resolveDeepWildcard = (scope, path, acc) ->
  if Array.isArray(scope)
    for item in scope
      resolvePath(item, path, acc)
      resolveDeepWildcard(item, path, acc)

  else if typeof(scope) == 'object'
    for k, v of scope
      resolvePath(v, path, acc)
      resolveDeepWildcard(v, path, acc)

resolvePath = (scope, path, acc) ->
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
          resolvePath(item, pathTail, acc)

      else if typeof(scope) == "object"
        for k, v of scope
          resolvePath(v, pathTail, acc)

      else
        acc.putValue(null)
        return
    else if isDeepWildcard(pathHead)
      acc.makeMultiple()

      resolveDeepWildcard(scope, pathTail, acc)
      return
    else if isPredicate(pathHead)
      acc.makeMultiple()

      if Array.isArray(scope)
        for item in scope
          if evalAst(pathHead[1], item)
            resolvePath(item, pathTail, acc)

      else if typeof(scope) == "object"
        for k, v of scope
          if evalAst(pathHead[1], v)
            resolvePath(v, pathTail, acc)

      else
        acc.putValue(null)
        return
    else if isPathExpression(pathHead)
      exprResult = evalAst(pathHead[1], scope)

      resolvePath(exprResult, pathTail, acc)
    else
      if Array.isArray(scope) && !Number.isInteger(pathHead)
        acc.putValue(null)
        return
      else
        resolvePath(scope[pathHead], pathTail, acc)

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

  resolvePath(scope, components, acc)
  return acc.result

evalCall = (ast, scope) ->
  fnName = ast[1]
  fn = HELPERS[fnName]

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
