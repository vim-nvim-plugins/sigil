; sigil: upstream marks every definition bare (@local.definition), so variables could not be
; told from procedures and types. Kinds for the ones the panel shows:
(declArg
  name: (identifier) @local.definition.parameter)

(declVar
  name: (identifier) @local.definition.var)

(declConst
  name: (identifier) @local.definition.constant)

(exceptionHandler
  variable: (identifier) @local.definition.var)
