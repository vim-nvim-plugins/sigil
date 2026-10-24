; sigil: upstream marks plain parameters bare (@local.definition), so they never showed.
(required_parameter
  (identifier) @local.definition.parameter)

(optional_parameter
  (identifier) @local.definition.parameter)

; Class fields (the class body scope and `this.x` uses come from queries/ecma.scm).
(public_field_definition
  name: (property_identifier) @local.definition.field)
