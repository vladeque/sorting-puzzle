# Sorting Puzzle — Bahasa Indonesia Translations

Locale: `id` · Prepared: October 7, 2026

Bilingual translations of all **251 keyed entries** in the attached **Sorting Puzzle — Translation String Inventory.md** (October 3 audit, with the October 5 copy updates). Original English, keys, context and source references are retained for review. This document supplies translation copy; runtime integration and rendered layout verification are pending.

## Indonesian terminology

| English | Bahasa Indonesia |
| --- | --- |
| Level | Level |
| Chapter | Bab |
| Shelf | Rak |
| Item / goods | Barang |
| Match / triple / set | Set tiga barang identik; set when the meaning is already clear |
| Combo | Kombo |
| Booster / ability | Booster |
| Hammer | Palu |
| Shuffle | Acak |
| Lantern | Lentera |
| Freezer | Pembeku |
| Dispenser | Mesin pelontar |
| Coins | Koin |
| Stars | Bintang |
| Lives | Nyawa |
| Reward chest | Peti hadiah |
| Bundle | Paket |
| Leaderboard | Papan peringkat; Peringkat on the narrow navigation tab |
| Support | Bantuan; tim bantuan when referring to the people |

## Reading the tables

- Copy uses friendly, concise Indonesian and addresses the player as `kamu` or with the suffix `-mu`.
- All `%d` and `%s` placeholders retain their original types and order. The `+`, `×`, `·`, `•` and `#` symbols retain their roles.
- Line-break markers retain the source document's Markdown escaping (`\\n`). Each marker represents one forced line break; consecutive markers separate paragraphs.
- Uppercase titles and banners remain uppercase. `SFX` becomes `Suara`, as requested by the source context for this toggle. Product-name entries retain title case; their card styling may use capitals.
- The updated home badge is `PAKET`. The locked-shelf marker `AD` and discount word `OFF` stay exactly as supplied. Preserve the percentage digits, `%` sign and existing order in tags such as `67% OFF`.
- `SortingPuzzle` / `Sorting Puzzle` retain the existing brand spelling. Native language names, email addresses, platform names, player names, IDs, reference values and store-formatted prices passed through placeholders retain their values.
- The six count-sensitive entries use the same Indonesian wording for every count. Booster names also stay fixed after quantities. See the count appendix.
- Compact durations use `h` for `hari` (days), `j` for `jam` (hours), and `m` for `menit` (minutes). Active booster countdowns use `dtk` for `detik` (seconds).
- `Lanjutkan` moves to the next step; `Lanjut Main` resumes the running puzzle; `Main Lagi` replays a failed level; `Muat Ulang` reloads screen data.
- The deletion copy preserves permanent loss, irreversibility, retained purchase/security records, the 30-day removal deadline, unknown outcomes, locked states and “nothing was deleted.” An accepted deletion request is distinct from a completed local deletion.
- The narrow labels stay within the inventory's approximate limits: `Penuh` is five characters, `PAKET` is five, `Peringkat` is nine, and `LEVEL BARU SEGERA HADIR` is 23. Actual fit, including two-line ad buttons and `%d dtk`, must be checked when the copy is integrated.

## Shared buttons, main menu and chapters

Shared buttons appear on several screens and need one translation each, except where the context says the meaning differs. Keys are suggestions for the future translation table.

| Key | English | Bahasa Indonesia | Context | Source |
| --- | --- | --- | --- | --- |
| `common.play` | Play | Main | Button that starts the chapter's next level on a chapter card. | `chapter_cover_card.gd` |
| `common.continue` | Continue | Lanjutkan | Button that moves on: closes the level-complete screen, the purchase dialog and the reward chest menu; on a chapter card it resumes a chapter already started. | `level_completion_screen.tscn`, `shop_purchase_dialog`, `reward_chest_menu.tscn`, `chapter_cover_card.gd` |
| `common.resume` | Continue | Lanjut Main | Button on Pause and on the leave confirmation that returns to the running level ("keep playing"). Separate key: some languages use a different verb than for "move on". | `pause_menu.tscn`, `leave_confirmation_menu.tscn` |
| `common.try_again` | Try Again | Coba Lagi | Retries a failed action (ad, purchase, account deletion). | ad modals, `account_deletion_modal.gd`, `starter_bundle_offer_modal.gd` |
| `common.close` | Close | Tutup | Closes a dialog without doing anything. | `account_deletion_modal.gd` |
| `common.cancel` | Cancel | Batal | Backs out of account deletion; nothing is deleted. | `account_deletion_modal.tscn` |
| `common.got_it` | Got it | Paham | Acknowledges an info dialog (ability description, lives already full). | `out_of_lives_menu.tscn`, `shop_screen.gd` |
| `common.get_help` | Get Help | Minta Bantuan | Opens a pre-filled email to support. | `account_deletion_modal.gd` |
| `common.save` | SAVE | SIMPAN | Confirms profile edits or the chosen language. All caps by design. | `profile_menu`, `language_selection_modal.tscn` |
| `common.loading` | Loading… | Memuat… | Shown while the Shop or Leaderboard loads its data. | `destination_status_panel.tscn` |
| `common.retry_load` | Retry | Muat Ulang | Reloads the Shop or Leaderboard after a load error. Not the same as replaying a level. | `destination_status_panel.tscn` |
| `menu.level_button` | LEVEL %d | LEVEL %d | Big play button on the home screen. `%d` = level number inside the current chapter. | `production_main_menu.gd` |
| `menu.more_levels_coming_soon` | MORE LEVELS COMING SOON | LEVEL BARU SEGERA HADIR | Home play button (disabled) after every level of the chapter is finished. Must fit the button, about 24 characters. | `production_main_menu.gd` |
| `menu.coming_soon` | COMING SOON | SEGERA HADIR | Home play button (disabled) when the chapter has no levels yet. | `production_main_menu.gd` |
| `menu.lives_full` | Full | Penuh | Top bar, next to the heart, when lives are at maximum; replaces the refill timer. About 5 characters. | `production_main_menu.gd`, `main_menu_top_status.tscn` |
| `menu.starter_badge` | BUNDLE | PAKET | Small badge on the home screen that opens the Starter Bundle offer. About 8 characters. Russian: НАБОР. The full offer title remains Starter Bundle / Стартовый набор. | `main_menu_starter_bundle_badge.tscn` |
| `nav.shop` | Shop | Toko | Bottom navigation tab. About 10 characters. | `main_menu_bottom_navigation.tscn` |
| `nav.home` | Home | Beranda | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `nav.leaderboard` | Leaderboard | Peringkat | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `chapter.button` | CHAPTER %d | BAB %d | Home button that opens chapter selection. `%d` = chapter number. | `main_menu_chapter_button.gd` |
| `chapter.button_tooltip` | Choose Chapter %d: %s | Pilih Bab %d: %s | Accessibility tooltip of that button. `%d` = chapter number, `%s` = chapter title. | `main_menu_chapter_button.gd` |
| `chapter.screen_title` | CHAPTERS | BAB | Title of the chapter selection screen. | `chapter_selection_screen.tscn` |
| `chapter.eyebrow` | CHAPTER %d | BAB %d | Small label above the chapter name on its card. | `chapter_cover_card.gd` |
| `chapter.title.chapter_01` | Grocery Town | Kota Kelontong | Name of chapter 1 (a grocery-store theme). | `configs/chapters.json` |
| `chapter.title.chapter_02` | Candy Corner | Sudut Permen | Name of chapter 2 (a candy-shop theme). | `configs/chapters.json` |
| `chapter.locked_status` | Complete %d more %s levels to unlock | Selesaikan %d level lagi di "%s" untuk membuka bab ini | Locked chapter card. `%d` = levels still needed, `%s` = previous chapter's name. Needs plural forms. | `chapter_cover_card.gd` |
| `chapter.unlock_progress` | Unlock progress | Progres membuka bab | Header over the progress bar on a locked chapter. | `chapter_cover_card.gd` |
| `chapter.current_progress` | Current progress | Progres saat ini | Header over the progress bar on an unlocked chapter. | `chapter_cover_card.gd` |
| `chapter.locked` | Locked | Terkunci | Disabled button on a locked chapter card. | `chapter_cover_card.gd` |
| `chapter.no_levels_status` | New levels are coming soon | Level baru segera hadir | Card message for a chapter with no levels yet. | `chapter_cover_card.gd` |
| `chapter.coming_soon` | Coming Soon | Segera Hadir | Disabled button on that card. | `chapter_cover_card.gd` |

