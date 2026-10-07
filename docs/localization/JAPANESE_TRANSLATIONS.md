# Sorting Puzzle — Japanese Translations

Locale: `ja` · 日本語  
Prepared: October 6, 2026  
Source: [Sorting Puzzle — Translation String Inventory](<C:/Users/vlad/Downloads/Sorting Puzzle — Translation String Inventory.md>)

All **251 inventory entries** are included below, with the English text, Japanese translation, original context and source references.

- Japanese copy uses a concise, friendly mobile-game tone. Japanese has no uppercase/lowercase distinction.
- Every `%d` and `%s` placeholder is preserved in its original order. Forced line breaks and paragraph breaks are preserved; `\n` in the tables represents a forced line break.
- Japanese uses one plural form, so the entries marked “Needs plural forms” have one Japanese translation each.
- `AD`, `OFF` and complete discount tags such as `67% OFF` stay unchanged. The home badge `BUNDLE` is translated as `セット`.
- The app name `SortingPuzzle` is retained as requested. The brand `Sorting Puzzle` also stays unchanged in email subject lines.
- Language names, player names, email addresses and reference-code values remain unchanged. Only their surrounding labels are translated.
- This is a translation document. Japanese font coverage and text fit still need to be checked when the copy is integrated into the game.

## Terminology

| English term | Japanese |
| --- | --- |
| Level | レベル |
| Chapter | チャプター |
| Shelf | 棚 |
| Item / goods | アイテム |
| Match (verb) | そろえる |
| Triple / matching set | 同じアイテム3つ / 3つ組 |
| Combo | コンボ |
| Booster / ability | ブースター |
| Dispenser | ディスペンサー |
| Coins | コイン |
| Stars | スター |
| Lives | ライフ |
| Reward chest | 報酬の宝箱 |
| Bundle | セット |
| Hammer | ハンマー |
| Shuffle | シャッフル |
| Lantern | ランタン |
| Freezer | フリーザー |

## Shared buttons, main menu and chapters

Shared buttons appear on several screens and need one translation each, except where the context says the meaning differs. Keys are suggestions for the future translation table.

| Key | English | Japanese (日本語) | Context | Source |
| --- | --- | --- | --- | --- |
| `common.play` | Play | プレイ | Button that starts the chapter's next level on a chapter card. | `chapter_cover_card.gd` |
| `common.continue` | Continue | 続ける | Button that moves on: closes the level-complete screen, the purchase dialog and the reward chest menu; on a chapter card it resumes a chapter already started. | `level_completion_screen.tscn`, `shop_purchase_dialog`, `reward_chest_menu.tscn`, `chapter_cover_card.gd` |
| `common.resume` | Continue | 再開 | Button on Pause and on the leave confirmation that returns to the running level ("keep playing"). Separate key: some languages use a different verb than for "move on". | `pause_menu.tscn`, `leave_confirmation_menu.tscn` |
| `common.try_again` | Try Again | もう一度 | Retries a failed action (ad, purchase, account deletion). | ad modals, `account_deletion_modal.gd`, `starter_bundle_offer_modal.gd` |
| `common.close` | Close | 閉じる | Closes a dialog without doing anything. | `account_deletion_modal.gd` |
| `common.cancel` | Cancel | キャンセル | Backs out of account deletion; nothing is deleted. | `account_deletion_modal.tscn` |
| `common.got_it` | Got it | OK | Acknowledges an info dialog (ability description, lives already full). | `out_of_lives_menu.tscn`, `shop_screen.gd` |
| `common.get_help` | Get Help | サポートへ | Opens a pre-filled email to support. | `account_deletion_modal.gd` |
| `common.save` | SAVE | 保存 | Confirms profile edits or the chosen language. All caps by design. | `profile_menu`, `language_selection_modal.tscn` |
| `common.loading` | Loading… | 読み込み中… | Shown while the Shop or Leaderboard loads its data. | `destination_status_panel.tscn` |
| `common.retry_load` | Retry | 再読み込み | Reloads the Shop or Leaderboard after a load error. Not the same as replaying a level. | `destination_status_panel.tscn` |
| `menu.level_button` | LEVEL %d | レベル %d | Big play button on the home screen. `%d` = level number inside the current chapter. | `production_main_menu.gd` |
| `menu.more_levels_coming_soon` | MORE LEVELS COMING SOON | 新しいレベルを近日追加 | Home play button (disabled) after every level of the chapter is finished. Must fit the button, about 24 characters. | `production_main_menu.gd` |
| `menu.coming_soon` | COMING SOON | 近日公開 | Home play button (disabled) when the chapter has no levels yet. | `production_main_menu.gd` |
| `menu.lives_full` | Full | 満タン | Top bar, next to the heart, when lives are at maximum; replaces the refill timer. About 5 characters. | `production_main_menu.gd`, `main_menu_top_status.tscn` |
| `menu.starter_badge` | BUNDLE | セット | Small badge on the home screen that opens the Starter Bundle offer. About 8 characters. Russian: НАБОР. The full offer title remains Starter Bundle / Стартовый набор. | `main_menu_starter_bundle_badge.tscn` |
| `nav.shop` | Shop | ショップ | Bottom navigation tab. About 10 characters. | `main_menu_bottom_navigation.tscn` |
| `nav.home` | Home | ホーム | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `nav.leaderboard` | Leaderboard | ランキング | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `chapter.button` | CHAPTER %d | チャプター %d | Home button that opens chapter selection. `%d` = chapter number. | `main_menu_chapter_button.gd` |
| `chapter.button_tooltip` | Choose Chapter %d: %s | チャプター%d「%s」を選択 | Accessibility tooltip of that button. `%d` = chapter number, `%s` = chapter title. | `main_menu_chapter_button.gd` |
| `chapter.screen_title` | CHAPTERS | チャプター | Title of the chapter selection screen. | `chapter_selection_screen.tscn` |
| `chapter.eyebrow` | CHAPTER %d | チャプター %d | Small label above the chapter name on its card. | `chapter_cover_card.gd` |
| `chapter.title.chapter_01` | Grocery Town | おかいものタウン | Name of chapter 1 (a grocery-store theme). | `configs/chapters.json` |
| `chapter.title.chapter_02` | Candy Corner | キャンディーコーナー | Name of chapter 2 (a candy-shop theme). | `configs/chapters.json` |
| `chapter.locked_status` | Complete %d more %s levels to unlock | あと%dレベルを「%s」内でクリアすると解放 | Locked chapter card. `%d` = levels still needed, `%s` = previous chapter's name. Needs plural forms. | `chapter_cover_card.gd` |
| `chapter.unlock_progress` | Unlock progress | 解放までの進み具合 | Header over the progress bar on a locked chapter. | `chapter_cover_card.gd` |
| `chapter.current_progress` | Current progress | 現在の進み具合 | Header over the progress bar on an unlocked chapter. | `chapter_cover_card.gd` |
| `chapter.locked` | Locked | ロック中 | Disabled button on a locked chapter card. | `chapter_cover_card.gd` |
| `chapter.no_levels_status` | New levels are coming soon | 新しいレベルを近日追加します | Card message for a chapter with no levels yet. | `chapter_cover_card.gd` |
| `chapter.coming_soon` | Coming Soon | 近日公開 | Disabled button on that card. | `chapter_cover_card.gd` |

