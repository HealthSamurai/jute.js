HELPERS =
  join: (s, sep) -> s.join(sep)
  toUpperCase: (s) -> String(s).toUpperCase()
  toLowerCase: (s) -> String(s).toLowerCase()

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

evalString = (node, scope, options) ->
  expressionStartRegexp = /^\s*\$\s+/

  if node.match expressionStartRegexp # is it expression?
    jute.evalExpression(node.replace(expressionStartRegexp, ''), scope)
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

jute =
  evalExpression: evalExpression
  evalNode: evalNode
  makeChildScope: makeChildScope

transform = (scope, template, options) ->
  options ?=
    directives: {}

  extend(options.directives, DEFAULT_DIRECTIVES)
  jute.evalNode(template, scope, options)

exports =
  transform: transform
  parser: parser
  jute: jute

if typeof(module) != 'undefined'
  module.exports = exports
else if typeof(window) != 'undefined'
  window.jute = exports
else
  this.jute = exports
