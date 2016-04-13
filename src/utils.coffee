extend = (obj, src) ->
  for key of src
    if src.hasOwnProperty(key)
      obj[key] = src[key]

  obj

intersectArrays = (a, b) ->
  result = []

  for aVal in a
    for bVal in b
      if aVal == bVal
        result.push aVal

  result

firstKeyName = (object) ->
  Object.keys(object)[0]