## Gameplay: HUD, level screens and results

These strings show during a level, mostly in modal titles (all caps, short) and action buttons. A "triple" or "match" is three identical items on one shelf, which clears them.

| Key | English | Japanese (日本語) | Context | Source |
| --- | --- | --- | --- | --- |
| `hud.level` | LEVEL %d | レベル %d | Top HUD during play. `%d` = level number inside the chapter. | `level.gd` |
| `hud.combo` | COMBO ×%d | コンボ ×%d | HUD counter for consecutive quick matches. `%d` = combo size; keep the × sign. | `level_top_hud.gd` |
| `hud.ability_tooltip.hammer` | Hammer -- clears a matching triple | ハンマー：同じアイテム3つを消します | Accessibility tooltip on the Hammer booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.shuffle` | Shuffle -- reshuffles unlocked items | シャッフル：ロックされていないアイテムを並べ替えます | Tooltip on the Shuffle booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.lantern` | Lantern -- highlights a matchable triple | ランタン：そろえられる同じアイテム3つを光らせます | Tooltip on the Lantern booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.freezer` | Freezer -- pauses the countdown timer | フリーザー：残り時間のカウントを一時停止します | Tooltip on the Freezer booster button. | `ability_bar.tscn` |
| `hud.seconds_short` | %ds | %d秒 | Countdown on an active Lantern or Freezer booster, e.g. "15s". `%d` = seconds; use the local short unit. | `ability_bar.gd` |
| `tip.tap_dispenser` | Tap a dispenser to throw items onto the shelves! | ディスペンサーをタップして、棚にアイテムを出そう！ | Tutorial bubble on level 10, where dispensers (machines that throw items onto shelves) first appear. | `configs/gameplay_tips.json` |
| `pause.title` | PAUSE | 一時停止 | Title of the in-level pause modal. | `pause_menu.gd` |
| `pause.leave` | Leave | 終了 | Pause button that quits the level (asks for confirmation next). | `pause_menu.tscn` |
| `leave.title` | LEAVING THE LEVEL | レベルを終了 | Title of the leave confirmation. | `leave_confirmation_menu.gd` |
| `leave.you_will_lose` | You will lose: | 失われるもの： | Followed by icons showing the stars earned this run and one life. Keep the colon (or local equivalent). | `leave_confirmation_menu.tscn` |
| `leave.confirm` | Leave | 終了 | Confirms quitting the level and losing that progress. | `leave_confirmation_menu.tscn` |
| `timeup.title` | TIME'S UP | 時間切れ | Title when the level timer reaches zero. | `time_up_extension_modal.gd` |
| `timeup.offer` | Add one minute and keep sorting! | 1分追加して、続きをプレイ！ | Offer to extend the timer by 60 seconds for coins or an ad. | `time_up_extension_modal.tscn` |
| `timeup.used` | Used | 使用済み | Shown on the coin price or ad button when that extension was already used this level. | `time_up_extension_modal.gd` |
| `ability_purchase.title` | USE ABILITY | ブースターを使う | Title of the modal that buys and immediately uses one booster when the player has none. | `ability_purchase_menu.gd` |
| `shelf_unlock.title` | UNLOCK SHELF | 棚を解放 | Title of the modal for a locked shelf. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer` | Watch one ad to unlock this shelf now. | 広告を1回見ると、この棚を今すぐ解放できます。 | Body when no other way to unlock remains. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer_or_clear` | Watch one ad to unlock this shelf now, or clear %s more. | 広告を1回見るか、あと%s組そろえて消すと、この棚を解放できます。 | Body when the shelf also unlocks by itself after more matches. `%s` = matches still needed. Needs plural forms. | `shelf_unlock_menu.gd` |
| `shelf_unlock.button` | Watch Ad · Unlock Shelf | 広告を見て棚を解放 | Ad button in that modal. | `shelf_unlock_menu.gd` |
| `shelf_unlock.ad_unavailable` | Ad unavailable. This shelf stays locked. | 広告を表示できません。棚はロックされたままです。 | Status line when no ad could be shown. | `shelf_unlock_menu.gd` |
| `complete.title` | GREAT JOB! | お見事！ | Title of the level-complete screen, above the stars earned. | `level_completion_screen.gd` |
| `failed.title` | LEVEL %d | レベル %d | Title of the level-failed screen. `%d` = level number. | `level_failure_screen.gd` |
| `failed.headline` | LEVEL FAILED | クリア失敗 | Banner on the level-failed screen. | `level_failure_screen.tscn` |
| `failed.retry` | Retry | もう一度プレイ | Replays the same level. | `level_failure_screen.tscn` |

Combo praise pops up above a match during a combo; each word is stronger than the one before, so keep the escalation. The label shrinks its font for long words, but one or two words is the limit.

| Key | English | Japanese (日本語) | Shown at |
| --- | --- | --- | --- |
| `combo.praise.2` | Cool | いいね！ | Combo ×2 |
| `combo.praise.3` | Great | やったね！ | ×3 |
| `combo.praise.4` | Awesome | すごい！ | ×4 |
| `combo.praise.5` | Amazing | お見事！ | ×5 |
| `combo.praise.6` | Fantastic | すばらしい！ | ×6 |
| `combo.praise.7` | Incredible | 驚きの腕前！ | ×7 |
| `combo.praise.8` | Spectacular | 圧巻！ | ×8 |
| `combo.praise.9` | Unstoppable | 止まらない！ | ×9 |
| `combo.praise.10` | Legendary | 伝説級！ | ×10 |
| `combo.praise.11` | Epic | すごすぎる！ | ×11 |
| `combo.praise.12` | Brilliant | 天才！ | ×12 |
| `combo.praise.13` | Masterful | 達人！ | ×13 |
| `combo.praise.14` | Supreme | 至高！ | ×14 |
| `combo.praise.15` | Phenomenal | 奇跡級！ | ×15 |
| `combo.praise.16` | Mythic | 神話級！ | ×16 |
| `combo.praise.17` | Majestic | 王者の風格！ | ×17 |
| `combo.praise.18` | Radiant | 輝いてる！ | ×18 |
| `combo.praise.19` | Divine | 神業！ | ×19 |
| `combo.praise.20` | Transcendent | 限界突破！ | ×20 and above |

Source: `COMBO_PRAISE_WORDS` in `level.gd`.

## Boosters, ads, lives, rewards and shop

The four boosters (also called abilities in code) are product names: pick one translation per language and reuse it everywhere, including the tooltips in the gameplay section.

| Key | English | Japanese (日本語) | Context | Source |
| --- | --- | --- | --- | --- |
| `ability.hammer.name` | Hammer | ハンマー | Booster that smashes away one matching set. | `reward_reveal_row.tscn`, `starter_bundle_offer_modal.tscn`, `shop_screen.gd` |
| `ability.shuffle.name` | Shuffle | シャッフル | Booster that rearranges items. | same |
| `ability.lantern.name` | Lantern | ランタン | Booster that lights up a set the player can match (internal id `highlight`). | same |
| `ability.freezer.name` | Freezer | フリーザー | Booster that stops the level timer. | same |
| `ability.hammer.description` | Instantly clears one matching set of items off the shelves. | 棚にある同じアイテム3つを一瞬で消します。 | Shop info dialog body after tapping the booster icon. | `shop_screen.gd` |
| `ability.shuffle.description` | Shuffles shelf items into new spots to help you find a match. | 棚のアイテムを並べ替えて、そろえられる組を見つけやすくします。 | Same dialog. | `shop_screen.gd` |
| `ability.lantern.description` | Highlights a matching triple you can clear for 15 seconds. | そろえて消せる同じアイテム3つを15秒間光らせます。 | Same dialog. Keep the number in sync with the game config. | `shop_screen.gd` |
| `ability.freezer.description` | Freezes the level timer for 30 seconds. | レベルの残り時間のカウントを30秒間止めます。 | Same dialog. | `shop_screen.gd` |
| `ad.watch` | Watch Ad | 広告を見る | Button that plays a rewarded video ad. | ad modals, `out_of_lives_menu`, `ability_purchase_menu.tscn` |
| `ad.loading` | Loading... | 読み込み中… | Ad button while the ad loads. | ad modals |
| `ad.verifying` | Verifying... | 確認中… | Ad button while the server confirms the reward. | ad modals |
| `ad.verify_reward` | Verify Reward | 報酬を確認 | Ad button to re-check a reward the server has not confirmed yet. | ad modals |
| `ad.reward_pending` | Reward verification is still pending. | 報酬の確認がまだ完了していません。 | Status line under that button. | `out_of_lives_menu.gd`, `shelf_unlock_menu.gd` |
| `ad.unavailable_retry` | Ad unavailable. Please try again. | 広告を表示できません。もう一度お試しください。 | Status line when no ad could be shown. | `out_of_lives_menu` |
| `ad.watch_unavailable` | Watch Ad\\nUnavailable | 広告を見る\\n利用不可 | Two-line disabled ad button (time-up modal). Keep the line break. | `time_up_extension_modal.gd` |
| `ad.watch_coming_soon` | Watch Ad\\nComing Soon | 広告を見る\\n近日公開 | Two-line disabled ad button before ads launch. | `time_up_extension_modal.tscn` |
| `ad.badge` | AD | AD | Tiny badge on a locked shelf that an ad can open. Do not translate: keep AD exactly in every language. | `shelf_lock_overlay.tscn`, `shelf_unlock_menu.tscn` |
| `lives.title.out` | OUT OF LIVES | ライフ切れ | Lives modal title at 0 lives. | `out_of_lives_menu.gd` |
| `lives.title.get_more` | GET MORE LIVES | ライフを補充 | Lives modal title with some lives left. | `out_of_lives_menu.gd` |
| `lives.title.full` | LIVES FULL | ライフ満タン | Lives modal title at maximum lives. | `out_of_lives_menu.gd` |
| `lives.next_in` | NEXT LIFE IN | 次のライフ回復まで | Label above the refill countdown (mm:ss). | `out_of_lives_menu.tscn` |
| `lives.full_body` | Your lives are full! Play a level to spend them. | ライフは満タンです！レベルをプレイしてライフを使いましょう。 | Body of the lives modal at maximum. | `out_of_lives_menu.tscn` |
| `chest.title` | CHEST REWARDS | 宝箱の報酬 | Title of the reward chest modal. | `reward_chest_menu.tscn` |
| `chest.progress_hint` | Collect stars to unlock a chest and claim your reward | スターを集めて宝箱を開け、報酬を受け取ろう | Under the star progress bar (e.g. 12/30). | `reward_chest_menu.tscn` |
| `chest.ready` | A REWARD CHEST AWAITS! | 報酬の宝箱が開けられる！ | Banner when the chest is full and can be opened. | `reward_chest_menu.tscn` |
| `chest.tap_to_open` | Tap to open | タップして開ける | Prompt under the closed chest in the opening animation. | `reward_chest_open_ceremony.tscn` |
| `purchase.tap_to_collect` | Tap to collect | タップして受け取る | Prompt to collect purchased rewards. | `purchase_reward_sequence.tscn` |
| `purchase.complete` | PURCHASE COMPLETE | 購入完了 | Banner after a successful purchase. | `purchase_reward_sequence.gd` |
| `shop.title` | SHOP | ショップ | Shop screen title. | `shop_screen.tscn` |
| `shop.section.bundles` | SPECIAL BUNDLES | スペシャルセット | Section header. | `shop_screen.tscn` |
| `shop.section.coins` | COINS | コイン | Section header for coin packs. | `shop_screen.tscn` |
| `shop.offer.starter_bundle` | Starter Bundle | スターターセット | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.offer.basic_bundle` | Basic Bundle | ベーシックセット | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.tag.best_value` | BEST VALUE | 一番お得 | Ribbon on the best coin pack. | `configs/shop_catalog.json` |
| `shop.discount_off` | OFF | OFF | Second line of the discount badge under "67%". Do not translate: keep the complete 67% OFF tag unchanged in every language; the numeric percentage can vary by offer. | `shop_bundle_card.tscn`, `starter_bundle_offer_modal.tscn` |
| `shop.ability_hint` | Tap an ability to see what it does | ブースターをタップして効果を確認 | Hint under a bundle's booster icons. | `shop_bundle_card.tscn` |
| `shop.purchasing` | Purchasing… | 購入中… | Buy button while a purchase is in progress. | shop cards, `production_main_menu.gd` |
| `shop.no_offers` | No shop offers are available for this region. | この地域で購入できる商品はありません。 | Shop error state. | `shop_screen.gd` |
| `shop.load_failed` | Could not load the shop. | ショップを読み込めませんでした。 | Shop error state (fallback text). | `shop_screen.gd` |
| `shop.error.title.purchase` | Purchase unavailable | 購入できません | Error dialog title when buying failed. | `shop_screen.gd` |
| `shop.error.title.reward` | Reward error | 報酬を受け取れません | Error dialog title when payment went through but rewards were not granted. | `shop_screen.gd` |
| `shop.error.purchase_failed` | The purchase could not be completed. | 購入を完了できませんでした。 | Error dialog body (fallback). | `shop_screen.gd`, `production_main_menu.gd` |
| `shop.error.grant_failed` | The purchased rewards could not be granted. | 購入した報酬を受け取れませんでした。 | Error dialog body. | `store/shop_purchase_flow.gd` |
| `shop.error.offer_unavailable` | This shop offer is unavailable. | この商品は購入できません。 | Error dialog body. | `store/store_service.gd` |
| `shop.error.already_bought` | This one-time shop offer has already been purchased. | この1回限りの商品は購入済みです。 | Error dialog body. | `store/store_service.gd` |
| `starter.title` | STARTER BUNDLE | スターターセット | Starter offer modal title. | `starter_bundle_offer_modal.gd` |
| `starter.one_time` | ONE-TIME OFFER | 1回限定 | Ribbon on the starter offer. | `starter_bundle_offer_modal.tscn` |
| `starter.boosters_included` | BOOSTERS INCLUDED | ブースター入り | Header over the four booster chips. | `starter_bundle_offer_modal.tscn` |
| `starter.coins` | %s COINS | コイン %s枚 | Ribbon over the coin art. `%s` = formatted amount, e.g. "1,000". Needs plural forms. | `starter_bundle_offer_modal.gd` |
| `starter.buy_for` | Buy for %s | %sで購入 | Buy button. `%s` = store price, e.g. "$4.99". | `starter_bundle_offer_modal.gd` |
| `starter.checking` | Checking offer… | 商品を確認中… | Status while the store confirms the offer. | `production_main_menu.gd` |
| `starter.checking_short` | Checking… | 確認中… | Buy button during that check. | `starter_bundle_offer_modal.gd` |
| `starter.no_longer_available` | This offer is no longer available. | この商品はもう購入できません。 | Error status in the starter modal. | `production_main_menu.gd` |
| `starter.unavailable` | Unavailable | 購入不可 | Disabled buy button after a non-retryable error. | `starter_bundle_offer_modal.gd` |
| `booster_chip.claimed` | +%d %s | +%d %s | Booster chip after purchase, e.g. "+3 Hammer". `%d` = count, `%s` = booster name. Needs plural forms. | `offer_booster_chip.gd` |

## Profile, leaderboard and settings

Language names in the language picker stay in their own language (English, Español, 日本語…) and are never translated.

| Key | English | Japanese (日本語) | Context | Source |
| --- | --- | --- | --- | --- |
| `profile.title` | EDIT PROFILE | プロフィール編集 | Profile modal title. | `profile_menu.tscn` |
| `profile.name_header` | PLAYER NAME | プレイヤー名 | Header over the name field. | `profile_menu.tscn` |
| `profile.name_placeholder` | Player name | プレイヤー名 | Placeholder inside the empty name field. | `profile_menu.tscn` |
| `profile.edit_name_tooltip` | Edit player name | プレイヤー名を編集 | Accessibility tooltip on the pencil button. | `profile_menu.tscn` |
| `profile.avatar_tab` | AVATAR | アバター | Tab that shows avatar pictures. | `profile_menu.tscn` |
| `profile.frame_tab` | FRAME | フレーム | Tab that shows decorative frames around the avatar. | `profile_menu.tscn` |
| `profile.unlock.level` | Complete level %d to unlock | レベル%dをクリアすると解放 | Toast after tapping a locked frame. `%d` = level number. | `profile_menu.gd` |
| `profile.unlock.combo` | Reach a combo of ×%d in any run to unlock | いずれかのプレイでコンボ×%dを達成すると解放 | Same toast. `%d` = combo size. | `profile_menu.gd` |
| `profile.unlock.weekly_first` | Finish 1st on the Weekly leaderboard to unlock | 週間ランキング終了時に1位になると解放 | Same toast for a first-place frame. Today built from two parts; see implementation notes. | `profile_menu.gd` |
| `profile.unlock.weekly_top` | Finish top %d on the Weekly leaderboard to unlock | 週間ランキング終了時に%d位以内に入ると解放 | Same toast. `%d` = rank cutoff (e.g. 10). | `profile_menu.gd` |
| `leaderboard.title` | LEADERBOARD | ランキング | Leaderboard screen title. | `leaderboard_screen.tscn` |
| `leaderboard.tab.weekly` | Weekly | 週間 | Tab: this week's stars. | `leaderboard_screen.tscn` |
| `leaderboard.tab.country` | Country | 国内 | Tab: all-time stars in the player's country. | `leaderboard_screen.tscn` |
| `leaderboard.tab.world` | World | 世界 | Tab: all-time stars worldwide. | `leaderboard_screen.tscn` |
| `leaderboard.weekly_reset` | Weekly reset in %s | 週間ランキングのリセットまで %s | Under the Weekly tab. `%s` = a duration such as "1d 4h". | `leaderboard_screen.gd` |
| `leaderboard.duration.dh` | %dd %dh | %d日 %d時間 | Duration: days and hours. Use local unit abbreviations. | `leaderboard_screen.gd` |
| `leaderboard.duration.hm` | %dh %dm | %d時間 %d分 | Duration: hours and minutes. | `leaderboard_screen.gd` |
| `leaderboard.duration.m` | %dm | %d分 | Duration: minutes. | `leaderboard_screen.gd` |
| `leaderboard.country_caption` | Country · All-time stars | 国内・累計スター | Caption under the Country tab. | `leaderboard_screen.gd` |
| `leaderboard.world_caption` | Worldwide · All-time stars | 世界・累計スター | Caption under the World tab. | `leaderboard_screen.gd` |
| `leaderboard.load_failed` | Could not load leaderboard. | ランキングを読み込めませんでした。 | Error state (fallback text). | `leaderboard_screen.gd` |
| `leaderboard.default_name` | Player | プレイヤー | Name shown for a player without one. | `leaderboard_row.gd` |
| `leaderboard.row_tooltip` | Rank %d, %s, %d stars | %d位、%s、スター%d個 | Accessibility text of a row. `%d` = rank, `%s` = player name, `%d` = stars. Needs plural forms. | `leaderboard_row.gd` |
| `leaderboard.reward_tooltip` | %s coin weekly reward | 週間報酬：コイン%s枚 | Accessibility text on the coin prize next to top ranks. `%s` = amount. | `leaderboard_rank_reward.gd` |
| `leaderboard.reward.title` | WEEKLY REWARD! | 週間報酬！ | Title of the dialog shown after a week ends. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.body` | You finished #%d last week and earned %d coins! | 先週は%d位！コイン%d枚を獲得しました！ | Body. `%d` = final rank, `%d` = coins. Needs plural forms. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.ok` | Nice! | やった！ | Button that closes the reward dialog. | `leaderboard_reward_dialog.tscn` |
| `settings.title` | SETTINGS | 設定 | Settings modal title (home screen). | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.music` | Music | 音楽 | Toggle label under an icon. Short, about 8 characters. | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.sfx` | SFX | 効果音 | Toggle for sound effects. Use a short local word for "Sounds". | same |
| `settings.vibrate` | Vibrate | 振動 | Toggle for haptic feedback. | same |
| `settings.support` | Support | サポート | Opens the Support screen. | `settings_menu.tscn` |
| `settings.language` | Language | 言語 | Opens the language picker. | `settings_menu.tscn`, `language_option_row.tscn` |
| `settings.privacy_policy` | Privacy Policy | プライバシーポリシー | Opens the privacy policy web page. | `settings_menu.tscn`, `production_main_menu.gd` |
| `settings.privacy_choices` | Privacy Choices | プライバシー設定 | Same button when the ad consent form must be offered (EU/UK). | `production_main_menu.gd` |
| `settings.diagnostics` | Version %s • Build %d\\nPlatform: %s • User: %s | バージョン %s • ビルド %d\\nプラットフォーム：%s • ユーザー：%s | Small footer for support. Values: app version, build number, OS name, short player id. Translating the four labels is optional. | `pause_menu.gd` |
| `language.title` | LANGUAGE | 言語 | Language picker title. | `language_selection_modal.gd` |

