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
    node

transform = (scope, template) ->
  evalNode(template, scope)

module.exports =
  transform: transform
