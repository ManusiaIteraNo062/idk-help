extends RefCounted
class_name StatusInstance
## One status currently on one unit (runtime only, rebuilt every fight).

var kind: StatusDefs.Kind
var stacks: int = 0
var turns_left: int = 1    # StatusDefs.PERMANENT = whole fight
var magnitude: int = 0     # extra number some statuses carry (Strengthen = +Attack)
var fresh: bool = false    # buff given during the owner's own turn: skips that turn's end tick
