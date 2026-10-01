# Starter Bundle main-menu promotion plan

Status: **Implemented for the current mock purchase provider (2026-09-26).** Platform billing and
backend-verified purchase claims remain the production release gate described below.

## Goal and product rule

When the Starter Bundle is currently eligible and has a display price, show a circular promotion on
the production Main Menu. Tapping it opens a focused offer modal with the current bundle contents
and a priced Buy action. The Starter Bundle is a one-time offer in both local and backend catalog
modes. The promotion disappears after a successful purchase or when eligibility can no longer be
confirmed.

The production Main Menu is `scenes/main_menu.tscn` with
`scripts/production_main_menu.gd`; `scripts/main_menu.gd` belongs to the developer menu. Both
catalog modes expose the internal offer id `starter_bundle` through `StoreService.load_catalog()`.
Use that exact id and require `type == "bundle"`; do not select the first bundle or compare platform
product ids, which differ between catalog modes.

## UI design

| Element | Design and behavior |
| --- | --- |
| Menu badge | A wooden shop sign (142x164 logical pixels with its bracket) hanging by two chains from a wrought-iron wall bracket, in the open sky opposite the reward chest, below the top status row. It echoes the storefront's bracket clock sign. The board shows the tier 7 coin bag and a painted `STARTER` label, and the red discount tag pinned to its corner shows `-N%` only when the offer supplies `discount_percent`. The sign rocks gently and the tag flicks once per loop while it is visible. The whole rect is tappable, and a press shrinks the sign but not the bracket. No price text on the small badge. Chosen 2026-09-30 from four studied directions; it replaced the first circular coral button, whose red coin bag blended into its red disc. |
| Placement | The bracket's wall plate mounts on the safe right edge itself (no side margin), and the sign's top sits 30 px above the reward chest's top so the hanging board lines up with the chest art. Preserve a gap from the chest and top status controls. Recompute on viewport and safe-area changes; if the chest and badge cannot sit side by side, put the badge below the chest while keeping it above the campaign button. |
| Modal | A separate centered scene using `gameplay_modal_shell.tscn` in the "shop window" layout (chosen 2026-09-29 from four studied directions): dimmed background, `STARTER BUNDLE` awning title, the coin pile large on a sunburst stage with a ribbon carrying the coin amount and a `ONE-TIME OFFER` pill, then a centered row of the positive-count boosters in the level ability bar's dark sockets with `×N` badges and names. Show quantities from the loaded offer, so the local four-ability bundle and the current backend three-ability bundle are both accurate. |
| Price and discount | Put `Buy for {store.formatted_price}` in the primary button, with the crossed-out compare price as a smaller line above it. Pin the existing red discount tag with `X% OFF` to the stage's corner. Show the compare price and tag only when the loaded offer supplies those fields; neither price nor reward amounts are hardcoded in the modal. |
| Interaction states | Close X and system Back dismiss the modal. During a purchase, disable Buy and closing (the close button dims), label the action `Purchasing…`, and ignore repeated taps. Status messages appear in a pill on the content region's bottom edge, just above the button: neutral while checking/purchasing, red for a failure with Retry/Close, and green for success, where the ribbon also turns green (`+1,000 COINS`), the booster chips show checks, and the action becomes Continue. Do not leave a second modal stacked behind it. |

The visual reuses existing art (coin pile tier 7, ability icons, `discount_badge_pinned.png`, green
button). The sunburst is a shader (`assets/shaders/offer_sunburst.gdshader`), the ribbon is drawn
by `offer_ribbon_banner.gd`, and the menu sign's bracket, chains, and wood board are drawn by
`shop_sign_bracket.gd` and `shop_sign_board.gd`, so no generated raster assets are needed.
Keep a clear tap target and readable quantities when the shell scales to a 540x960 viewport. A
compact/scrollable content area should protect the price action on short screens.

## Data and purchase behavior

1. On Main Menu entry, hide the badge until `StoreService.load_catalog()` succeeds. Show it only
   when the returned `starter_bundle` is a priced bundle and has not been claimed. Refresh when
   returning to the Main Menu and before starting a purchase. Use a request serial or equivalent
   guard so a late response cannot restore a stale badge.
