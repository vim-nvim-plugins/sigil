#!/bin/sh
# run.sh — golden tests: for each tests/<lang>/sample.*, bin/sigil's output must equal expected.txt.
#   make test            all languages
#   UPDATE=1 make test   rewrite expected.txt from the current output (review the diff before committing)
cd "$(dirname "$0")/.." || exit 1
fail=0
for d in tests/*/; do
	lang=$(basename "$d")
	for f in "$d"sample.*; do
		out=$(./bin/sigil "$lang" "$f" 2>&1)
		if [ "${UPDATE:-0}" = 1 ]; then
			printf '%s\n' "$out" > "$d/expected.txt"
			[ -f "$d/expected-scopes.txt" ] && ./bin/sigil --scopes "$lang" "$f" > "$d/expected-scopes.txt"
			continue
		fi
		if printf '%s\n' "$out" | diff -u "$d/expected.txt" - > /dev/null; then
			echo "ok    $lang"
		else
			echo "FAIL  $lang"; printf '%s\n' "$out" | diff -u "$d/expected.txt" - | sed 's/^/      /'; fail=1
		fi
		[ -f "$d/expected-scopes.txt" ] || continue
		out=$(./bin/sigil --scopes "$lang" "$f" 2>&1)
		if printf '%s\n' "$out" | diff -u "$d/expected-scopes.txt" - > /dev/null; then
			echo "ok    $lang --scopes"
		else
			echo "FAIL  $lang --scopes"; printf '%s\n' "$out" | diff -u "$d/expected-scopes.txt" - | sed 's/^/      /'; fail=1
		fi
	done
done
exit $fail
