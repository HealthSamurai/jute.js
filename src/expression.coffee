parser = require("./parser")

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

flatten = (arr) ->
  arr.reduce((acc, i) ->
    acc.concat if Array.isArray(i) then flatten(i) else i
  , [])

isWildcard = (c) ->
  Array.isArray(c) && c.length == 1 && c[0] == 'wildcard'

mapAndFilterNulls = (array, mapFn) ->
  array.map(mapFn).filter((i) -> i != null && i != undefined)

resolvePath = (scope, path) ->
  pathHead = path[0]
  pathTail = path.slice(1)

  if pathHead == null || pathHead == undefined
    return scope

  if !(scope == null || scope == undefined)
    if isWildcard(pathHead)
      if Array.isArray(scope)
        return mapAndFilterNulls scope, (item) -> resolvePath(item, pathTail)
      else if typeof(scope) == "object"
        return flatten(mapAndFilterNulls Object.keys(scope), (k) -> resolvePath(scope[k], pathTail))
      else
        return resolvePath(scope, pathTail)
    else
      if Array.isArray(scope) && !(pathHead.match(/^\d+$/))
        return mapAndFilterNulls scope, (item) -> resolvePath(item[pathHead], pathTail)
      else
        return resolvePath(scope[pathHead], pathTail)

# resolvePath = (scope, path) ->
#   notNull = (i) -> !!i
#   result = scope

#   path.forEach (comp, index) ->
#     if !(result == null or result == undefined)
#       if isWildcard(comp)
#         if Array.isArray(result)
#           pathRest = path.slice(index + 1)
#           console.log "before wc:", result
#           result = result.map (item) -> resolvePath(item, pathRest)
#           result = result.filter notNull
#           console.log "wc result:", result, pathRest
#           # TODO: hard return here!
#           return result
#         else if typeof(result) == "object"
#           result = Object.keys(result)
#           console.log "wc result obj:", result
#         else
#           result = result
#       else
#         # TODO: numeric/non-numeric components should be
#         # distinguished by parser
#         if Array.isArray(result) && !(comp.match(/^\d+$/))
#           result = result.map (item) -> item[comp]
#           result = result.filter notNull
#         else
#           result = result[comp]

#   result

evalPath = (ast, scope) ->
  components = ast.slice(1)
  resolvePath(scope, components)

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

module.exports =
  eval: evalExpression
