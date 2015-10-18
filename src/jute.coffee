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

  value = node.$body

  if typeof(value) == 'undefined'
    throw "No $value attr in $let node: " + JSON.stringify(node)

  evalNode(value, childScope)

evalIf = (node, scope) ->
  evalResult = evalExpression(node.$if, scope)
  # console.log "!!!!! if:", node.$if, "=>", evalResult

  if evalResult
    v = nodeValue(node, '$then')
    evalNode(v, scope)
  else
    evalNode(node.$else || null, scope)

evalSwitch = (node, scope) ->
  evalResult = evalExpression(node.$switch, scope)
  resultNode = node[evalResult]

  if typeof(resultNode) == 'undefined'
    resultNode = node['$default']

  if typeof(resultNode) == 'undefined'
    null
  else
    evalNode(resultNode, scope)

evalFilter = (node, scope) ->
  if node && node.$filter
    filter = node.$filter
    val = nodeValue(node)
    delete val['$filter']

    val = evalNode(val, scope)

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


    if Array.isArray(filter)
      result = val

      for f in filter
        result = applyFilter(f, result)

      result
    else
      applyFilter(filter, val)
  else
    node

evalJs = (node, scope) ->
  if node && node.$js
    eval(node.$js)
  else
    node

evalMap = (node, scope) ->
  array = evalExpression(node.$map, scope)
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

parsePath = (p) ->
  p.split('.').map (e) -> e.trim()

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

  # console.log "!!!! getIn", JSON.stringify(path), "=>", JSON.stringify(result)

  result

# This is a quick & dirty implementation
# of expression evaluator. More robust approach
# is to write a parser and to implement
# an interpreter, but it's too much work for now.
evalExpression = (expr, scope) ->
  if typeof(scope) == 'undefined'
    throw "evalExpression() called with undefined scope. Expression is: #{expr}"


  pathRegexp = /"(?:[^"\\]|\\.)*"|([a-zA-Z_0-9~][a-zA-Z_0-9.~]+[a-zA-Z_0-9~])/g
  filterRegexp = /(\s*\|\s*[a-zA-Z0-9_]+(\([^)]+\))?)*\s*$/
  filters = null

  # get filters at first
  e = expr.replace filterRegexp, (f_str) ->
    filters = f_str.split(/\s*\|\s*/).map (f) ->
      f = f.trim()

      if f.indexOf("(") > 0
        args = f.match(/\(([^)]+)\)$/)[1].split(",").map(JSON.parse)
        f = f.substr(0, f.indexOf("("))
        [f, args]
      else
        f

    filters.shift()
    ""

  e = e.replace pathRegexp, (fullMatch, pathStr) ->
    if pathStr
      path = parsePath(pathStr)
      "getIn(scope, #{JSON.stringify(path)})"
    else
      fullMatch

  result = eval(e)
  # console.log "!!!!! evalExpression:", e, " => ", result, scope

  for filter in filters
    if Array.isArray(filter)
      name = filter.shift()
      args = filter
    else
      name = filter
      args = []

    filterFn = HELPERS[name]

    if !filterFn
      throw "Unknown filter: '#{name}'"

    result = filterFn.apply(scope, [result].concat(args))

  result

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

  if node.match expressionStartRegexp     # is it expression?
    evalExpression(node.replace(expressionStartRegexp, ''), scope)
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
