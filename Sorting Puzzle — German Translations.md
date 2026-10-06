# Sorting Puzzle — German Translations

Locale: `de` (Deutsch) · Prepared: October 6, 2026

Bilingual translation of all **251 keyed entries** in **Sorting Puzzle — Translation String Inventory.md**, including its October 5, 2026 copy updates. The original English, string keys, context and source references are retained. The two unchanged compact markers are included for lookup. This document supplies German copy for review; it does not install translations in the game.

## German terminology

| English | German |
| --- | --- |
| Level | Level |
| Chapter | Kapitel |
| Shelf | Regal |
| Item / goods | Gegenstand / Gegenstände |
| Match / triple / set | Dreiergruppe (three identical items) |
| Combo | Kombo |
| Booster / ability | Booster |
| Hammer | Hammer |
| Shuffle | Mischen |
| Lantern | Laterne |
| Freezer | Zeitstopp |
| Dispenser | Automat |
| Coins | Münzen |
| Stars | Sterne |
| Lives | Leben |
| Reward chest | Belohnungstruhe |
| Bundle | Paket |

## Reading the tables

- The tone is friendly and informal, using **du** when addressing the player.
- Every `%d` and `%s` placeholder keeps its type and order. Dynamic player names, email addresses, prices and reference codes remain unchanged.
- Forced line breaks retain the source document's Markdown escaping (`\\n`). Each marker represents one line break in the game; consecutive markers separate paragraphs.
- Main-table entries use the plural wording where the source says **Needs plural forms**. The appendix supplies both German forms for all six marked keys.
- `ad.badge` stays exactly **AD**. `shop.discount_off` stays exactly **OFF**, so percentage tags such as **67% OFF** remain unchanged.
- The updated home-screen badge **BUNDLE** is **PAKET** (5 characters). **Voll** is 4 characters and **Rangliste** is 9 characters; actual UI fit still needs rendered verification.
- Uppercase titles and banners remain uppercase. The offer names are **Startpaket** and **Basispaket**; their uppercase card forms are **STARTPAKET** and **BASISPAKET**.
- The four booster names are fixed product names and are reused in tooltips and descriptions. **Zeitstopp** names the effect of the Freezer booster. Keep these names unchanged after quantities in booster chips.
- `SortingPuzzle` and `Sorting Puzzle` retain the existing brand spelling. Language names in the picker retain their native spelling.
- Account-deletion copy preserves irreversibility, retained records, the 30-day deadline, blocked states and the explicit statement **Nichts wurde gelöscht.**
- The translations have been checked against the inventory. Text fit has not been verified in rendered game screens; that check belongs to integration.

## Shared buttons, main menu and chapters

Shared buttons appear on several screens and need one translation each, except where the context says the meaning differs. Keys are suggestions for the future translation table.

| Key | English | German | Context | Source |
| --- | --- | --- | --- | --- |
| `common.play` | Play | Spielen | Button that starts the chapter's next level on a chapter card. | `chapter_cover_card.gd` |
| `common.continue` | Continue | Weiter | Button that moves on: closes the level-complete screen, the purchase dialog and the reward chest menu; on a chapter card it resumes a chapter already started. | `level_completion_screen.tscn`, `shop_purchase_dialog`, `reward_chest_menu.tscn`, `chapter_cover_card.gd` |
| `common.resume` | Continue | Weiterspielen | Button on Pause and on the leave confirmation that returns to the running level ("keep playing"). Separate key: some languages use a different verb than for "move on". | `pause_menu.tscn`, `leave_confirmation_menu.tscn` |
| `common.try_again` | Try Again | Erneut versuchen | Retries a failed action (ad, purchase, account deletion). | ad modals, `account_deletion_modal.gd`, `starter_bundle_offer_modal.gd` |
| `common.close` | Close | Schließen | Closes a dialog without doing anything. | `account_deletion_modal.gd` |
| `common.cancel` | Cancel | Abbrechen | Backs out of account deletion; nothing is deleted. | `account_deletion_modal.tscn` |
| `common.got_it` | Got it | Verstanden | Acknowledges an info dialog (ability description, lives already full). | `out_of_lives_menu.tscn`, `shop_screen.gd` |
| `common.get_help` | Get Help | Hilfe erhalten | Opens a pre-filled email to support. | `account_deletion_modal.gd` |
| `common.save` | SAVE | SPEICHERN | Confirms profile edits or the chosen language. All caps by design. | `profile_menu`, `language_selection_modal.tscn` |
| `common.loading` | Loading… | Laden… | Shown while the Shop or Leaderboard loads its data. | `destination_status_panel.tscn` |
| `common.retry_load` | Retry | Neu laden | Reloads the Shop or Leaderboard after a load error. Not the same as replaying a level. | `destination_status_panel.tscn` |
| `menu.level_button` | LEVEL %d | LEVEL %d | Big play button on the home screen. `%d` = level number inside the current chapter. | `production_main_menu.gd` |
| `menu.more_levels_coming_soon` | MORE LEVELS COMING SOON | BALD MEHR LEVEL | Home play button (disabled) after every level of the chapter is finished. Must fit the button, about 24 characters. | `production_main_menu.gd` |
| `menu.coming_soon` | COMING SOON | DEMNÄCHST | Home play button (disabled) when the chapter has no levels yet. | `production_main_menu.gd` |
| `menu.lives_full` | Full | Voll | Top bar, next to the heart, when lives are at maximum; replaces the refill timer. About 5 characters. | `production_main_menu.gd`, `main_menu_top_status.tscn` |
| `menu.starter_badge` | BUNDLE | PAKET | Small badge on the home screen that opens the Starter Bundle offer. About 8 characters. Russian: НАБОР. The full offer title remains Starter Bundle / Стартовый набор. | `main_menu_starter_bundle_badge.tscn` |
| `nav.shop` | Shop | Shop | Bottom navigation tab. About 10 characters. | `main_menu_bottom_navigation.tscn` |
| `nav.home` | Home | Start | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `nav.leaderboard` | Leaderboard | Rangliste | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `chapter.button` | CHAPTER %d | KAPITEL %d | Home button that opens chapter selection. `%d` = chapter number. | `main_menu_chapter_button.gd` |
| `chapter.button_tooltip` | Choose Chapter %d: %s | Kapitel %d wählen: %s | Accessibility tooltip of that button. `%d` = chapter number, `%s` = chapter title. | `main_menu_chapter_button.gd` |
| `chapter.screen_title` | CHAPTERS | KAPITEL | Title of the chapter selection screen. | `chapter_selection_screen.tscn` |
| `chapter.eyebrow` | CHAPTER %d | KAPITEL %d | Small label above the chapter name on its card. | `chapter_cover_card.gd` |
| `chapter.title.chapter_01` | Grocery Town | Marktstädtchen | Name of chapter 1 (a grocery-store theme). | `configs/chapters.json` |
| `chapter.title.chapter_02` | Candy Corner | Naschecke | Name of chapter 2 (a candy-shop theme). | `configs/chapters.json` |
| `chapter.locked_status` | Complete %d more %s levels to unlock | Zum Freischalten noch %d weitere Level in „%s“ abschließen. | Locked chapter card. `%d` = levels still needed, `%s` = previous chapter's name. Needs plural forms. | `chapter_cover_card.gd` |
| `chapter.unlock_progress` | Unlock progress | Freischaltung | Header over the progress bar on a locked chapter. | `chapter_cover_card.gd` |
| `chapter.current_progress` | Current progress | Aktueller Fortschritt | Header over the progress bar on an unlocked chapter. | `chapter_cover_card.gd` |
| `chapter.locked` | Locked | Gesperrt | Disabled button on a locked chapter card. | `chapter_cover_card.gd` |
| `chapter.no_levels_status` | New levels are coming soon | Neue Level kommen demnächst | Card message for a chapter with no levels yet. | `chapter_cover_card.gd` |
| `chapter.coming_soon` | Coming Soon | Demnächst | Disabled button on that card. | `chapter_cover_card.gd` |