## Gameplay: HUD, level screens and results

These strings show during a level, mostly in modal titles (all caps, short) and action buttons. A "triple" or "match" is three identical items on one shelf, which clears them.

| Key | English | Bahasa Indonesia | Context | Source |
| --- | --- | --- | --- | --- |
| `hud.level` | LEVEL %d | LEVEL %d | Top HUD during play. `%d` = level number inside the chapter. | `level.gd` |
| `hud.combo` | COMBO ×%d | KOMBO ×%d | HUD counter for consecutive quick matches. `%d` = combo size; keep the × sign. | `level_top_hud.gd` |
| `hud.ability_tooltip.hammer` | Hammer -- clears a matching triple | Palu -- menghapus satu set tiga barang identik | Accessibility tooltip on the Hammer booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.shuffle` | Shuffle -- reshuffles unlocked items | Acak -- mengacak ulang barang yang tidak terkunci | Tooltip on the Shuffle booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.lantern` | Lantern -- highlights a matchable triple | Lentera -- menyorot tiga barang identik yang bisa dicocokkan | Tooltip on the Lantern booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.freezer` | Freezer -- pauses the countdown timer | Pembeku -- menjeda hitung mundur | Tooltip on the Freezer booster button. | `ability_bar.tscn` |
| `hud.seconds_short` | %ds | %d dtk | Countdown on an active Lantern or Freezer booster, e.g. "15s". `%d` = seconds; use the local short unit. | `ability_bar.gd` |
| `tip.tap_dispenser` | Tap a dispenser to throw items onto the shelves! | Ketuk mesin pelontar untuk melempar barang ke rak! | Tutorial bubble on level 10, where dispensers (machines that throw items onto shelves) first appear. | `configs/gameplay_tips.json` |
| `pause.title` | PAUSE | JEDA | Title of the in-level pause modal. | `pause_menu.gd` |
| `pause.leave` | Leave | Keluar | Pause button that quits the level (asks for confirmation next). | `pause_menu.tscn` |
| `leave.title` | LEAVING THE LEVEL | KELUAR DARI LEVEL | Title of the leave confirmation. | `leave_confirmation_menu.gd` |
| `leave.you_will_lose` | You will lose: | Kamu akan kehilangan: | Followed by icons showing the stars earned this run and one life. Keep the colon (or local equivalent). | `leave_confirmation_menu.tscn` |
| `leave.confirm` | Leave | Keluar | Confirms quitting the level and losing that progress. | `leave_confirmation_menu.tscn` |
| `timeup.title` | TIME'S UP | WAKTU HABIS | Title when the level timer reaches zero. | `time_up_extension_modal.gd` |
| `timeup.offer` | Add one minute and keep sorting! | Tambah satu menit dan lanjutkan menyortir! | Offer to extend the timer by 60 seconds for coins or an ad. | `time_up_extension_modal.tscn` |
| `timeup.used` | Used | Terpakai | Shown on the coin price or ad button when that extension was already used this level. | `time_up_extension_modal.gd` |
| `ability_purchase.title` | USE ABILITY | GUNAKAN BOOSTER | Title of the modal that buys and immediately uses one booster when the player has none. | `ability_purchase_menu.gd` |
| `shelf_unlock.title` | UNLOCK SHELF | BUKA RAK | Title of the modal for a locked shelf. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer` | Watch one ad to unlock this shelf now. | Tonton satu iklan untuk membuka rak ini sekarang. | Body when no other way to unlock remains. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer_or_clear` | Watch one ad to unlock this shelf now, or clear %s more. | Tonton satu iklan untuk membuka rak ini sekarang, atau hapus %s set lagi. | Body when the shelf also unlocks by itself after more matches. `%s` = matches still needed. Needs plural forms. | `shelf_unlock_menu.gd` |
| `shelf_unlock.button` | Watch Ad · Unlock Shelf | Tonton Iklan · Buka Rak | Ad button in that modal. | `shelf_unlock_menu.gd` |
| `shelf_unlock.ad_unavailable` | Ad unavailable. This shelf stays locked. | Iklan tidak tersedia. Rak ini tetap terkunci. | Status line when no ad could be shown. | `shelf_unlock_menu.gd` |
| `complete.title` | GREAT JOB! | KERJA BAGUS! | Title of the level-complete screen, above the stars earned. | `level_completion_screen.gd` |
| `failed.title` | LEVEL %d | LEVEL %d | Title of the level-failed screen. `%d` = level number. | `level_failure_screen.gd` |
| `failed.headline` | LEVEL FAILED | LEVEL GAGAL | Banner on the level-failed screen. | `level_failure_screen.tscn` |
| `failed.retry` | Retry | Main Lagi | Replays the same level. | `level_failure_screen.tscn` |

Combo praise pops up above a match during a combo; each word is stronger than the one before, so keep the escalation. The label shrinks its font for long words, but one or two words is the limit.

| Key | English | Bahasa Indonesia | Shown at |
| --- | --- | --- | --- |
| `combo.praise.2` | Cool | Keren | Combo ×2 |
| `combo.praise.3` | Great | Hebat | ×3 |
| `combo.praise.4` | Awesome | Mantap | ×4 |
| `combo.praise.5` | Amazing | Menakjubkan | ×5 |
| `combo.praise.6` | Fantastic | Fantastis | ×6 |
| `combo.praise.7` | Incredible | Luar Biasa | ×7 |
| `combo.praise.8` | Spectacular | Spektakuler | ×8 |
| `combo.praise.9` | Unstoppable | Tak Terhentikan | ×9 |
| `combo.praise.10` | Legendary | Legendaris | ×10 |
| `combo.praise.11` | Epic | Epik | ×11 |
| `combo.praise.12` | Brilliant | Brilian | ×12 |
| `combo.praise.13` | Masterful | Maestro | ×13 |
| `combo.praise.14` | Supreme | Tak Terkalahkan | ×14 |
| `combo.praise.15` | Phenomenal | Fenomenal | ×15 |
| `combo.praise.16` | Mythic | Sakti | ×16 |
| `combo.praise.17` | Majestic | Agung | ×17 |
| `combo.praise.18` | Radiant | Gemilang | ×18 |
| `combo.praise.19` | Divine | Sempurna | ×19 |
| `combo.praise.20` | Transcendent | Melampaui Batas | ×20 and above |

Source: `COMBO_PRAISE_WORDS` in `level.gd`.

## Boosters, ads, lives, rewards and shop

The four boosters (also called abilities in code) are product names: pick one translation per language and reuse it everywhere, including the tooltips in the gameplay section.

| Key | English | Bahasa Indonesia | Context | Source |
| --- | --- | --- | --- | --- |
| `ability.hammer.name` | Hammer | Palu | Booster that smashes away one matching set. | `reward_reveal_row.tscn`, `starter_bundle_offer_modal.tscn`, `shop_screen.gd` |
| `ability.shuffle.name` | Shuffle | Acak | Booster that rearranges items. | same |
| `ability.lantern.name` | Lantern | Lentera | Booster that lights up a set the player can match (internal id `highlight`). | same |
| `ability.freezer.name` | Freezer | Pembeku | Booster that stops the level timer. | same |
| `ability.hammer.description` | Instantly clears one matching set of items off the shelves. | Langsung menghapus satu set tiga barang identik dari rak. | Shop info dialog body after tapping the booster icon. | `shop_screen.gd` |
| `ability.shuffle.description` | Shuffles shelf items into new spots to help you find a match. | Mengacak posisi barang di rak untuk membantumu menemukan barang yang cocok. | Same dialog. | `shop_screen.gd` |
| `ability.lantern.description` | Highlights a matching triple you can clear for 15 seconds. | Menyorot tiga barang identik selama 15 detik agar bisa kamu hapus. | Same dialog. Keep the number in sync with the game config. | `shop_screen.gd` |
| `ability.freezer.description` | Freezes the level timer for 30 seconds. | Membekukan hitung mundur level selama 30 detik. | Same dialog. | `shop_screen.gd` |
| `ad.watch` | Watch Ad | Tonton Iklan | Button that plays a rewarded video ad. | ad modals, `out_of_lives_menu`, `ability_purchase_menu.tscn` |
| `ad.loading` | Loading... | Memuat... | Ad button while the ad loads. | ad modals |
| `ad.verifying` | Verifying... | Verifikasi... | Ad button while the server confirms the reward. | ad modals |
| `ad.verify_reward` | Verify Reward | Verifikasi Hadiah | Ad button to re-check a reward the server has not confirmed yet. | ad modals |
| `ad.reward_pending` | Reward verification is still pending. | Verifikasi hadiah masih tertunda. | Status line under that button. | `out_of_lives_menu.gd`, `shelf_unlock_menu.gd` |
| `ad.unavailable_retry` | Ad unavailable. Please try again. | Iklan tidak tersedia. Silakan coba lagi. | Status line when no ad could be shown. | `out_of_lives_menu` |
| `ad.watch_unavailable` | Watch Ad\\nUnavailable | Tonton Iklan\\nTidak Tersedia | Two-line disabled ad button (time-up modal). Keep the line break. | `time_up_extension_modal.gd` |
| `ad.watch_coming_soon` | Watch Ad\\nComing Soon | Tonton Iklan\\nSegera Hadir | Two-line disabled ad button before ads launch. | `time_up_extension_modal.tscn` |
| `ad.badge` | AD | AD | Tiny badge on a locked shelf that an ad can open. Do not translate: keep AD exactly in every language. | `shelf_lock_overlay.tscn`, `shelf_unlock_menu.tscn` |
| `lives.title.out` | OUT OF LIVES | NYAWA HABIS | Lives modal title at 0 lives. | `out_of_lives_menu.gd` |
| `lives.title.get_more` | GET MORE LIVES | TAMBAH NYAWA | Lives modal title with some lives left. | `out_of_lives_menu.gd` |
| `lives.title.full` | LIVES FULL | NYAWA PENUH | Lives modal title at maximum lives. | `out_of_lives_menu.gd` |
| `lives.next_in` | NEXT LIFE IN | NYAWA BARU DALAM | Label above the refill countdown (mm:ss). | `out_of_lives_menu.tscn` |
| `lives.full_body` | Your lives are full! Play a level to spend them. | Nyawamu penuh! Mainkan level untuk menggunakannya. | Body of the lives modal at maximum. | `out_of_lives_menu.tscn` |
| `chest.title` | CHEST REWARDS | HADIAH DARI PETI | Title of the reward chest modal. | `reward_chest_menu.tscn` |
| `chest.progress_hint` | Collect stars to unlock a chest and claim your reward | Kumpulkan bintang untuk membuka peti dan mengambil hadiahmu | Under the star progress bar (e.g. 12/30). | `reward_chest_menu.tscn` |
| `chest.ready` | A REWARD CHEST AWAITS! | PETI HADIAH MENANTIMU! | Banner when the chest is full and can be opened. | `reward_chest_menu.tscn` |
| `chest.tap_to_open` | Tap to open | Ketuk untuk membuka | Prompt under the closed chest in the opening animation. | `reward_chest_open_ceremony.tscn` |
| `purchase.tap_to_collect` | Tap to collect | Ketuk untuk mengambil | Prompt to collect purchased rewards. | `purchase_reward_sequence.tscn` |
| `purchase.complete` | PURCHASE COMPLETE | PEMBELIAN SELESAI | Banner after a successful purchase. | `purchase_reward_sequence.gd` |
| `shop.title` | SHOP | TOKO | Shop screen title. | `shop_screen.tscn` |
| `shop.section.bundles` | SPECIAL BUNDLES | PAKET SPESIAL | Section header. | `shop_screen.tscn` |
| `shop.section.coins` | COINS | KOIN | Section header for coin packs. | `shop_screen.tscn` |
| `shop.offer.starter_bundle` | Starter Bundle | Paket Pemula | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.offer.basic_bundle` | Basic Bundle | Paket Dasar | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.tag.best_value` | BEST VALUE | PALING HEMAT | Ribbon on the best coin pack. | `configs/shop_catalog.json` |
| `shop.discount_off` | OFF | OFF | Second line of the discount badge under "67%". Do not translate: keep the complete 67% OFF tag unchanged in every language; the numeric percentage can vary by offer. | `shop_bundle_card.tscn`, `starter_bundle_offer_modal.tscn` |
| `shop.ability_hint` | Tap an ability to see what it does | Ketuk booster untuk melihat fungsinya | Hint under a bundle's booster icons. | `shop_bundle_card.tscn` |
| `shop.purchasing` | Purchasing… | Membeli… | Buy button while a purchase is in progress. | shop cards, `production_main_menu.gd` |
| `shop.no_offers` | No shop offers are available for this region. | Tidak ada penawaran toko yang tersedia untuk wilayah ini. | Shop error state. | `shop_screen.gd` |
| `shop.load_failed` | Could not load the shop. | Toko tidak dapat dimuat. | Shop error state (fallback text). | `shop_screen.gd` |
| `shop.error.title.purchase` | Purchase unavailable | Pembelian tidak tersedia | Error dialog title when buying failed. | `shop_screen.gd` |
| `shop.error.title.reward` | Reward error | Masalah hadiah | Error dialog title when payment went through but rewards were not granted. | `shop_screen.gd` |
| `shop.error.purchase_failed` | The purchase could not be completed. | Pembelian tidak dapat diselesaikan. | Error dialog body (fallback). | `shop_screen.gd`, `production_main_menu.gd` |
| `shop.error.grant_failed` | The purchased rewards could not be granted. | Hadiah yang dibeli tidak dapat diberikan. | Error dialog body. | `store/shop_purchase_flow.gd` |
| `shop.error.offer_unavailable` | This shop offer is unavailable. | Penawaran toko ini tidak tersedia. | Error dialog body. | `store/store_service.gd` |
| `shop.error.already_bought` | This one-time shop offer has already been purchased. | Penawaran yang hanya bisa dibeli sekali ini sudah dibeli. | Error dialog body. | `store/store_service.gd` |
| `starter.title` | STARTER BUNDLE | PAKET PEMULA | Starter offer modal title. | `starter_bundle_offer_modal.gd` |
| `starter.one_time` | ONE-TIME OFFER | HANYA SEKALI BELI | Ribbon on the starter offer. | `starter_bundle_offer_modal.tscn` |
| `starter.boosters_included` | BOOSTERS INCLUDED | TERMASUK BOOSTER | Header over the four booster chips. | `starter_bundle_offer_modal.tscn` |
| `starter.coins` | %s COINS | %s KOIN | Ribbon over the coin art. `%s` = formatted amount, e.g. "1,000". Needs plural forms. | `starter_bundle_offer_modal.gd` |
| `starter.buy_for` | Buy for %s | Beli seharga %s | Buy button. `%s` = store price, e.g. "$4.99". | `starter_bundle_offer_modal.gd` |
| `starter.checking` | Checking offer… | Memeriksa penawaran… | Status while the store confirms the offer. | `production_main_menu.gd` |
| `starter.checking_short` | Checking… | Memeriksa… | Buy button during that check. | `starter_bundle_offer_modal.gd` |
| `starter.no_longer_available` | This offer is no longer available. | Penawaran ini tidak lagi tersedia. | Error status in the starter modal. | `production_main_menu.gd` |
| `starter.unavailable` | Unavailable | Tidak Tersedia | Disabled buy button after a non-retryable error. | `starter_bundle_offer_modal.gd` |
| `booster_chip.claimed` | +%d %s | +%d %s | Booster chip after purchase, e.g. "+3 Hammer". `%d` = count, `%s` = booster name. Needs plural forms. | `offer_booster_chip.gd` |

## Profile, leaderboard and settings

Language names in the language picker stay in their own language (English, Español, 日本語…) and are never translated.

| Key | English | Bahasa Indonesia | Context | Source |
| --- | --- | --- | --- | --- |
| `profile.title` | EDIT PROFILE | EDIT PROFIL | Profile modal title. | `profile_menu.tscn` |
| `profile.name_header` | PLAYER NAME | NAMA PEMAIN | Header over the name field. | `profile_menu.tscn` |
| `profile.name_placeholder` | Player name | Nama pemain | Placeholder inside the empty name field. | `profile_menu.tscn` |
| `profile.edit_name_tooltip` | Edit player name | Edit nama pemain | Accessibility tooltip on the pencil button. | `profile_menu.tscn` |
| `profile.avatar_tab` | AVATAR | AVATAR | Tab that shows avatar pictures. | `profile_menu.tscn` |
| `profile.frame_tab` | FRAME | BINGKAI | Tab that shows decorative frames around the avatar. | `profile_menu.tscn` |
| `profile.unlock.level` | Complete level %d to unlock | Selesaikan level %d untuk membukanya | Toast after tapping a locked frame. `%d` = level number. | `profile_menu.gd` |
| `profile.unlock.combo` | Reach a combo of ×%d in any run to unlock | Raih kombo ×%d dalam satu permainan untuk membukanya | Same toast. `%d` = combo size. | `profile_menu.gd` |
| `profile.unlock.weekly_first` | Finish 1st on the Weekly leaderboard to unlock | Raih peringkat 1 di papan peringkat Mingguan untuk membukanya | Same toast for a first-place frame. Today built from two parts; see implementation notes. | `profile_menu.gd` |
| `profile.unlock.weekly_top` | Finish top %d on the Weekly leaderboard to unlock | Masuk %d besar di papan peringkat Mingguan untuk membukanya | Same toast. `%d` = rank cutoff (e.g. 10). | `profile_menu.gd` |
| `leaderboard.title` | LEADERBOARD | PAPAN PERINGKAT | Leaderboard screen title. | `leaderboard_screen.tscn` |
| `leaderboard.tab.weekly` | Weekly | Mingguan | Tab: this week's stars. | `leaderboard_screen.tscn` |
| `leaderboard.tab.country` | Country | Negara | Tab: all-time stars in the player's country. | `leaderboard_screen.tscn` |
| `leaderboard.tab.world` | World | Dunia | Tab: all-time stars worldwide. | `leaderboard_screen.tscn` |
| `leaderboard.weekly_reset` | Weekly reset in %s | Reset mingguan dalam %s | Under the Weekly tab. `%s` = a duration such as "1d 4h". | `leaderboard_screen.gd` |
| `leaderboard.duration.dh` | %dd %dh | %dh %dj | Duration: days and hours. Use local unit abbreviations. | `leaderboard_screen.gd` |
| `leaderboard.duration.hm` | %dh %dm | %dj %dm | Duration: hours and minutes. | `leaderboard_screen.gd` |
| `leaderboard.duration.m` | %dm | %dm | Duration: minutes. | `leaderboard_screen.gd` |
| `leaderboard.country_caption` | Country · All-time stars | Negara · Total bintang sepanjang waktu | Caption under the Country tab. | `leaderboard_screen.gd` |
| `leaderboard.world_caption` | Worldwide · All-time stars | Seluruh dunia · Total bintang sepanjang waktu | Caption under the World tab. | `leaderboard_screen.gd` |
| `leaderboard.load_failed` | Could not load leaderboard. | Papan peringkat tidak dapat dimuat. | Error state (fallback text). | `leaderboard_screen.gd` |
| `leaderboard.default_name` | Player | Pemain | Name shown for a player without one. | `leaderboard_row.gd` |
| `leaderboard.row_tooltip` | Rank %d, %s, %d stars | Peringkat %d, %s, %d bintang | Accessibility text of a row. `%d` = rank, `%s` = player name, `%d` = stars. Needs plural forms. | `leaderboard_row.gd` |
| `leaderboard.reward_tooltip` | %s coin weekly reward | Hadiah mingguan: %s koin | Accessibility text on the coin prize next to top ranks. `%s` = amount. | `leaderboard_rank_reward.gd` |
| `leaderboard.reward.title` | WEEKLY REWARD! | HADIAH MINGGUAN! | Title of the dialog shown after a week ends. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.body` | You finished #%d last week and earned %d coins! | Kamu meraih peringkat #%d minggu lalu dan mendapat %d koin! | Body. `%d` = final rank, `%d` = coins. Needs plural forms. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.ok` | Nice! | Asyik! | Button that closes the reward dialog. | `leaderboard_reward_dialog.tscn` |
| `settings.title` | SETTINGS | PENGATURAN | Settings modal title (home screen). | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.music` | Music | Musik | Toggle label under an icon. Short, about 8 characters. | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.sfx` | SFX | Suara | Toggle for sound effects. Use a short local word for "Sounds". | same |
| `settings.vibrate` | Vibrate | Getar | Toggle for haptic feedback. | same |
| `settings.support` | Support | Bantuan | Opens the Support screen. | `settings_menu.tscn` |
| `settings.language` | Language | Bahasa | Opens the language picker. | `settings_menu.tscn`, `language_option_row.tscn` |
| `settings.privacy_policy` | Privacy Policy | Kebijakan Privasi | Opens the privacy policy web page. | `settings_menu.tscn`, `production_main_menu.gd` |
| `settings.privacy_choices` | Privacy Choices | Pilihan Privasi | Same button when the ad consent form must be offered (EU/UK). | `production_main_menu.gd` |
| `settings.diagnostics` | Version %s • Build %d\\nPlatform: %s • User: %s | Versi %s • Build %d\\nPlatform: %s • Pengguna: %s | Small footer for support. Values: app version, build number, OS name, short player id. Translating the four labels is optional. | `pause_menu.gd` |
| `language.title` | LANGUAGE | BAHASA | Language picker title. | `language_selection_modal.gd` |

