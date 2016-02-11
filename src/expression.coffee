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

getIn = (obj, path) ->
  result = obj

  path.forEach (x) ->
    if !(result == null or result == undefined)
      getFirst = false

      if x[x.length - 1] == '~'
        x = x.substr(0, x.length - 1)
        getFirst = true

      result = result[x]

      if getFirst && Array.isArray(result)
        result = result[1]

  result

evalPath = (ast, scope) ->
  components = ast.slice(1)
  getIn(scope, components)

TABLE =
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
    evalFn = TABLE[ast[0]]
    if !evalFn
      throw new Error("Don't know how to evaluate #{ast[0]}: #{JSON.stringify(ast)}")

    evalFn(ast, scope)
  else
    ast

module.exports =
  eval: evalExpression
