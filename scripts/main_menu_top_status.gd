extends HBoxContainer

const DEFAULT_CENTER_EXCLUSION_WIDTH := 80.0

@onready var _profile_widget := $ProfileWidget as Control
@onready var _coins_widget := $CoinsWidget as Control
@onready var _center_spacer := $Spacer02 as Control
@onready var _lives_widget := $LivesWidget as Control
@onready var _settings_widget := $SettingsWidget as Control


func set_center_exclusion_width(requested_width: float, available_width: float) -> float:
	var maximum_width := _get_maximum_center_exclusion_width(available_width)
	var target_width := minf(maxf(requested_width, DEFAULT_CENTER_EXCLUSION_WIDTH), maximum_width)
	var minimum_size := _center_spacer.custom_minimum_size
	minimum_size.x = target_width
	_center_spacer.custom_minimum_size = minimum_size
	return target_width


func _get_maximum_center_exclusion_width(available_width: float) -> float:
	var fixed_content_width := (
		_profile_widget.get_combined_minimum_size().x
		+ _coins_widget.get_combined_minimum_size().x
		+ _lives_widget.get_combined_minimum_size().x
		+ _settings_widget.get_combined_minimum_size().x
	)
	var separation_width := float(get_theme_constant("separation")) * float(maxi(get_child_count() - 1, 0))
	return maxf(available_width - fixed_content_width - separation_width, 0.0)
