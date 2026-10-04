# Russian localization verification — October 4, 2026

## Automated checks

Verified with Godot 4.6.2 through `scripts/tools/run_isolated_godot_test.ps1`:

- `test_russian_localization`: all 251 reviewed strings in Russian and English; English fallback
  for an untranslated locale; Russian plural boundaries; Cyrillic font coverage; grouped numbers
  and genitive dates; live language switches; unchanged names/prices and reward-action state;
  local preference persistence and exclusion from authoritative saves.
- `test_language_selection`, `test_support_screen`, `test_account_deletion_modal`,
  `test_profile_menu`, `test_chapter_ui`, `test_starter_bundle_offer`,
  `test_level_failure_screen`, `test_level_ui_consistency`, `test_out_of_lives_menu`, and
  `test_purchase_reward_sequence` passed.
- Shop and Leaderboard scene verification passed, including their five responsive viewport checks.

English UI assertions explicitly select English now that a Russian device locale has real
translations. Rewarded-life test fixtures keep their refill timestamp one hour in the future,
instead of using the expired September 20 date. Locked-shelf feedback uses current Level 3;
Level 7 no longer contains a locked shelf. These changes affect tests only.

## Rendered review

Reviewed actual PNGs/contact sheets in ignored `tmp/ui_capture/`. Captures use `-Locale ru`
and isolated saves; no real player account or locale preference is changed.

Main Menu and Shop were captured at 540x960, 720x1280, 1080x1920 and 1080x2400.
Additional screens were checked at 540x960, 720x1280 and 1080x2400:

- Settings and Language: Cyrillic headings, native language labels, selected Russian row and Save.
- Starter Bundle and chest reveal: long booster names, grouped coins, unchanged platform prices,
  offer ribbons and discounts.
- Support: expanded ad-report instructions and the complete action label. The action button was
  widened from 260 to 320 logical pixels after the first capture showed text beyond its border.
- Account deletion: confirmation paragraphs in their scrollable region, both action labels,
  and accepted-result text with the date `1 ноября 2026 г.`.
- Profile: unchanged generated player name, frame choices, Save and the wrapped weekly-rank hint.
- Leaderboard and weekly reward: unchanged player names, tabs, reset time and inflected coin payout.
- Locked Chapter 2: translated chapter names and remaining-level requirement, progress and disabled CTA.
- Pause, shelf unlock, failed level and completion: fitted modal headers, descriptions and actions.
  The failure message and privacy action were refitted after their first captures showed overflow.

Final contact-sheet prefixes include `main_menu_ru`, `shop_ru`, `settings_ru`, `language_ru`,
`starter_ru`, `chest_reward_ru`, `support_ru`, `deletion_ru`, `deletion_deadline_ru`,
`profile_ru`, `leaderboard_ru`, `weekly_reward_ru`, `chapter_locked_ru`, `pause_ru`,
`shelf_unlock_ru`, `failure_ru`, and `completion_ru`.

## Capture limitations and unrelated layout findings

- Requests for 1200x1600 and 900x1200 under the production keep-width stretch policy produced
  narrower textures (900x1600 and 675x1200). Their manifests report the mismatch. These PNGs
  do not verify the requested tablet dimensions. The existing Pause setup disables aspect
  preservation and did produce a faithful 900x1200 capture; its Russian modal fits.
- Main Menu captures after resizing to 1080x1920 and 1080x2400 place the bottom navigation and
  level button above the bottom of the image. An English 1080x1920 comparison shows the same
  placement. The translation change does not alter Main Menu geometry. This resize/capture
  behavior remains a separate layout issue; full responsive Main Menu approval is not claimed.
- Generic Level capture setups show the board/background cropped toward the lower-right while
  modal text and HUD labels remain visible. These captures verify localized overlays, rather
  than establishing complete gameplay-layout correctness.
- Existing hammer-art UID fallback and level layout/anchor warnings remain unchanged.