## Support, account deletion and platform text

Support and deletion copy is legal-adjacent: translate meaning exactly, keep "Nothing was deleted" and "You can't undo this" unambiguous, and do not soften the warnings.

### Support screen

| Key | English | Bahasa Indonesia | Context | Source |
| --- | --- | --- | --- | --- |
| `support.title` | SUPPORT | BANTUAN | Support screen title. | `support_screen.tscn` |
| `support.faq_header` | Frequently Asked Questions | Pertanyaan Umum | Section header. | `support_screen.tscn` |
| `support.faq.play.q` | How do I play? | Bagaimana cara bermain? | FAQ question (tap to expand). | `support_screen.tscn` |
| `support.faq.play.a` | Move matching goods onto the same shelf. When three identical items are visible together, they clear. Complete the board before time runs out. | Pindahkan barang yang cocok ke rak yang sama. Saat tiga barang identik terlihat bersama di satu rak, ketiganya akan hilang. Bersihkan papan sebelum waktu habis. | FAQ answer. "Goods" = shop items such as snacks and toys. | `support_screen.tscn` |
| `support.faq.contact.q` | How do I contact support? | Bagaimana cara menghubungi tim bantuan? | FAQ question. | `support_screen.tscn` |
| `support.faq.contact.a` | Email us at %s. Include a short description, your device platform, and when the problem happened. | Kirim email kepada kami di %s. Sertakan penjelasan singkat, platform perangkatmu, dan waktu terjadinya masalah. | FAQ answer. `%s` = support email address. | `support_screen.gd` |
| `support.faq.contact.action` | Email Support | Email Tim Bantuan | Button that opens a pre-filled email. | `support_screen.tscn` |
| `support.faq.crash.q` | What if the game freezes or crashes? | Bagaimana jika game macet atau tiba-tiba tertutup? | FAQ question. | `support_screen.tscn` |
| `support.faq.crash.a` | Close and reopen the game first. If it happens again, restart the device and make sure the game is updated. Contact support with the device model, platform version, and what you were doing before the problem. | Tutup lalu buka kembali game terlebih dahulu. Jika terjadi lagi, mulai ulang perangkat dan pastikan game sudah diperbarui. Hubungi tim bantuan dengan menyertakan model perangkat, versi platform, dan apa yang kamu lakukan sebelum masalah terjadi. | FAQ answer. | `support_screen.tscn` |
| `support.faq.sync.q` | How do I sync progress between devices? | Bagaimana cara menyinkronkan progres antarperangkat? | FAQ question. | `support_screen.tscn` |
| `support.faq.sync.a` | Use the same signed-in platform account on both devices and allow synchronization to finish before playing. If the progress differs, avoid playing on both devices and contact support. | Masuk dengan akun platform yang sama di kedua perangkat dan tunggu hingga sinkronisasi selesai sebelum bermain. Jika progresnya berbeda, hindari bermain di kedua perangkat dan hubungi tim bantuan. | FAQ answer. "Platform account" = Google Play Games / Game Center. | `support_screen.tscn` |
| `support.faq.bad_ad.q` | How do I report a bad ad? | Bagaimana cara melaporkan iklan bermasalah? | FAQ question. | `support_screen.tscn` |
| `support.faq.bad_ad.a` | 1. Close the ad if you can do so safely.\\n2. Take a screenshot of the ad and any advertiser or app name shown.\\n3. Note the approximate time and where the ad appeared in the game.\\n4. Describe why the ad seemed offensive, misleading, or fraudulent.\\n5. Email these details to %s. Do not include passwords or payment information. | 1. Tutup iklan jika aman untuk dilakukan.\\n2. Ambil tangkapan layar iklan beserta nama pengiklan atau aplikasi yang ditampilkan.\\n3. Catat perkiraan waktu dan tempat iklan muncul di dalam game.\\n4. Jelaskan mengapa iklan terasa menyinggung, menyesatkan, atau mengandung penipuan.\\n5. Kirim detail ini melalui email ke %s. Jangan sertakan kata sandi atau informasi pembayaran. | FAQ answer, a five-step list in one string. `%s` = support email. Keep the numbering and line breaks. | `support_screen.gd` |
| `support.faq.bad_ad.action` | Email Ad Report | Email Laporan Iklan | Button that opens a pre-filled ad-report email. | `support_screen.tscn` |
| `support.account_header` | Account | Akun | Section header above the delete button. | `support_screen.tscn` |
| `support.delete_account` | Delete Account | Hapus Akun | Opens account deletion (player has an online account). | `support_screen.gd` |
| `support.delete_game_data` | Delete Game Data | Hapus Data Game | Same button when only local data exists. | `support_screen.gd` |
| `support.no_secrets` | Please never send passwords or payment information. | Jangan pernah mengirim kata sandi atau informasi pembayaran. | Warning at the bottom of the screen. | `support_screen.tscn` |