## Support, account deletion and platform text

Support and deletion copy is legal-adjacent: translate meaning exactly, keep "Nothing was deleted" and "You can't undo this" unambiguous, and do not soften the warnings.

### Support screen

| Key | English | Japanese (日本語) | Context | Source |
| --- | --- | --- | --- | --- |
| `support.title` | SUPPORT | サポート | Support screen title. | `support_screen.tscn` |
| `support.faq_header` | Frequently Asked Questions | よくある質問 | Section header. | `support_screen.tscn` |
| `support.faq.play.q` | How do I play? | 遊び方は？ | FAQ question (tap to expand). | `support_screen.tscn` |
| `support.faq.play.a` | Move matching goods onto the same shelf. When three identical items are visible together, they clear. Complete the board before time runs out. | 同じアイテムを同じ棚に移動させましょう。同じアイテムが3つ同じ棚に見えている状態になると消えます。時間内にすべてのアイテムを消しましょう。 | FAQ answer. "Goods" = shop items such as snacks and toys. | `support_screen.tscn` |
| `support.faq.contact.q` | How do I contact support? | サポートへの問い合わせ方法は？ | FAQ question. | `support_screen.tscn` |
| `support.faq.contact.a` | Email us at %s. Include a short description, your device platform, and when the problem happened. | %sにメールをお送りください。問題の簡単な説明、端末のプラットフォーム、問題が起きた日時を記載してください。 | FAQ answer. `%s` = support email address. | `support_screen.gd` |
| `support.faq.contact.action` | Email Support | サポートにメール | Button that opens a pre-filled email. | `support_screen.tscn` |
| `support.faq.crash.q` | What if the game freezes or crashes? | ゲームがフリーズしたり、強制終了したら？ | FAQ question. | `support_screen.tscn` |
| `support.faq.crash.a` | Close and reopen the game first. If it happens again, restart the device and make sure the game is updated. Contact support with the device model, platform version, and what you were doing before the problem. | まずゲームを閉じて、開き直してください。再び起きる場合は端末を再起動し、ゲームが最新バージョンになっているか確認してください。端末の機種、プラットフォームのバージョン、問題が起きる直前にしていたことを添えて、サポートにお問い合わせください。 | FAQ answer. | `support_screen.tscn` |
| `support.faq.sync.q` | How do I sync progress between devices? | 端末間で進行状況を同期するには？ | FAQ question. | `support_screen.tscn` |
| `support.faq.sync.a` | Use the same signed-in platform account on both devices and allow synchronization to finish before playing. If the progress differs, avoid playing on both devices and contact support. | 両方の端末で同じプラットフォームアカウントにサインインし、同期が完了してからプレイしてください。進行状況が異なる場合は、どちらの端末でもプレイを控え、サポートにお問い合わせください。 | FAQ answer. "Platform account" = Google Play Games / Game Center. | `support_screen.tscn` |
| `support.faq.bad_ad.q` | How do I report a bad ad? | 問題のある広告を報告するには？ | FAQ question. | `support_screen.tscn` |
| `support.faq.bad_ad.a` | 1. Close the ad if you can do so safely.\\n2. Take a screenshot of the ad and any advertiser or app name shown.\\n3. Note the approximate time and where the ad appeared in the game.\\n4. Describe why the ad seemed offensive, misleading, or fraudulent.\\n5. Email these details to %s. Do not include passwords or payment information. | 1. 安全に閉じられる場合は、広告を閉じてください。\\n2. 広告と、表示されている広告主名やアプリ名のスクリーンショットを撮ってください。\\n3. おおよその日時と、ゲーム内のどこに広告が表示されたかを控えてください。\\n4. 不快な内容、誤解を招く内容、詐欺的な内容だと思った理由を記載してください。\\n5. これらの情報を%sにメールでお送りください。パスワードや支払い情報は含めないでください。 | FAQ answer, a five-step list in one string. `%s` = support email. Keep the numbering and line breaks. | `support_screen.gd` |
| `support.faq.bad_ad.action` | Email Ad Report | 広告をメールで報告 | Button that opens a pre-filled ad-report email. | `support_screen.tscn` |
| `support.account_header` | Account | アカウント | Section header above the delete button. | `support_screen.tscn` |
| `support.delete_account` | Delete Account | アカウントを削除 | Opens account deletion (player has an online account). | `support_screen.gd` |
| `support.delete_game_data` | Delete Game Data | ゲームデータを削除 | Same button when only local data exists. | `support_screen.gd` |
| `support.no_secrets` | Please never send passwords or payment information. | パスワードや支払い情報は絶対に送らないでください。 | Warning at the bottom of the screen. | `support_screen.tscn` |