2. In local catalog mode, add `purchase_limit: 1` and `limit_period: "lifetime"` to the Starter
   Bundle in `configs/shop_catalog.json`. `StoreService` already filters and rechecks local offers
   with those fields using `PlayerProgress.has_purchased_shop_offer()`.
3. In backend catalog mode, trust only the eligible offers from live `GET /v1/catalog` for this
   promotion. Hide the badge when the load is unavailable or returns only the offline cache:
   cached eligibility may be stale. The modal must recheck a live offer and its price before Buy.
4. The current backend catalog source still executes **mock** purchases and records grants only in
   `PlayerProgress`; the backend does not learn about that mock transaction. While that provider is
   in use, also suppress an already locally claimed `starter_bundle` after a purchase, including
   on later backend catalog loads, and recheck this immediately before provider purchase. This
   local rule may narrow visibility but must never make a server-ineligible offer visible.
5. Extract the provider-purchase plus `PlayerProgress.apply_shop_purchase()` sequence currently in
   `scripts/shop_screen.gd` into a focused shared purchase flow. The Shop and Main Menu modal call
   the same flow, receive the same success/error/grant result, and play success feedback only for a
   newly applied grant. The Main Menu then refreshes coin balance and offer eligibility, hiding the
   badge on success. Keep the offer modal's view wiring in its own script; the Main Menu only loads
   the offer, initiates the flow, and passes state/result to the modal.

The mock path supports development and UI verification. A released one-time purchase across
reinstalls, devices, and account merges requires platform billing, backend purchase intent and
verification, and the server's lifetime claim. The backend already defines that eligibility rule;
the present client `StoreService` does not execute that production purchase flow. Treat the real
billing integration as a release gate for this Buy action, not as a property provided by the mock
grant or local save.

## Implementation sequence

1. Add the local Starter Bundle limit fields and focused catalog tests for available, purchased,
   unpriced, missing, malformed, cached, and backend-ineligible cases.
2. Add `scenes/ui/main_menu_starter_bundle_badge.tscn` and its focused script, plus
   `scenes/ui/starter_bundle_offer_modal.tscn` and its focused script. Bind all visible rewards and
   price data from the offer dictionary. Reuse the existing UI theme/art resources.
3. Add the shared purchase flow, move the Shop's current purchase/grant sequence to it, and connect
   the Main Menu modal. Guard duplicate taps and stale async results; keep current Shop behavior.
4. Wire badge loading, positioning, modal stacking, Back handling, purchase result, and balance
   refresh in `scripts/production_main_menu.gd` and `scenes/main_menu.tscn`. Update `docs/SCENES.md`,
   `docs/CONFIGS.md`, and `docs/PROJECT_MAP.md` when implementing the feature.

## Acceptance checks

- Badge appears only for a priced, eligible Starter Bundle; no badge appears for a missing offer,
  failed live backend load, cached-only backend load, or a claimed Starter Bundle.
- Modal shows the exact current catalog rewards and formatted regional price. It omits zero-count
  abilities and absent discount/compare-price data.
- Buy is applied at most once per tap sequence. A successful local/mock purchase updates balances,
  gives the shown rewards once, removes the badge, and prevents the second local/mock purchase even
  after returning to the menu. An error leaves the player able to retry without a grant.
- Shop purchasing continues to work after the flow extraction. System Back closes the offer modal
  before acting on underlying Main Menu overlays.
- Capture the menu and open modal at 540x960, 720x1280, 1080x1920, 1080x2400, and a squarer
  portrait tablet size. Inspect the actual screenshots for chest/badge separation, safe-area
  clearance, complete reward visibility, and an unobstructed Buy/Close action.

## Existing visual baseline

The menu was captured before implementation at 540x960, 720x1280, and 1080x2400. The reward
chest occupies the left space below the status row, while open sky remains on the right. Captures
are in git-ignored `tmp/ui_capture/starter_bundle_plan_menu_*` for local design reference.
