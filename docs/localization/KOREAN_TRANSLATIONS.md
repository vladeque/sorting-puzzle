# Sorting Puzzle — Korean Translations

Locale: `ko` · Language: 한국어 · Prepared: October 7, 2026

Bilingual translations of every keyed entry in **Sorting Puzzle — Translation String Inventory.md**, including the October 5 copy updates. English strings, keys, context and source references are retained for review. The source audit describes the October 3 build at commit `ade3b3d`; it is historical context. This document supplies translations for review and does not install them in the game.

## Korean terminology

| English | Korean | Usage |
| --- | --- | --- |
| Level | 레벨 | One numbered puzzle board. |
| Chapter | 챕터 | A themed group of levels. |
| Shelf | 선반 | A row of item slots. |
| Item / goods | 아이템 | Goods on the board and inventory items. |
| Match / triple / set | 같은 아이템 3개 / 세트 | A set always means three identical items; matching a set clears it. |
| Combo | 콤보 | Several matches in quick succession. |
| Booster / ability | 부스터 | The same term is used for shop products and gameplay abilities. |
| Hammer | 망치 | Consistent product name. |
| Shuffle | 섞기 | Consistent product name. |
| Lantern | 랜턴 | Consistent product name. |
| Freezer | 얼리기 | Consistent product name; its description clarifies that it stops time. |
| Dispenser | 배출기 | The machine that sends items onto shelves. |
| Coins | 코인 | Soft currency. |
| Stars | 별 | Level, chest and ranking stars. |
| Lives | 하트 | Matches the heart icon used in the game. |
| Reward chest | 보상 상자 | The chest unlocked by collecting stars. |
| Bundle | 패키지 | A pack of coins and boosters. |

## Reading the tables

- Every `%d` and `%s` placeholder retains its source type, count and order. Placeholder values such as player names, email addresses, prices and reference codes stay unchanged. Chapter and booster names supplied through placeholders use their Korean translations.
- Forced line-break markers retain the source document's exact Markdown escaping (`\\n`). Each marker represents one in-game line break; repeated markers separate paragraphs. Trailing line breaks in email templates are retained.
- Korean uses one plural form. The same Korean entry works for every count in rows marked **Needs plural forms**.
- Korean has no uppercase/lowercase distinction. Short Korean labels are used for uppercase English titles and banners.
- `AD`, `OFF`, the complete dynamic percentage discount tag (for example, `67% OFF`), and the existing app brand `SortingPuzzle` / `Sorting Puzzle` remain unchanged. The home badge `BUNDLE` is translated as `패키지`.
- General copy uses friendly, polite Korean. Combo praise uses brief exclamations. Account deletion copy uses formal wording and retains irreversibility, retained records, the 30-day deadline, locked states and “nothing was deleted.”
- Four additional email field labels mentioned in the inventory's context, but lacking their own keys, appear in the appendix.
- Completeness, placeholders and line breaks have been checked against the inventory. In-game layout and Hangul font coverage have not been rendered or verified as part of this document translation.

## Shared buttons, main menu and chapters

Shared buttons appear on several screens and need one translation each, except where the context says the meaning differs. Keys are suggestions for the future translation table.

| Key | English | 한국어 (Korean) | Context | Source |
| --- | --- | --- | --- | --- |
| `common.play` | Play | 플레이 | Button that starts the chapter's next level on a chapter card. | `chapter_cover_card.gd` |
| `common.continue` | Continue | 계속 | Button that moves on: closes the level-complete screen, the purchase dialog and the reward chest menu; on a chapter card it resumes a chapter already started. | `level_completion_screen.tscn`, `shop_purchase_dialog`, `reward_chest_menu.tscn`, `chapter_cover_card.gd` |
| `common.resume` | Continue | 계속하기 | Button on Pause and on the leave confirmation that returns to the running level ("keep playing"). Separate key: some languages use a different verb than for "move on". | `pause_menu.tscn`, `leave_confirmation_menu.tscn` |
| `common.try_again` | Try Again | 다시 시도 | Retries a failed action (ad, purchase, account deletion). | ad modals, `account_deletion_modal.gd`, `starter_bundle_offer_modal.gd` |
| `common.close` | Close | 닫기 | Closes a dialog without doing anything. | `account_deletion_modal.gd` |
| `common.cancel` | Cancel | 취소 | Backs out of account deletion; nothing is deleted. | `account_deletion_modal.tscn` |
| `common.got_it` | Got it | 확인 | Acknowledges an info dialog (ability description, lives already full). | `out_of_lives_menu.tscn`, `shop_screen.gd` |
| `common.get_help` | Get Help | 도움 요청 | Opens a pre-filled email to support. | `account_deletion_modal.gd` |
| `common.save` | SAVE | 저장 | Confirms profile edits or the chosen language. All caps by design. | `profile_menu`, `language_selection_modal.tscn` |
| `common.loading` | Loading… | 불러오는 중… | Shown while the Shop or Leaderboard loads its data. | `destination_status_panel.tscn` |
| `common.retry_load` | Retry | 다시 불러오기 | Reloads the Shop or Leaderboard after a load error. Not the same as replaying a level. | `destination_status_panel.tscn` |
| `menu.level_button` | LEVEL %d | 레벨 %d | Big play button on the home screen. `%d` = level number inside the current chapter. | `production_main_menu.gd` |
| `menu.more_levels_coming_soon` | MORE LEVELS COMING SOON | 새 레벨이 곧 추가돼요 | Home play button (disabled) after every level of the chapter is finished. Must fit the button, about 24 characters. | `production_main_menu.gd` |
| `menu.coming_soon` | COMING SOON | 곧 공개 | Home play button (disabled) when the chapter has no levels yet. | `production_main_menu.gd` |
| `menu.lives_full` | Full | 가득 | Top bar, next to the heart, when lives are at maximum; replaces the refill timer. About 5 characters. | `production_main_menu.gd`, `main_menu_top_status.tscn` |
| `menu.starter_badge` | BUNDLE | 패키지 | Small badge on the home screen that opens the Starter Bundle offer. About 8 characters. Russian: НАБОР. The full offer title remains Starter Bundle / Стартовый набор. | `main_menu_starter_bundle_badge.tscn` |
| `nav.shop` | Shop | 상점 | Bottom navigation tab. About 10 characters. | `main_menu_bottom_navigation.tscn` |
| `nav.home` | Home | 홈 | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `nav.leaderboard` | Leaderboard | 랭킹 | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `chapter.button` | CHAPTER %d | 챕터 %d | Home button that opens chapter selection. `%d` = chapter number. | `main_menu_chapter_button.gd` |
| `chapter.button_tooltip` | Choose Chapter %d: %s | 챕터 %d, %s 선택 | Accessibility tooltip of that button. `%d` = chapter number, `%s` = chapter title. | `main_menu_chapter_button.gd` |
| `chapter.screen_title` | CHAPTERS | 챕터 | Title of the chapter selection screen. | `chapter_selection_screen.tscn` |
| `chapter.eyebrow` | CHAPTER %d | 챕터 %d | Small label above the chapter name on its card. | `chapter_cover_card.gd` |
| `chapter.title.chapter_01` | Grocery Town | 마트 마을 | Name of chapter 1 (a grocery-store theme). | `configs/chapters.json` |
| `chapter.title.chapter_02` | Candy Corner | 사탕 골목 | Name of chapter 2 (a candy-shop theme). | `configs/chapters.json` |
| `chapter.locked_status` | Complete %d more %s levels to unlock | 레벨 %d개를 '%s'에서 더 완료하면 잠금이 해제됩니다 | Locked chapter card. `%d` = levels still needed, `%s` = previous chapter's name. Needs plural forms. | `chapter_cover_card.gd` |
| `chapter.unlock_progress` | Unlock progress | 잠금 해제 진행도 | Header over the progress bar on a locked chapter. | `chapter_cover_card.gd` |
| `chapter.current_progress` | Current progress | 현재 진행도 | Header over the progress bar on an unlocked chapter. | `chapter_cover_card.gd` |
| `chapter.locked` | Locked | 잠김 | Disabled button on a locked chapter card. | `chapter_cover_card.gd` |
| `chapter.no_levels_status` | New levels are coming soon | 새 레벨이 곧 추가돼요 | Card message for a chapter with no levels yet. | `chapter_cover_card.gd` |
| `chapter.coming_soon` | Coming Soon | 곧 공개 | Disabled button on that card. | `chapter_cover_card.gd` |

