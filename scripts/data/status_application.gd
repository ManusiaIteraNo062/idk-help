extends Resource
class_name StatusApplication
## "Apply this status" - one entry in a Move's `inflicts` (on every hit that
## connects, to the target) or `grants_self` (once per use, to the user).

@export var kind: StatusDefs.Kind = StatusDefs.Kind.GLOOP
@export var stacks: int = 1
## 0 = use the status's default duration from StatusDefs.
@export var duration: int = 0
@export var magnitude: int = 0

static func make(p_kind: StatusDefs.Kind, p_stacks: int = 1) -> StatusApplication:
	var a := StatusApplication.new()
	a.kind = p_kind
	a.stacks = p_stacks
	return a
