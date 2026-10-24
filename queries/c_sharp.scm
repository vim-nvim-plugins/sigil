; sigil: upstream only scopes blocks, so a method's parameters landed in the class and
; same-named parameters of different methods merged.
[
  (method_declaration)
  (constructor_declaration)
  (local_function_statement)
  (lambda_expression)
] @local.scope

; Class fields: upstream gives them kind var, so they showed as globals.
(field_declaration
  (variable_declaration
    (variable_declarator
      name: (identifier) @local.definition.field)))