### Account deletion modal

One modal switches between states; each state has a title (caps), a headline, a body and up to two buttons.

| Key | English | Bahasa Indonesia | Context | Source |
| --- | --- | --- | --- | --- |
| `deletion.title.delete_account` | DELETE ACCOUNT | HAPUS AKUN | Title: confirm, in progress and unavailable states. | `account_deletion_modal.gd` |
| `deletion.title.delete_game_data` | DELETE GAME DATA | HAPUS DATA GAME | Title for a player who never had an online account. | same |
| `deletion.title.not_confirmed` | NOT CONFIRMED | BELUM DIKONFIRMASI | Title: request sent, answer lost. | same |
| `deletion.title.status_unconfirmed` | STATUS UNCONFIRMED | STATUS BELUM DIKONFIRMASI | Title: server outcome unknown. | same |
| `deletion.title.finishing_up` | FINISHING UP | MENYELESAIKAN | Title: local cleanup incomplete. | same |
| `deletion.title.new_game` | NEW GAME | GAME BARU | Title while a fresh save is created. | same |
| `deletion.title.status_unknown` | STATUS UNKNOWN | STATUS TIDAK DIKETAHUI | Title: local deletion record unreadable. | same |
| `deletion.title.not_deleted` | NOT DELETED | TIDAK DIHAPUS | Title after a failed attempt. | same |
| `deletion.title.data_deleted` | DATA DELETED | DATA DIHAPUS | Title after local data is deleted. | same |
| `deletion.title.accepted` | DELETION ACCEPTED | PENGHAPUSAN DITERIMA | Title after the server accepts the request. | same |
| `deletion.confirm.headline` | This permanently deletes your account. | Ini akan menghapus akunmu secara permanen. | Confirm step, online account. | same |
| `deletion.confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nIf you sign in again later, you'll start a new account.\\n\\nSome purchase and security records are kept without your name or profile. The rest is removed within 30 days. | Progres, koin, barang, dan profilmu akan hilang. Tindakan ini tidak bisa dibatalkan.\\n\\nJika masuk lagi nanti, kamu akan memulai dengan akun baru.\\n\\nSebagian catatan pembelian dan keamanan disimpan tanpa nama atau profilmu. Data lainnya akan dihapus dalam 30 hari. | Confirm step body. Keep the three paragraphs. | same |
| `deletion.confirm.button` | Delete Account | Hapus Akun | Red destructive button. | same |
| `deletion.local_confirm.headline` | This deletes your game data on this device. | Ini akan menghapus data gamemu di perangkat ini. | Confirm step, local-only player. | same |
| `deletion.local_confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nThis game never created an online account for you, so nothing needs to be deleted from our servers. | Progres, koin, barang, dan profilmu akan hilang. Tindakan ini tidak bisa dibatalkan.\\n\\nGame ini tidak pernah membuat akun online untukmu, jadi tidak ada data yang perlu dihapus dari server kami. | Body for that step. | same |
| `deletion.local_confirm.button` | Delete Data | Hapus Data | Red destructive button. | same |
| `deletion.pending_setup.headline` | Your account is still being set up. | Akunmu masih sedang disiapkan. | Deletion blocked: first registration not finished. | same |
| `deletion.pending_setup.body` | Connect to the internet and try again in a moment. Nothing was deleted. | Hubungkan ke internet, tunggu sebentar, lalu coba lagi. Tidak ada yang dihapus. | Body. | same |
| `deletion.sign_in.headline` | Sign in to the account you want to delete. | Masuk ke akun yang ingin kamu hapus. | Deletion blocked: signed out. | same |
| `deletion.sign_in.body` | If you can't sign in, contact support for help. | Jika kamu tidak bisa masuk, hubungi tim bantuan. | Body. | same |
| `deletion.read_failed.headline` | Your game data couldn't be read. | Data gamemu tidak dapat dibaca. | Deletion blocked: save unreadable. | same |
| `deletion.read_failed.body` | Restart the game, then try again. Nothing was deleted. | Mulai ulang game, lalu coba lagi. Tidak ada yang dihapus. | Body. | same |
| `deletion.unavailable.headline` | Account deletion isn't available in this version of the game. | Penghapusan akun tidak tersedia di versi game ini. | Deletion blocked: feature off. Also a failure headline. | same |
| `deletion.unavailable.body` | Update the game, or contact support for help deleting your account. Nothing was deleted. | Perbarui game, atau hubungi tim bantuan untuk menghapus akunmu. Tidak ada yang dihapus. | Body. | same |
| `deletion.in_progress.account` | Deleting your account... | Menghapus akunmu... | Headline while the request runs. | same |
| `deletion.in_progress.local` | Deleting your game data... | Menghapus data gamemu... | Same for local-only data. | same |
| `deletion.in_progress.body` | Keep the game open. This only takes a moment. | Biarkan game tetap terbuka. Proses ini hanya sebentar. | Body while deleting. | same |
| `deletion.not_confirmed.headline` | We haven't heard back about your deletion yet. | Kami belum menerima respons atas permintaan penghapusanmu. | Request sent, answer lost. | same |
| `deletion.not_confirmed.body` | Your request was sent, but the answer didn't arrive. Connect to the internet and try again. The game stays locked until we know the result. | Permintaanmu sudah dikirim, tetapi responsnya belum diterima. Hubungkan ke internet dan coba lagi. Game tetap terkunci hingga kami mengetahui hasilnya. | Body. | same |
| `deletion.unconfirmed.headline` | Deletion status unconfirmed | Status penghapusan belum dikonfirmasi | Server outcome unknown. | same |
| `deletion.unconfirmed.body` | We couldn't confirm whether your account was deleted. To keep your data safe, the game stays locked. Contact support and include the reference below. | Kami tidak dapat memastikan apakah akunmu sudah dihapus. Demi keamanan datamu, game tetap terkunci. Hubungi tim bantuan dan sertakan referensi di bawah ini. | Body; a reference code is shown under it. | same |
| `deletion.check_again` | Check Again | Periksa Lagi | Asks the server again. | same |
| `deletion.cleanup.headline.local` | Your local game data couldn't be fully deleted yet. | Data game lokalmu belum dapat dihapus sepenuhnya. | Local cleanup incomplete (local-only player). | same |
| `deletion.cleanup.headline.account` | Account deletion accepted; finishing cleanup. | Permintaan penghapusan akun diterima; pembersihan sedang diselesaikan. | Local cleanup incomplete after the server accepted. | same |
| `deletion.cleanup.body` | Some game data couldn't be removed from this device yet. Try again to finish. | Sebagian data game belum dapat dihapus dari perangkat ini. Coba lagi untuk menyelesaikannya. | Body. | same |
| `deletion.new_game.headline` | Starting a new game... | Memulai game baru... | While a fresh save is created. | same |
| `deletion.new_game.body` | This only takes a moment. | Proses ini hanya sebentar. | Body. | same |
| `deletion.status_unknown.headline` | We couldn't read the deletion status on this device. | Kami tidak dapat membaca status penghapusan di perangkat ini. | Local deletion record unreadable. | same |
| `deletion.status_unknown.body` | To keep your data safe, the game stays locked. Contact support for help. | Demi keamanan datamu, game tetap terkunci. Hubungi tim bantuan. | Body. | same |
| `deletion.fail.offline` | Connect to the internet to delete your account. | Hubungkan ke internet untuk menghapus akunmu. | Failure headline. | same |
| `deletion.fail.rate_limited` | Too many attempts. Wait a moment, then try again. | Terlalu banyak percobaan. Tunggu sebentar, lalu coba lagi. | Failure headline. | same |
| `deletion.fail.busy` | Account deletion is busy right now. Try again in a moment. | Layanan penghapusan akun sedang sibuk. Tunggu sebentar, lalu coba lagi. | Failure headline (server unavailable). | same |
| `deletion.fail.syncing` | The game is still syncing. Try again in a moment. | Game masih melakukan sinkronisasi. Tunggu sebentar, lalu coba lagi. | Failure headline. | same |
| `deletion.fail.auth` | We couldn't verify your account. Restart the game, then try again. | Kami tidak dapat memverifikasi akunmu. Mulai ulang game, lalu coba lagi. | Failure headline. | same |
| `deletion.fail.update` | Update the game to delete your account. | Perbarui game untuk menghapus akunmu. | Failure headline (client too old). | same |
| `deletion.fail.changed` | Your account changed while we were deleting it. Try again. | Akunmu berubah saat kami menghapusnya. Coba lagi. | Failure headline. | same |
| `deletion.fail.storage` | Your device couldn't save the deletion request. Try again. | Perangkatmu tidak dapat menyimpan permintaan penghapusan. Coba lagi. | Failure headline. | same |
| `deletion.fail.generic` | We couldn't delete your account. Try again later or contact support. | Kami tidak dapat menghapus akunmu. Coba lagi nanti atau hubungi tim bantuan. | Failure headline (fallback). | same |
| `deletion.fail.local` | Your game data couldn't be deleted. Try again. | Data gamemu tidak dapat dihapus. Coba lagi. | Failure headline, local-only player. | same |
| `deletion.fail.body` | Nothing was deleted, and you can keep playing. | Tidak ada yang dihapus, dan kamu bisa tetap bermain. | Body for every failure. | same |
| `deletion.done_local.headline` | Your local game data was deleted. | Data game lokalmu sudah dihapus. | Success, local-only player. | same |
| `deletion.done_local.body` | You can start over with a new game. | Kamu bisa mulai dari awal dengan game baru. | Body. | same |
| `deletion.new_game_failed` | The new game couldn't start. Try again. | Game baru tidak dapat dimulai. Coba lagi. | Appended under a success body if the fresh save failed. | same |
| `deletion.accepted.headline` | Your account is no longer accessible. | Akunmu tidak lagi dapat diakses. | Success, online account. | same |
| `deletion.accepted.body` | Your deletion request was accepted. | Permintaan penghapusanmu diterima. | Body when no deadline is known. | same |
| `deletion.accepted.body_deadline` | Your deletion request was accepted. Data removal is due by %s. | Permintaan penghapusanmu diterima. Data akan dihapus paling lambat %s. | Body. `%s` = a date such as "November 2, 2026". | same |
| `deletion.reference` | Reference: %s | Referensi: %s | Support reference code under the body. `%s` = operation id; never translated. | same |
| `deletion.start_new_game` | Start New Game | Mulai Game Baru | Button after a successful deletion. | same |

