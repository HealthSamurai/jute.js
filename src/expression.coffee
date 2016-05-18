# parser var is defined here

mkEvalOp = (opFn) ->
  (ast, scope) ->
    op = ast[0]

    if ast.length < 3
      throw new Error("Insufficient operands for '#{op}' operator: #{JSON.stringify(ast)}")

    if !opFn
      throw new Error("Don't know how to evaluate #{op}")

    operands = ast.slice(2)
    result = evalAst(ast[1], scope)

    for operand in operands
      result = opFn(result, evalAst(operand, scope))

    result

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

putPathResult = (acc, res) ->
  if Array.isArray(acc.result)
    if res != null && res != undefined
      acc.result.push(res)
  else
    acc.result = res

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
