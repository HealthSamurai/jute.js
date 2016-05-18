# parser var is defined here

toSet = (v) ->
  if Array.isArray(v)
    new Set((v.map (x) -> JSON.stringify(x)))
  else
    new Set([JSON.stringify(v)])

setToArray = (s) ->
  r = []

  s.forEach (v) ->
    r.push(JSON.parse(v))

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
  result = toSet(evalAst(ast[1], scope))

  for operand in operands
    otherSet = toSet(evalAst(operand, scope))
    result = toSet(setToArray(result).concat(setToArray(otherSet)))

  setToArray(result)

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

putPathResult = (acc, res) ->
  if Array.isArray(acc.result)
    if res != null && res != undefined
      acc.result.push(res)
  else
    acc.result = res

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

  if !pathHead
    putPathResult(acc, scope)
    return

  if !scope
    putPathResult(acc, null)
    return
  else
    if isWildcard(pathHead)
      if !Array.isArray(acc.result)
        acc.result = []

      if Array.isArray(scope)
        for item in scope
          resolvePath(item, pathTail, acc)

      else if typeof(scope) == "object"
        for k, v of scope
          resolvePath(v, pathTail, acc)

      else
        putPathResult(acc, null)
        return
    else if isDeepWildcard(pathHead)
      if !Array.isArray(acc.result)
        acc.result = []

      resolveDeepWildcard(scope, pathTail, acc)
      return
    else if isPredicate(pathHead)
      if !Array.isArray(acc.result)
        acc.result = []

      if Array.isArray(scope)
        for item in scope
          if evalAst(pathHead[1], item)
            resolvePath(item, pathTail, acc)

      else if typeof(scope) == "object"
        for k, v of scope
          if evalAst(pathHead[1], v)
            resolvePath(v, pathTail, acc)

      else
        putPathResult(acc, null)
        return
    else if isPathExpression(pathHead)
      putPathResult(acc, "TODO: path expressions are not implemented")
      return
    else
      if Array.isArray(scope) && !Number.isInteger(pathHead)
        putPathResult(acc, null)
        return
      else
        resolvePath(scope[pathHead], pathTail, acc)

evalPath = (ast, scope) ->
  # console.log "evaluating:", JSON.stringify(ast, null, 2)
  components = ast.slice(1)
  acc = { result: null }

  resolvePath(scope, components, acc)
  return acc.result

EVAL_TABLE =
  "+": mkEvalOp((a, b) -> a + b)
  "|": evalUnion
  "-": mkEvalOp((a, b) -> a - b)
  "*": mkEvalOp((a, b) -> a * b)
  "/": mkEvalOp((a, b) -> a / b)
  "=": mkEvalOp((a, b) -> a == b)
  "!=": mkEvalOp((a, b) -> a != b)
  ">": mkEvalOp((a, b) -> a > b)
  "<": mkEvalOp((a, b) -> a < b)
  ">=": mkEvalOp((a, b) -> a >= b)
  "<=": mkEvalOp((a, b) -> a <= b)
  "unary-": evalUnaryMinus
  "path": evalPath

evalExpression = (expr, scope) ->
  ast = parser.parse(expr)
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