## Gameplay: HUD, level screens and results

These strings show during a level, mostly in modal titles (all caps, short) and action buttons. A "triple" or "match" is three identical items on one shelf, which clears them.

| Key | English | 한국어 (Korean) | Context | Source |
| --- | --- | --- | --- | --- |
| `hud.level` | LEVEL %d | 레벨 %d | Top HUD during play. `%d` = level number inside the chapter. | `level.gd` |
| `hud.combo` | COMBO ×%d | 콤보 ×%d | HUD counter for consecutive quick matches. `%d` = combo size; keep the × sign. | `level_top_hud.gd` |
| `hud.ability_tooltip.hammer` | Hammer -- clears a matching triple | 망치 -- 같은 아이템 3개를 제거해요 | Accessibility tooltip on the Hammer booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.shuffle` | Shuffle -- reshuffles unlocked items | 섞기 -- 잠기지 않은 아이템을 다시 섞어요 | Tooltip on the Shuffle booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.lantern` | Lantern -- highlights a matchable triple | 랜턴 -- 맞출 수 있는 같은 아이템 3개를 표시해요 | Tooltip on the Lantern booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.freezer` | Freezer -- pauses the countdown timer | 얼리기 -- 카운트다운 타이머를 멈춰요 | Tooltip on the Freezer booster button. | `ability_bar.tscn` |
| `hud.seconds_short` | %ds | %d초 | Countdown on an active Lantern or Freezer booster, e.g. "15s". `%d` = seconds; use the local short unit. | `ability_bar.gd` |
| `tip.tap_dispenser` | Tap a dispenser to throw items onto the shelves! | 배출기를 터치하면 아이템이 선반으로 나와요! | Tutorial bubble on level 10, where dispensers (machines that throw items onto shelves) first appear. | `configs/gameplay_tips.json` |
| `pause.title` | PAUSE | 일시정지 | Title of the in-level pause modal. | `pause_menu.gd` |
| `pause.leave` | Leave | 나가기 | Pause button that quits the level (asks for confirmation next). | `pause_menu.tscn` |
| `leave.title` | LEAVING THE LEVEL | 레벨 나가기 | Title of the leave confirmation. | `leave_confirmation_menu.gd` |
| `leave.you_will_lose` | You will lose: | 다음을 잃게 돼요: | Followed by icons showing the stars earned this run and one life. Keep the colon (or local equivalent). | `leave_confirmation_menu.tscn` |
| `leave.confirm` | Leave | 나가기 | Confirms quitting the level and losing that progress. | `leave_confirmation_menu.tscn` |
| `timeup.title` | TIME'S UP | 시간 종료 | Title when the level timer reaches zero. | `time_up_extension_modal.gd` |
| `timeup.offer` | Add one minute and keep sorting! | 1분을 추가하고 계속 정리해요! | Offer to extend the timer by 60 seconds for coins or an ad. | `time_up_extension_modal.tscn` |
| `timeup.used` | Used | 사용 완료 | Shown on the coin price or ad button when that extension was already used this level. | `time_up_extension_modal.gd` |
| `ability_purchase.title` | USE ABILITY | 부스터 사용 | Title of the modal that buys and immediately uses one booster when the player has none. | `ability_purchase_menu.gd` |
| `shelf_unlock.title` | UNLOCK SHELF | 선반 잠금 해제 | Title of the modal for a locked shelf. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer` | Watch one ad to unlock this shelf now. | 광고 하나를 보고 지금 이 선반의 잠금을 해제하세요. | Body when no other way to unlock remains. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer_or_clear` | Watch one ad to unlock this shelf now, or clear %s more. | 광고 하나를 보고 지금 이 선반의 잠금을 해제하거나, 세트를 %s번 더 맞추세요. | Body when the shelf also unlocks by itself after more matches. `%s` = matches still needed. Needs plural forms. | `shelf_unlock_menu.gd` |
| `shelf_unlock.button` | Watch Ad · Unlock Shelf | 광고 보기 · 선반 잠금 해제 | Ad button in that modal. | `shelf_unlock_menu.gd` |
| `shelf_unlock.ad_unavailable` | Ad unavailable. This shelf stays locked. | 광고를 볼 수 없어요. 이 선반은 잠긴 상태로 유지돼요. | Status line when no ad could be shown. | `shelf_unlock_menu.gd` |
| `complete.title` | GREAT JOB! | 잘했어요! | Title of the level-complete screen, above the stars earned. | `level_completion_screen.gd` |
| `failed.title` | LEVEL %d | 레벨 %d | Title of the level-failed screen. `%d` = level number. | `level_failure_screen.gd` |
| `failed.headline` | LEVEL FAILED | 레벨 실패 | Banner on the level-failed screen. | `level_failure_screen.tscn` |
| `failed.retry` | Retry | 다시 도전 | Replays the same level. | `level_failure_screen.tscn` |

Combo praise pops up above a match during a combo; each word is stronger than the one before, so keep the escalation. The label shrinks its font for long words, but one or two words is the limit.

| Key | English | 한국어 (Korean) | Shown at |
| --- | --- | --- | --- |
| `combo.praise.2` | Cool | 좋아! | Combo ×2 |
| `combo.praise.3` | Great | 잘했어! | ×3 |
| `combo.praise.4` | Awesome | 멋져! | ×4 |
| `combo.praise.5` | Amazing | 놀라워! | ×5 |
| `combo.praise.6` | Fantastic | 환상적이야! | ×6 |
| `combo.praise.7` | Incredible | 믿기지 않아! | ×7 |
| `combo.praise.8` | Spectacular | 엄청나! | ×8 |
| `combo.praise.9` | Unstoppable | 거침없어! | ×9 |
| `combo.praise.10` | Legendary | 전설적이야! | ×10 |
| `combo.praise.11` | Epic | 압도적이야! | ×11 |
| `combo.praise.12` | Brilliant | 눈부신 실력! | ×12 |
| `combo.praise.13` | Masterful | 달인의 실력! | ×13 |
| `combo.praise.14` | Supreme | 최고의 실력! | ×14 |
| `combo.praise.15` | Phenomenal | 경이로운 실력! | ×15 |
| `combo.praise.16` | Mythic | 신화급이야! | ×16 |
| `combo.praise.17` | Majestic | 독보적이야! | ×17 |
| `combo.praise.18` | Radiant | 차원이 달라! | ×18 |
| `combo.praise.19` | Divine | 신의 경지! | ×19 |
| `combo.praise.20` | Transcendent | 초월의 경지! | ×20 and above |

Source: `COMBO_PRAISE_WORDS` in `level.gd`.

## Boosters, ads, lives, rewards and shop

The four boosters (also called abilities in code) are product names: pick one translation per language and reuse it everywhere, including the tooltips in the gameplay section.

| Key | English | 한국어 (Korean) | Context | Source |
| --- | --- | --- | --- | --- |
| `ability.hammer.name` | Hammer | 망치 | Booster that smashes away one matching set. | `reward_reveal_row.tscn`, `starter_bundle_offer_modal.tscn`, `shop_screen.gd` |
| `ability.shuffle.name` | Shuffle | 섞기 | Booster that rearranges items. | same |
| `ability.lantern.name` | Lantern | 랜턴 | Booster that lights up a set the player can match (internal id `highlight`). | same |
| `ability.freezer.name` | Freezer | 얼리기 | Booster that stops the level timer. | same |
| `ability.hammer.description` | Instantly clears one matching set of items off the shelves. | 선반에서 같은 아이템 3개로 이루어진 세트 하나를 즉시 제거해요. | Shop info dialog body after tapping the booster icon. | `shop_screen.gd` |
| `ability.shuffle.description` | Shuffles shelf items into new spots to help you find a match. | 선반 위 아이템의 위치를 섞어 맞출 세트를 찾기 쉽게 해줘요. | Same dialog. | `shop_screen.gd` |
| `ability.lantern.description` | Highlights a matching triple you can clear for 15 seconds. | 없앨 수 있는 같은 아이템 3개를 15초 동안 강조해요. | Same dialog. Keep the number in sync with the game config. | `shop_screen.gd` |
| `ability.freezer.description` | Freezes the level timer for 30 seconds. | 레벨 타이머를 30초 동안 멈춰요. | Same dialog. | `shop_screen.gd` |
| `ad.watch` | Watch Ad | 광고 보기 | Button that plays a rewarded video ad. | ad modals, `out_of_lives_menu`, `ability_purchase_menu.tscn` |
| `ad.loading` | Loading... | 불러오는 중... | Ad button while the ad loads. | ad modals |
| `ad.verifying` | Verifying... | 확인 중... | Ad button while the server confirms the reward. | ad modals |
| `ad.verify_reward` | Verify Reward | 보상 확인 | Ad button to re-check a reward the server has not confirmed yet. | ad modals |
| `ad.reward_pending` | Reward verification is still pending. | 아직 보상 확인이 완료되지 않았어요. | Status line under that button. | `out_of_lives_menu.gd`, `shelf_unlock_menu.gd` |
| `ad.unavailable_retry` | Ad unavailable. Please try again. | 광고를 볼 수 없어요. 다시 시도해 주세요. | Status line when no ad could be shown. | `out_of_lives_menu` |
| `ad.watch_unavailable` | Watch Ad\\nUnavailable | 광고 보기\\n이용 불가 | Two-line disabled ad button (time-up modal). Keep the line break. | `time_up_extension_modal.gd` |
| `ad.watch_coming_soon` | Watch Ad\\nComing Soon | 광고 보기\\n곧 제공 | Two-line disabled ad button before ads launch. | `time_up_extension_modal.tscn` |
| `ad.badge` | AD | AD | Tiny badge on a locked shelf that an ad can open. Do not translate: keep AD exactly in every language. | `shelf_lock_overlay.tscn`, `shelf_unlock_menu.tscn` |
| `lives.title.out` | OUT OF LIVES | 하트 없음 | Lives modal title at 0 lives. | `out_of_lives_menu.gd` |
| `lives.title.get_more` | GET MORE LIVES | 하트 충전 | Lives modal title with some lives left. | `out_of_lives_menu.gd` |
| `lives.title.full` | LIVES FULL | 하트 가득 | Lives modal title at maximum lives. | `out_of_lives_menu.gd` |
| `lives.next_in` | NEXT LIFE IN | 다음 하트까지 | Label above the refill countdown (mm:ss). | `out_of_lives_menu.tscn` |
| `lives.full_body` | Your lives are full! Play a level to spend them. | 하트가 가득해요! 레벨을 플레이해 하트를 사용하세요. | Body of the lives modal at maximum. | `out_of_lives_menu.tscn` |
| `chest.title` | CHEST REWARDS | 상자 보상 | Title of the reward chest modal. | `reward_chest_menu.tscn` |
| `chest.progress_hint` | Collect stars to unlock a chest and claim your reward | 별을 모아 보상 상자를 열고 보상을 받으세요 | Under the star progress bar (e.g. 12/30). | `reward_chest_menu.tscn` |
| `chest.ready` | A REWARD CHEST AWAITS! | 보상 상자가 기다려요! | Banner when the chest is full and can be opened. | `reward_chest_menu.tscn` |
| `chest.tap_to_open` | Tap to open | 터치해서 열기 | Prompt under the closed chest in the opening animation. | `reward_chest_open_ceremony.tscn` |
| `purchase.tap_to_collect` | Tap to collect | 터치해서 받기 | Prompt to collect purchased rewards. | `purchase_reward_sequence.tscn` |
| `purchase.complete` | PURCHASE COMPLETE | 구매 완료 | Banner after a successful purchase. | `purchase_reward_sequence.gd` |
| `shop.title` | SHOP | 상점 | Shop screen title. | `shop_screen.tscn` |
| `shop.section.bundles` | SPECIAL BUNDLES | 특별 패키지 | Section header. | `shop_screen.tscn` |
| `shop.section.coins` | COINS | 코인 | Section header for coin packs. | `shop_screen.tscn` |
| `shop.offer.starter_bundle` | Starter Bundle | 스타터 패키지 | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.offer.basic_bundle` | Basic Bundle | 기본 패키지 | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.tag.best_value` | BEST VALUE | 최고 혜택 | Ribbon on the best coin pack. | `configs/shop_catalog.json` |
| `shop.discount_off` | OFF | OFF | Second line of the discount badge under "67%". Do not translate: keep the complete 67% OFF tag unchanged in every language; the numeric percentage can vary by offer. | `shop_bundle_card.tscn`, `starter_bundle_offer_modal.tscn` |
| `shop.ability_hint` | Tap an ability to see what it does | 부스터를 터치해 효과를 확인하세요 | Hint under a bundle's booster icons. | `shop_bundle_card.tscn` |
| `shop.purchasing` | Purchasing… | 구매 중… | Buy button while a purchase is in progress. | shop cards, `production_main_menu.gd` |
| `shop.no_offers` | No shop offers are available for this region. | 이 지역에서 구매할 수 있는 상품이 없어요. | Shop error state. | `shop_screen.gd` |
| `shop.load_failed` | Could not load the shop. | 상점을 불러오지 못했어요. | Shop error state (fallback text). | `shop_screen.gd` |
| `shop.error.title.purchase` | Purchase unavailable | 구매 불가 | Error dialog title when buying failed. | `shop_screen.gd` |
| `shop.error.title.reward` | Reward error | 보상 오류 | Error dialog title when payment went through but rewards were not granted. | `shop_screen.gd` |
| `shop.error.purchase_failed` | The purchase could not be completed. | 구매를 완료하지 못했어요. | Error dialog body (fallback). | `shop_screen.gd`, `production_main_menu.gd` |
| `shop.error.grant_failed` | The purchased rewards could not be granted. | 구매한 보상을 지급하지 못했어요. | Error dialog body. | `store/shop_purchase_flow.gd` |
| `shop.error.offer_unavailable` | This shop offer is unavailable. | 이 상품은 구매할 수 없어요. | Error dialog body. | `store/store_service.gd` |
| `shop.error.already_bought` | This one-time shop offer has already been purchased. | 한 번만 구매할 수 있는 이 상품을 이미 구매했어요. | Error dialog body. | `store/store_service.gd` |
| `starter.title` | STARTER BUNDLE | 스타터 패키지 | Starter offer modal title. | `starter_bundle_offer_modal.gd` |
| `starter.one_time` | ONE-TIME OFFER | 한 번만 구매 가능 | Ribbon on the starter offer. | `starter_bundle_offer_modal.tscn` |
| `starter.boosters_included` | BOOSTERS INCLUDED | 부스터 포함 | Header over the four booster chips. | `starter_bundle_offer_modal.tscn` |
| `starter.coins` | %s COINS | 코인 %s개 | Ribbon over the coin art. `%s` = formatted amount, e.g. "1,000". Needs plural forms. | `starter_bundle_offer_modal.gd` |
| `starter.buy_for` | Buy for %s | %s에 구매하기 | Buy button. `%s` = store price, e.g. "$4.99". | `starter_bundle_offer_modal.gd` |
| `starter.checking` | Checking offer… | 상품 확인 중… | Status while the store confirms the offer. | `production_main_menu.gd` |
| `starter.checking_short` | Checking… | 확인 중… | Buy button during that check. | `starter_bundle_offer_modal.gd` |
| `starter.no_longer_available` | This offer is no longer available. | 이 상품은 더 이상 구매할 수 없어요. | Error status in the starter modal. | `production_main_menu.gd` |
| `starter.unavailable` | Unavailable | 구매 불가 | Disabled buy button after a non-retryable error. | `starter_bundle_offer_modal.gd` |
| `booster_chip.claimed` | +%d %s | +%d %s | Booster chip after purchase, e.g. "+3 Hammer". `%d` = count, `%s` = booster name. Needs plural forms. | `offer_booster_chip.gd` |

## Profile, leaderboard and settings

Language names in the language picker stay in their own language (English, Español, 日本語…) and are never translated.

| Key | English | 한국어 (Korean) | Context | Source |
| --- | --- | --- | --- | --- |
| `profile.title` | EDIT PROFILE | 프로필 수정 | Profile modal title. | `profile_menu.tscn` |
| `profile.name_header` | PLAYER NAME | 플레이어 이름 | Header over the name field. | `profile_menu.tscn` |
| `profile.name_placeholder` | Player name | 플레이어 이름 | Placeholder inside the empty name field. | `profile_menu.tscn` |
| `profile.edit_name_tooltip` | Edit player name | 플레이어 이름 수정 | Accessibility tooltip on the pencil button. | `profile_menu.tscn` |
| `profile.avatar_tab` | AVATAR | 아바타 | Tab that shows avatar pictures. | `profile_menu.tscn` |
| `profile.frame_tab` | FRAME | 프레임 | Tab that shows decorative frames around the avatar. | `profile_menu.tscn` |
| `profile.unlock.level` | Complete level %d to unlock | 레벨 %d를 완료하면 해제됩니다 | Toast after tapping a locked frame. `%d` = level number. | `profile_menu.gd` |
| `profile.unlock.combo` | Reach a combo of ×%d in any run to unlock | 한 번의 플레이에서 콤보 ×%d를 달성하면 해제됩니다 | Same toast. `%d` = combo size. | `profile_menu.gd` |
| `profile.unlock.weekly_first` | Finish 1st on the Weekly leaderboard to unlock | 주간 랭킹에서 1위를 차지하면 해제됩니다 | Same toast for a first-place frame. Today built from two parts; see implementation notes. | `profile_menu.gd` |
| `profile.unlock.weekly_top` | Finish top %d on the Weekly leaderboard to unlock | 주간 랭킹에서 %d위 안에 들면 해제됩니다 | Same toast. `%d` = rank cutoff (e.g. 10). | `profile_menu.gd` |
| `leaderboard.title` | LEADERBOARD | 랭킹 | Leaderboard screen title. | `leaderboard_screen.tscn` |
| `leaderboard.tab.weekly` | Weekly | 주간 | Tab: this week's stars. | `leaderboard_screen.tscn` |
| `leaderboard.tab.country` | Country | 국가 | Tab: all-time stars in the player's country. | `leaderboard_screen.tscn` |
| `leaderboard.tab.world` | World | 세계 | Tab: all-time stars worldwide. | `leaderboard_screen.tscn` |
| `leaderboard.weekly_reset` | Weekly reset in %s | 주간 초기화까지 %s | Under the Weekly tab. `%s` = a duration such as "1d 4h". | `leaderboard_screen.gd` |
| `leaderboard.duration.dh` | %dd %dh | %d일 %d시간 | Duration: days and hours. Use local unit abbreviations. | `leaderboard_screen.gd` |
| `leaderboard.duration.hm` | %dh %dm | %d시간 %d분 | Duration: hours and minutes. | `leaderboard_screen.gd` |
| `leaderboard.duration.m` | %dm | %d분 | Duration: minutes. | `leaderboard_screen.gd` |
| `leaderboard.country_caption` | Country · All-time stars | 국가 · 누적 별 | Caption under the Country tab. | `leaderboard_screen.gd` |
| `leaderboard.world_caption` | Worldwide · All-time stars | 전 세계 · 누적 별 | Caption under the World tab. | `leaderboard_screen.gd` |
| `leaderboard.load_failed` | Could not load leaderboard. | 랭킹을 불러오지 못했어요. | Error state (fallback text). | `leaderboard_screen.gd` |
| `leaderboard.default_name` | Player | 플레이어 | Name shown for a player without one. | `leaderboard_row.gd` |
| `leaderboard.row_tooltip` | Rank %d, %s, %d stars | %d위, %s, 별 %d개 | Accessibility text of a row. `%d` = rank, `%s` = player name, `%d` = stars. Needs plural forms. | `leaderboard_row.gd` |
| `leaderboard.reward_tooltip` | %s coin weekly reward | 주간 보상: 코인 %s개 | Accessibility text on the coin prize next to top ranks. `%s` = amount. | `leaderboard_rank_reward.gd` |
| `leaderboard.reward.title` | WEEKLY REWARD! | 주간 보상! | Title of the dialog shown after a week ends. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.body` | You finished #%d last week and earned %d coins! | 지난주에 %d위를 차지해 코인 %d개를 받았어요! | Body. `%d` = final rank, `%d` = coins. Needs plural forms. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.ok` | Nice! | 좋아요! | Button that closes the reward dialog. | `leaderboard_reward_dialog.tscn` |
| `settings.title` | SETTINGS | 설정 | Settings modal title (home screen). | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.music` | Music | 음악 | Toggle label under an icon. Short, about 8 characters. | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.sfx` | SFX | 효과음 | Toggle for sound effects. Use a short local word for "Sounds". | same |
| `settings.vibrate` | Vibrate | 진동 | Toggle for haptic feedback. | same |
| `settings.support` | Support | 고객지원 | Opens the Support screen. | `settings_menu.tscn` |
| `settings.language` | Language | 언어 | Opens the language picker. | `settings_menu.tscn`, `language_option_row.tscn` |
| `settings.privacy_policy` | Privacy Policy | 개인정보 처리방침 | Opens the privacy policy web page. | `settings_menu.tscn`, `production_main_menu.gd` |
| `settings.privacy_choices` | Privacy Choices | 개인정보 보호 설정 | Same button when the ad consent form must be offered (EU/UK). | `production_main_menu.gd` |
| `settings.diagnostics` | Version %s • Build %d\\nPlatform: %s • User: %s | 버전 %s • 빌드 %d\\n플랫폼: %s • 사용자: %s | Small footer for support. Values: app version, build number, OS name, short player id. Translating the four labels is optional. | `pause_menu.gd` |
| `language.title` | LANGUAGE | 언어 | Language picker title. | `language_selection_modal.gd` |

