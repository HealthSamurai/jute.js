HELPERS =
  join: (s, sep) -> s.join(sep)
  toUpperCase: (s) -> String(s).toUpperCase()
  toLowerCase: (s) -> String(s).toLowerCase()

jute =
  evalExpression: evalExpression

intersectArrays = (a, b) ->
  result = []

  for aVal in a
    for bVal in b
      if aVal == bVal
        result.push aVal

  result

jute.makeChildScope = (scope) ->
  childScope = {}
  childScope.__proto__ = scope

  childScope

firstKeyName = (object) ->
  Object.keys(object)[0]

evalLet = (jute, node, scope, options) ->
  childScope = jute.makeChildScope(scope)
  addVarToScope = (name, node) ->
    childScope[name] = jute.evalNode(node, childScope, options)

  if Array.isArray(node.$let)
    for varDecl in node.$let
      varName = firstKeyName(varDecl)

      if varName
        addVarToScope(varName, varDecl[varName])
  else
    for k, v of node.$let
      addVarToScope(k, v)

  body = node.$body

  if typeof(body) == 'undefined'
    throw "No $body attr in $let node: " + JSON.stringify(node)

  jute.evalNode(body, childScope, options)

evalIf = (jute, node, scope, options) ->
  evalResult = jute.evalExpression(node.$if, scope, options)
  # console.log "!!!!! if:", node.$if, "=>", evalResult

  if evalResult
    v = nodeValue(node, '$then')
    jute.evalNode(v, scope, options)
  else
    jute.evalNode(node.$else || null, scope, options)

evalSwitch = (jute, node, scope, options) ->
  evalResult = jute.evalExpression(node.$switch, scope, options)
  resultNode = node[evalResult]

  if typeof(resultNode) == 'undefined'
    resultNode = node['$default']

  if typeof(resultNode) == 'undefined'
    null
  else
    jute.evalNode(resultNode, scope, options)

evalFilter = (jute, node, scope, options) ->
  filters = node.$filter
  val = jute.evalNode(nodeValue(node, '$body'), scope, options)

  applyFilter = (filterName, val) ->
    if filterName.indexOf('(') > 0
      filterArgs = filterName.match(/\(([^)]+)\)$/)[1].split(",").map(JSON.parse)
      filterName = filterName.substr(0, filterName.indexOf("("))
    else
      filterArgs = []

    filterFn = HELPERS[filterName]

    if !filterFn
      throw "Unknown filter: '#{filterName}'"

    filterFn.apply(scope, [val].concat(filterArgs))


  if Array.isArray(filters)
    result = val

    for f in filters
      result = applyFilter(f, result)

    result
  else
    applyFilter(filters, val)

evalJs = (jute, node, scope, options) ->
  eval(node.$js)

evalMap = (jute, node, scope, options) ->
  array = jute.evalExpression(node.$map, scope, options)
  varName = node.$as
  value = nodeValue(node, '$body', options)

  result = []
  childScope = jute.makeChildScope(scope)

  array.forEach (item) ->
    childScope[varName] = item
    result.push jute.evalNode(value, childScope, options)

  result

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

evalString = (node, scope, options) ->
  expressionStartRegexp = /^\s*\$\s+/

  if node.match expressionStartRegexp # is it expression?
    jute.evalExpression(node.replace(expressionStartRegexp, ''), scope)
  else
    node

jute.evalNode = (node, scope, options) ->
  if typeof(options) == 'undefined' || !options
    throw "evalNode() called without options. Node is: #{JSON.stringify(node)}"

  if typeof(scope) == 'undefined'
    throw "evalNode() called with undefined scope. Node is: #{JSON.stringify(node)}"

  nodeType = typeof(node)

  if nodeType == 'object' && node != null
    if Array.isArray(node)
      node.map (element) -> jute.evalNode(element, scope, options)
    else
      evalObject(node, scope, options)
  else
    if nodeType == 'string'
      evalString(node, scope, options)
    else if nodeType == 'undefined'
      null
    else
      node

DEFAULT_DIRECTIVES =
  $if: evalIf
  $switch: evalSwitch
  $let: evalLet
  $filter: evalFilter
  $map: evalMap
  $js: evalJs

transform = (scope, template, options) ->
  options ?=
    directives: {}

  extend(options.directives, DEFAULT_DIRECTIVES)

  jute.evalNode(template, scope, options)

exports =
  transform: transform
  parser: parser

if typeof(module) != 'undefined'
  module.exports = exports
else if typeof(window) != 'undefined'
  window.jute = exports
else
  this.jute = exports
