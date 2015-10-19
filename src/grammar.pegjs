Root
  = e:Expr !. { return e; }

Expr
  = expr:AdditiveExpr filters:Filters? {
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

AdditiveExpr
  = left:MultiplicativeExpr
    SPACE operator:$( PLUS / MINUS ) SPACE
    right:AdditiveExpr
    { return [operator, left, right]; }

  / MultiplicativeExpr

MultiplicativeExpr
  = left:NegationExpr
    SPACE operator:$( MUL / DIV / MOD ) SPACE
    right:MultiplicativeExpr
    { return [operator, left, right]; }

  / NegationExpr

NegationExpr
  = MINUS v:Value { return ["-", v]; }
  / v:Value { return v; }

Value
  = l:Literal { return l; }
  / q:JuQuery { return q; }
  / LPAR e:Expr RPAR { return e; }

//////////////////////////////////////////

JuQuery
  = PathHead (DOT PathComponent)*
    { return ["query", text()]; }

PathHead
  = IdentifierStart IdentifierComponent*

PathComponent
  = IdentifierComponent+

IdentifierStart
  = NON_DIGIT_CHAR

IdentifierComponent
  = ID_CHAR

//////////////////////////////////////////

Filters
  = filters:(SPACE PIPE SPACE filter:Filter { return filter; })+
    { return filters; }

Filter
  = name:$FilterName args:FilterArgs? {
    return {name: name, args: args || []};
  }

FilterName
  = ID_CHAR +

FilterArgs
  = LPAR SPACE head:Expr
    tail:(SPACE COMMA SPACE e:Expr {return e;})* SPACE RPAR {
      return [head].concat(tail);
    }

//////////////////////////////////////////
// Literals
//////////////////////////////////////////

Literal
  = NumberLiteral
  / ArrayLiteral
  / StringLiteral
  / BoolLiteral
  / NullLiteral

NumberLiteral
  = (PLUS / MINUS)? [0-9]+ fract:(DOT [0-9]+)? {
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
  = "true" !IdentifierStart { return true; }
  / "false" !IdentifierStart { return false; }

NullLiteral
  = "null" !IdentifierStart { return null; }

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
