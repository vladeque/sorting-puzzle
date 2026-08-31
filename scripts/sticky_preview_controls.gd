extends MarginContainer

signal variant_changed(variant: String)
signal reset_requested


func _ready() -> void:
	%Pink.pressed.connect(func() -> void: variant_changed.emit("pink"))
	%Amber.pressed.connect(func() -> void: variant_changed.emit("amber"))
	%Both.pressed.connect(func() -> void: variant_changed.emit("both"))
	%Reset.pressed.connect(func() -> void: reset_requested.emit())


func set_variant(variant: String) -> void:
	%Pink.set_pressed_no_signal(variant == "pink")
	%Amber.set_pressed_no_signal(variant == "amber")
	%Both.set_pressed_no_signal(variant == "both")


func apply_safe_layout(safe_margins: Vector4) -> void:
	offset_left = safe_margins.x
	offset_right = -safe_margins.z
	offset_top = -90.0 - safe_margins.w
	offset_bottom = -safe_margins.w
