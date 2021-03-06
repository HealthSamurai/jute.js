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
  evalResult = jute.evalNode(node.$if, scope, options)

  if evalResult
    v = nodeValue(node, '$then')
    jute.evalNode(v, scope, options)
  else
    jute.evalNode(node.$else || null, scope, options)

evalSwitch = (jute, node, scope, options) ->
  evalResult = jute.evalNode(node.$switch, scope, options)
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
  array = jute.evalNode(node.$map, scope, options)
  isObject = false

  if (!Array.isArray(array))
    if typeof(array) == "object"
      isObject = true
    else
      array = [array]

  varName = node.$as
  value = nodeValue(node, '$body', options)

  result = []
  childScope = jute.makeChildScope(scope)

  if isObject
    for k, v of array
      childScope[varName] = { key: k, value: v }
      result.push jute.evalNode(value, childScope, options)
  else
    array.forEach (item) ->
      childScope[varName] = item
      result.push jute.evalNode(value, childScope, options)

  result

evalConcat = (jute, node, scope, options) ->
  array = jute.evalNode(node.$concat, scope, options)

  if (!Array.isArray(array))
    array = [array]

  result = []

  array.forEach (item) ->
    if Array.isArray(item)
      result = result.concat(item)
    else
      result.push(item)

  result


DEFAULT_DIRECTIVES =
  $if: evalIf
  $switch: evalSwitch
  $let: evalLet
  $filter: evalFilter
  $map: evalMap
  $js: evalJs
  $concat: evalConcat
