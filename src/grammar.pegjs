Root
  = e:Expr !. { return e; }

Expr
  = expr:EqualityExpr filters:Filters? {
    var result = expr;
    if (filters != null) {
      for(var i = 0; i < filters.length; i++) {
        var f = filters[i];
        result = ["call", f.name, result].concat(f.args);
      }

      return result;
    } else {
      return result;
    }
  }

EqualityExpr
  = left:ComparisonExpr
    SPACE operator:$( '=' / '!=' ) SPACE
    right:EqualityExpr
    { return [operator, left, right]; }

  / ComparisonExpr

ComparisonExpr
  = left:AdditiveExpr
    SPACE operator:$( '<' / '<=' / '>' / '>=' ) SPACE
    right:ComparisonExpr
    { return [operator, left, right]; }

  / AdditiveExpr

AdditiveExpr
  = left:MultiplicativeExpr
    SPACE operator:$( PLUS / MINUS ) SPACE
    right:AdditiveExpr
    { return [operator, left, right]; }

  / MultiplicativeExpr

MultiplicativeExpr
  = left:SetExpr
    SPACE operator:$( MUL / DIV / MOD ) SPACE
    right:MultiplicativeExpr
    { return [operator, left, right]; }

  / SetExpr

SetExpr
  = left:NegationExpr
    SPACE operator:$( '|' ) SPACE
    right:SetExpr
    { return [operator, left, right]; }

  / NegationExpr

NegationExpr
  = MINUS v:Value { return ["unary-", v]; }
  / v:Value { return v; }

Value
  = l:Literal { return l; }
  / q:Path { return q; }
  / LPAR e:Expr RPAR { return e; }

//////////////////////////////////////////
// PATHS
//////////////////////////////////////////

Path
  = '@' components:(DOT c:PathComponent { return c; } )*
    { return ["path"].concat(components); }

  / head:PathHead components:(DOT c:PathComponent { return c; } )*
    { return ["path"].concat([head].concat(components)); }

PathHead
  = NON_DIGIT_CHAR ID_CHAR*
    { return text() };

PathComponent
  = c:ID_CHAR+
    { return text(); }
  / p:PathPredicate
    { return p; }
  / '**'
    { return ['deepWildcard']; }
  / '*'
    { return ['wildcard']; }
  / LPAR e:Expr RPAR
    { return ['expr', e]; }

PathPredicate
  = '*' LPAR e:Expr RPAR
    { return ["filter", e]; }

//////////////////////////////////////////
// FILTERS
//////////////////////////////////////////

Filters
  = filters:(SPACE '|>' SPACE filter:Filter { return filter; })+
    { return filters; }

Filter
  = name:$FilterName args:FilterArgs? {
    return {name: name, args: args || []};
  }

FilterName
  = ID_CHAR +

FilterArgs
  = LPAR SPACE head:Expr
    tail:(SPACE COMMA SPACE e:Expr {return e;})* SPACE RPAR
    { return [head].concat(tail); }

//////////////////////////////////////////
// LITERALS
//////////////////////////////////////////

Literal
  = NumberLiteral
  / ArrayLiteral
  / StringLiteral
  / BoolLiteral
  / NullLiteral

NumberLiteral
  = ('+' / '-')? [0-9]+ fract:(DOT [0-9]+)? {
    if (fract) {
      return parseFloat(text());
    } else {
      return parseInt(text());
    }
  }

ArrayLiteral
  = LSB head:Expr
    tail:(SPACE COMMA SPACE e:Expr {return e;})* RSB
    { return ["array", head].concat(tail || {}); }

BoolLiteral
  = "true" !ID_CHAR { return true; }
  / "false" !ID_CHAR { return false; }

NullLiteral
  = "null" !ID_CHAR { return null; }

//////////////////////////////////////////
// String Literal
//////////////////////////////////////////

StringLiteral
  = '"' chars:DoubleStringCharacter* '"' {
      return chars.join("");
    }
  / "'" chars:SingleStringCharacter* "'" {
      return chars.join("");
    }

DoubleStringCharacter
  = !'"' . { return text(); }
  / "\\" sequence:EscapeSequence { return sequence; }

SingleStringCharacter
  = !"'" . { return text(); }
  / "\\" sequence:EscapeSequence { return sequence; }

EscapeSequence
  = CharacterEscapeSequence
  / "0" ![0-9] { return "\0"; }
  / HexEscapeSequence
  / UnicodeEscapeSequence

CharacterEscapeSequence
  = SingleEscapeCharacter
  / NonEscapeCharacter

SingleEscapeCharacter
  = "'"
  / '"'
  / "\\"
  / "b"  { return "\b";   }
  / "f"  { return "\f";   }
  / "n"  { return "\n";   }
  / "r"  { return "\r";   }
  / "t"  { return "\t";   }
  / "v"  { return "\x0B"; }   // IE does not recognize "\v".

NonEscapeCharacter
  = !EscapeCharacter . { return text(); }

EscapeCharacter
  = SingleEscapeCharacter
  / [0-9]
  / "x"
  / "u"

HexEscapeSequence
  = "x" digits:$(HexDigit HexDigit) {
      return String.fromCharCode(parseInt(digits, 16));
    }

HexDigit
  = [0-9a-f]i

UnicodeEscapeSequence
  = "u" digits:$(HexDigit HexDigit HexDigit HexDigit) {
      return String.fromCharCode(parseInt(digits, 16));
    }

//////////////////////////////////////////
// Constants
//////////////////////////////////////////

PIPE = '|'
PLUS = '+'
MINUS = '-'
MUL = '*'
DIV = '/'
MOD = '%'

COMMA = ','
DOT = '.'
SPACE = (' ' / '\t') *
NON_DIGIT_CHAR = [a-z] / [A-Z] / [_]
ID_CHAR = [a-z] / [A-Z] / [0-9] / [_]
LPAR = '('
RPAR = ')'
LSB = '['
RSB = ']'
