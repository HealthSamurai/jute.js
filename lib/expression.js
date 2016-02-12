// Generated by CoffeeScript 1.10.0
(function() {
  var EVAL_TABLE, evalAst, evalExpression, evalPath, evalUnaryMinus, flatten, isWildcard, mapAndFilterNulls, mkEvalOp, parser, resolvePath;

  parser = require("./parser");

  mkEvalOp = function(opFn) {
    return function(ast, scope) {
      var j, len, op, operand, operands, result;
      op = ast[0];
      if (ast.length < 3) {
        throw new Error("Insufficient operands for '" + op + "' operator: " + (JSON.stringify(ast)));
      }
      if (!opFn) {
        throw new Error("Don't know how to evaluate " + op);
      }
      operands = ast.slice(2);
      result = evalAst(ast[1], scope);
      for (j = 0, len = operands.length; j < len; j++) {
        operand = operands[j];
        result = opFn(result, evalAst(operand, scope));
      }
      return result;
    };
  };

  evalUnaryMinus = function(ast, scope) {
    var op, operands;
    op = ast[0];
    if (ast.length !== 2) {
      throw new Error("Wrong number of operands for '" + op + "' operator: " + (JSON.stringify(ast)));
    }
    operands = ast.slice(2);
    return -(evalAst(ast[1], scope));
  };

  flatten = function(arr) {
    return arr.reduce(function(acc, i) {
      return acc.concat(Array.isArray(i) ? flatten(i) : i);
    }, []);
  };

  isWildcard = function(c) {
    return Array.isArray(c) && c.length === 1 && c[0] === 'wildcard';
  };

  mapAndFilterNulls = function(array, mapFn) {
    return array.map(mapFn).filter(function(i) {
      return i !== null && i !== void 0;
    });
  };

  resolvePath = function(scope, path) {
    var pathHead, pathTail;
    pathHead = path[0];
    pathTail = path.slice(1);
    if (pathHead === null || pathHead === void 0) {
      return scope;
    }
    if (!(scope === null || scope === void 0)) {
      if (isWildcard(pathHead)) {
        if (Array.isArray(scope)) {
          return mapAndFilterNulls(scope, function(item) {
            return resolvePath(item, pathTail);
          });
        } else if (typeof scope === "object") {
          return flatten(mapAndFilterNulls(Object.keys(scope), function(k) {
            return resolvePath(scope[k], pathTail);
          }));
        } else {
          return resolvePath(scope, pathTail);
        }
      } else {
        if (Array.isArray(scope) && !(pathHead.match(/^\d+$/))) {
          return mapAndFilterNulls(scope, function(item) {
            return resolvePath(item[pathHead], pathTail);
          });
        } else {
          return resolvePath(scope[pathHead], pathTail);
        }
      }
    }
  };

  evalPath = function(ast, scope) {
    var components;
    components = ast.slice(1);
    return resolvePath(scope, components);
  };

  EVAL_TABLE = {
    "+": mkEvalOp(function(a, b) {
      return a + b;
    }),
    "-": mkEvalOp(function(a, b) {
      return a - b;
    }),
    "*": mkEvalOp(function(a, b) {
      return a * b;
    }),
    "/": mkEvalOp(function(a, b) {
      return a / b;
    }),
    "=": mkEvalOp(function(a, b) {
      return a === b;
    }),
    "!=": mkEvalOp(function(a, b) {
      return a !== b;
    }),
    ">": mkEvalOp(function(a, b) {
      return a > b;
    }),
    "<": mkEvalOp(function(a, b) {
      return a < b;
    }),
    ">=": mkEvalOp(function(a, b) {
      return a >= b;
    }),
    "<=": mkEvalOp(function(a, b) {
      return a <= b;
    }),
    "unary-": evalUnaryMinus,
    "path": evalPath
  };

  evalExpression = function(expr, scope) {
    var ast;
    ast = parser.parse(expr);
    return evalAst(ast, scope);
  };

  evalAst = function(ast, scope) {
    var evalFn;
    if (Array.isArray(ast)) {
      evalFn = EVAL_TABLE[ast[0]];
      if (!evalFn) {
        throw new Error("Don't know how to evaluate " + ast[0] + ": " + (JSON.stringify(ast)));
      }
      return evalFn(ast, scope);
    } else {
      return ast;
    }
  };

  module.exports = {
    "eval": evalExpression
  };

}).call(this);