## Gameplay: HUD, level screens and results

These strings show during a level, mostly in modal titles (all caps, short) and action buttons. A "triple" or "match" is three identical items on one shelf, which clears them.

| Key | English | German | Context | Source |
| --- | --- | --- | --- | --- |
| `hud.level` | LEVEL %d | LEVEL %d | Top HUD during play. `%d` = level number inside the chapter. | `level.gd` |
| `hud.combo` | COMBO ×%d | KOMBO ×%d | HUD counter for consecutive quick matches. `%d` = combo size; keep the × sign. | `level_top_hud.gd` |
| `hud.ability_tooltip.hammer` | Hammer -- clears a matching triple | Hammer -- entfernt eine Dreiergruppe | Accessibility tooltip on the Hammer booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.shuffle` | Shuffle -- reshuffles unlocked items | Mischen -- mischt Gegenstände auf freigeschalteten Regalen neu | Tooltip on the Shuffle booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.lantern` | Lantern -- highlights a matchable triple | Laterne -- markiert eine mögliche Dreiergruppe | Tooltip on the Lantern booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.freezer` | Freezer -- pauses the countdown timer | Zeitstopp -- hält den Countdown an | Tooltip on the Freezer booster button. | `ability_bar.tscn` |
| `hud.seconds_short` | %ds | %d s | Countdown on an active Lantern or Freezer booster, e.g. "15s". `%d` = seconds; use the local short unit. | `ability_bar.gd` |
| `tip.tap_dispenser` | Tap a dispenser to throw items onto the shelves! | Tippe auf einen Automaten, damit er Gegenstände auf die Regale wirft! | Tutorial bubble on level 10, where dispensers (machines that throw items onto shelves) first appear. | `configs/gameplay_tips.json` |
| `pause.title` | PAUSE | PAUSE | Title of the in-level pause modal. | `pause_menu.gd` |
| `pause.leave` | Leave | Verlassen | Pause button that quits the level (asks for confirmation next). | `pause_menu.tscn` |
| `leave.title` | LEAVING THE LEVEL | LEVEL VERLASSEN | Title of the leave confirmation. | `leave_confirmation_menu.gd` |
| `leave.you_will_lose` | You will lose: | Du verlierst: | Followed by icons showing the stars earned this run and one life. Keep the colon (or local equivalent). | `leave_confirmation_menu.tscn` |
| `leave.confirm` | Leave | Verlassen | Confirms quitting the level and losing that progress. | `leave_confirmation_menu.tscn` |
| `timeup.title` | TIME'S UP | ZEIT UM | Title when the level timer reaches zero. | `time_up_extension_modal.gd` |
| `timeup.offer` | Add one minute and keep sorting! | Hol dir eine zusätzliche Minute und sortiere weiter! | Offer to extend the timer by 60 seconds for coins or an ad. | `time_up_extension_modal.tscn` |
| `timeup.used` | Used | Genutzt | Shown on the coin price or ad button when that extension was already used this level. | `time_up_extension_modal.gd` |
| `ability_purchase.title` | USE ABILITY | BOOSTER NUTZEN | Title of the modal that buys and immediately uses one booster when the player has none. | `ability_purchase_menu.gd` |
| `shelf_unlock.title` | UNLOCK SHELF | REGAL FREISCHALTEN | Title of the modal for a locked shelf. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer` | Watch one ad to unlock this shelf now. | Sieh dir eine Werbung an, um dieses Regal jetzt freizuschalten. | Body when no other way to unlock remains. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer_or_clear` | Watch one ad to unlock this shelf now, or clear %s more. | Sieh dir eine Werbung an, um dieses Regal jetzt freizuschalten, oder entferne noch %s Dreiergruppen. | Body when the shelf also unlocks by itself after more matches. `%s` = matches still needed. Needs plural forms. | `shelf_unlock_menu.gd` |
| `shelf_unlock.button` | Watch Ad · Unlock Shelf | Werbung ansehen · Regal freischalten | Ad button in that modal. | `shelf_unlock_menu.gd` |
| `shelf_unlock.ad_unavailable` | Ad unavailable. This shelf stays locked. | Werbung nicht verfügbar. Dieses Regal bleibt gesperrt. | Status line when no ad could be shown. | `shelf_unlock_menu.gd` |
| `complete.title` | GREAT JOB! | GUT GEMACHT! | Title of the level-complete screen, above the stars earned. | `level_completion_screen.gd` |
| `failed.title` | LEVEL %d | LEVEL %d | Title of the level-failed screen. `%d` = level number. | `level_failure_screen.gd` |
| `failed.headline` | LEVEL FAILED | LEVEL GESCHEITERT | Banner on the level-failed screen. | `level_failure_screen.tscn` |
| `failed.retry` | Retry | Nochmal spielen | Replays the same level. | `level_failure_screen.tscn` |

Combo praise pops up above a match during a combo; each word is stronger than the one before, so keep the escalation. The label shrinks its font for long words, but one or two words is the limit.

| Key | English | German | Shown at |
| --- | --- | --- | --- |
| `combo.praise.2` | Cool | Cool | Combo ×2 |
| `combo.praise.3` | Great | Toll | ×3 |
| `combo.praise.4` | Awesome | Klasse | ×4 |
| `combo.praise.5` | Amazing | Großartig | ×5 |
| `combo.praise.6` | Fantastic | Fantastisch | ×6 |
| `combo.praise.7` | Incredible | Unglaublich | ×7 |
| `combo.praise.8` | Spectacular | Spektakulär | ×8 |
| `combo.praise.9` | Unstoppable | Unaufhaltsam | ×9 |
| `combo.praise.10` | Legendary | Legendär | ×10 |
| `combo.praise.11` | Epic | Episch | ×11 |
| `combo.praise.12` | Brilliant | Brillant | ×12 |
| `combo.praise.13` | Masterful | Meisterhaft | ×13 |
| `combo.praise.14` | Supreme | Unübertroffen | ×14 |
| `combo.praise.15` | Phenomenal | Phänomenal | ×15 |
| `combo.praise.16` | Mythic | Sagenhaft | ×16 |
| `combo.praise.17` | Majestic | Majestätisch | ×17 |
| `combo.praise.18` | Radiant | Glanzvoll | ×18 |
| `combo.praise.19` | Divine | Göttlich | ×19 |
| `combo.praise.20` | Transcendent | Überirdisch | ×20 and above |

Source: `COMBO_PRAISE_WORDS` in `level.gd`.

## Boosters, ads, lives, rewards and shop

The four boosters (also called abilities in code) are product names: pick one translation per language and reuse it everywhere, including the tooltips in the gameplay section.

| Key | English | German | Context | Source |
| --- | --- | --- | --- | --- |
| `ability.hammer.name` | Hammer | Hammer | Booster that smashes away one matching set. | `reward_reveal_row.tscn`, `starter_bundle_offer_modal.tscn`, `shop_screen.gd` |
| `ability.shuffle.name` | Shuffle | Mischen | Booster that rearranges items. | same |
| `ability.lantern.name` | Lantern | Laterne | Booster that lights up a set the player can match (internal id `highlight`). | same |
| `ability.freezer.name` | Freezer | Zeitstopp | Booster that stops the level timer. | same |
| `ability.hammer.description` | Instantly clears one matching set of items off the shelves. | Entfernt sofort eine Dreiergruppe gleicher Gegenstände von den Regalen. | Shop info dialog body after tapping the booster icon. | `shop_screen.gd` |
| `ability.shuffle.description` | Shuffles shelf items into new spots to help you find a match. | Verteilt die Gegenstände auf den Regalen neu, damit du leichter eine Dreiergruppe findest. | Same dialog. | `shop_screen.gd` |
| `ability.lantern.description` | Highlights a matching triple you can clear for 15 seconds. | Markiert 15 Sekunden lang eine Dreiergruppe, die du entfernen kannst. | Same dialog. Keep the number in sync with the game config. | `shop_screen.gd` |
| `ability.freezer.description` | Freezes the level timer for 30 seconds. | Hält den Leveltimer für 30 Sekunden an. | Same dialog. | `shop_screen.gd` |
| `ad.watch` | Watch Ad | Werbung ansehen | Button that plays a rewarded video ad. | ad modals, `out_of_lives_menu`, `ability_purchase_menu.tscn` |
| `ad.loading` | Loading... | Laden... | Ad button while the ad loads. | ad modals |
| `ad.verifying` | Verifying... | Prüfen... | Ad button while the server confirms the reward. | ad modals |
| `ad.verify_reward` | Verify Reward | Belohnung prüfen | Ad button to re-check a reward the server has not confirmed yet. | ad modals |
| `ad.reward_pending` | Reward verification is still pending. | Die Bestätigung der Belohnung steht noch aus. | Status line under that button. | `out_of_lives_menu.gd`, `shelf_unlock_menu.gd` |
| `ad.unavailable_retry` | Ad unavailable. Please try again. | Werbung nicht verfügbar. Bitte versuche es erneut. | Status line when no ad could be shown. | `out_of_lives_menu` |
| `ad.watch_unavailable` | Watch Ad\\nUnavailable | Werbung ansehen\\nNicht verfügbar | Two-line disabled ad button (time-up modal). Keep the line break. | `time_up_extension_modal.gd` |
| `ad.watch_coming_soon` | Watch Ad\\nComing Soon | Werbung ansehen\\nDemnächst | Two-line disabled ad button before ads launch. | `time_up_extension_modal.tscn` |
| `ad.badge` | AD | AD | Tiny badge on a locked shelf that an ad can open. Do not translate: keep AD exactly in every language. | `shelf_lock_overlay.tscn`, `shelf_unlock_menu.tscn` |
| `lives.title.out` | OUT OF LIVES | KEINE LEBEN MEHR | Lives modal title at 0 lives. | `out_of_lives_menu.gd` |
| `lives.title.get_more` | GET MORE LIVES | MEHR LEBEN | Lives modal title with some lives left. | `out_of_lives_menu.gd` |
| `lives.title.full` | LIVES FULL | LEBEN AUFGEFÜLLT | Lives modal title at maximum lives. | `out_of_lives_menu.gd` |
| `lives.next_in` | NEXT LIFE IN | NÄCHSTES LEBEN IN | Label above the refill countdown (mm:ss). | `out_of_lives_menu.tscn` |
| `lives.full_body` | Your lives are full! Play a level to spend them. | Deine Leben sind voll aufgefüllt! Spiele ein Level, um sie zu nutzen. | Body of the lives modal at maximum. | `out_of_lives_menu.tscn` |
| `chest.title` | CHEST REWARDS | TRUHENBELOHNUNGEN | Title of the reward chest modal. | `reward_chest_menu.tscn` |
| `chest.progress_hint` | Collect stars to unlock a chest and claim your reward | Sammle Sterne, um eine Truhe freizuschalten und deine Belohnung abzuholen | Under the star progress bar (e.g. 12/30). | `reward_chest_menu.tscn` |
| `chest.ready` | A REWARD CHEST AWAITS! | EINE BELOHNUNGSTRUHE WARTET! | Banner when the chest is full and can be opened. | `reward_chest_menu.tscn` |
| `chest.tap_to_open` | Tap to open | Zum Öffnen tippen | Prompt under the closed chest in the opening animation. | `reward_chest_open_ceremony.tscn` |
| `purchase.tap_to_collect` | Tap to collect | Zum Abholen tippen | Prompt to collect purchased rewards. | `purchase_reward_sequence.tscn` |
| `purchase.complete` | PURCHASE COMPLETE | KAUF ABGESCHLOSSEN | Banner after a successful purchase. | `purchase_reward_sequence.gd` |
| `shop.title` | SHOP | SHOP | Shop screen title. | `shop_screen.tscn` |
| `shop.section.bundles` | SPECIAL BUNDLES | SPEZIALPAKETE | Section header. | `shop_screen.tscn` |
| `shop.section.coins` | COINS | MÜNZEN | Section header for coin packs. | `shop_screen.tscn` |
| `shop.offer.starter_bundle` | Starter Bundle | Startpaket | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.offer.basic_bundle` | Basic Bundle | Basispaket | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.tag.best_value` | BEST VALUE | BESTES ANGEBOT | Ribbon on the best coin pack. | `configs/shop_catalog.json` |
| `shop.discount_off` | OFF | OFF | Second line of the discount badge under "67%". Do not translate: keep the complete 67% OFF tag unchanged in every language; the numeric percentage can vary by offer. | `shop_bundle_card.tscn`, `starter_bundle_offer_modal.tscn` |
| `shop.ability_hint` | Tap an ability to see what it does | Tippe auf einen Booster, um zu sehen, was er macht | Hint under a bundle's booster icons. | `shop_bundle_card.tscn` |
| `shop.purchasing` | Purchasing… | Kauf läuft… | Buy button while a purchase is in progress. | shop cards, `production_main_menu.gd` |
| `shop.no_offers` | No shop offers are available for this region. | Für diese Region sind keine Angebote im Shop verfügbar. | Shop error state. | `shop_screen.gd` |
| `shop.load_failed` | Could not load the shop. | Der Shop konnte nicht geladen werden. | Shop error state (fallback text). | `shop_screen.gd` |
| `shop.error.title.purchase` | Purchase unavailable | Kauf nicht verfügbar | Error dialog title when buying failed. | `shop_screen.gd` |
| `shop.error.title.reward` | Reward error | Fehler bei der Belohnung | Error dialog title when payment went through but rewards were not granted. | `shop_screen.gd` |
| `shop.error.purchase_failed` | The purchase could not be completed. | Der Kauf konnte nicht abgeschlossen werden. | Error dialog body (fallback). | `shop_screen.gd`, `production_main_menu.gd` |
| `shop.error.grant_failed` | The purchased rewards could not be granted. | Die gekauften Belohnungen konnten nicht gutgeschrieben werden. | Error dialog body. | `store/shop_purchase_flow.gd` |
| `shop.error.offer_unavailable` | This shop offer is unavailable. | Dieses Angebot im Shop ist nicht verfügbar. | Error dialog body. | `store/store_service.gd` |
| `shop.error.already_bought` | This one-time shop offer has already been purchased. | Dieses einmalige Angebot im Shop wurde bereits gekauft. | Error dialog body. | `store/store_service.gd` |
| `starter.title` | STARTER BUNDLE | STARTPAKET | Starter offer modal title. | `starter_bundle_offer_modal.gd` |
| `starter.one_time` | ONE-TIME OFFER | EINMALIGES ANGEBOT | Ribbon on the starter offer. | `starter_bundle_offer_modal.tscn` |
| `starter.boosters_included` | BOOSTERS INCLUDED | BOOSTER ENTHALTEN | Header over the four booster chips. | `starter_bundle_offer_modal.tscn` |
| `starter.coins` | %s COINS | %s MÜNZEN | Ribbon over the coin art. `%s` = formatted amount, e.g. "1,000". Needs plural forms. | `starter_bundle_offer_modal.gd` |
| `starter.buy_for` | Buy for %s | Für %s kaufen | Buy button. `%s` = store price, e.g. "$4.99". | `starter_bundle_offer_modal.gd` |
| `starter.checking` | Checking offer… | Angebot wird geprüft… | Status while the store confirms the offer. | `production_main_menu.gd` |
| `starter.checking_short` | Checking… | Prüfen… | Buy button during that check. | `starter_bundle_offer_modal.gd` |
| `starter.no_longer_available` | This offer is no longer available. | Dieses Angebot ist nicht mehr verfügbar. | Error status in the starter modal. | `production_main_menu.gd` |
| `starter.unavailable` | Unavailable | Nicht verfügbar | Disabled buy button after a non-retryable error. | `starter_bundle_offer_modal.gd` |
| `booster_chip.claimed` | +%d %s | +%d %s | Booster chip after purchase, e.g. "+3 Hammer". `%d` = count, `%s` = booster name. Needs plural forms. | `offer_booster_chip.gd` |

## Profile, leaderboard and settings

Language names in the language picker stay in their own language (English, Español, 日本語…) and are never translated.

| Key | English | German | Context | Source |
| --- | --- | --- | --- | --- |
| `profile.title` | EDIT PROFILE | PROFIL BEARBEITEN | Profile modal title. | `profile_menu.tscn` |
| `profile.name_header` | PLAYER NAME | SPIELERNAME | Header over the name field. | `profile_menu.tscn` |
| `profile.name_placeholder` | Player name | Spielername | Placeholder inside the empty name field. | `profile_menu.tscn` |
| `profile.edit_name_tooltip` | Edit player name | Spielernamen bearbeiten | Accessibility tooltip on the pencil button. | `profile_menu.tscn` |
| `profile.avatar_tab` | AVATAR | AVATAR | Tab that shows avatar pictures. | `profile_menu.tscn` |
| `profile.frame_tab` | FRAME | RAHMEN | Tab that shows decorative frames around the avatar. | `profile_menu.tscn` |
| `profile.unlock.level` | Complete level %d to unlock | Zum Freischalten Level %d abschließen | Toast after tapping a locked frame. `%d` = level number. | `profile_menu.gd` |
| `profile.unlock.combo` | Reach a combo of ×%d in any run to unlock | Zum Freischalten in einem Level eine Kombo von ×%d erreichen | Same toast. `%d` = combo size. | `profile_menu.gd` |
| `profile.unlock.weekly_first` | Finish 1st on the Weekly leaderboard to unlock | Zum Freischalten Platz 1 in der Wochenrangliste erreichen | Same toast for a first-place frame. Today built from two parts; see implementation notes. | `profile_menu.gd` |
| `profile.unlock.weekly_top` | Finish top %d on the Weekly leaderboard to unlock | Zum Freischalten die Top %d der Wochenrangliste erreichen | Same toast. `%d` = rank cutoff (e.g. 10). | `profile_menu.gd` |
| `leaderboard.title` | LEADERBOARD | RANGLISTE | Leaderboard screen title. | `leaderboard_screen.tscn` |
| `leaderboard.tab.weekly` | Weekly | Woche | Tab: this week's stars. | `leaderboard_screen.tscn` |
| `leaderboard.tab.country` | Country | Land | Tab: all-time stars in the player's country. | `leaderboard_screen.tscn` |
| `leaderboard.tab.world` | World | Welt | Tab: all-time stars worldwide. | `leaderboard_screen.tscn` |
| `leaderboard.weekly_reset` | Weekly reset in %s | Wochenreset in %s | Under the Weekly tab. `%s` = a duration such as "1d 4h". | `leaderboard_screen.gd` |
| `leaderboard.duration.dh` | %dd %dh | %d T %d Std | Duration: days and hours. Use local unit abbreviations. | `leaderboard_screen.gd` |
| `leaderboard.duration.hm` | %dh %dm | %d Std %d Min | Duration: hours and minutes. | `leaderboard_screen.gd` |
| `leaderboard.duration.m` | %dm | %d Min | Duration: minutes. | `leaderboard_screen.gd` |
| `leaderboard.country_caption` | Country · All-time stars | Land · Sterne insgesamt | Caption under the Country tab. | `leaderboard_screen.gd` |
| `leaderboard.world_caption` | Worldwide · All-time stars | Weltweit · Sterne insgesamt | Caption under the World tab. | `leaderboard_screen.gd` |
| `leaderboard.load_failed` | Could not load leaderboard. | Die Rangliste konnte nicht geladen werden. | Error state (fallback text). | `leaderboard_screen.gd` |
| `leaderboard.default_name` | Player | Spieler | Name shown for a player without one. | `leaderboard_row.gd` |
| `leaderboard.row_tooltip` | Rank %d, %s, %d stars | Rang %d, %s, %d Sterne | Accessibility text of a row. `%d` = rank, `%s` = player name, `%d` = stars. Needs plural forms. | `leaderboard_row.gd` |
| `leaderboard.reward_tooltip` | %s coin weekly reward | Wochenbelohnung in Münzen: %s | Accessibility text on the coin prize next to top ranks. `%s` = amount. | `leaderboard_rank_reward.gd` |
| `leaderboard.reward.title` | WEEKLY REWARD! | WOCHENBELOHNUNG! | Title of the dialog shown after a week ends. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.body` | You finished #%d last week and earned %d coins! | Letzte Woche hast du Platz %d erreicht und %d Münzen verdient! | Body. `%d` = final rank, `%d` = coins. Needs plural forms. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.ok` | Nice! | Super! | Button that closes the reward dialog. | `leaderboard_reward_dialog.tscn` |
| `settings.title` | SETTINGS | EINSTELLUNGEN | Settings modal title (home screen). | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.music` | Music | Musik | Toggle label under an icon. Short, about 8 characters. | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.sfx` | SFX | Klänge | Toggle for sound effects. Use a short local word for "Sounds". | same |
| `settings.vibrate` | Vibrate | Vibration | Toggle for haptic feedback. | same |
| `settings.support` | Support | Support | Opens the Support screen. | `settings_menu.tscn` |
| `settings.language` | Language | Sprache | Opens the language picker. | `settings_menu.tscn`, `language_option_row.tscn` |
| `settings.privacy_policy` | Privacy Policy | Datenschutzerklärung | Opens the privacy policy web page. | `settings_menu.tscn`, `production_main_menu.gd` |
| `settings.privacy_choices` | Privacy Choices | Datenschutzoptionen | Same button when the ad consent form must be offered (EU/UK). | `production_main_menu.gd` |
| `settings.diagnostics` | Version %s • Build %d\\nPlatform: %s • User: %s | Version %s • Build %d\\nPlattform: %s • Nutzer: %s | Small footer for support. Values: app version, build number, OS name, short player id. Translating the four labels is optional. | `pause_menu.gd` |
| `language.title` | LANGUAGE | SPRACHE | Language picker title. | `language_selection_modal.gd` |