### Platform and system text

| Key | English | Bahasa Indonesia | Context | Source |
| --- | --- | --- | --- | --- |
| `app.name` | SortingPuzzle | SortingPuzzle | App name under the home-screen icon; today the internal project name. Decide the public name per store first. | `project.godot`, `export_presets.cfg` |
| `support.email.subject` | Sorting Puzzle support request | Permintaan bantuan Sorting Puzzle | Subject of the pre-filled support email. | `support_screen.gd` |
| `support.email.body` | Please describe the issue here.\\n\\nDevice/platform:\\nApproximate time:\\n | Jelaskan masalahnya di sini.\\n\\nPerangkat/platform:\\nPerkiraan waktu:\\n | Body template the player fills in. | `support_screen.gd` |
| `support.ad_email.subject` | Sorting Puzzle ad report | Laporan iklan Sorting Puzzle | Subject of the ad-report email. | `support_screen.gd` |
| `support.ad_email.body` | Please attach a screenshot and complete the details below.\\n\\nApproximate time:\\nAd placement in the game:\\nAdvertiser or app name:\\nWhy the ad should be reviewed:\\n | Lampirkan tangkapan layar dan lengkapi detail di bawah ini.\\n\\nPerkiraan waktu:\\nPosisi iklan di dalam game:\\nNama pengiklan atau aplikasi:\\nAlasan iklan perlu ditinjau:\\n | Body template the player fills in. | `support_screen.gd` |
| `deletion.email.subject` | Sorting Puzzle account deletion | Penghapusan akun Sorting Puzzle | Subject of the deletion help email. | `account_deletion_modal.gd` |
| `deletion.email.body` | Please help me with my account deletion. | Mohon bantu saya menghapus akun saya. | First line; followed by `Status:`, `Deletion reference:`, `Server reference:` and `Player ID:` lines. | `account_deletion_modal.gd` |