### Account deletion modal

One modal switches between states; each state has a title (caps), a headline, a body and up to two buttons.

| Key | English | Japanese (日本語) | Context | Source |
| --- | --- | --- | --- | --- |
| `deletion.title.delete_account` | DELETE ACCOUNT | アカウント削除 | Title: confirm, in progress and unavailable states. | `account_deletion_modal.gd` |
| `deletion.title.delete_game_data` | DELETE GAME DATA | ゲームデータ削除 | Title for a player who never had an online account. | same |
| `deletion.title.not_confirmed` | NOT CONFIRMED | 未確認 | Title: request sent, answer lost. | same |
| `deletion.title.status_unconfirmed` | STATUS UNCONFIRMED | 削除状況は未確認 | Title: server outcome unknown. | same |
| `deletion.title.finishing_up` | FINISHING UP | 削除の最終処理中 | Title: local cleanup incomplete. | same |
| `deletion.title.new_game` | NEW GAME | 新しいゲーム | Title while a fresh save is created. | same |
| `deletion.title.status_unknown` | STATUS UNKNOWN | 状況不明 | Title: local deletion record unreadable. | same |
| `deletion.title.not_deleted` | NOT DELETED | 削除されていません | Title after a failed attempt. | same |
| `deletion.title.data_deleted` | DATA DELETED | データ削除完了 | Title after local data is deleted. | same |
| `deletion.title.accepted` | DELETION ACCEPTED | 削除を受け付けました | Title after the server accepts the request. | same |
| `deletion.confirm.headline` | This permanently deletes your account. | アカウントを永久に削除します。 | Confirm step, online account. | same |
| `deletion.confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nIf you sign in again later, you'll start a new account.\\n\\nSome purchase and security records are kept without your name or profile. The rest is removed within 30 days. | 進行状況、コイン、アイテム、プロフィールが失われます。この操作は取り消せません。\\n\\n後で再びサインインした場合は、新しいアカウントで始めることになります。\\n\\n購入やセキュリティに関する一部の記録は、名前やプロフィールを含めずに保管されます。その他のデータは30日以内に削除されます。 | Confirm step body. Keep the three paragraphs. | same |
| `deletion.confirm.button` | Delete Account | アカウントを削除 | Red destructive button. | same |
| `deletion.local_confirm.headline` | This deletes your game data on this device. | この端末のゲームデータを削除します。 | Confirm step, local-only player. | same |
| `deletion.local_confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nThis game never created an online account for you, so nothing needs to be deleted from our servers. | 進行状況、コイン、アイテム、プロフィールが失われます。この操作は取り消せません。\\n\\nこのゲームでは、あなたのオンラインアカウントは作成されていません。そのため、当社のサーバーから削除するデータはありません。 | Body for that step. | same |
| `deletion.local_confirm.button` | Delete Data | データを削除 | Red destructive button. | same |
| `deletion.pending_setup.headline` | Your account is still being set up. | アカウントの作成処理がまだ完了していません。 | Deletion blocked: first registration not finished. | same |
| `deletion.pending_setup.body` | Connect to the internet and try again in a moment. Nothing was deleted. | インターネットに接続し、少し待ってからもう一度お試しください。何も削除されていません。 | Body. | same |
| `deletion.sign_in.headline` | Sign in to the account you want to delete. | 削除したいアカウントにサインインしてください。 | Deletion blocked: signed out. | same |
| `deletion.sign_in.body` | If you can't sign in, contact support for help. | サインインできない場合は、サポートにお問い合わせください。 | Body. | same |
| `deletion.read_failed.headline` | Your game data couldn't be read. | ゲームデータを読み込めませんでした。 | Deletion blocked: save unreadable. | same |
| `deletion.read_failed.body` | Restart the game, then try again. Nothing was deleted. | ゲームを再起動して、もう一度お試しください。何も削除されていません。 | Body. | same |
| `deletion.unavailable.headline` | Account deletion isn't available in this version of the game. | このバージョンのゲームでは、アカウントを削除できません。 | Deletion blocked: feature off. Also a failure headline. | same |
| `deletion.unavailable.body` | Update the game, or contact support for help deleting your account. Nothing was deleted. | ゲームを更新するか、アカウントの削除についてサポートにお問い合わせください。何も削除されていません。 | Body. | same |
| `deletion.in_progress.account` | Deleting your account... | アカウントを削除中… | Headline while the request runs. | same |
| `deletion.in_progress.local` | Deleting your game data... | ゲームデータを削除中… | Same for local-only data. | same |
| `deletion.in_progress.body` | Keep the game open. This only takes a moment. | ゲームを開いたままお待ちください。まもなく完了します。 | Body while deleting. | same |
| `deletion.not_confirmed.headline` | We haven't heard back about your deletion yet. | 削除リクエストへの応答がまだ届いていません。 | Request sent, answer lost. | same |
| `deletion.not_confirmed.body` | Your request was sent, but the answer didn't arrive. Connect to the internet and try again. The game stays locked until we know the result. | リクエストは送信されましたが、応答が届きませんでした。インターネットに接続し、もう一度お試しください。結果が確認できるまで、ゲームはロックされたままになります。 | Body. | same |
| `deletion.unconfirmed.headline` | Deletion status unconfirmed | 削除状況は未確認です | Server outcome unknown. | same |
| `deletion.unconfirmed.body` | We couldn't confirm whether your account was deleted. To keep your data safe, the game stays locked. Contact support and include the reference below. | アカウントが削除されたか確認できませんでした。データを保護するため、ゲームはロックされたままになります。以下の照会番号を添えて、サポートにお問い合わせください。 | Body; a reference code is shown under it. | same |
| `deletion.check_again` | Check Again | もう一度確認 | Asks the server again. | same |
| `deletion.cleanup.headline.local` | Your local game data couldn't be fully deleted yet. | この端末のゲームデータをまだ完全に削除できていません。 | Local cleanup incomplete (local-only player). | same |
| `deletion.cleanup.headline.account` | Account deletion accepted; finishing cleanup. | アカウントの削除を受け付けました。残りのデータを削除中です。 | Local cleanup incomplete after the server accepted. | same |
| `deletion.cleanup.body` | Some game data couldn't be removed from this device yet. Try again to finish. | この端末から一部のゲームデータをまだ削除できていません。もう一度試して、削除を完了してください。 | Body. | same |
| `deletion.new_game.headline` | Starting a new game... | 新しいゲームを開始中… | While a fresh save is created. | same |
| `deletion.new_game.body` | This only takes a moment. | まもなく完了します。 | Body. | same |
| `deletion.status_unknown.headline` | We couldn't read the deletion status on this device. | この端末の削除状況を読み取れませんでした。 | Local deletion record unreadable. | same |
| `deletion.status_unknown.body` | To keep your data safe, the game stays locked. Contact support for help. | データを保護するため、ゲームはロックされたままになります。サポートにお問い合わせください。 | Body. | same |
| `deletion.fail.offline` | Connect to the internet to delete your account. | アカウントを削除するには、インターネットに接続してください。 | Failure headline. | same |
| `deletion.fail.rate_limited` | Too many attempts. Wait a moment, then try again. | 試行回数が多すぎます。少し待ってから、もう一度お試しください。 | Failure headline. | same |
| `deletion.fail.busy` | Account deletion is busy right now. Try again in a moment. | 現在、アカウント削除の処理が混み合っています。少し待ってから、もう一度お試しください。 | Failure headline (server unavailable). | same |
| `deletion.fail.syncing` | The game is still syncing. Try again in a moment. | ゲームはまだ同期中です。少し待ってから、もう一度お試しください。 | Failure headline. | same |
| `deletion.fail.auth` | We couldn't verify your account. Restart the game, then try again. | アカウントを確認できませんでした。ゲームを再起動して、もう一度お試しください。 | Failure headline. | same |
| `deletion.fail.update` | Update the game to delete your account. | アカウントを削除するには、ゲームを更新してください。 | Failure headline (client too old). | same |
| `deletion.fail.changed` | Your account changed while we were deleting it. Try again. | 削除処理中にアカウントが変更されました。もう一度お試しください。 | Failure headline. | same |
| `deletion.fail.storage` | Your device couldn't save the deletion request. Try again. | この端末に削除リクエストを保存できませんでした。もう一度お試しください。 | Failure headline. | same |
| `deletion.fail.generic` | We couldn't delete your account. Try again later or contact support. | アカウントを削除できませんでした。後でもう一度試すか、サポートにお問い合わせください。 | Failure headline (fallback). | same |
| `deletion.fail.local` | Your game data couldn't be deleted. Try again. | ゲームデータを削除できませんでした。もう一度お試しください。 | Failure headline, local-only player. | same |
| `deletion.fail.body` | Nothing was deleted, and you can keep playing. | 何も削除されていません。そのままプレイを続けられます。 | Body for every failure. | same |
| `deletion.done_local.headline` | Your local game data was deleted. | この端末のゲームデータを削除しました。 | Success, local-only player. | same |
| `deletion.done_local.body` | You can start over with a new game. | 新しいゲームで最初からやり直せます。 | Body. | same |
| `deletion.new_game_failed` | The new game couldn't start. Try again. | 新しいゲームを開始できませんでした。もう一度お試しください。 | Appended under a success body if the fresh save failed. | same |
| `deletion.accepted.headline` | Your account is no longer accessible. | このアカウントにはもうアクセスできません。 | Success, online account. | same |
| `deletion.accepted.body` | Your deletion request was accepted. | 削除リクエストが受け付けられました。 | Body when no deadline is known. | same |
| `deletion.accepted.body_deadline` | Your deletion request was accepted. Data removal is due by %s. | 削除リクエストが受け付けられました。データは%sまでに削除されます。 | Body. `%s` = a date such as "November 2, 2026". | same |
| `deletion.reference` | Reference: %s | 照会番号：%s | Support reference code under the body. `%s` = operation id; never translated. | same |
| `deletion.start_new_game` | Start New Game | 新しいゲームを開始 | Button after a successful deletion. | same |

