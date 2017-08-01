EXPRESSION_START_REGEXP = /^\s*\$\s+/
EXPRESSION_INDICATOR = "!expr"
STRING_INTERPOLATION_REGEXP = /\{\{([^}]+)\}\}/g

md5 = require('md5');

HELPERS =
  join: (s, sep) -> s.join(sep)
  toUpperCase: (s) -> String(s).toUpperCase()
  toLowerCase: (s) -> String(s).toLowerCase()

  trim: (v) ->
    return v if typeof(v) != 'string'
    v.trim()

  dateTime: (v) -> v && v[1] || null

  translateCode: (v) -> v

  truncate: (v, length) ->
    if typeof(v) == 'string'
      v.substring(0, length)
    else
      null

  parseInt: parseInt

  capitalize: (s) ->
    return null if !s
    s[0].toUpperCase() + s.substr(1).toLowerCase()

  sortBy: (v, expr) ->
    ast = globalParser.parse(expr)

    if Array.isArray(v)
      v.sort (a, b) ->
        aVal = evalAst(ast, a)
        bVal = evalAst(ast, b)

        if aVal > bVal then 1 else (if aVal < bVal then -1 else 0)
    else
      v

  toStr: (result) ->
    if result == null || result == undefined
      ""
    else
      String(result)

  groupBy: (v, expr) ->
    ast = globalParser.parse(expr)

    if Array.isArray(v)
      fn = (res, x) ->
        keyVal = evalAst(ast, x)

        if keyVal
          res[keyVal] ?= []
          res[keyVal].push(x)

        res

      r = v.reduce(fn, {})
      r

    else
      v

  md5: (v) ->
    md5(JSON.stringify(v))

  flatten: (v) ->
    return v if !Array.isArray(v)

    result = []
    for item in v
      if Array.isArray(item)
        result = result.concat(item)
      else
        result.push(item)

    result

makeChildScope = (scope) ->
  childScope = {}
  childScope.__proto__ = scope

  childScope

nodeValue = (node, valueAttr) ->
  valueObject = node[(valueAttr || '$value')]

  if typeof(valueObject) != 'undefined'
    valueObject
  else
    valueObject = {}

    for key, value of node
      if !key.match /^\$/
        valueObject[key] = value

    valueObject

# TODO: do we really need options here?
isDirective = (node, options) ->
  for key, value of node
    return true if key.match /^\$/

  false

evalDirective = (node, scope, options) ->
  knownDirectives = Object.keys(options.directives)
  nodeKeys = Object.keys(node)
  keys = intersectArrays(nodeKeys, knownDirectives)

  if keys.length == 0
    throw "Could not find known directive among #{nodeKeys.join(', ')}; Known directives are: #{knownDirectives.join(', ')}"
  else if keys.length > 1
    throw "Ambigous node with multiple directives found: #{keys.join(', ')}"

  directiveName = keys[0]
  directiveFn = options.directives[directiveName]

  directiveFn(jute, node, scope, options)

evalObject = (node, scope, options) ->
  if isDirective(node, options)
    evalDirective(node, scope, options)
  else
    result = {}
    for key, value of node
      result[key] = jute.evalNode(value, scope, options)

    result

isInterpolableString = (node) ->
  node != null and
    node != undefined and
    typeof node == 'string' and
    (node.indexOf('{{') >= 0 || node[0] == '$')

evalString = (node, scope, options) ->
  if node.match EXPRESSION_START_REGEXP
    jute.evalExpression(node.replace(EXPRESSION_START_REGEXP, ''), scope)
  else if isInterpolableString(node)
    interpolateString(node, scope)
  else
    node

evalNode = (node, scope, options) ->
  if typeof(options) == 'undefined' || !options
    throw "evalNode() called without options. Node is: #{JSON.stringify(node)}"

  if typeof(scope) == 'undefined'
    throw "evalNode() called with undefined scope. Node is: #{JSON.stringify(node)}"

  nodeType = typeof(node)

  if nodeType == 'object' && node != null
    if Array.isArray(node)
      if node[0] == EXPRESSION_INDICATOR
        evalAst(node[1], scope)
      else
        node.map (element) -> jute.evalNode(element, scope, options)
    else
      evalObject(node, scope, options)
  else
    node

compileStringInterpolation = (node) ->
  re = new RegExp(STRING_INTERPOLATION_REGEXP)
  ast = ['+']
  prevMatchIdx = 0

  while match = re.exec(node)
    ast.push(node.substr(prevMatchIdx, match.index - prevMatchIdx))
    ast.push(["call", "toStr", globalParser.parse(match[1])])

    prevMatchIdx = match.index + match[0].length

  # string tail to the ast
  ast.push(node.substr(prevMatchIdx))

  [EXPRESSION_INDICATOR, ast]

compile = (node) ->
  if typeof(node) == 'string'
    if node.match(EXPRESSION_START_REGEXP)
      [EXPRESSION_INDICATOR, globalParser.parse(node.replace(EXPRESSION_START_REGEXP, ''))]
    else if isInterpolableString(node)
      compileStringInterpolation(node)
    else
      node
  else if Array.isArray(node)
    node.map compile
  else if typeof(node) == 'object'
    result = {}
    Object.keys(node).forEach((k) -> result[k] = compile(node[k]))
    result
  else
    node

jute =
  # evalExpression: evalExpression
  evalExpressionAst: evalAst
  evalNode: evalNode
  makeChildScope: makeChildScope

transform = (scope, template, options) ->
  options ?=
    directives: {}

  extend(options.directives, DEFAULT_DIRECTIVES)
  jute.evalNode(template, scope, options)

exports =
  transform: transform
  parser: globalParser
  compile: compile
  EXPRESSION_INDICATOR: EXPRESSION_INDICATOR
  jute: jute

if typeof(module) != 'undefined'
  module.exports = exports
else if typeof(window) != 'undefined'
  window.jute = exports
else
  this.jute = exports
