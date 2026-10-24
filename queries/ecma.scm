; sigil (JavaScript, TypeScript, TSX): upstream never captures `obj.x` names and the class
; body is no scope, so a class's fields had no uses. `obj.x` is a member (the grammar's
; `property` field); sigil links it to a field only inside the class that defines it.
(member_expression
  property: (property_identifier) @local.reference)

(class_body) @local.scope
