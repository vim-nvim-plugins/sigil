name="x"
greet() {
  local who=$1
  echo "$name $who"
}
for f in a b; do greet "$f"; done