## Support, account deletion and platform text

Support and deletion copy is legal-adjacent: translate meaning exactly, keep "Nothing was deleted" and "You can't undo this" unambiguous, and do not soften the warnings.

### Support screen

| Key | English | German | Context | Source |
| --- | --- | --- | --- | --- |
| `support.title` | SUPPORT | SUPPORT | Support screen title. | `support_screen.tscn` |
| `support.faq_header` | Frequently Asked Questions | Häufige Fragen | Section header. | `support_screen.tscn` |
| `support.faq.play.q` | How do I play? | Wie spiele ich? | FAQ question (tap to expand). | `support_screen.tscn` |
| `support.faq.play.a` | Move matching goods onto the same shelf. When three identical items are visible together, they clear. Complete the board before time runs out. | Verschiebe gleiche Gegenstände auf dasselbe Regal. Sobald drei gleiche Gegenstände zusammen sichtbar sind, verschwinden sie. Räume das Spielfeld ab, bevor die Zeit abläuft. | FAQ answer. "Goods" = shop items such as snacks and toys. | `support_screen.tscn` |
| `support.faq.contact.q` | How do I contact support? | Wie erreiche ich den Support? | FAQ question. | `support_screen.tscn` |
| `support.faq.contact.a` | Email us at %s. Include a short description, your device platform, and when the problem happened. | Schreib uns eine E-Mail an %s. Beschreibe kurz das Problem und nenne die Plattform deines Geräts sowie den Zeitpunkt, zu dem es aufgetreten ist. | FAQ answer. `%s` = support email address. | `support_screen.gd` |
| `support.faq.contact.action` | Email Support | Support anschreiben | Button that opens a pre-filled email. | `support_screen.tscn` |
| `support.faq.crash.q` | What if the game freezes or crashes? | Was tun, wenn das Spiel hängen bleibt oder abstürzt? | FAQ question. | `support_screen.tscn` |
| `support.faq.crash.a` | Close and reopen the game first. If it happens again, restart the device and make sure the game is updated. Contact support with the device model, platform version, and what you were doing before the problem. | Schließe zuerst das Spiel und öffne es erneut. Falls das Problem wieder auftritt, starte dein Gerät neu und prüfe, ob das Spiel auf dem neuesten Stand ist. Nenne dem Support dein Gerätemodell, die Version deines Betriebssystems und was du vor dem Problem gemacht hast. | FAQ answer. | `support_screen.tscn` |
| `support.faq.sync.q` | How do I sync progress between devices? | Wie synchronisiere ich meinen Fortschritt zwischen Geräten? | FAQ question. | `support_screen.tscn` |
| `support.faq.sync.a` | Use the same signed-in platform account on both devices and allow synchronization to finish before playing. If the progress differs, avoid playing on both devices and contact support. | Melde dich auf beiden Geräten mit demselben Plattformkonto an und warte, bis die Synchronisierung abgeschlossen ist, bevor du spielst. Wenn sich der Fortschritt unterscheidet, spiele nicht auf beiden Geräten weiter und kontaktiere den Support. | FAQ answer. "Platform account" = Google Play Games / Game Center. | `support_screen.tscn` |
| `support.faq.bad_ad.q` | How do I report a bad ad? | Wie melde ich eine problematische Werbung? | FAQ question. | `support_screen.tscn` |
| `support.faq.bad_ad.a` | 1. Close the ad if you can do so safely.\\n2. Take a screenshot of the ad and any advertiser or app name shown.\\n3. Note the approximate time and where the ad appeared in the game.\\n4. Describe why the ad seemed offensive, misleading, or fraudulent.\\n5. Email these details to %s. Do not include passwords or payment information. | 1. Schließe die Werbung, wenn das sicher möglich ist.\\n2. Mache einen Screenshot der Werbung und aller angezeigten Namen des Werbetreibenden oder der App.\\n3. Notiere den ungefähren Zeitpunkt und wo die Werbung im Spiel erschienen ist.\\n4. Beschreibe, warum die Werbung anstößig, irreführend oder betrügerisch wirkte.\\n5. Sende diese Angaben per E-Mail an %s. Gib keine Passwörter oder Zahlungsdaten an. | FAQ answer, a five-step list in one string. `%s` = support email. Keep the numbering and line breaks. | `support_screen.gd` |
| `support.faq.bad_ad.action` | Email Ad Report | Werbung per E-Mail melden | Button that opens a pre-filled ad-report email. | `support_screen.tscn` |
| `support.account_header` | Account | Konto | Section header above the delete button. | `support_screen.tscn` |
| `support.delete_account` | Delete Account | Konto löschen | Opens account deletion (player has an online account). | `support_screen.gd` |
| `support.delete_game_data` | Delete Game Data | Spieldaten löschen | Same button when only local data exists. | `support_screen.gd` |
| `support.no_secrets` | Please never send passwords or payment information. | Sende bitte niemals Passwörter oder Zahlungsdaten. | Warning at the bottom of the screen. | `support_screen.tscn` |

