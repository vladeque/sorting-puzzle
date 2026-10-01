extends Control
class_name MainMenuStarterBundleBadge

## Main Menu Starter Bundle promotion drawn as a wooden shop sign hanging from a wall bracket on the
## right safe edge. The scene's IdleMotion player swings the sign and flicks the discount tag; it
## only runs while the badge is visible. The production menu owns eligibility and placement.

signal pressed

@onready var _button := %BadgeButton as Button
@onready var _discount_tag := %DiscountTag as Control
@onready var _discount_label := %DiscountLabel as Label
@onready var _idle_motion := %IdleMotion as AnimationPlayer


func _ready() -> void:
	_button.pressed.connect(pressed.emit)
	visibility_changed.connect(_sync_idle_motion)
	_sync_idle_motion()


## Shows the pinned tag only for a positive catalog discount, matching the offer modal's tag.
func set_discount_percent(percent: int) -> void:
	_discount_tag.visible = percent > 0
	_discount_label.text = "-%d%%" % percent


func _sync_idle_motion() -> void:
	if is_visible_in_tree():
		_idle_motion.play(&"idle")
	else:
		_idle_motion.pause()
