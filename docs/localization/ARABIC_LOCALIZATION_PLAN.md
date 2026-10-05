# Arabic localization implementation plan

Prepared October 5, 2026. Investigated against Godot **4.6.2** and game commit
`10823f8` (`Add reviewed Italian localization and language selection`).

This is an implementation plan. Arabic is not yet enabled in the shipping locale allowlist,
and no Arabic runtime catalog, permanent font resources or scene changes are part of this commit.

## Source and decisions

The reviewed source is archived verbatim in [ARABIC_TRANSLATIONS.md](ARABIC_TRANSLATIONS.md),
copied from `Sorting Puzzle — Arabic Translations — Revised.md` supplied by the owner.
Its SHA-256 is `F9CF21E2D45439E63F585F86D9542A4D87C0874C4288993C01CC7178AFC1B567`.

The document contains all **251 inventory keys**, **42 plural variants** across seven entries,
and four supplementary email labels. Thirteen main translations were refined relative to the
earlier Arabic draft; the glossary's dispenser term and leaderboard tooltip plural wording were
also refined. Import from this revised source. Preserve its wording, placeholders, line breaks
and the explicit singular/dual forms with parenthesized counts.

Owner-confirmed decision: ordinary Arabic counts, ranks, timers and dates keep **0–9**.
Store prices keep the provider's supplied string. Protected `AD`, `OFF`, discount percentages,
the game brand, reference values and player names keep their existing content.

The proposed typography is **Baloo Bhaijaan 2 for headings and short actions**, with
**Noto Sans Arabic for reading text and editing**. A Noto-only alternative was also previewed;
the owner's font preference is pending. Numeric Gregorian dates in day/month/year order and
the missing empty-leaderboard caption are proposed supplementary copy to review in phase 1.
The revised document's translator and integration notes are source context; the work scope
comes from the owner's request to investigate and plan.

## Findings

The current localization system already has stable-key and English-alias gettext catalogs,
plural-aware presentation, local-only locale persistence and live text refreshes. English,
Russian, Ukrainian and Italian catalogs are registered. Thirteen languages are selectable.
Adding Arabic can reuse this system and make the picker contain fourteen entries.

