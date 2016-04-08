#!/bin/sh

out=./lib/jute.js
rm -f $out

echo "// Autogenerated file, don't change by hand" >> $out
echo "// Run build.sh from jute.js root to rebuild this file\n" >> $out

echo "(function () {" >> $out

cat ./src/grammar.pegjs | `npm bin`/pegjs -o size -e "var parser" >> $out
cat ./src/expression.coffee | coffee -c -s -b >> $out
cat ./src/jute.coffee | coffee -c -s -b >> $out

echo "}).call(this);" >> $out
