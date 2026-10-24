; sigil: in PHP the first assignment declares a variable; upstream has no assignment pattern.
(assignment_expression
  left: (variable_name
    (name) @local.definition.var))

; `foreach ($xs as $x)`: upstream only covers the `$k => $v` form.
(foreach_statement
  (variable_name
    (name) @local.definition.var)
  .
  body: (_))

; Parameters: upstream gives them kind var.
(simple_parameter
  (variable_name
    (name) @local.definition.parameter))