## Support, account deletion and platform text

Support and deletion copy is legal-adjacent: translate meaning exactly, keep "Nothing was deleted" and "You can't undo this" unambiguous, and do not soften the warnings.

### Support screen

| Key | English | 한국어 (Korean) | Context | Source |
| --- | --- | --- | --- | --- |
| `support.title` | SUPPORT | 고객지원 | Support screen title. | `support_screen.tscn` |
| `support.faq_header` | Frequently Asked Questions | 자주 묻는 질문 | Section header. | `support_screen.tscn` |
| `support.faq.play.q` | How do I play? | 어떻게 플레이하나요? | FAQ question (tap to expand). | `support_screen.tscn` |
| `support.faq.play.a` | Move matching goods onto the same shelf. When three identical items are visible together, they clear. Complete the board before time runs out. | 같은 아이템을 같은 선반으로 옮기세요. 동일한 아이템 3개가 함께 보이면 사라져요. 시간이 다 되기 전에 보드의 아이템을 모두 제거하세요. | FAQ answer. "Goods" = shop items such as snacks and toys. | `support_screen.tscn` |
| `support.faq.contact.q` | How do I contact support? | 고객지원에 어떻게 문의하나요? | FAQ question. | `support_screen.tscn` |
| `support.faq.contact.a` | Email us at %s. Include a short description, your device platform, and when the problem happened. | %s로 이메일을 보내 주세요. 문제에 대한 간단한 설명, 기기 플랫폼, 문제가 발생한 시간을 함께 알려 주세요. | FAQ answer. `%s` = support email address. | `support_screen.gd` |
| `support.faq.contact.action` | Email Support | 이메일 문의 | Button that opens a pre-filled email. | `support_screen.tscn` |
| `support.faq.crash.q` | What if the game freezes or crashes? | 게임이 멈추거나 갑자기 종료되면 어떻게 하나요? | FAQ question. | `support_screen.tscn` |
| `support.faq.crash.a` | Close and reopen the game first. If it happens again, restart the device and make sure the game is updated. Contact support with the device model, platform version, and what you were doing before the problem. | 먼저 게임을 종료한 뒤 다시 실행해 보세요. 문제가 반복되면 기기를 재시작하고 게임이 최신 버전인지 확인하세요. 기기 모델, 플랫폼 버전, 문제가 발생하기 직전에 무엇을 하고 있었는지 고객지원에 알려 주세요. | FAQ answer. | `support_screen.tscn` |
| `support.faq.sync.q` | How do I sync progress between devices? | 기기 간에 진행 상황을 어떻게 동기화하나요? | FAQ question. | `support_screen.tscn` |
| `support.faq.sync.a` | Use the same signed-in platform account on both devices and allow synchronization to finish before playing. If the progress differs, avoid playing on both devices and contact support. | 두 기기에서 같은 플랫폼 계정으로 로그인하고, 동기화가 완료된 뒤 플레이하세요. 진행 상황이 다르면 두 기기에서 플레이하지 말고 고객지원에 문의하세요. | FAQ answer. "Platform account" = Google Play Games / Game Center. | `support_screen.tscn` |
| `support.faq.bad_ad.q` | How do I report a bad ad? | 부적절한 광고는 어떻게 신고하나요? | FAQ question. | `support_screen.tscn` |
| `support.faq.bad_ad.a` | 1. Close the ad if you can do so safely.\\n2. Take a screenshot of the ad and any advertiser or app name shown.\\n3. Note the approximate time and where the ad appeared in the game.\\n4. Describe why the ad seemed offensive, misleading, or fraudulent.\\n5. Email these details to %s. Do not include passwords or payment information. | 1. 안전하게 닫을 수 있다면 광고를 닫으세요.\\n2. 광고와 화면에 표시된 광고주 또는 앱 이름의 스크린샷을 찍으세요.\\n3. 광고가 나타난 대략적인 시간과 게임 내 위치를 기록하세요.\\n4. 광고가 불쾌하거나 오해를 유발하거나 사기성이라고 느낀 이유를 설명해 주세요.\\n5. %s로 이 내용을 담은 이메일을 보내 주세요. 비밀번호나 결제 정보는 포함하지 마세요. | FAQ answer, a five-step list in one string. `%s` = support email. Keep the numbering and line breaks. | `support_screen.gd` |
| `support.faq.bad_ad.action` | Email Ad Report | 이메일로 광고 신고 | Button that opens a pre-filled ad-report email. | `support_screen.tscn` |
| `support.account_header` | Account | 계정 | Section header above the delete button. | `support_screen.tscn` |
| `support.delete_account` | Delete Account | 계정 삭제 | Opens account deletion (player has an online account). | `support_screen.gd` |
| `support.delete_game_data` | Delete Game Data | 게임 데이터 삭제 | Same button when only local data exists. | `support_screen.gd` |
| `support.no_secrets` | Please never send passwords or payment information. | 비밀번호나 결제 정보는 절대 보내지 마세요. | Warning at the bottom of the screen. | `support_screen.tscn` |

