assert = require("assert")
yaml = require("js-yaml")
fs = require("fs")
jute = require("./../lib/jute")

load = () ->
  specsRoot = __dirname

  fs.readdirSync(specsRoot).forEach (path) ->
    if path.match /\.yml$/
      absPath = specsRoot + "/" + path
      spec = yaml.safeLoad(fs.readFileSync(absPath, 'utf8'))

      describe spec.suite, () ->
        spec.tests.forEach (test) ->
          it test.desc, () ->
            result = jute.transform(test.scope, test.template)
            assert.deepEqual(result, test.result)

load()