## Appendix: count-sensitive entries

Indonesian uses one wording for all integer counts, including 0, 1, 2, 5 and 21. Use the main-table translation unchanged for all six entries marked “Needs plural forms” in the source:

- `chapter.locked_status`
- `shelf_unlock.offer_or_clear`
- `starter.coins`
- `booster_chip.claimed`
- `leaderboard.row_tooltip`
- `leaderboard.reward.body`

Do not duplicate nouns after a number: use `1 koin`, `2 koin`, `1 bintang`, `5 bintang`, `1 level` and `3 level`. The same principle applies to `leaderboard.reward_tooltip`, even though it is not marked as plural-sensitive in the source.

Counted product names remain `Palu`, `Acak`, `Lentera` and `Pembeku`: for example, `+1 Palu`, `+3 Palu` and `+2 Pembeku`. Replace `%s` in `booster_chip.claimed` with the already translated booster name.

## Appendix: supplementary deletion-email labels

The inventory mentions four additional labels in the context for `deletion.email.body` without assigning them keys. Their values remain unchanged; only the labels translate.

| English | Bahasa Indonesia |
| --- | --- |
| Status: | Status: |
| Deletion reference: | Referensi penghapusan: |
| Server reference: | Referensi server: |
| Player ID: | ID Pemain: |

## Appendix: Indonesian dates and numbers

Use day–month–year for readable deadlines, for example `2 November 2026`. The `%s` in `deletion.accepted.body_deadline` receives an already formatted date. It is separate from the translated sentence.

| English month | Bahasa Indonesia |
| --- | --- |
| January | Januari |
| February | Februari |
| March | Maret |
| April | April |
| May | Mei |
| June | Juni |
| July | Juli |
| August | Agustus |
| September | September |
| October | Oktober |
| November | November |
| December | Desember |

Use periods for grouped integer counts (`1.234.567`) and a comma for a decimal separator when formatting game-owned numbers. Store-supplied prices keep their supplied localized formatting.

## Review status

All 251 inventory entries are present once in the main tables, with no missing or extra keys. The original English, contexts and source references are preserved. Placeholder sequences and escaped line-break counts were checked against the source. The invariant `AD`, `OFF`, app name, compact label lengths, booster terminology and count-sensitive entries were also checked.

The attached inventory's implementation recommendations describe its October audit. They have not been applied by this translation-only task. The Indonesian copy has not yet been installed or rendered in the game.
