; sigil: upstream has no references at all, so no use was ever linked to its definition.
(simple_identifier) @local.reference

; `obj.name`: a member, not a use of a variable `name` (the grammar has no field names here).
(navigation_suffix
  (simple_identifier) @local.member)