### Account deletion modal

One modal switches between states; each state has a title (caps), a headline, a body and up to two buttons.

| Key | English | German | Context | Source |
| --- | --- | --- | --- | --- |
| `deletion.title.delete_account` | DELETE ACCOUNT | KONTO LÖSCHEN | Title: confirm, in progress and unavailable states. | `account_deletion_modal.gd` |
| `deletion.title.delete_game_data` | DELETE GAME DATA | SPIELDATEN LÖSCHEN | Title for a player who never had an online account. | same |
| `deletion.title.not_confirmed` | NOT CONFIRMED | NICHT BESTÄTIGT | Title: request sent, answer lost. | same |
| `deletion.title.status_unconfirmed` | STATUS UNCONFIRMED | STATUS UNBESTÄTIGT | Title: server outcome unknown. | same |
| `deletion.title.finishing_up` | FINISHING UP | WIRD ABGESCHLOSSEN | Title: local cleanup incomplete. | same |
| `deletion.title.new_game` | NEW GAME | NEUES SPIEL | Title while a fresh save is created. | same |
| `deletion.title.status_unknown` | STATUS UNKNOWN | STATUS UNBEKANNT | Title: local deletion record unreadable. | same |
| `deletion.title.not_deleted` | NOT DELETED | NICHT GELÖSCHT | Title after a failed attempt. | same |
| `deletion.title.data_deleted` | DATA DELETED | DATEN GELÖSCHT | Title after local data is deleted. | same |
| `deletion.title.accepted` | DELETION ACCEPTED | LÖSCHANTRAG ANGENOMMEN | Title after the server accepts the request. | same |
| `deletion.confirm.headline` | This permanently deletes your account. | Dadurch wird dein Konto dauerhaft gelöscht. | Confirm step, online account. | same |
| `deletion.confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nIf you sign in again later, you'll start a new account.\\n\\nSome purchase and security records are kept without your name or profile. The rest is removed within 30 days. | Dein Fortschritt, deine Münzen, Gegenstände und dein Profil werden gelöscht. Das kannst du nicht rückgängig machen.\\n\\nWenn du dich später wieder anmeldest, beginnst du mit einem neuen Konto.\\n\\nEinige Kauf- und Sicherheitsaufzeichnungen werden ohne deinen Namen oder dein Profil aufbewahrt. Die übrigen Daten werden innerhalb von 30 Tagen gelöscht. | Confirm step body. Keep the three paragraphs. | same |
| `deletion.confirm.button` | Delete Account | Konto löschen | Red destructive button. | same |
| `deletion.local_confirm.headline` | This deletes your game data on this device. | Dadurch werden deine Spieldaten auf diesem Gerät gelöscht. | Confirm step, local-only player. | same |
| `deletion.local_confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nThis game never created an online account for you, so nothing needs to be deleted from our servers. | Dein Fortschritt, deine Münzen, Gegenstände und dein Profil werden gelöscht. Das kannst du nicht rückgängig machen.\\n\\nFür dich wurde in diesem Spiel nie ein Onlinekonto erstellt. Deshalb muss auf unseren Servern nichts gelöscht werden. | Body for that step. | same |
| `deletion.local_confirm.button` | Delete Data | Daten löschen | Red destructive button. | same |
| `deletion.pending_setup.headline` | Your account is still being set up. | Dein Konto wird noch eingerichtet. | Deletion blocked: first registration not finished. | same |
| `deletion.pending_setup.body` | Connect to the internet and try again in a moment. Nothing was deleted. | Verbinde dich mit dem Internet und versuche es gleich noch einmal. Nichts wurde gelöscht. | Body. | same |
| `deletion.sign_in.headline` | Sign in to the account you want to delete. | Melde dich bei dem Konto an, das du löschen möchtest. | Deletion blocked: signed out. | same |
| `deletion.sign_in.body` | If you can't sign in, contact support for help. | Wenn du dich nicht anmelden kannst, wende dich an den Support. | Body. | same |
| `deletion.read_failed.headline` | Your game data couldn't be read. | Deine Spieldaten konnten nicht gelesen werden. | Deletion blocked: save unreadable. | same |
| `deletion.read_failed.body` | Restart the game, then try again. Nothing was deleted. | Starte das Spiel neu und versuche es dann erneut. Nichts wurde gelöscht. | Body. | same |
| `deletion.unavailable.headline` | Account deletion isn't available in this version of the game. | Die Kontolöschung ist in dieser Spielversion nicht verfügbar. | Deletion blocked: feature off. Also a failure headline. | same |
| `deletion.unavailable.body` | Update the game, or contact support for help deleting your account. Nothing was deleted. | Aktualisiere das Spiel oder bitte den Support um Hilfe beim Löschen deines Kontos. Nichts wurde gelöscht. | Body. | same |
| `deletion.in_progress.account` | Deleting your account... | Dein Konto wird gelöscht... | Headline while the request runs. | same |
| `deletion.in_progress.local` | Deleting your game data... | Deine Spieldaten werden gelöscht... | Same for local-only data. | same |
| `deletion.in_progress.body` | Keep the game open. This only takes a moment. | Lass das Spiel geöffnet. Das dauert nur einen Moment. | Body while deleting. | same |
| `deletion.not_confirmed.headline` | We haven't heard back about your deletion yet. | Wir haben noch keine Rückmeldung zu deiner Löschung erhalten. | Request sent, answer lost. | same |
| `deletion.not_confirmed.body` | Your request was sent, but the answer didn't arrive. Connect to the internet and try again. The game stays locked until we know the result. | Dein Antrag wurde gesendet, aber die Antwort ist nicht angekommen. Verbinde dich mit dem Internet und versuche es erneut. Das Spiel bleibt gesperrt, bis wir das Ergebnis kennen. | Body. | same |
| `deletion.unconfirmed.headline` | Deletion status unconfirmed | Löschstatus unbestätigt | Server outcome unknown. | same |
| `deletion.unconfirmed.body` | We couldn't confirm whether your account was deleted. To keep your data safe, the game stays locked. Contact support and include the reference below. | Wir konnten nicht bestätigen, ob dein Konto gelöscht wurde. Zum Schutz deiner Daten bleibt das Spiel gesperrt. Kontaktiere den Support und gib die Referenz unten an. | Body; a reference code is shown under it. | same |
| `deletion.check_again` | Check Again | Erneut prüfen | Asks the server again. | same |
| `deletion.cleanup.headline.local` | Your local game data couldn't be fully deleted yet. | Deine lokalen Spieldaten konnten noch nicht vollständig gelöscht werden. | Local cleanup incomplete (local-only player). | same |
| `deletion.cleanup.headline.account` | Account deletion accepted; finishing cleanup. | Kontolöschung angenommen. Die Bereinigung wird abgeschlossen. | Local cleanup incomplete after the server accepted. | same |
| `deletion.cleanup.body` | Some game data couldn't be removed from this device yet. Try again to finish. | Einige Spieldaten konnten noch nicht von diesem Gerät entfernt werden. Versuche es erneut, um den Vorgang abzuschließen. | Body. | same |
| `deletion.new_game.headline` | Starting a new game... | Ein neues Spiel wird gestartet... | While a fresh save is created. | same |
| `deletion.new_game.body` | This only takes a moment. | Das dauert nur einen Moment. | Body. | same |
| `deletion.status_unknown.headline` | We couldn't read the deletion status on this device. | Wir konnten den Löschstatus auf diesem Gerät nicht lesen. | Local deletion record unreadable. | same |
| `deletion.status_unknown.body` | To keep your data safe, the game stays locked. Contact support for help. | Zum Schutz deiner Daten bleibt das Spiel gesperrt. Bitte den Support um Hilfe. | Body. | same |
| `deletion.fail.offline` | Connect to the internet to delete your account. | Verbinde dich mit dem Internet, um dein Konto zu löschen. | Failure headline. | same |
| `deletion.fail.rate_limited` | Too many attempts. Wait a moment, then try again. | Zu viele Versuche. Warte einen Moment und versuche es dann erneut. | Failure headline. | same |
| `deletion.fail.busy` | Account deletion is busy right now. Try again in a moment. | Die Kontolöschung ist gerade nicht verfügbar. Versuche es gleich noch einmal. | Failure headline (server unavailable). | same |
| `deletion.fail.syncing` | The game is still syncing. Try again in a moment. | Das Spiel wird noch synchronisiert. Versuche es gleich noch einmal. | Failure headline. | same |
| `deletion.fail.auth` | We couldn't verify your account. Restart the game, then try again. | Wir konnten dein Konto nicht verifizieren. Starte das Spiel neu und versuche es dann erneut. | Failure headline. | same |
| `deletion.fail.update` | Update the game to delete your account. | Aktualisiere das Spiel, um dein Konto zu löschen. | Failure headline (client too old). | same |
| `deletion.fail.changed` | Your account changed while we were deleting it. Try again. | Dein Konto hat sich während der Löschung geändert. Versuche es erneut. | Failure headline. | same |
| `deletion.fail.storage` | Your device couldn't save the deletion request. Try again. | Dein Gerät konnte den Löschantrag nicht speichern. Versuche es erneut. | Failure headline. | same |
| `deletion.fail.generic` | We couldn't delete your account. Try again later or contact support. | Wir konnten dein Konto nicht löschen. Versuche es später erneut oder kontaktiere den Support. | Failure headline (fallback). | same |
| `deletion.fail.local` | Your game data couldn't be deleted. Try again. | Deine Spieldaten konnten nicht gelöscht werden. Versuche es erneut. | Failure headline, local-only player. | same |
| `deletion.fail.body` | Nothing was deleted, and you can keep playing. | Nichts wurde gelöscht. Du kannst weiterspielen. | Body for every failure. | same |
| `deletion.done_local.headline` | Your local game data was deleted. | Deine lokalen Spieldaten wurden gelöscht. | Success, local-only player. | same |
| `deletion.done_local.body` | You can start over with a new game. | Du kannst mit einem neuen Spiel von vorn anfangen. | Body. | same |
| `deletion.new_game_failed` | The new game couldn't start. Try again. | Das neue Spiel konnte nicht gestartet werden. Versuche es erneut. | Appended under a success body if the fresh save failed. | same |
| `deletion.accepted.headline` | Your account is no longer accessible. | Auf dein Konto kann nicht mehr zugegriffen werden. | Success, online account. | same |
| `deletion.accepted.body` | Your deletion request was accepted. | Dein Löschantrag wurde angenommen. | Body when no deadline is known. | same |
| `deletion.accepted.body_deadline` | Your deletion request was accepted. Data removal is due by %s. | Dein Löschantrag wurde angenommen. Die Daten werden bis spätestens %s gelöscht. | Body. `%s` = a date such as "November 2, 2026". | same |
| `deletion.reference` | Reference: %s | Referenz: %s | Support reference code under the body. `%s` = operation id; never translated. | same |
| `deletion.start_new_game` | Start New Game | Neues Spiel starten | Button after a successful deletion. | same |

