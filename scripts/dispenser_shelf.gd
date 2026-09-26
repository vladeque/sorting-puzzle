class_name DispenserShelf
extends Shelf

## A source-only shelf: one item slot, 2-4 stacked layers, and an integrated segmented stock readout
## showing how many items are still on it, the one on display included. The player can take from it
## but never place onto it, so its authored queue is the only route its items take to the board.
##
## The queue is not a new system. `Shelf`'s back-layer machinery already models "one hidden item per
## layer, promoted when the front layer empties", and with a single front slot that is exactly a
## dispenser. This type only narrows the cell and refuses the interactions that would rewrite the
## queue -- see `scripts/level.gd` for how those refusals are read.

## Named apart from `Shelf`'s own `BASE_CELL_SIZE`/`SLOT_COUNT` because GDScript does not let a
## subclass reuse a parent constant's name.
const DISPENSER_BASE_CELL_SIZE := Vector2(96, 135)
const DISPENSER_SLOT_COUNT := 1
const MIN_LAYER_COUNT := 2
const MAX_LAYER_COUNT := 4

## The item protrudes above the short cradle while the stock rail extends slightly beyond the wood.
## These drawing bounds stay separate from the 96px packing cell so mixed rows do not become wider.
const VISUAL_BOUNDS := Rect2(-52.0, -70.0, 104.0, 134.0)

## The item stands tall in a cradle packed directly under the row above, and a locked shelf there
## hangs its padlock to the bottom of that shelf, so the item's tip (a pump nozzle, a unicorn horn)
## reached up under the padlock and was covered by it. Lifting the item's body draws it over that
## lock overlay (`scenes/ui/shelf_lock_overlay.tscn` reaches z 52) instead of shrinking the item.
##
## Everything that has to stay in front of the body lifts by the same amount in
## `scenes/dispenser_shelf.tscn`: `LayerIndicator` is authored at z 8 + this, so the stock badge still
## sits over the item's base, and `LockedOverlay` at 75 so a locked dispenser still covers its own
## item. `tests/gameplay/test_dispenser_item_clears_lock_above.gd` holds the three together.
const ITEM_BODY_Z_LIFT := 50

const LAYER_INDICATOR_NODE := "LayerIndicator"

var _capacity := 0
var _remaining := 0


func _ready() -> void:
	super._ready()
	_refresh_indicator(false)


func get_base_cell_size() -> Vector2:
	return DISPENSER_BASE_CELL_SIZE


func get_visual_bounds() -> Rect2:
	return VISUAL_BOUNDS


func get_slot_count() -> int:
	return DISPENSER_SLOT_COUNT


func accepts_dropped_items() -> bool:
	return false


func forms_triples() -> bool:
	return false


func allows_ability_modification() -> bool:
	return false


## One item on display at a time. The indicator already says how many are left, and a dimmed preview
## of the next item reads as a second item sitting on a shelf that only has one slot -- on a cell
## this narrow it also spills past the frame onto the neighbouring shelf.
func shows_back_layer_preview() -> bool:
	return false


func get_item_body_z_lift() -> int:
	return ITEM_BODY_Z_LIFT


## Row placement paints the shared left/middle/right edges that let neighbouring cells butt against
## each other. A dispenser carries its own complete frame, so it stays neutral wherever it sits.
func set_row_placement(_placement: String) -> void:
	super.set_row_placement(ROW_PLACEMENT_MIDDLE)


func set_top_ceiling_cap_visible(_should_show: bool) -> void:
	# The dispenser is intentionally an open cradle, so it never grows the standard shelf's top cap.
	super.set_top_ceiling_cap_visible(false)


func set_visual_variant(visual_variant: String) -> void:
	if visual_variant == VISUAL_VARIANT_FLOOR_ONLY:
		push_warning("%s is a dispenser and has no floor_only variant. Using full shelf." % name)

	super.set_visual_variant(VISUAL_VARIANT_FULL)


## Sets the readout's total capacity and fills it completely. Called once per shelf from the level
## config, where capacity is the authored item count.
func set_capacity(capacity: int) -> void:
	_capacity = maxi(capacity, 0)
	_remaining = _capacity
	_refresh_indicator(false)


func get_capacity() -> int:
	return _capacity


func get_remaining_count() -> int:
	return _remaining


## Records that one item left this shelf for good.
##
## The count is authoritative state rather than something recomputed from live nodes, because a
## carried item is reparented out of its slot for the length of the drag: a shelf that counted its
## own children would read as already emptied the moment the player picked the item up, and would
## have to count back up again if they dropped it somewhere invalid. `scripts/level.gd` calls this
## exactly once per committed move off the shelf instead.
func take_one() -> void:
	set_remaining_count(_remaining - 1)


func set_remaining_count(remaining: int) -> void:
	var next_remaining := clampi(remaining, 0, _capacity)
	if next_remaining == _remaining:
		return

	_remaining = next_remaining
	_refresh_indicator(true)


func _refresh_indicator(should_animate: bool) -> void:
	var indicator := get_node_or_null(LAYER_INDICATOR_NODE) as ShelfLayerIndicator
	if indicator == null:
		return

	if should_animate:
		indicator.set_remaining(_remaining)
	else:
		indicator.configure(_capacity, _remaining)
