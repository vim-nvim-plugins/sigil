# Sigil
## Overview
A clean little vim plugin that scans the active file and lists every variable in a separate panel.
<p align="center"><img src="./assets/wide.png" alt="Sigil-Panel" width="600" height="200" /></p>
<p align="center"><img src="./assets/full.png" alt="Sigil-Full" width="600" height="400" /></p>

- **Display Scope**: every line each variable occurs on — definitions and uses
- **Features**: Jump, cycle, filter, rename across 21 languages
- **One parser for everything** — [tree-sitter](https://tree-sitter.github.io) with each language's scope rules, so every language gets the same treatment: `global`, `local`, `param`, `field`, and uses resolved to the right definition (a local `x` and a global `x` stay apart)

Languages: Bash, C, C#, C++, Go, Java, JavaScript (+JSX), Julia, Kotlin, Lua, OCaml, Pascal, PHP, Python, R, Ruby, Rust, TSX, TypeScript, Vim script, Zig. `bin/sigil --list` shows the filetypes and extensions each one covers.

## Requirements
- [vim] (obviously)
- A C compiler, `make`, `curl` and `tar` — to build the helper once (it fetches the pinned tree-sitter grammars on the first build)

No Python, no ctags.

## Installation
<details>
<summary><b>Vim-Plug</b></summary>

#### Github 
```vim
Plug 'vim-nvim-plugins/sigil', { 'do': 'make' }
```
#### Local
```vim
Plug '~/.vim/plugged/sigil', { 'do': 'make' }
```
</details>

<details>
<summary><b>Manual</b></summary>

#### Clone and build
```bash
git clone https://github.com/vim-nvim-plugins/sigil ~/.vim/bundle/sigil
cd ~/.vim/bundle/sigil && make
```

#### Edit .vimrc
```vim
set runtimepath+=~/.vim/bundle/sigil
```
</details>

Update anytime with `:PlugUpdate sigil` (rebuilds through the `do` hook).

## Outside Vim (agents, scripts)
The same repo is an agent skill: `SKILL.md` at the root tells an AI assistant how to use the helper.

```sh
git clone https://github.com/vim-nvim-plugins/sigil ~/.claude/skills/sigil
cd ~/.claude/skills/sigil && make
```

Or call the helper directly:

```sh
bin/sigil python app.py              # context|name|line,line,...
bin/sigil --scopes python app.py     # one row per variable per scope, plus the scope's line range
```

`--scopes` never merges same-named variables from different scopes, so it is the one to use before an edit such as a rename.

## Configuration

```vim
let g:sigil_height = 15      " panel height (default: 12)
let g:sigil_binary = '~/bin/sigil'   " helper path (default: bin/sigil inside the plugin)
```

### Adding a language
One line in `grammars.txt` (grammar repo + revision + filetypes), then `make`. The language needs a `locals.scm` in [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter/tree/main/runtime/queries); add a `tests/<lang>/` sample and run `make test`.

## Usage

| Key / Command  | Action |
|----------------|--------|
| `<leader>s`    | Open / refresh panel |
| `<leader>n`    | Next occurrence of word under cursor |
| `<leader>p`    | Previous occurrence |
| `<leader>r`    | Rename word under cursor |
| `:Sigil`       | Open panel |
| `:SigilX`     | Close panel |
| `:SigilR` 	 | Rename under cursor |

**Inside the panel:**

| Key       | Action |
|-----------|--------|
| `Enter`   | Jump to first occurrence, close panel |
| `o`       | Jump, keep panel open |
| `n` / `p` | Cycle occurrences |
| `r`       | Rename selected variable |
| `/`       | Filter |
| `Esc`     | Clear filter |
| `q`       | Close |

## Change Log

### v0.1.3 (Latest)
One parsing path for every language.
- New helper `bin/sigil` (C, built with `make`): tree-sitter + each language's locals query from nvim-treesitter. Replaces both the Python AST parser and Universal Ctags
- Shows every use of a variable, not only where it is defined, and keeps same-named variables in different scopes apart
- Contexts are now `global`, `local`, `param`, `field` in every language (Python's `loop` / `comp` / `except` are `local`)
- 21 languages. Dropped: Perl, SQL, Fortran (no scope rules upstream yet), Swift (grammar needs generating)
- Removed `g:sigil_python` and `g:sigil_script`; new `g:sigil_binary`
- `bin/sigil --scopes`: one row per variable per scope, with the scope's line range
- `SKILL.md`: the repo doubles as an agent skill
- Golden tests: `make test`

***v0.1.2***
Universal Ctags detection, PNG screenshots, README fixes.

## Credits
`make` builds in [tree-sitter](https://github.com/tree-sitter/tree-sitter) (MIT), the grammars listed in `grammars.txt` (each under its own license, MIT for most) and the `locals.scm` queries from [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) (Apache-2.0). None of it is stored in this repo; it is fetched at the pinned revisions on build.

## Contributing
If you share the belief that simplicity empowers creativity, feel free to contribute.

#### Contribution is welcome in the form of:
- Forking this repo
- Submitting a Pull Request
- Bug reports and feature requests
Ensure your code follows the existing style.

## Thank you for your attention.
This project started out as self-solving a specific need, and evolved into something I think could actually be useful. If you hit any issues, feel free to open one. Pull requests, suggestions, and fixes I don't have to make myself are welcome. Complaints go to /dev/null.