### Platform and system text

| Key | English | German | Context | Source |
| --- | --- | --- | --- | --- |
| `app.name` | SortingPuzzle | SortingPuzzle | App name under the home-screen icon; today the internal project name. Decide the public name per store first. | `project.godot`, `export_presets.cfg` |
| `support.email.subject` | Sorting Puzzle support request | Sorting Puzzle – Supportanfrage | Subject of the pre-filled support email. | `support_screen.gd` |
| `support.email.body` | Please describe the issue here.\\n\\nDevice/platform:\\nApproximate time:\\n | Beschreibe hier bitte das Problem.\\n\\nGerät/Plattform:\\nUngefährer Zeitpunkt:\\n | Body template the player fills in. | `support_screen.gd` |
| `support.ad_email.subject` | Sorting Puzzle ad report | Sorting Puzzle – Werbemeldung | Subject of the ad-report email. | `support_screen.gd` |
| `support.ad_email.body` | Please attach a screenshot and complete the details below.\\n\\nApproximate time:\\nAd placement in the game:\\nAdvertiser or app name:\\nWhy the ad should be reviewed:\\n | Füge bitte einen Screenshot bei und ergänze die Angaben unten.\\n\\nUngefährer Zeitpunkt:\\nPosition der Werbung im Spiel:\\nName des Werbetreibenden oder der App:\\nWarum die Werbung überprüft werden sollte:\\n | Body template the player fills in. | `support_screen.gd` |
| `deletion.email.subject` | Sorting Puzzle account deletion | Sorting Puzzle – Kontolöschung | Subject of the deletion help email. | `account_deletion_modal.gd` |
| `deletion.email.body` | Please help me with my account deletion. | Bitte helft mir beim Löschen meines Kontos. | First line; followed by `Status:`, `Deletion reference:`, `Server reference:` and `Player ID:` lines. | `account_deletion_modal.gd` |

