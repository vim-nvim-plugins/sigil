---
name: sigil
description: Scope-aware variable lookup for 21 languages (Bash, C, C#, C++, Go, Java, JavaScript, Julia, Kotlin, Lua, OCaml, Pascal, PHP, Python, R, Ruby, Rust, TSX, TypeScript, Vim script, Zig). Use before renaming a variable, when finding every use of a variable, or to get a cheap map of a file's globals, locals, params and fields without reading the whole file.
---

# sigil

sigil parses a file with tree-sitter and resolves every use of a variable to the definition it belongs to, so a local `total` and a global `total` stay apart. Text search can't do that.

## Setup

The helper lives next to this file at `bin/sigil`. If it is missing, build it once from this directory:

```sh
make        # needs a C compiler, make, curl, tar; fetches pinned grammars, ~40 s the first time
```

## Use

```sh
bin/sigil <language|extension> <file>            # one line per variable
bin/sigil --scopes <language|extension> <file>   # one line per variable per scope
bin/sigil --list                                 # languages and the names/extensions each accepts
```

Output, one variable per line:

```
context|name|line,line,...                 (default)
context|name|line,line,...|first-last      (--scopes: the scope's line range)
```

- `context` is `global`, `local`, `param` or `field`.
- The lines are every line the variable is defined or used on. Comments and strings are never counted.
- The default merges same-named variables of the same context from different scopes into one row (built for a display panel). **Use `--scopes` whenever you will edit**: each row is exactly one variable.
- Exit 2 = no parser for that language. Exit 1 = error on stderr.

## Renaming a variable safely

1. `bin/sigil --scopes <lang> <file>` and pick the row for the variable you mean (match its context and the scope range that contains the line you care about).
2. Edit only the listed lines, and on each line only the whole-word occurrences of the name.
3. Check that another row with the same name has no line in common with yours. If one does, both variables appear on that line: edit it by hand, looking at which occurrence is which.
4. Re-run sigil afterwards: the old name should be gone from that scope and the new name should list the same lines.

Before choosing the new name, check that it isn't already a row in an enclosing scope. Reusing it would shadow, or be shadowed by, the other variable.

## In Vim

The same directory is a Vim plugin (`:Sigil` opens a panel of these variables). See `README.md`.