### Platform and system text

| Key | English | Japanese (日本語) | Context | Source |
| --- | --- | --- | --- | --- |
| `app.name` | SortingPuzzle | SortingPuzzle | App name under the home-screen icon; today the internal project name. Decide the public name per store first. | `project.godot`, `export_presets.cfg` |
| `support.email.subject` | Sorting Puzzle support request | Sorting Puzzle サポートへのお問い合わせ | Subject of the pre-filled support email. | `support_screen.gd` |
| `support.email.body` | Please describe the issue here.\\n\\nDevice/platform:\\nApproximate time:\\n | こちらに問題の内容を記載してください。\\n\\n端末／プラットフォーム：\\nおおよその日時：\\n | Body template the player fills in. | `support_screen.gd` |
| `support.ad_email.subject` | Sorting Puzzle ad report | Sorting Puzzle 広告の報告 | Subject of the ad-report email. | `support_screen.gd` |
| `support.ad_email.body` | Please attach a screenshot and complete the details below.\\n\\nApproximate time:\\nAd placement in the game:\\nAdvertiser or app name:\\nWhy the ad should be reviewed:\\n | スクリーンショットを添付し、以下の項目をご記入ください。\\n\\nおおよその日時：\\nゲーム内の広告表示場所：\\n広告主名またはアプリ名：\\n広告を確認してほしい理由：\\n | Body template the player fills in. | `support_screen.gd` |
| `deletion.email.subject` | Sorting Puzzle account deletion | Sorting Puzzle アカウント削除について | Subject of the deletion help email. | `account_deletion_modal.gd` |
| `deletion.email.body` | Please help me with my account deletion. | アカウントの削除についてサポートをお願いします。 | First line; followed by `Status:`, `Deletion reference:`, `Server reference:` and `Player ID:` lines. | `account_deletion_modal.gd` |

## Additional email labels mentioned in the inventory

These four labels are mentioned in the context of `deletion.email.body`, but do not have separate inventory keys. The values following them remain unchanged.

| English | Japanese (日本語) |
| --- | --- |
| Status: | 状況： |
| Deletion reference: | 削除の照会番号： |
| Server reference: | サーバーの照会番号： |
| Player ID: | プレイヤーID： |

## Verification

- 251 of 251 inventory keys have a target entry; there are no missing or duplicate keys.
- Placeholder types, counts and order match the English source for every entry.
- Forced line-break counts match the English source, including blank paragraphs and trailing email-template line breaks.
- Protected markers `AD` and `OFF` are unchanged.