### Account deletion modal

One modal switches between states; each state has a title (caps), a headline, a body and up to two buttons.

| Key | English | 한국어 (Korean) | Context | Source |
| --- | --- | --- | --- | --- |
| `deletion.title.delete_account` | DELETE ACCOUNT | 계정 삭제 | Title: confirm, in progress and unavailable states. | `account_deletion_modal.gd` |
| `deletion.title.delete_game_data` | DELETE GAME DATA | 게임 데이터 삭제 | Title for a player who never had an online account. | same |
| `deletion.title.not_confirmed` | NOT CONFIRMED | 확인되지 않음 | Title: request sent, answer lost. | same |
| `deletion.title.status_unconfirmed` | STATUS UNCONFIRMED | 상태 미확인 | Title: server outcome unknown. | same |
| `deletion.title.finishing_up` | FINISHING UP | 마무리 중 | Title: local cleanup incomplete. | same |
| `deletion.title.new_game` | NEW GAME | 새 게임 | Title while a fresh save is created. | same |
| `deletion.title.status_unknown` | STATUS UNKNOWN | 상태 알 수 없음 | Title: local deletion record unreadable. | same |
| `deletion.title.not_deleted` | NOT DELETED | 삭제되지 않음 | Title after a failed attempt. | same |
| `deletion.title.data_deleted` | DATA DELETED | 데이터 삭제 완료 | Title after local data is deleted. | same |
| `deletion.title.accepted` | DELETION ACCEPTED | 삭제 요청 접수 | Title after the server accepts the request. | same |
| `deletion.confirm.headline` | This permanently deletes your account. | 계정이 영구적으로 삭제됩니다. | Confirm step, online account. | same |
| `deletion.confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nIf you sign in again later, you'll start a new account.\\n\\nSome purchase and security records are kept without your name or profile. The rest is removed within 30 days. | 진행 상황, 코인, 아이템, 프로필이 모두 사라집니다. 이 작업은 되돌릴 수 없습니다.\\n\\n나중에 다시 로그인하면 새 계정으로 시작하게 됩니다.\\n\\n일부 구매 및 보안 기록은 이름이나 프로필 없이 보관됩니다. 나머지 데이터는 30일 이내에 삭제됩니다. | Confirm step body. Keep the three paragraphs. | same |
| `deletion.confirm.button` | Delete Account | 계정 삭제 | Red destructive button. | same |
| `deletion.local_confirm.headline` | This deletes your game data on this device. | 이 기기의 게임 데이터가 삭제됩니다. | Confirm step, local-only player. | same |
| `deletion.local_confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nThis game never created an online account for you, so nothing needs to be deleted from our servers. | 진행 상황, 코인, 아이템, 프로필이 모두 사라집니다. 이 작업은 되돌릴 수 없습니다.\\n\\n이 게임은 온라인 계정을 생성하지 않았으므로 서버에서 삭제할 데이터는 없습니다. | Body for that step. | same |
| `deletion.local_confirm.button` | Delete Data | 데이터 삭제 | Red destructive button. | same |
| `deletion.pending_setup.headline` | Your account is still being set up. | 계정 생성이 아직 완료되지 않았습니다. | Deletion blocked: first registration not finished. | same |
| `deletion.pending_setup.body` | Connect to the internet and try again in a moment. Nothing was deleted. | 인터넷에 연결한 뒤 잠시 후 다시 시도해 주세요. 아무것도 삭제되지 않았습니다. | Body. | same |
| `deletion.sign_in.headline` | Sign in to the account you want to delete. | 삭제하려는 계정으로 로그인해 주세요. | Deletion blocked: signed out. | same |
| `deletion.sign_in.body` | If you can't sign in, contact support for help. | 로그인할 수 없다면 고객지원에 도움을 요청해 주세요. | Body. | same |
| `deletion.read_failed.headline` | Your game data couldn't be read. | 게임 데이터를 읽지 못했습니다. | Deletion blocked: save unreadable. | same |
| `deletion.read_failed.body` | Restart the game, then try again. Nothing was deleted. | 게임을 다시 실행한 뒤 다시 시도해 주세요. 아무것도 삭제되지 않았습니다. | Body. | same |
| `deletion.unavailable.headline` | Account deletion isn't available in this version of the game. | 이 게임 버전에서는 계정을 삭제할 수 없습니다. | Deletion blocked: feature off. Also a failure headline. | same |
| `deletion.unavailable.body` | Update the game, or contact support for help deleting your account. Nothing was deleted. | 게임을 업데이트하거나 고객지원에 계정 삭제를 요청해 주세요. 아무것도 삭제되지 않았습니다. | Body. | same |
| `deletion.in_progress.account` | Deleting your account... | 계정 삭제 중... | Headline while the request runs. | same |
| `deletion.in_progress.local` | Deleting your game data... | 게임 데이터 삭제 중... | Same for local-only data. | same |
| `deletion.in_progress.body` | Keep the game open. This only takes a moment. | 게임을 종료하지 말아 주세요. 잠시만 기다리면 됩니다. | Body while deleting. | same |
| `deletion.not_confirmed.headline` | We haven't heard back about your deletion yet. | 삭제 요청에 대한 응답을 아직 받지 못했습니다. | Request sent, answer lost. | same |
| `deletion.not_confirmed.body` | Your request was sent, but the answer didn't arrive. Connect to the internet and try again. The game stays locked until we know the result. | 요청을 보냈지만 응답을 받지 못했습니다. 인터넷에 연결한 뒤 다시 시도해 주세요. 결과가 확인될 때까지 게임이 잠긴 상태로 유지됩니다. | Body. | same |
| `deletion.unconfirmed.headline` | Deletion status unconfirmed | 삭제 상태 미확인 | Server outcome unknown. | same |
| `deletion.unconfirmed.body` | We couldn't confirm whether your account was deleted. To keep your data safe, the game stays locked. Contact support and include the reference below. | 계정이 삭제되었는지 확인하지 못했습니다. 데이터를 안전하게 보호하기 위해 게임이 잠긴 상태로 유지됩니다. 아래 참조 번호를 포함해 고객지원에 문의해 주세요. | Body; a reference code is shown under it. | same |
| `deletion.check_again` | Check Again | 다시 확인 | Asks the server again. | same |
| `deletion.cleanup.headline.local` | Your local game data couldn't be fully deleted yet. | 기기의 게임 데이터가 아직 완전히 삭제되지 않았습니다. | Local cleanup incomplete (local-only player). | same |
| `deletion.cleanup.headline.account` | Account deletion accepted; finishing cleanup. | 계정 삭제 요청이 접수되었습니다. 기기 내 남은 데이터를 정리 중입니다. | Local cleanup incomplete after the server accepted. | same |
| `deletion.cleanup.body` | Some game data couldn't be removed from this device yet. Try again to finish. | 이 기기의 일부 게임 데이터가 아직 삭제되지 않았습니다. 다시 시도해 삭제를 마무리해 주세요. | Body. | same |
| `deletion.new_game.headline` | Starting a new game... | 새 게임 시작 중... | While a fresh save is created. | same |
| `deletion.new_game.body` | This only takes a moment. | 잠시만 기다리면 됩니다. | Body. | same |
| `deletion.status_unknown.headline` | We couldn't read the deletion status on this device. | 이 기기에서 삭제 상태를 읽지 못했습니다. | Local deletion record unreadable. | same |
| `deletion.status_unknown.body` | To keep your data safe, the game stays locked. Contact support for help. | 데이터를 안전하게 보호하기 위해 게임이 잠긴 상태로 유지됩니다. 고객지원에 도움을 요청해 주세요. | Body. | same |
| `deletion.fail.offline` | Connect to the internet to delete your account. | 계정을 삭제하려면 인터넷에 연결해 주세요. | Failure headline. | same |
| `deletion.fail.rate_limited` | Too many attempts. Wait a moment, then try again. | 시도 횟수가 너무 많습니다. 잠시 기다린 뒤 다시 시도해 주세요. | Failure headline. | same |
| `deletion.fail.busy` | Account deletion is busy right now. Try again in a moment. | 현재 계정 삭제를 처리할 수 없습니다. 잠시 후 다시 시도해 주세요. | Failure headline (server unavailable). | same |
| `deletion.fail.syncing` | The game is still syncing. Try again in a moment. | 게임이 아직 동기화 중입니다. 잠시 후 다시 시도해 주세요. | Failure headline. | same |
| `deletion.fail.auth` | We couldn't verify your account. Restart the game, then try again. | 계정을 확인하지 못했습니다. 게임을 다시 실행한 뒤 다시 시도해 주세요. | Failure headline. | same |
| `deletion.fail.update` | Update the game to delete your account. | 계정을 삭제하려면 게임을 업데이트해 주세요. | Failure headline (client too old). | same |
| `deletion.fail.changed` | Your account changed while we were deleting it. Try again. | 삭제 처리 중 계정이 변경되었습니다. 다시 시도해 주세요. | Failure headline. | same |
| `deletion.fail.storage` | Your device couldn't save the deletion request. Try again. | 기기에 삭제 요청을 저장하지 못했습니다. 다시 시도해 주세요. | Failure headline. | same |
| `deletion.fail.generic` | We couldn't delete your account. Try again later or contact support. | 계정을 삭제하지 못했습니다. 나중에 다시 시도하거나 고객지원에 문의해 주세요. | Failure headline (fallback). | same |
| `deletion.fail.local` | Your game data couldn't be deleted. Try again. | 게임 데이터를 삭제하지 못했습니다. 다시 시도해 주세요. | Failure headline, local-only player. | same |
| `deletion.fail.body` | Nothing was deleted, and you can keep playing. | 아무것도 삭제되지 않았으며, 계속 플레이할 수 있습니다. | Body for every failure. | same |
| `deletion.done_local.headline` | Your local game data was deleted. | 기기의 게임 데이터가 삭제되었습니다. | Success, local-only player. | same |
| `deletion.done_local.body` | You can start over with a new game. | 새 게임으로 처음부터 시작할 수 있습니다. | Body. | same |
| `deletion.new_game_failed` | The new game couldn't start. Try again. | 새 게임을 시작하지 못했습니다. 다시 시도해 주세요. | Appended under a success body if the fresh save failed. | same |
| `deletion.accepted.headline` | Your account is no longer accessible. | 계정에 더 이상 접근할 수 없습니다. | Success, online account. | same |
| `deletion.accepted.body` | Your deletion request was accepted. | 삭제 요청이 접수되었습니다. | Body when no deadline is known. | same |
| `deletion.accepted.body_deadline` | Your deletion request was accepted. Data removal is due by %s. | 삭제 요청이 접수되었습니다. 데이터는 %s까지 삭제됩니다. | Body. `%s` = a date such as "November 2, 2026". | same |
| `deletion.reference` | Reference: %s | 참조 번호: %s | Support reference code under the body. `%s` = operation id; never translated. | same |
| `deletion.start_new_game` | Start New Game | 새 게임 시작 | Button after a successful deletion. | same |

