; sigil: upstream defines `l:x` / `g:x` as the whole scoped_identifier but references only the
; bare identifier, so scoped variables never matched their uses.
(scoped_identifier) @local.reference

(for_loop
  variable: [
    (scoped_identifier)
    (identifier)
  ] @local.definition.var)

; `let g:x` / `let s:x` inside a function still defines the script-level variable.
(let_statement
  (scoped_identifier
    (scope) @_scope) @local.definition.var
  (#any-of? @_scope "g:" "s:")
  (#set! definition.var.scope "parent"))
