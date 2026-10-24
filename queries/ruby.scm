; sigil: parameters get kind parameter (upstream: var).
(method_parameters
  (identifier) @local.definition.parameter)

(lambda_parameters
  (identifier) @local.definition.parameter)

(block_parameters
  (identifier) @local.definition.parameter)

(optional_parameter
  name: (identifier) @local.definition.parameter)

(keyword_parameter
  name: (identifier) @local.definition.parameter)

(splat_parameter
  (identifier) @local.definition.parameter)

(hash_splat_parameter
  (identifier) @local.definition.parameter)

(block_parameter
  name: (identifier) @local.definition.parameter)

; `@x` is a field of the object, like `self.x`: assigned in one method, used in others.
(assignment
  left: (instance_variable) @local.definition.field)

(instance_variable) @local.member