### Platform and system text

| Key | English | 한국어 (Korean) | Context | Source |
| --- | --- | --- | --- | --- |
| `app.name` | SortingPuzzle | SortingPuzzle | App name under the home-screen icon; today the internal project name. Decide the public name per store first. | `project.godot`, `export_presets.cfg` |
| `support.email.subject` | Sorting Puzzle support request | Sorting Puzzle 고객지원 문의 | Subject of the pre-filled support email. | `support_screen.gd` |
| `support.email.body` | Please describe the issue here.\\n\\nDevice/platform:\\nApproximate time:\\n | 여기에 문제를 설명해 주세요.\\n\\n기기/플랫폼:\\n대략적인 발생 시간:\\n | Body template the player fills in. | `support_screen.gd` |
| `support.ad_email.subject` | Sorting Puzzle ad report | Sorting Puzzle 광고 신고 | Subject of the ad-report email. | `support_screen.gd` |
| `support.ad_email.body` | Please attach a screenshot and complete the details below.\\n\\nApproximate time:\\nAd placement in the game:\\nAdvertiser or app name:\\nWhy the ad should be reviewed:\\n | 스크린샷을 첨부하고 아래 내용을 작성해 주세요.\\n\\n대략적인 발생 시간:\\n게임 내 광고 위치:\\n광고주 또는 앱 이름:\\n광고 검토가 필요한 이유:\\n | Body template the player fills in. | `support_screen.gd` |
| `deletion.email.subject` | Sorting Puzzle account deletion | Sorting Puzzle 계정 삭제 | Subject of the deletion help email. | `account_deletion_modal.gd` |
| `deletion.email.body` | Please help me with my account deletion. | 계정 삭제에 도움을 요청합니다. | First line; followed by `Status:`, `Deletion reference:`, `Server reference:` and `Player ID:` lines. | `account_deletion_modal.gd` |

## Additional email field labels

These four labels are explicitly mentioned in the context for `deletion.email.body` and have no individual keys in the source inventory. Only the labels translate; their values stay unchanged.

| English label | 한국어 (Korean) |
| --- | --- |
| Status: | 상태: |
| Deletion reference: | 삭제 참조 번호: |
| Server reference: | 서버 참조 번호: |
| Player ID: | 플레이어 ID: |

## Translation validation

- All 251 keyed inventory entries have a corresponding Korean table entry, with no missing, extra or duplicate keys.
- Every formatting placeholder retains its original type, count and order.
- Every forced line break and paragraph separator retains the source escaping, including the final line break in both support email templates.
- `AD`, `OFF`, `SortingPuzzle` and the count/name pattern `+%d %s` remain unchanged. The dynamic booster name in that pattern should use its Korean product name.
- All 19 combo praise labels contain no more than two words.
- The four additional deletion-help email labels are translated above.
- This is a translation deliverable. Game integration and visual verification remain separate work.