## German plural forms

German uses two gettext forms: **one** for `n = 1`, and **other** for `n = 0` or `n > 1`.

```text
Plural-Forms: nplurals=2; plural=(n != 1);
```

Use the actual numeric quantity to select a form, even when the string receives a formatted `%s`. For `leaderboard.row_tooltip`, select by the star count, not the rank. For `leaderboard.reward.body`, select by the coin count, not the rank.

| Key | one (`n = 1`) | other (`n = 0` or `n > 1`) |
| --- | --- | --- |
| `chapter.locked_status` | Zum Freischalten noch %d weiteres Level in „%s“ abschließen. | Zum Freischalten noch %d weitere Level in „%s“ abschließen. |
| `shelf_unlock.offer_or_clear` | Sieh dir eine Werbung an, um dieses Regal jetzt freizuschalten, oder entferne noch %s Dreiergruppe. | Sieh dir eine Werbung an, um dieses Regal jetzt freizuschalten, oder entferne noch %s Dreiergruppen. |
| `starter.coins` | %s MÜNZE | %s MÜNZEN |
| `booster_chip.claimed` | +%d %s | +%d %s |
| `leaderboard.row_tooltip` | Rang %d, %s, %d Stern | Rang %d, %s, %d Sterne |
| `leaderboard.reward.body` | Letzte Woche hast du Platz %d erreicht und %d Münze verdient! | Letzte Woche hast du Platz %d erreicht und %d Münzen verdient! |

Both booster-chip forms are identical because `%s` is a fixed booster product name, such as **Hammer**, **Mischen**, **Laterne** or **Zeitstopp**. Example: `+1 Hammer` / `+3 Hammer`.

The unmarked `leaderboard.reward_tooltip` is deliberately phrased as **Wochenbelohnung in Münzen: %s**. This works with both one coin and multiple coins.

## Additional labels mentioned in context

The inventory mentions these deletion-help email labels in the context of `deletion.email.body`, without assigning separate keys. Their German copy is included here for completeness.

| English | German |
| --- | --- |
| Status: | Status: |
| Deletion reference: | Löschreferenz: |
| Server reference: | Serverreferenz: |
| Player ID: | Spieler-ID: |

## Integration notes

- Preserve the source's line-break semantics when converting this Markdown into a translation catalog; the visible escaped markers are not extra display characters.
- Use German formatting for values supplied through placeholders, for example **1.000** coins and **02.11.2026** for a date. Store prices retain the platform-provided localized text.
- German glyph coverage, modal titles, ad buttons and long labels such as **Datenschutzerklärung** still require rendered UI verification at the project's representative resolutions.
- Source-context wording describes the supplied inventory's audit; it is not a fresh audit of the current repository.
