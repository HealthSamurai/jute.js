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

  result

# This is a quick & dirty implementation
# of expression evaluator. More robust approach
# is to write a parser and to implement
# an interpreter, but it's too much work for now.
evalExpression = (expr, scope) ->
  pathRegexp = /"(?:[^"\\]|\\.)*"|([a-zA-Z_0-9~][a-zA-Z_0-9.~]+[a-zA-Z_0-9~])/g
  filterRegexp = /(\s*\|\s*[a-zA-Z0-9_]+(\([^)]+\))?)*\s*$/
  filters = null

  # get filters at first
  e = String(expr.substr(1)).replace filterRegexp, (f_str) ->
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

  # console.log "!!!!! =>", e
  result = eval(e)

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


evalNode = (node, scope) ->
  if typeof(node) == 'object' && node != null
    if Array.isArray(node)
      node.map (element) -> evalNode(element, scope)
    else
      result = {}

      for key, value of node
        result[key] = evalNode(value, scope)

      result
  else
    if typeof(node) == 'string' && node[0] == '$'
      evalExpression(node, scope)
    else
      node

transform = (scope, template) ->
  evalNode(template, scope)

module.exports =
  transform: transform