Godot supports Arabic shaping, bidirectional text and automatic Control mirroring. It mirrors
anchors and container child order and swaps ordinary left/right text alignment; centered
titles stay centered. Its coordinate system and non-UI nodes are unaffected. This is why the
work should retain the existing 2D puzzle geometry while auditing UI components for direction.
See [Godot 4.6 internationalization](https://docs.godotengine.org/en/4.6/tutorials/i18n/internationalizing_games.html#bidirectional-text-and-ui-mirroring)
and [Control layout direction](https://docs.godotengine.org/en/4.6/classes/class_control.html#class-control-property-layout-direction).

An isolated local engine probe confirmed bidirectional layout and complex-shaping capability.
With Arabic selected, existing navigation, leaderboard rows, the gameplay HUD and ability
buttons mirrored without source edits. At a 720-wide viewport, the Shop tab moved from
`x=0` to `x=480`, the leaderboard rank slot from `x=14` to `x=640`, and the HUD Pause button
from `x=600` to `x=30`. These are geometry observations, not full Arabic gameplay verification.

Both bundled fonts, DynaPuff and Nunito, lack most of the sampled Arabic letters and combining
marks. Desktop system fallback can obscure that omission. A bundled Arabic fallback is required
for predictable mobile rendering and for Arabic names/native language labels in other locales.

Rendered investigation previews confirmed specific problems:

| Finding | Evidence | Implementation owner |
| --- | --- | --- |
| FAQ questions mirror, but answer paragraphs remain left aligned. | Support captures at 540×960 and 720×1280. A temporary explicit right alignment produced correct paragraph alignment at 540×960. | `scripts/support_faq_item.gd`, `scenes/ui/support_faq_item.tscn` |
| Chapter progress reverses the two values. | `0 / 20` appears as `20 / 0` in both chapter captures. | `scenes/ui/chapter_cover_card.tscn` |
| The starter sign moves left, but its drawn bracket still mounts on its right. | Home preview at 540×960. | `scripts/shop_sign_bracket.gd`, starter badge owner |
| The chapter carousel retains LTR movement rules. | `horizontal_pager.gd` uses positive page positions, negative next-page track movement and left-swipe advancement. An RTL right swipe from page 0 remained on page 0. | `scripts/horizontal_pager.gd`, `scenes/ui/horizontal_pager.tscn` |
| Arabic font metrics increase reading-text height. | The deletion confirmation at 540×960 needs scrolling to reach the final retained-records/deadline paragraph. | Shared typography, deletion modal's existing scroll area |

The sampled shelf-lock, dispenser and layer-count labels remained attached to their Node2D
objects when direction changed. The lock's `AD` label showed a small horizontal shift; review
its plate alignment and hit rectangle explicitly. Board art, shelves, slots, item coordinates
and dispenser physics require no locale-dependent reversal.

Local evidence remains in the git-ignored `tmp/` directory:

- `tmp/translations_ar/investigation_report.json`: engine/font/geometry and swipe observations.
- `tmp/ui_capture/arabic_investigation_menu_540x960.png`: Baloo heading/Noto body experiment.
- `tmp/ui_capture/arabic_investigation_menu_noto_540x960.png`: Noto-only experiment.
- `tmp/ui_capture/arabic_investigation_support_contact_sheet.png`: initial FAQ alignment.
- `tmp/ui_capture/arabic_investigation_support_aligned_540x960.png`: explicit alignment experiment.
- `tmp/ui_capture/arabic_investigation_chapters_contact_sheet.png`: reversed progress values.
- `tmp/ui_capture/arabic_investigation_deletion_540x960.png`: modal text-height/scrolling review.

The previews used a temporary in-memory translation and font setup in isolated test projects.
The first chapter capture reported incomplete prototype plural registration; that preview
establishes layout observations only. The corrected setup subsequently rendered Support and
Deletion without those errors. No full Arabic catalog/import/export test has run, and taller
or tablet resolutions have not been reviewed for Arabic yet.

## Direction policy

| Content | Planned behavior |
| --- | --- |
| Menus, settings, shop, profile and leaderboard | Inherit application-locale Control mirroring. Logical leading edges move right in Arabic. |
| Ordinary paragraph text | Arabic text direction and leading/right alignment. Apply an explicit RTL/LTR alignment choice for FAQ RichTextLabel paragraphs. |
| Centered headings, action captions and result banners | Keep their existing centered alignment and fit the shaped Arabic text. |
| Puzzle board, slots, item art, movement and hit coordinates | Preserve the existing physical coordinate system and logical identifiers. |
| Timers, ranks, fractions and isolated numeric quantities | Keep 0–9; pin the text run to LTR where punctuation/order needs it. Its containing widget may still mirror. |
| `AD`, percentage + `OFF`, standalone discount signs | Keep their content and numeric order; use explicit LTR text/group direction where required. |
| Player names and editable name text | Preserve content and use automatic text direction for Arabic, Latin and mixed names. Disable automatic translation as today. |
| Store prices | Preserve provider text, including its existing direction marks; use content-sensitive text direction and isolate a price when embedded in prose. |
| Emails, IDs, dates and multiplier tokens inside Arabic prose | Isolate the relevant run at presentation time if the native BiDi result is wrong. Keep raw values and gettext copy unchanged. |
| Back/next arrows and custom directional art | Follow the logical navigation direction; verify the rendered arrow because some text symbols already mirror. |

Avoid a blanket conversion of every label to right alignment: normal Control alignment already
mirrors, and centered UI has a deliberate layout. Likewise, avoid reversing child arrays,
negatively scaling a whole screen, or globally forcing RTL for other languages.

## Ordered implementation batches

### 1. Catalog, locale registration and source fixtures

Create `assets/translations/ar.po`, register it in `project.godot`, and add
`{"locale": "ar", "label": "العربية"}` plus Arabic device-locale mapping in
`scripts/localization/locale_catalog.gd`. Cover `ar`, `ar_SA`, `ar_EG` and other regional Arabic
locales while keeping the saved release code `ar`. `LocaleManager` remains the only production
entry point for changing language; locale remains a local preference.

Import stable keys and English scene/config aliases using the same convention as Italian.
Retain existing disambiguation of Continue/resume and Retry/reload. Decode Markdown line-break
markers once before serializing gettext escapes. Do not uppercase or revise the Arabic source.
Arabic has no case distinction; existing uppercase English aliases still need catalog coverage.

Use six gettext plural forms in this order: `zero`, `one`, `two`, `few`, `many`, `other`.
For nonnegative integer counts, the planned header is:

```text
nplurals=6; plural=(n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 && n%100<=99 ? 4 : 5);
```

Import all seven reviewed plural tables. Select row/reward plurals using stars/coins, not rank.
Existing claimed booster chips format `booster_chip.claimed` with `tr()` and select product
names through `GameText.counted_booster()`. Supply six identical reviewed names for each of
the four `booster.counted` contexts; Arabic product names remain uninflected. The chip's six
template variants are also identical. No quantity-dependent rename of those product names is needed.

Archive a machine-readable reviewed fixture at `tests/localization/arabic_inventory.json`.
Map the four email labels to the existing supplementary keys. Review an Arabic equivalent of
`No scores yet`, and use a proposed numeric Gregorian deadline such as `2/11/2026` through an
Arabic branch in `GameText.format_date()`. This avoids introducing twelve unreviewed regional
month names. Keep grouping/number output in 0–9 and do not alter store price formatting.

Deliverable: imported catalog resolves every reviewed key and scene alias, all plural
boundaries pass, the native-name picker displays Arabic under English as well as Arabic,
and a selected language persists without entering authoritative save/protocol data.

### 2. Bundled Arabic typography

Add the chosen font files and their OFL notices under `assets/fonts/`, and extend the existing
roles in `assets/themes/game_typography.tres`. Use Arabic fallback variations at the existing
500/600/700 weights; keep DynaPuff/Nunito and their Cyrillic fallbacks for text they already cover.
Review title, section, HUD, body, small-label, button, RichTextLabel normal/bold and LineEdit roles.
Arabic glyph coverage must be available even when the active locale is English.

The candidates are listed as Arabic/OFL fonts in the official Google Fonts metadata:
[Baloo Bhaijaan 2](https://raw.githubusercontent.com/google/fonts/main/ofl/baloobhaijaan2/METADATA.pb)
and [Noto Sans Arabic](https://raw.githubusercontent.com/google/fonts/main/ofl/notosansarabic/METADATA.pb).
The downloaded investigation files total approximately 1.13 MB before packaging. Pin the
eventually vendored files/version rather than depending on runtime downloads or installed fonts.

Measure complete shaped strings through the effective control font. Existing fit helpers
already measure translated strings; adjust component height, line spacing and padding where
the new metrics require it. Check joined forms, lam-alef, hamza, shadda, tanween, dots, punctuation
and clipping from outlines. Preserve Arabic joining/mark features. Verify the selected text
server provides BiDi and complex shaping in exported mobile builds as well as the editor.
See [TextServer capabilities](https://docs.godotengine.org/en/4.6/classes/class_textserver.html#enum-textserver-feature)
and [Font fallbacks](https://docs.godotengine.org/en/4.6/classes/class_font.html#class-font-property-fallbacks).

Deliverable: readable, correctly joined Arabic with bundled glyph coverage and no dependence
on desktop system fallback. Update `docs/TYPOGRAPHY.md` with the chosen ownership and weights.

### 3. Reading text and mixed-direction values

Make `SupportFaqItem` own its paragraph alignment on startup and language/direction changes.
Use `RichTextLabel.horizontal_alignment` for the default paragraph alignment rather than
embedding layout tags in approved translation copy. Preserve FAQ expansion and paragraph breaks.
Verify the numbered ad-report list and its email address. The explicit right-alignment
prototype already confirms the relevant property works in this engine.
See [RichTextLabel paragraph alignment](https://docs.godotengine.org/en/4.6/classes/class_richtextlabel.html#class-richtextlabel-property-horizontal-alignment).

Set text direction for semantic numeric fields: chapter progress, chest progress, level/HUD
countdowns, leaderboard ranks/scores, reward `+amount`, booster `×count`, and discount labels.
Keep Arabic prose around these fields RTL. In particular, fix `ProgressValueLabel` without
changing the chapter's mirrored position or its underlying current/total values.

Prefer control properties for standalone values. For an embedded email, reference, date,
price, player name or `×n` token, use an appropriately scoped structured parser or display-only
Unicode isolation only where rendering tests show it is necessary. Put shared presentation
helpers in `scripts/localization/game_text.gd`; do not put direction controls in the catalogs,
persisted names, reference values, backend messages or email addresses. Preserve literal mailto
values and the translated email templates used by `SupportContact`.

Verify the profile LineEdit's caret movement, selection, deletion and placeholder with Arabic
and mixed text. Keep current name validation and automatic-translation exclusions.

Deliverable: correct reading alignment and intact numeric/technical values, with stable raw
data and existing English/Russian/Ukrainian/Italian behavior.

### 4. Carousel, custom art and safe-area geometry

Make `HorizontalPager` direction-aware for page positions, snap targets, overscroll bounds,
gesture thresholds and logical next/previous actions. Arabic next-page movement should enter
from the left and a right swipe should advance the logical chapter index. Keep chapter IDs,
config order, selected progress and the page index unchanged. Let the dot HBox mirror itself.
On a live direction change, cancel an in-progress drag/tween and lay out/snap the same page.
Cover first/last pages, arrow actions, mouse/touch input and resizing in both directions.

Make the sign bracket's own drawing direction-aware so its wall plate attaches to the physical
outer edge after the badge moves left. Update only the directional art; do not flip labels or
coin imagery. Review the sign's pivot, swing, pinned discount tag and click rectangle.

Audit physical safe-area math because Control anchor mirroring can swap asymmetric insets.
Keep left/right device cutouts tied to their physical screen sides; convert to logical
leading/trailing inputs where the engine will mirror anchors. Existing owners to review include:

- `scripts/destination_screen_layout.gd` and `scripts/production_main_menu.gd`;
- `scripts/level_top_hud.gd`, `scripts/gameplay_ui_theme.gd`, and the modal/result shells;
- `scripts/chapters/chapter_selection_screen.gd`, `chapter_cover_card.gd` and the pager;
- `scripts/profile_menu.gd`, `scripts/language_selection_modal.gd` and level overlay placement.

Use a small shared layout helper only if the measured fixes need common inset conversion.
Do not mirror the same positions twice. Test simulated asymmetric insets, including a cutout
on either side, rather than relying on symmetric desktop screenshots.

Audit custom horizontal fills and global-coordinate animations: combo/reward progress,
gameplay tip tails, reward pop-ins/flights and HUD receive targets. Compute animated endpoints
from the rendered widgets. Preserve board-attached lock labels/counters and their hit areas.
Change these owners only where geometry or rendered evidence establishes a defect.

Deliverable: consistent chapter navigation, correctly mounted directional art, safe touch
targets and cutout padding, with puzzle geometry and gameplay IDs preserved.

### 5. Live switching and responsive screen pass

Verify `en → ar → en`, plus transitions from Russian/Ukrainian/Italian, while screens remain
open. Existing owners already handle `NOTIFICATION_TRANSLATION_CHANGED`; add direction/layout
refreshes where necessary and defer font fitting until the mirrored layout has settled.
Language changes must preserve pause state, FAQ expansion, pending ad verification, offers,
purchases, reward visibility and current chapter. They must not replay requests, grants or animations.

Review Home/Settings/Language/Profile; Shop/cards/starter/purchase errors/reward collection;
Leaderboard/weekly reward; chapter selection; gameplay HUD/abilities/tips/locks; Pause/Leave;
Time Up/lives/shelf unlock; completion/failure; chest/opening; and Support/deletion states.
Include long titles, legal paragraphs, maximum counters, large prices, long/mixed player names
and reference strings. The deletion body's last paragraph must remain accessible by scrolling.

Keep behavior in its owning scene/script and reuse existing shells. Update `docs/LOCALIZATION.md`,
`docs/TYPOGRAPHY.md`, and relevant entries in `docs/SCENES.md`, `docs/SCRIPTS.md` and
`docs/PROJECT_MAP.md` after each meaningful implementation batch.

### 6. Verification and release evidence

Add `tests/ui/test_arabic_localization.gd` and focused direction/pager coverage. Update the
language-picker tests' thirteen-entry expectations to fourteen and test regional Arabic
mapping, Save/cancel behavior, persistence and authoritative-snapshot exclusion.

Required automated coverage:

- All 251 reviewed entries, stable keys and aliases; the four email labels and reviewed supplements.
- Placeholder types/order, forced/trailing line breaks, exact protected markers and copied prices/names.
- All seven plural tables and four fixed booster-name contexts at counts
  `0, 1, 2, 3, 10, 11, 99, 100, 101, 102, 103, 110, 111, 199, 200, 1000`.
- Arabic letters and combining marks through every effective font role, with bundled coverage
  checked independently from operating-system fallback.
- Numeric fractions/signs/multipliers, mixed-direction values, profile editing and live switching.
- Carousel gestures/arrows/dots, state preservation and asymmetric safe areas.
- Existing English/Russian/Ukrainian/Italian localization and affected component checks.

Capture affected screens at **540×960, 720×1280, 1080×1920, 1080×2400, and 1200×1600**.
Once Arabic is registered, the existing locale-aware capture tool can be used normally:

```powershell
& .\scripts\tools\capture_ui.ps1 -Scene scenes/ui/support_screen.tscn -Name support_ar -Locale ar -Setup scripts/tools/captures/support_screen_report_setup.gd
& .\scripts\tools\capture_ui.ps1 -Scene scenes/ui/chapter_selection_screen.tscn -Name chapter_ar -Locale ar -Setup scripts/tools/captures/chapter_locked_setup.gd
```

Inspect every rendered contact sheet. A requested/actual-size mismatch is a capture limitation,
not evidence that the requested resolution passes. Obtain correctly sized renders before
closing that resolution's review. Desktop engine tests do not establish native keyboard,
touch/scroll, mobile export shaping or safe-area behavior; include Android/iOS device checks.
Record results, defects, limitations and screenshots in `docs/localization/ARABIC_LOCALIZATION_QA.md`.

Arabic is ready when reviewed copy resolves, all six plural categories work, text joins and
reads correctly, mixed tokens retain their order, navigation matches RTL conventions, every
target resolution is verified, switching preserves state, and existing locales still pass.
Commit each meaningful implementation batch separately under the project Git workflow.

## Scope boundary

This work changes client presentation and language preference handling. It does not require
changes to authoritative progression, economy, purchases, ad verification, gameplay proof,
chapter IDs or the backend protocol. Before future changes touching the Shop, purchases,
leaderboards or profiles, read the sibling backend's `AGENTS.md` and canonical boundary documents
as the project instructions require. Any backend change needs a separate explicit scope.

Decorative English words already baked into background illustrations are outside the keyed
inventory; translating those would be a separate art pass. The app/store public name and
platform-owned consent/system dialogs also retain their existing ownership.
