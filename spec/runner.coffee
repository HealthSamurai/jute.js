assert = require("assert")
yaml = require("js-yaml")
fs = require("fs")
jute = require("./../lib/jute")
parser = jute.parser

findYamls = (rootPath, re, cb) ->
  fs.readdirSync(rootPath).forEach (fn) ->
    if fn.match /\.yml$/ && fn.match re
      absPath = rootPath + "/" + fn
      spec = yaml.safeLoad(fs.readFileSync(absPath, 'utf8'))
      cb(spec)

specsRoot = __dirname

findYamls specsRoot, /_directive|expressions/, (spec) ->
  describe spec.suite, () ->
    spec.tests.forEach (test) ->
      it test.desc, () ->
        ast = jute.compile test.template
        result = jute.transform(test.scope, ast)
        assert.deepEqual(test.result, result)

parserSpec = yaml.safeLoad(fs.readFileSync(specsRoot + "/parser.yml", 'utf8'))
describe parserSpec.suite, () ->
  parserSpec.tests.forEach (test) ->
    it "'#{test.str}' is correct expression", () ->
      result = parser.parse(test.str)
      assert.deepEqual(test.ast, result)

######## MISC TESTS ##########

describe "custom directive", () ->
  it "should allow to provide custom directive in 'options' argument", () ->
    evalJoin = (jute, node, scope, options) ->
      arr = jute.evalNode(node.$join, scope, options)
      arr.join(node.$separator || ', ')

    s =
      names: ['Mike', 'Bob', 'July']

    t =
      $join:
        $map: "$ names"
        $as: "name"
        $body: "$ name"
      $separator: ', '

    options =
      directives:
        $join: evalJoin

    ast = jute.compile(t)
    result = jute.transform(s, ast, options)
    assert.deepEqual("Mike, Bob, July", result)

describe "jute.compile", () ->
  it "should allow to provide custom directive in 'options' argument", () ->
    t =
      $if: "$ 2 + 3"
      $then: "foo"
      $else: ["$ 4 - 2"]

    ast =
      $if: [jute.EXPRESSION_INDICATOR, ["+", 2, 3]]
      $then: "foo"
      $else: [[jute.EXPRESSION_INDICATOR, ["-", 4, 2]]]

    result = jute.compile(t)
    assert.deepEqual(ast, result)
