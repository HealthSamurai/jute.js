expr = require("./expression")

HELPERS =
  join: (s, sep) ->
    s.join(sep)

intersectArrays = (a, b) ->
  result = []

  for aVal in a
    for bVal in b
      if aVal == bVal
        result.push aVal

  result

makeChildScope = (scope) ->
  childScope = {}
  childScope.__proto__ = scope

  childScope

firstKeyName = (object) ->
  Object.keys(object)[0]

evalLet = (node, scope) ->
  childScope = makeChildScope(scope)
  addVarToScope = (name, node) ->
    childScope[name] = evalNode(node, childScope)

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

  evalNode(body, childScope)

evalIf = (node, scope) ->
  evalResult = expr.eval(node.$if, scope)
  # console.log "!!!!! if:", node.$if, "=>", evalResult

  if evalResult
    v = nodeValue(node, '$then')
    evalNode(v, scope)
  else
    evalNode(node.$else || null, scope)

evalSwitch = (node, scope) ->
  evalResult = expr.eval(node.$switch, scope)
  resultNode = node[evalResult]

  if typeof(resultNode) == 'undefined'
    resultNode = node['$default']

  if typeof(resultNode) == 'undefined'
    null
  else
    evalNode(resultNode, scope)

evalFilter = (node, scope) ->
  filters = node.$filter
  val = evalNode(nodeValue(node, '$body'), scope)

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

evalJs = (node, scope) ->
  eval(node.$js)

evalMap = (node, scope) ->
  array = expr.eval(node.$map, scope)
  varName = node.$as
  value = nodeValue(node, '$body')

  result = []
  childScope = makeChildScope(scope)

  array.forEach (item) ->
    childScope[varName] = item
    result.push evalNode(value, childScope)

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

DIRECTIVES =
  $if: evalIf
  $switch: evalSwitch
  $let: evalLet
  $filter: evalFilter
  $map: evalMap
  $js: evalJs


isDirective = (node) ->
  for key, value of node
    return true if key.match /^\$/

  false

evalDirective = (node, scope) ->
  knownDirectives = Object.keys(DIRECTIVES)
  nodeKeys = Object.keys(node)
  keys = intersectArrays(nodeKeys, knownDirectives)

  if keys.length == 0
    throw "Could not find known directive among #{nodeKeys.join(', ')}; Known directives are: #{knownDirectives.join(', ')}"
  else if keys.length > 1
    throw "Ambigous node with multiple directives found: #{keys.join(', ')}"

  directiveName = keys[0]
  directiveFn = DIRECTIVES[directiveName]

  directiveFn(node, scope)


evalObject = (node, scope) ->
  if isDirective(node)
    evalDirective(node, scope)
  else
    result = {}
    for key, value of node
      result[key] = evalNode(value, scope)

    result

evalString = (node, scope) ->
  expressionStartRegexp = /^\s*\$\s+/

  if node.match expressionStartRegexp # is it expression?
    expr.eval(node.replace(expressionStartRegexp, ''), scope)
  else
    node

evalNode = (node, scope) ->
  if typeof(scope) == 'undefined'
    throw "evalNode() called with undefined scope. Node is: #{JSON.stringify(node)}"

  nodeType = typeof(node)

  if nodeType == 'object' && node != null
    if Array.isArray(node)
      node.map (element) -> evalNode(element, scope)
    else
      evalObject(node, scope)
  else
    if nodeType == 'string'
      evalString(node, scope)
    else if nodeType == 'undefined'
      null
    else
      node

transform = (scope, template) ->
  evalNode(template, scope)

module.exports =
  transform: transform
