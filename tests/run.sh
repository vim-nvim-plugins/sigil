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
			for m in scopes positions; do
				[ -f "$d/expected-$m.txt" ] && ./bin/sigil --$m "$lang" "$f" > "$d/expected-$m.txt"
			done
			continue
		fi
		if printf '%s\n' "$out" | diff -u "$d/expected.txt" - > /dev/null; then
			echo "ok    $lang"
		else
			echo "FAIL  $lang"; printf '%s\n' "$out" | diff -u "$d/expected.txt" - | sed 's/^/      /'; fail=1
		fi
		for m in scopes positions; do
			[ -f "$d/expected-$m.txt" ] || continue
			out=$(./bin/sigil --$m "$lang" "$f" 2>&1)
			if printf '%s\n' "$out" | diff -u "$d/expected-$m.txt" - > /dev/null; then
				echo "ok    $lang --$m"
			else
				echo "FAIL  $lang --$m"; printf '%s\n' "$out" | diff -u "$d/expected-$m.txt" - | sed 's/^/      /'; fail=1
			fi
		done
	done
done
exit $fail
