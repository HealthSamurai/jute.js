Root = Expression !.

Expression = AdditiveExpression (Filters)?

AdditiveExpression = MultiplicativeExpression
                      (SPACE ( PLUS / MINUS ) SPACE MultiplicativeExpression)*

MultiplicativeExpression = NegationExpression
                            (SPACE ( MUL / DIV / MOD ) SPACE NegationExpression)*

NegationExpression = MINUS Value /
                      Value

Value = Identifier /
        Literal /
        LPAR Expression RPAR

//////////////////////////////////////////

Identifier = IdentifierComponentStartingWithNonDigit (DOT IdentifierComponent)* SPACE

IdentifierComponent = ID_CHAR*

IdentifierComponentStartingWithNonDigit = NON_DIGIT_CHAR ID_CHAR*

//////////////////////////////////////////

Filters = (SPACE PIPE SPACE Filter)+

Filter = FilterName FilterArgs?

FilterName = ID_CHAR +

FilterArgs = LPAR SPACE Expression SPACE RPAR

//////////////////////////////////////////

Literal = NumberLiteral /
           ArrayLiteral /
           StringLiteral

NumberLiteral = (PLUS / MINUS)? [0-9]+ (DOT [0-9]+)?

ArrayLiteral = LSB Expression (SPACE COMMA SPACE Expression)* RSB

StringLiteral = ["] StringChar* ["]

StringChar = Escape / ![\"\n\\] .

Escape = SimpleEscape
       / OctalEscape
       / HexEscape

SimpleEscape = '\\' ['\"?\\abfnrtv]
OctalEscape  = '\\' [0-7][0-7]?[0-7]?
HexEscape    = '\\x' HexDigit+
HexDigit        = [a-f] / [A-F] / [0-9]

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
