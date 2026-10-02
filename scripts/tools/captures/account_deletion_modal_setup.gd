extends RefCounted

## GAME-012: opens Support and the account-deletion modal over the production Main Menu, then
## presents one modal view for responsive review. Pick the view with
## `$env:SORTING_PUZZLE_CAPTURE_DELETION_VIEW` (default `account_confirm`); see VIEWS for names.
##
##   $env:SORTING_PUZZLE_CAPTURE_DELETION_VIEW = 'unconfirmed'
##   & .\scripts\tools\capture_ui.ps1 -Scene scenes/main_menu.tscn -Name deletion_unconfirmed `
##       -Setup scripts/tools/captures/account_deletion_modal_setup.gd

const VIEW_ENVIRONMENT_VARIABLE := "SORTING_PUZZLE_CAPTURE_DELETION_VIEW"
const DEFAULT_VIEW := "account_confirm"
const REFERENCE := {"operation_id": "8f14e45f-ceea-467e-a9b2-1d5c3e2f0a7b"}
const RECEIPT := {"complete_by": "2026-11-01T12:00:00.000Z"}
## view name -> [state, availability, failure shown as this modal's own attempt]
const VIEWS := {
	"account_confirm": [{"phase": "idle"}, {"kind": "account"}, false],
	"local_confirm": [{"phase": "idle"}, {"kind": "local_data"}, false],
	"progress": [{"phase": "submitting", "kind": "account", "busy": true}, {}, false],
	"offline": [{"phase": "idle", "failure": {"reason": "offline"}}, {"kind": "account"}, true],
	"retry_pending": [{"phase": "retry_pending", "kind": "account", "support_reference": REFERENCE}, {}, false],
	"unconfirmed": [{"phase": "unconfirmed", "kind": "account", "support_reference": REFERENCE}, {}, false],
	"cleanup_failed": [{"phase": "cleaning", "kind": "account", "receipt": RECEIPT}, {}, false],
	"accepted": [{"phase": "ready", "kind": "account", "receipt": RECEIPT}, {}, false],
	"local_deleted": [{"phase": "ready", "kind": "local_data"}, {}, false],
	"unavailable": [{"phase": "idle"}, {"kind": "unavailable", "reason": "not_configured"}, false],
}


func setup(scene_root: Node, tree: SceneTree) -> void:
	scene_root.call("_open_support_screen")
	scene_root.call("_open_account_deletion_modal")
	await tree.create_timer(0.6).timeout
	var modal := scene_root.get("_account_deletion_modal") as Control
	if modal == null:
		push_error("account_deletion_modal_setup could not open the modal.")
		return
	var view_name := OS.get_environment(VIEW_ENVIRONMENT_VARIABLE)
	if not VIEWS.has(view_name):
		view_name = DEFAULT_VIEW
	var view: Array = VIEWS[view_name]
	modal.set("_attempted", bool(view[2]))
	modal.call("present", view[0], view[1])
	for _frame in range(3):
		await tree.process_frame
