extend = (obj, src) ->
  for key of src
    if src.hasOwnProperty(key)
      obj[key] = src[key]

  obj
