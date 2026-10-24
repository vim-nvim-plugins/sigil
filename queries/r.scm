; sigil: upstream marks every definition bare (@local.definition). Kinds:
(parameter
  name: (identifier) @local.definition.parameter)

(binary_operator
  lhs: (identifier) @local.definition.var
  operator: "<-")

(binary_operator
  lhs: (identifier) @local.definition.var
  operator: "=")

(binary_operator
  operator: "->"
  rhs: (identifier) @local.definition.var)

(for_statement
  variable: (identifier) @local.definition.var)
