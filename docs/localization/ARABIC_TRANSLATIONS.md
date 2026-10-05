# Sorting Puzzle — Arabic Translations

Locale: `ar` · Language: العربية (Modern Standard Arabic) · Prepared: October 5, 2026

Bilingual translation of all **251 keyed strings** in **Sorting Puzzle — Translation String Inventory.md**, including its October 5, 2026 copy updates. English strings, suggested keys, context and source references are retained for review. Protected markers, the existing app name and the quantity-and-product template are intentionally unchanged. This document supplies translation copy for later integration.

## Arabic terminology

| English | Arabic | Usage |
| --- | --- | --- |
| Level | مستوى | One puzzle board. |
| Chapter | فصل | A themed group of levels. |
| Shelf | رف | Plural: رفوف. |
| Item / goods | عنصر / منتج | Items are عناصر; shop goods are منتجات. |
| Match / triple / set | ثلاثية متطابقة | Three identical items; use ثلاثية when context is clear. |
| Combo | تتابع | A chain of matches made in quick succession. |
| Booster / ability | معزز | The four consumable gameplay abilities. |
| Hammer | المطرقة | Product name; reuse unchanged. |
| Shuffle | الخلط | Product name; reuse unchanged. |
| Lantern | الفانوس | Product name; reuse unchanged. |
| Freezer | التجميد | Product name; reuse unchanged. |
| Dispenser | موزّع | Tappable machine that throws items onto shelves. |
| Coins | عملات | Singular: عملة. |
| Stars | نجوم | Singular: نجمة. |
| Lives | محاولات | Heart-based attempts consumed on failure or leaving. |
| Reward chest | صندوق مكافآت | A chest unlocked by collecting stars. |
| Bundle | حزمة | A pack containing coins and boosters. |

## Reading the tables

- Copy uses clear Modern Standard Arabic suitable across Arabic-speaking regions. Arabic has no uppercase/lowercase distinction, so capitalized English headings use ordinary Arabic lettering.
- Every `%d` and `%s` placeholder retains its original type and order. Placeholder values such as player names, email addresses, prices and reference codes stay unchanged.
- Forced line breaks retain the source document's Markdown representation (`\\n`). Decode each marker to one line break when building a translation catalog; consecutive markers separate paragraphs.
- The six source entries marked **Needs plural forms** use representative forms in the main tables. Use the complete variants in the appendix according to the actual count. The appendix also covers the count-bearing weekly-reward tooltip.
- `AD` and `OFF` remain exactly as specified. Keep complete tags such as `67% OFF`, including their digits, `%` sign, order and existing two-line layout. The home badge is translated from the updated `BUNDLE` copy as «حزمة».
- `SortingPuzzle` / `Sorting Puzzle` remain the existing app and brand names. Language-picker names remain native; Arabic's own display name is «العربية».
- Compact time units are `ث` (seconds), `د` (minutes), `س` (hours), and `ي` (days). Existing numeric values, including 15, 30 and 30 days, are preserved.
- Support and account-deletion copy preserves irreversibility, retained records, deletion deadlines, blocked states and the explicit statement that nothing was deleted.
- Strings use normal Unicode logical order and contain no invisible bidirectional control characters. During integration, verify Arabic glyph coverage and shaping, right-to-left layout, and mixed-direction runs such as `×%d`, `+%d`, prices, email addresses, player names and reference codes. Keep `AD` and discount tags in their intended left-to-right order.
- These translations have been checked against the inventory. They have not been installed or rendered in the game; font coverage, shaping and actual fit need verification during integration.

## Shared buttons, main menu and chapters

Shared buttons appear on several screens and need one translation each, except where the context says the meaning differs. Keys are suggestions for the future translation table.

| Key | English | Arabic | Context | Source |
| --- | --- | --- | --- | --- |
| `common.play` | Play | العب | Button that starts the chapter's next level on a chapter card. | `chapter_cover_card.gd` |
| `common.continue` | Continue | متابعة | Button that moves on: closes the level-complete screen, the purchase dialog and the reward chest menu; on a chapter card it resumes a chapter already started. | `level_completion_screen.tscn`, `shop_purchase_dialog`, `reward_chest_menu.tscn`, `chapter_cover_card.gd` |
| `common.resume` | Continue | استئناف | Button on Pause and on the leave confirmation that returns to the running level ("keep playing"). Separate key: some languages use a different verb than for "move on". | `pause_menu.tscn`, `leave_confirmation_menu.tscn` |
| `common.try_again` | Try Again | حاول مجددًا | Retries a failed action (ad, purchase, account deletion). | ad modals, `account_deletion_modal.gd`, `starter_bundle_offer_modal.gd` |
| `common.close` | Close | إغلاق | Closes a dialog without doing anything. | `account_deletion_modal.gd` |
| `common.cancel` | Cancel | إلغاء | Backs out of account deletion; nothing is deleted. | `account_deletion_modal.tscn` |
| `common.got_it` | Got it | فهمت | Acknowledges an info dialog (ability description, lives already full). | `out_of_lives_menu.tscn`, `shop_screen.gd` |
| `common.get_help` | Get Help | طلب المساعدة | Opens a pre-filled email to support. | `account_deletion_modal.gd` |
| `common.save` | SAVE | حفظ | Confirms profile edits or the chosen language. All caps by design. | `profile_menu`, `language_selection_modal.tscn` |
| `common.loading` | Loading… | جارٍ التحميل… | Shown while the Shop or Leaderboard loads its data. | `destination_status_panel.tscn` |
| `common.retry_load` | Retry | إعادة التحميل | Reloads the Shop or Leaderboard after a load error. Not the same as replaying a level. | `destination_status_panel.tscn` |
| `menu.level_button` | LEVEL %d | المستوى %d | Big play button on the home screen. `%d` = level number inside the current chapter. | `production_main_menu.gd` |
| `menu.more_levels_coming_soon` | MORE LEVELS COMING SOON | مستويات جديدة قريبًا | Home play button (disabled) after every level of the chapter is finished. Must fit the button, about 24 characters. | `production_main_menu.gd` |
| `menu.coming_soon` | COMING SOON | قريبًا | Home play button (disabled) when the chapter has no levels yet. | `production_main_menu.gd` |
| `menu.lives_full` | Full | ممتلئ | Top bar, next to the heart, when lives are at maximum; replaces the refill timer. About 5 characters. | `production_main_menu.gd`, `main_menu_top_status.tscn` |
| `menu.starter_badge` | BUNDLE | حزمة | Small badge on the home screen that opens the Starter Bundle offer. About 8 characters. Russian: НАБОР. The full offer title remains Starter Bundle / Стартовый набор. | `main_menu_starter_bundle_badge.tscn` |
| `nav.shop` | Shop | المتجر | Bottom navigation tab. About 10 characters. | `main_menu_bottom_navigation.tscn` |
| `nav.home` | Home | الرئيسية | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `nav.leaderboard` | Leaderboard | المتصدرون | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `chapter.button` | CHAPTER %d | الفصل %d | Home button that opens chapter selection. `%d` = chapter number. | `main_menu_chapter_button.gd` |
| `chapter.button_tooltip` | Choose Chapter %d: %s | اختر الفصل %d: %s | Accessibility tooltip of that button. `%d` = chapter number, `%s` = chapter title. | `main_menu_chapter_button.gd` |
| `chapter.screen_title` | CHAPTERS | الفصول | Title of the chapter selection screen. | `chapter_selection_screen.tscn` |
| `chapter.eyebrow` | CHAPTER %d | الفصل %d | Small label above the chapter name on its card. | `chapter_cover_card.gd` |
| `chapter.title.chapter_01` | Grocery Town | مدينة البقالة | Name of chapter 1 (a grocery-store theme). | `configs/chapters.json` |
| `chapter.title.chapter_02` | Candy Corner | ركن الحلوى | Name of chapter 2 (a candy-shop theme). | `configs/chapters.json` |
| `chapter.locked_status` | Complete %d more %s levels to unlock | أكمل %d مستوى إضافيًا في «%s» لفتح الفصل | Locked chapter card. `%d` = levels still needed, `%s` = previous chapter's name. Needs plural forms. | `chapter_cover_card.gd` |
| `chapter.unlock_progress` | Unlock progress | التقدم نحو الفتح | Header over the progress bar on a locked chapter. | `chapter_cover_card.gd` |
| `chapter.current_progress` | Current progress | التقدم الحالي | Header over the progress bar on an unlocked chapter. | `chapter_cover_card.gd` |
| `chapter.locked` | Locked | مقفل | Disabled button on a locked chapter card. | `chapter_cover_card.gd` |
| `chapter.no_levels_status` | New levels are coming soon | مستويات جديدة قادمة قريبًا | Card message for a chapter with no levels yet. | `chapter_cover_card.gd` |
| `chapter.coming_soon` | Coming Soon | قريبًا | Disabled button on that card. | `chapter_cover_card.gd` |

## Gameplay: HUD, level screens and results

These strings show during a level, mostly in modal titles (all caps, short) and action buttons. A "triple" or "match" is three identical items on one shelf, which clears them.

| Key | English | Arabic | Context | Source |
| --- | --- | --- | --- | --- |
| `hud.level` | LEVEL %d | المستوى %d | Top HUD during play. `%d` = level number inside the chapter. | `level.gd` |
| `hud.combo` | COMBO ×%d | تتابع ×%d | HUD counter for consecutive quick matches. `%d` = combo size; keep the × sign. | `level_top_hud.gd` |
| `hud.ability_tooltip.hammer` | Hammer -- clears a matching triple | المطرقة — تزيل ثلاثية متطابقة | Accessibility tooltip on the Hammer booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.shuffle` | Shuffle -- reshuffles unlocked items | الخلط — يعيد ترتيب العناصر غير المقفلة | Tooltip on the Shuffle booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.lantern` | Lantern -- highlights a matchable triple | الفانوس — يبرز ثلاثية قابلة للمطابقة | Tooltip on the Lantern booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.freezer` | Freezer -- pauses the countdown timer | التجميد — يوقف مؤقت العد التنازلي | Tooltip on the Freezer booster button. | `ability_bar.tscn` |
| `hud.seconds_short` | %ds | %d ث | Countdown on an active Lantern or Freezer booster, e.g. "15s". `%d` = seconds; use the local short unit. | `ability_bar.gd` |
| `tip.tap_dispenser` | Tap a dispenser to throw items onto the shelves! | اضغط على الموزّع لإلقاء العناصر على الرفوف! | Tutorial bubble on level 10, where dispensers (machines that throw items onto shelves) first appear. | `configs/gameplay_tips.json` |
| `pause.title` | PAUSE | إيقاف مؤقت | Title of the in-level pause modal. | `pause_menu.gd` |
| `pause.leave` | Leave | مغادرة | Pause button that quits the level (asks for confirmation next). | `pause_menu.tscn` |
| `leave.title` | LEAVING THE LEVEL | مغادرة المستوى | Title of the leave confirmation. | `leave_confirmation_menu.gd` |
| `leave.you_will_lose` | You will lose: | ستفقد: | Followed by icons showing the stars earned this run and one life. Keep the colon (or local equivalent). | `leave_confirmation_menu.tscn` |
| `leave.confirm` | Leave | مغادرة | Confirms quitting the level and losing that progress. | `leave_confirmation_menu.tscn` |
| `timeup.title` | TIME'S UP | انتهى الوقت | Title when the level timer reaches zero. | `time_up_extension_modal.gd` |
| `timeup.offer` | Add one minute and keep sorting! | أضف دقيقة وواصل الفرز! | Offer to extend the timer by 60 seconds for coins or an ad. | `time_up_extension_modal.tscn` |
| `timeup.used` | Used | تم الاستخدام | Shown on the coin price or ad button when that extension was already used this level. | `time_up_extension_modal.gd` |
| `ability_purchase.title` | USE ABILITY | استخدام معزز | Title of the modal that buys and immediately uses one booster when the player has none. | `ability_purchase_menu.gd` |
| `shelf_unlock.title` | UNLOCK SHELF | فتح الرف | Title of the modal for a locked shelf. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer` | Watch one ad to unlock this shelf now. | شاهد إعلانًا لفتح هذا الرف الآن. | Body when no other way to unlock remains. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer_or_clear` | Watch one ad to unlock this shelf now, or clear %s more. | شاهد إعلانًا لفتح هذا الرف الآن، أو أزل %s ثلاثية أخرى. | Body when the shelf also unlocks by itself after more matches. `%s` = matches still needed. Needs plural forms. | `shelf_unlock_menu.gd` |
| `shelf_unlock.button` | Watch Ad · Unlock Shelf | شاهد إعلانًا · افتح الرف | Ad button in that modal. | `shelf_unlock_menu.gd` |
| `shelf_unlock.ad_unavailable` | Ad unavailable. This shelf stays locked. | الإعلان غير متاح. سيبقى هذا الرف مقفلًا. | Status line when no ad could be shown. | `shelf_unlock_menu.gd` |
| `complete.title` | GREAT JOB! | أحسنت! | Title of the level-complete screen, above the stars earned. | `level_completion_screen.gd` |
| `failed.title` | LEVEL %d | المستوى %d | Title of the level-failed screen. `%d` = level number. | `level_failure_screen.gd` |
| `failed.headline` | LEVEL FAILED | لم تكمل المستوى | Banner on the level-failed screen. | `level_failure_screen.tscn` |
| `failed.retry` | Retry | أعد المحاولة | Replays the same level. | `level_failure_screen.tscn` |

Combo praise pops up above a match during a combo; each word is stronger than the one before, so keep the escalation. The label shrinks its font for long words, but one or two words is the limit.

| Key | English | Arabic | Shown at |
| --- | --- | --- | --- |
| `combo.praise.2` | Cool | جميل | Combo ×2 |
| `combo.praise.3` | Great | رائع | ×3 |
| `combo.praise.4` | Awesome | مذهل | ×4 |
| `combo.praise.5` | Amazing | مدهش | ×5 |
| `combo.praise.6` | Fantastic | مبهر | ×6 |
| `combo.praise.7` | Incredible | لا يصدق | ×7 |
| `combo.praise.8` | Spectacular | خاطف للأنظار | ×8 |
| `combo.praise.9` | Unstoppable | لا يتوقف | ×9 |
| `combo.praise.10` | Legendary | أسطوري | ×10 |
| `combo.praise.11` | Epic | ملحمي | ×11 |
| `combo.praise.12` | Brilliant | عبقري | ×12 |
| `combo.praise.13` | Masterful | احترافي | ×13 |
| `combo.praise.14` | Supreme | لا يضاهى | ×14 |
| `combo.praise.15` | Phenomenal | استثنائي | ×15 |
| `combo.praise.16` | Mythic | خرافي | ×16 |
| `combo.praise.17` | Majestic | مهيب | ×17 |
| `combo.praise.18` | Radiant | متألق | ×18 |
| `combo.praise.19` | Divine | ساحر | ×19 |
| `combo.praise.20` | Transcendent | يفوق الخيال | ×20 and above |

Source: `COMBO_PRAISE_WORDS` in `level.gd`.

## Boosters, ads, lives, rewards and shop

The four boosters (also called abilities in code) are product names: pick one translation per language and reuse it everywhere, including the tooltips in the gameplay section.

| Key | English | Arabic | Context | Source |
| --- | --- | --- | --- | --- |
| `ability.hammer.name` | Hammer | المطرقة | Booster that smashes away one matching set. | `reward_reveal_row.tscn`, `starter_bundle_offer_modal.tscn`, `shop_screen.gd` |
| `ability.shuffle.name` | Shuffle | الخلط | Booster that rearranges items. | same |
| `ability.lantern.name` | Lantern | الفانوس | Booster that lights up a set the player can match (internal id `highlight`). | same |
| `ability.freezer.name` | Freezer | التجميد | Booster that stops the level timer. | same |
| `ability.hammer.description` | Instantly clears one matching set of items off the shelves. | تزيل فورًا ثلاثية من العناصر المتطابقة من الرفوف. | Shop info dialog body after tapping the booster icon. | `shop_screen.gd` |
| `ability.shuffle.description` | Shuffles shelf items into new spots to help you find a match. | يعيد توزيع عناصر الرفوف في أماكن جديدة ليساعدك على إيجاد ثلاثية متطابقة. | Same dialog. | `shop_screen.gd` |
| `ability.lantern.description` | Highlights a matching triple you can clear for 15 seconds. | يبرز لمدة 15 ثانية ثلاثية متطابقة يمكنك إزالتها. | Same dialog. Keep the number in sync with the game config. | `shop_screen.gd` |
| `ability.freezer.description` | Freezes the level timer for 30 seconds. | يجمد مؤقت المستوى لمدة 30 ثانية. | Same dialog. | `shop_screen.gd` |
| `ad.watch` | Watch Ad | شاهد إعلانًا | Button that plays a rewarded video ad. | ad modals, `out_of_lives_menu`, `ability_purchase_menu.tscn` |
| `ad.loading` | Loading... | جارٍ التحميل... | Ad button while the ad loads. | ad modals |
| `ad.verifying` | Verifying... | جارٍ التحقق... | Ad button while the server confirms the reward. | ad modals |
| `ad.verify_reward` | Verify Reward | التحقق من المكافأة | Ad button to re-check a reward the server has not confirmed yet. | ad modals |
| `ad.reward_pending` | Reward verification is still pending. | لا يزال التحقق من المكافأة معلقًا. | Status line under that button. | `out_of_lives_menu.gd`, `shelf_unlock_menu.gd` |
| `ad.unavailable_retry` | Ad unavailable. Please try again. | الإعلان غير متاح. حاول مجددًا. | Status line when no ad could be shown. | `out_of_lives_menu` |
| `ad.watch_unavailable` | Watch Ad\\nUnavailable | شاهد إعلانًا\\nغير متاح | Two-line disabled ad button (time-up modal). Keep the line break. | `time_up_extension_modal.gd` |
| `ad.watch_coming_soon` | Watch Ad\\nComing Soon | شاهد إعلانًا\\nقريبًا | Two-line disabled ad button before ads launch. | `time_up_extension_modal.tscn` |
| `ad.badge` | AD | AD | Tiny badge on a locked shelf that an ad can open. Do not translate: keep AD exactly in every language. | `shelf_lock_overlay.tscn`, `shelf_unlock_menu.tscn` |
| `lives.title.out` | OUT OF LIVES | نفدت المحاولات | Lives modal title at 0 lives. | `out_of_lives_menu.gd` |
| `lives.title.get_more` | GET MORE LIVES | المزيد من المحاولات | Lives modal title with some lives left. | `out_of_lives_menu.gd` |
| `lives.title.full` | LIVES FULL | كل المحاولات متاحة | Lives modal title at maximum lives. | `out_of_lives_menu.gd` |
| `lives.next_in` | NEXT LIFE IN | المحاولة التالية بعد | Label above the refill countdown (mm:ss). | `out_of_lives_menu.tscn` |
| `lives.full_body` | Your lives are full! Play a level to spend them. | لديك الحد الأقصى من المحاولات! العب مستوى لاستخدام محاولة. | Body of the lives modal at maximum. | `out_of_lives_menu.tscn` |
| `chest.title` | CHEST REWARDS | مكافآت الصندوق | Title of the reward chest modal. | `reward_chest_menu.tscn` |
| `chest.progress_hint` | Collect stars to unlock a chest and claim your reward | اجمع النجوم لفتح صندوق والحصول على مكافأتك | Under the star progress bar (e.g. 12/30). | `reward_chest_menu.tscn` |
| `chest.ready` | A REWARD CHEST AWAITS! | صندوق مكافآت ينتظرك! | Banner when the chest is full and can be opened. | `reward_chest_menu.tscn` |
| `chest.tap_to_open` | Tap to open | اضغط للفتح | Prompt under the closed chest in the opening animation. | `reward_chest_open_ceremony.tscn` |
| `purchase.tap_to_collect` | Tap to collect | اضغط للاستلام | Prompt to collect purchased rewards. | `purchase_reward_sequence.tscn` |
| `purchase.complete` | PURCHASE COMPLETE | اكتملت عملية الشراء | Banner after a successful purchase. | `purchase_reward_sequence.gd` |
| `shop.title` | SHOP | المتجر | Shop screen title. | `shop_screen.tscn` |
| `shop.section.bundles` | SPECIAL BUNDLES | حزم خاصة | Section header. | `shop_screen.tscn` |
| `shop.section.coins` | COINS | عملات | Section header for coin packs. | `shop_screen.tscn` |
| `shop.offer.starter_bundle` | Starter Bundle | حزمة البداية | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.offer.basic_bundle` | Basic Bundle | الحزمة الأساسية | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.tag.best_value` | BEST VALUE | أفضل قيمة | Ribbon on the best coin pack. | `configs/shop_catalog.json` |
| `shop.discount_off` | OFF | OFF | Second line of the discount badge under "67%". Do not translate: keep the complete 67% OFF tag unchanged in every language; the numeric percentage can vary by offer. | `shop_bundle_card.tscn`, `starter_bundle_offer_modal.tscn` |
| `shop.ability_hint` | Tap an ability to see what it does | اضغط على معزز لمعرفة وظيفته | Hint under a bundle's booster icons. | `shop_bundle_card.tscn` |
| `shop.purchasing` | Purchasing… | جارٍ الشراء… | Buy button while a purchase is in progress. | shop cards, `production_main_menu.gd` |
| `shop.no_offers` | No shop offers are available for this region. | لا توجد عروض متاحة في المتجر لهذه المنطقة. | Shop error state. | `shop_screen.gd` |
| `shop.load_failed` | Could not load the shop. | تعذر تحميل المتجر. | Shop error state (fallback text). | `shop_screen.gd` |
| `shop.error.title.purchase` | Purchase unavailable | الشراء غير متاح | Error dialog title when buying failed. | `shop_screen.gd` |
| `shop.error.title.reward` | Reward error | خطأ في المكافأة | Error dialog title when payment went through but rewards were not granted. | `shop_screen.gd` |
| `shop.error.purchase_failed` | The purchase could not be completed. | تعذر إكمال عملية الشراء. | Error dialog body (fallback). | `shop_screen.gd`, `production_main_menu.gd` |
| `shop.error.grant_failed` | The purchased rewards could not be granted. | تعذر منح المكافآت التي اشتريتها. | Error dialog body. | `store/shop_purchase_flow.gd` |
| `shop.error.offer_unavailable` | This shop offer is unavailable. | عرض المتجر هذا غير متاح. | Error dialog body. | `store/store_service.gd` |
| `shop.error.already_bought` | This one-time shop offer has already been purchased. | سبق شراء هذا العرض المتاح لمرة واحدة. | Error dialog body. | `store/store_service.gd` |
| `starter.title` | STARTER BUNDLE | حزمة البداية | Starter offer modal title. | `starter_bundle_offer_modal.gd` |
| `starter.one_time` | ONE-TIME OFFER | عرض لمرة واحدة | Ribbon on the starter offer. | `starter_bundle_offer_modal.tscn` |
| `starter.boosters_included` | BOOSTERS INCLUDED | معززات ضمن الحزمة | Header over the four booster chips. | `starter_bundle_offer_modal.tscn` |
| `starter.coins` | %s COINS | %s عملة | Ribbon over the coin art. `%s` = formatted amount, e.g. "1,000". Needs plural forms. | `starter_bundle_offer_modal.gd` |
| `starter.buy_for` | Buy for %s | اشترِ مقابل %s | Buy button. `%s` = store price, e.g. "$4.99". | `starter_bundle_offer_modal.gd` |
| `starter.checking` | Checking offer… | جارٍ التحقق من العرض… | Status while the store confirms the offer. | `production_main_menu.gd` |
| `starter.checking_short` | Checking… | جارٍ التحقق… | Buy button during that check. | `starter_bundle_offer_modal.gd` |
| `starter.no_longer_available` | This offer is no longer available. | لم يعد هذا العرض متاحًا. | Error status in the starter modal. | `production_main_menu.gd` |
| `starter.unavailable` | Unavailable | غير متاح | Disabled buy button after a non-retryable error. | `starter_bundle_offer_modal.gd` |
| `booster_chip.claimed` | +%d %s | +%d %s | Booster chip after purchase, e.g. "+3 Hammer". `%d` = count, `%s` = booster name. Needs plural forms. | `offer_booster_chip.gd` |

## Profile, leaderboard and settings

Language names in the language picker stay in their own language (English, Español, 日本語…) and are never translated.

| Key | English | Arabic | Context | Source |
| --- | --- | --- | --- | --- |
| `profile.title` | EDIT PROFILE | تعديل الملف الشخصي | Profile modal title. | `profile_menu.tscn` |
| `profile.name_header` | PLAYER NAME | اسم اللاعب | Header over the name field. | `profile_menu.tscn` |
| `profile.name_placeholder` | Player name | اسم اللاعب | Placeholder inside the empty name field. | `profile_menu.tscn` |
| `profile.edit_name_tooltip` | Edit player name | تعديل اسم اللاعب | Accessibility tooltip on the pencil button. | `profile_menu.tscn` |
| `profile.avatar_tab` | AVATAR | الصورة | Tab that shows avatar pictures. | `profile_menu.tscn` |
| `profile.frame_tab` | FRAME | الإطار | Tab that shows decorative frames around the avatar. | `profile_menu.tscn` |
| `profile.unlock.level` | Complete level %d to unlock | أكمل المستوى %d لفتح الإطار | Toast after tapping a locked frame. `%d` = level number. | `profile_menu.gd` |
| `profile.unlock.combo` | Reach a combo of ×%d in any run to unlock | صل إلى تتابع ×%d في أي محاولة لفتح الإطار | Same toast. `%d` = combo size. | `profile_menu.gd` |
| `profile.unlock.weekly_first` | Finish 1st on the Weekly leaderboard to unlock | احتل المركز الأول في الترتيب الأسبوعي لفتح الإطار | Same toast for a first-place frame. Today built from two parts; see implementation notes. | `profile_menu.gd` |
| `profile.unlock.weekly_top` | Finish top %d on the Weekly leaderboard to unlock | كن ضمن أفضل %d في الترتيب الأسبوعي لفتح الإطار | Same toast. `%d` = rank cutoff (e.g. 10). | `profile_menu.gd` |
| `leaderboard.title` | LEADERBOARD | المتصدرون | Leaderboard screen title. | `leaderboard_screen.tscn` |
| `leaderboard.tab.weekly` | Weekly | أسبوعي | Tab: this week's stars. | `leaderboard_screen.tscn` |
| `leaderboard.tab.country` | Country | البلد | Tab: all-time stars in the player's country. | `leaderboard_screen.tscn` |
| `leaderboard.tab.world` | World | العالم | Tab: all-time stars worldwide. | `leaderboard_screen.tscn` |
| `leaderboard.weekly_reset` | Weekly reset in %s | إعادة تعيين الترتيب الأسبوعي بعد %s | Under the Weekly tab. `%s` = a duration such as "1d 4h". | `leaderboard_screen.gd` |
| `leaderboard.duration.dh` | %dd %dh | %d ي %d س | Duration: days and hours. Use local unit abbreviations. | `leaderboard_screen.gd` |
| `leaderboard.duration.hm` | %dh %dm | %d س %d د | Duration: hours and minutes. | `leaderboard_screen.gd` |
| `leaderboard.duration.m` | %dm | %d د | Duration: minutes. | `leaderboard_screen.gd` |
| `leaderboard.country_caption` | Country · All-time stars | البلد · مجموع النجوم منذ البداية | Caption under the Country tab. | `leaderboard_screen.gd` |
| `leaderboard.world_caption` | Worldwide · All-time stars | العالم · مجموع النجوم منذ البداية | Caption under the World tab. | `leaderboard_screen.gd` |
| `leaderboard.load_failed` | Could not load leaderboard. | تعذر تحميل قائمة المتصدرين. | Error state (fallback text). | `leaderboard_screen.gd` |
| `leaderboard.default_name` | Player | لاعب | Name shown for a player without one. | `leaderboard_row.gd` |
| `leaderboard.row_tooltip` | Rank %d, %s, %d stars | المركز %d، %s، %d نجمة | Accessibility text of a row. `%d` = rank, `%s` = player name, `%d` = stars. Needs plural forms. | `leaderboard_row.gd` |
| `leaderboard.reward_tooltip` | %s coin weekly reward | مكافأة أسبوعية: %s عملة | Accessibility text on the coin prize next to top ranks. `%s` = amount. | `leaderboard_rank_reward.gd` |
| `leaderboard.reward.title` | WEEKLY REWARD! | مكافأة أسبوعية! | Title of the dialog shown after a week ends. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.body` | You finished #%d last week and earned %d coins! | أنهيت الأسبوع الماضي في المركز #%d وربحت %d عملة! | Body. `%d` = final rank, `%d` = coins. Needs plural forms. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.ok` | Nice! | رائع! | Button that closes the reward dialog. | `leaderboard_reward_dialog.tscn` |
| `settings.title` | SETTINGS | الإعدادات | Settings modal title (home screen). | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.music` | Music | موسيقى | Toggle label under an icon. Short, about 8 characters. | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.sfx` | SFX | أصوات | Toggle for sound effects. Use a short local word for "Sounds". | same |
| `settings.vibrate` | Vibrate | اهتزاز | Toggle for haptic feedback. | same |
| `settings.support` | Support | الدعم | Opens the Support screen. | `settings_menu.tscn` |
| `settings.language` | Language | اللغة | Opens the language picker. | `settings_menu.tscn`, `language_option_row.tscn` |
| `settings.privacy_policy` | Privacy Policy | سياسة الخصوصية | Opens the privacy policy web page. | `settings_menu.tscn`, `production_main_menu.gd` |
| `settings.privacy_choices` | Privacy Choices | خيارات الخصوصية | Same button when the ad consent form must be offered (EU/UK). | `production_main_menu.gd` |
| `settings.diagnostics` | Version %s • Build %d\\nPlatform: %s • User: %s | الإصدار %s • النسخة %d\\nالمنصة: %s • المستخدم: %s | Small footer for support. Values: app version, build number, OS name, short player id. Translating the four labels is optional. | `pause_menu.gd` |
| `language.title` | LANGUAGE | اللغة | Language picker title. | `language_selection_modal.gd` |

## Support, account deletion and platform text

Support and deletion copy is legal-adjacent: translate meaning exactly, keep "Nothing was deleted" and "You can't undo this" unambiguous, and do not soften the warnings.

### Support screen

| Key | English | Arabic | Context | Source |
| --- | --- | --- | --- | --- |
| `support.title` | SUPPORT | الدعم | Support screen title. | `support_screen.tscn` |
| `support.faq_header` | Frequently Asked Questions | الأسئلة الشائعة | Section header. | `support_screen.tscn` |
| `support.faq.play.q` | How do I play? | كيف ألعب؟ | FAQ question (tap to expand). | `support_screen.tscn` |
| `support.faq.play.a` | Move matching goods onto the same shelf. When three identical items are visible together, they clear. Complete the board before time runs out. | انقل المنتجات المتطابقة إلى الرف نفسه. عندما تظهر ثلاثة عناصر متطابقة معًا، تختفي. أفرغ اللوحة قبل انتهاء الوقت. | FAQ answer. "Goods" = shop items such as snacks and toys. | `support_screen.tscn` |
| `support.faq.contact.q` | How do I contact support? | كيف أتواصل مع الدعم؟ | FAQ question. | `support_screen.tscn` |
| `support.faq.contact.a` | Email us at %s. Include a short description, your device platform, and when the problem happened. | راسلنا عبر البريد الإلكتروني على %s. أرفق وصفًا موجزًا للمشكلة ومنصة جهازك ووقت حدوث المشكلة. | FAQ answer. `%s` = support email address. | `support_screen.gd` |
| `support.faq.contact.action` | Email Support | مراسلة الدعم | Button that opens a pre-filled email. | `support_screen.tscn` |
| `support.faq.crash.q` | What if the game freezes or crashes? | ماذا أفعل إذا تجمدت اللعبة أو تعطلت؟ | FAQ question. | `support_screen.tscn` |
| `support.faq.crash.a` | Close and reopen the game first. If it happens again, restart the device and make sure the game is updated. Contact support with the device model, platform version, and what you were doing before the problem. | أغلق اللعبة وافتحها مجددًا أولًا. إذا تكررت المشكلة، فأعد تشغيل الجهاز وتأكد من تحديث اللعبة. تواصل مع الدعم واذكر طراز الجهاز وإصدار نظام التشغيل وما كنت تفعله قبل حدوث المشكلة. | FAQ answer. | `support_screen.tscn` |
| `support.faq.sync.q` | How do I sync progress between devices? | كيف أزامن التقدم بين الأجهزة؟ | FAQ question. | `support_screen.tscn` |
| `support.faq.sync.a` | Use the same signed-in platform account on both devices and allow synchronization to finish before playing. If the progress differs, avoid playing on both devices and contact support. | سجل الدخول إلى حساب المنصة نفسه على الجهازين، وانتظر اكتمال المزامنة قبل اللعب. إذا اختلف التقدم، فتجنب اللعب على الجهازين وتواصل مع الدعم. | FAQ answer. "Platform account" = Google Play Games / Game Center. | `support_screen.tscn` |
| `support.faq.bad_ad.q` | How do I report a bad ad? | كيف أبلغ عن إعلان غير مناسب؟ | FAQ question. | `support_screen.tscn` |
| `support.faq.bad_ad.a` | 1. Close the ad if you can do so safely.\\n2. Take a screenshot of the ad and any advertiser or app name shown.\\n3. Note the approximate time and where the ad appeared in the game.\\n4. Describe why the ad seemed offensive, misleading, or fraudulent.\\n5. Email these details to %s. Do not include passwords or payment information. | 1. أغلق الإعلان إذا أمكنك ذلك بأمان.\\n2. التقط لقطة شاشة للإعلان وأي اسم ظاهر للمعلن أو التطبيق.\\n3. دوّن الوقت التقريبي وموضع ظهور الإعلان في اللعبة.\\n4. وضح سبب اعتقادك أن الإعلان مسيء أو مضلل أو احتيالي.\\n5. أرسل هذه التفاصيل عبر البريد الإلكتروني إلى %s. لا ترفق كلمات مرور أو معلومات دفع. | FAQ answer, a five-step list in one string. `%s` = support email. Keep the numbering and line breaks. | `support_screen.gd` |
| `support.faq.bad_ad.action` | Email Ad Report | إرسال بلاغ عن إعلان | Button that opens a pre-filled ad-report email. | `support_screen.tscn` |
| `support.account_header` | Account | الحساب | Section header above the delete button. | `support_screen.tscn` |
| `support.delete_account` | Delete Account | حذف الحساب | Opens account deletion (player has an online account). | `support_screen.gd` |
| `support.delete_game_data` | Delete Game Data | حذف بيانات اللعبة | Same button when only local data exists. | `support_screen.gd` |
| `support.no_secrets` | Please never send passwords or payment information. | يرجى عدم إرسال كلمات مرور أو معلومات دفع مطلقًا. | Warning at the bottom of the screen. | `support_screen.tscn` |

### Account deletion modal

One modal switches between states; each state has a title (caps), a headline, a body and up to two buttons.

| Key | English | Arabic | Context | Source |
| --- | --- | --- | --- | --- |
| `deletion.title.delete_account` | DELETE ACCOUNT | حذف الحساب | Title: confirm, in progress and unavailable states. | `account_deletion_modal.gd` |
| `deletion.title.delete_game_data` | DELETE GAME DATA | حذف بيانات اللعبة | Title for a player who never had an online account. | same |
| `deletion.title.not_confirmed` | NOT CONFIRMED | لم يتم التأكيد | Title: request sent, answer lost. | same |
| `deletion.title.status_unconfirmed` | STATUS UNCONFIRMED | الحالة غير مؤكدة | Title: server outcome unknown. | same |
| `deletion.title.finishing_up` | FINISHING UP | جارٍ الإنهاء | Title: local cleanup incomplete. | same |
| `deletion.title.new_game` | NEW GAME | لعبة جديدة | Title while a fresh save is created. | same |
| `deletion.title.status_unknown` | STATUS UNKNOWN | الحالة غير معروفة | Title: local deletion record unreadable. | same |
| `deletion.title.not_deleted` | NOT DELETED | لم يتم الحذف | Title after a failed attempt. | same |
| `deletion.title.data_deleted` | DATA DELETED | تم حذف البيانات | Title after local data is deleted. | same |
| `deletion.title.accepted` | DELETION ACCEPTED | تم قبول طلب الحذف | Title after the server accepts the request. | same |
| `deletion.confirm.headline` | This permanently deletes your account. | سيؤدي هذا إلى حذف حسابك نهائيًا. | Confirm step, online account. | same |
| `deletion.confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nIf you sign in again later, you'll start a new account.\\n\\nSome purchase and security records are kept without your name or profile. The rest is removed within 30 days. | ستفقد تقدمك وعملاتك وعناصرك وملفك الشخصي. لا يمكنك التراجع عن هذا الإجراء.\\n\\nإذا سجلت الدخول لاحقًا، فستبدأ بحساب جديد.\\n\\nنحتفظ ببعض سجلات الشراء والأمان دون اسمك أو ملفك الشخصي. يُحذف الباقي خلال 30 يومًا. | Confirm step body. Keep the three paragraphs. | same |
| `deletion.confirm.button` | Delete Account | حذف الحساب | Red destructive button. | same |
| `deletion.local_confirm.headline` | This deletes your game data on this device. | سيؤدي هذا إلى حذف بيانات لعبتك على هذا الجهاز. | Confirm step, local-only player. | same |
| `deletion.local_confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nThis game never created an online account for you, so nothing needs to be deleted from our servers. | ستفقد تقدمك وعملاتك وعناصرك وملفك الشخصي. لا يمكنك التراجع عن هذا الإجراء.\\n\\nلم تنشئ هذه اللعبة حسابًا لك عبر الإنترنت، لذا لا توجد بيانات يلزم حذفها من خوادمنا. | Body for that step. | same |
| `deletion.local_confirm.button` | Delete Data | حذف البيانات | Red destructive button. | same |
| `deletion.pending_setup.headline` | Your account is still being set up. | لا يزال حسابك قيد الإعداد. | Deletion blocked: first registration not finished. | same |
| `deletion.pending_setup.body` | Connect to the internet and try again in a moment. Nothing was deleted. | اتصل بالإنترنت وحاول مجددًا بعد لحظات. لم يُحذف أي شيء. | Body. | same |
| `deletion.sign_in.headline` | Sign in to the account you want to delete. | سجل الدخول إلى الحساب الذي تريد حذفه. | Deletion blocked: signed out. | same |
| `deletion.sign_in.body` | If you can't sign in, contact support for help. | إذا تعذر عليك تسجيل الدخول، فتواصل مع الدعم للمساعدة. | Body. | same |
| `deletion.read_failed.headline` | Your game data couldn't be read. | تعذرت قراءة بيانات لعبتك. | Deletion blocked: save unreadable. | same |
| `deletion.read_failed.body` | Restart the game, then try again. Nothing was deleted. | أعد تشغيل اللعبة، ثم حاول مجددًا. لم يُحذف أي شيء. | Body. | same |
| `deletion.unavailable.headline` | Account deletion isn't available in this version of the game. | حذف الحساب غير متاح في هذا الإصدار من اللعبة. | Deletion blocked: feature off. Also a failure headline. | same |
| `deletion.unavailable.body` | Update the game, or contact support for help deleting your account. Nothing was deleted. | حدّث اللعبة، أو تواصل مع الدعم للمساعدة في حذف حسابك. لم يُحذف أي شيء. | Body. | same |
| `deletion.in_progress.account` | Deleting your account... | جارٍ حذف حسابك... | Headline while the request runs. | same |
| `deletion.in_progress.local` | Deleting your game data... | جارٍ حذف بيانات لعبتك... | Same for local-only data. | same |
| `deletion.in_progress.body` | Keep the game open. This only takes a moment. | أبقِ اللعبة مفتوحة. لن يستغرق هذا سوى لحظات. | Body while deleting. | same |
| `deletion.not_confirmed.headline` | We haven't heard back about your deletion yet. | لم نتلقَّ ردًا بشأن الحذف بعد. | Request sent, answer lost. | same |
| `deletion.not_confirmed.body` | Your request was sent, but the answer didn't arrive. Connect to the internet and try again. The game stays locked until we know the result. | أُرسل طلبك، لكن الرد لم يصل. اتصل بالإنترنت وحاول مجددًا. ستبقى اللعبة مقفلة حتى نعرف النتيجة. | Body. | same |
| `deletion.unconfirmed.headline` | Deletion status unconfirmed | حالة الحذف غير مؤكدة | Server outcome unknown. | same |
| `deletion.unconfirmed.body` | We couldn't confirm whether your account was deleted. To keep your data safe, the game stays locked. Contact support and include the reference below. | تعذر التأكد مما إذا كان حسابك قد حُذف. حفاظًا على أمان بياناتك، ستبقى اللعبة مقفلة. تواصل مع الدعم وأرفق الرمز المرجعي أدناه. | Body; a reference code is shown under it. | same |
| `deletion.check_again` | Check Again | تحقق مجددًا | Asks the server again. | same |
| `deletion.cleanup.headline.local` | Your local game data couldn't be fully deleted yet. | لم نتمكن بعد من حذف بيانات لعبتك المحلية بالكامل. | Local cleanup incomplete (local-only player). | same |
| `deletion.cleanup.headline.account` | Account deletion accepted; finishing cleanup. | تم قبول طلب حذف الحساب؛ جارٍ استكمال إزالة البيانات. | Local cleanup incomplete after the server accepted. | same |
| `deletion.cleanup.body` | Some game data couldn't be removed from this device yet. Try again to finish. | لم نتمكن بعد من إزالة بعض بيانات اللعبة من هذا الجهاز. حاول مجددًا لإكمال العملية. | Body. | same |
| `deletion.new_game.headline` | Starting a new game... | جارٍ بدء لعبة جديدة... | While a fresh save is created. | same |
| `deletion.new_game.body` | This only takes a moment. | لن يستغرق هذا سوى لحظات. | Body. | same |
| `deletion.status_unknown.headline` | We couldn't read the deletion status on this device. | تعذرت قراءة حالة الحذف على هذا الجهاز. | Local deletion record unreadable. | same |
| `deletion.status_unknown.body` | To keep your data safe, the game stays locked. Contact support for help. | حفاظًا على أمان بياناتك، ستبقى اللعبة مقفلة. تواصل مع الدعم للمساعدة. | Body. | same |
| `deletion.fail.offline` | Connect to the internet to delete your account. | اتصل بالإنترنت لحذف حسابك. | Failure headline. | same |
| `deletion.fail.rate_limited` | Too many attempts. Wait a moment, then try again. | محاولات كثيرة جدًا. انتظر لحظات، ثم حاول مجددًا. | Failure headline. | same |
| `deletion.fail.busy` | Account deletion is busy right now. Try again in a moment. | يتعذر حذف الحساب حاليًا. حاول مجددًا بعد لحظات. | Failure headline (server unavailable). | same |
| `deletion.fail.syncing` | The game is still syncing. Try again in a moment. | لا تزال مزامنة اللعبة جارية. حاول مجددًا بعد لحظات. | Failure headline. | same |
| `deletion.fail.auth` | We couldn't verify your account. Restart the game, then try again. | تعذر التحقق من حسابك. أعد تشغيل اللعبة، ثم حاول مجددًا. | Failure headline. | same |
| `deletion.fail.update` | Update the game to delete your account. | حدّث اللعبة لحذف حسابك. | Failure headline (client too old). | same |
| `deletion.fail.changed` | Your account changed while we were deleting it. Try again. | طرأ تغيير على حسابك أثناء محاولة حذفه. حاول مجددًا. | Failure headline. | same |
| `deletion.fail.storage` | Your device couldn't save the deletion request. Try again. | تعذر على جهازك حفظ طلب الحذف. حاول مجددًا. | Failure headline. | same |
| `deletion.fail.generic` | We couldn't delete your account. Try again later or contact support. | تعذر حذف حسابك. حاول لاحقًا أو تواصل مع الدعم. | Failure headline (fallback). | same |
| `deletion.fail.local` | Your game data couldn't be deleted. Try again. | تعذر حذف بيانات لعبتك. حاول مجددًا. | Failure headline, local-only player. | same |
| `deletion.fail.body` | Nothing was deleted, and you can keep playing. | لم يُحذف أي شيء، ويمكنك مواصلة اللعب. | Body for every failure. | same |
| `deletion.done_local.headline` | Your local game data was deleted. | تم حذف بيانات لعبتك المحلية. | Success, local-only player. | same |
| `deletion.done_local.body` | You can start over with a new game. | يمكنك البدء من جديد بلعبة جديدة. | Body. | same |
| `deletion.new_game_failed` | The new game couldn't start. Try again. | تعذر بدء اللعبة الجديدة. حاول مجددًا. | Appended under a success body if the fresh save failed. | same |
| `deletion.accepted.headline` | Your account is no longer accessible. | لم يعد بالإمكان الوصول إلى حسابك. | Success, online account. | same |
| `deletion.accepted.body` | Your deletion request was accepted. | تم قبول طلب الحذف. | Body when no deadline is known. | same |
| `deletion.accepted.body_deadline` | Your deletion request was accepted. Data removal is due by %s. | تم قبول طلب الحذف. ستتم إزالة البيانات بحلول %s. | Body. `%s` = a date such as "November 2, 2026". | same |
| `deletion.reference` | Reference: %s | الرمز المرجعي: %s | Support reference code under the body. `%s` = operation id; never translated. | same |
| `deletion.start_new_game` | Start New Game | بدء لعبة جديدة | Button after a successful deletion. | same |

### Platform and system text

| Key | English | Arabic | Context | Source |
| --- | --- | --- | --- | --- |
| `app.name` | SortingPuzzle | SortingPuzzle | App name under the home-screen icon; today the internal project name. Decide the public name per store first. | `project.godot`, `export_presets.cfg` |
| `support.email.subject` | Sorting Puzzle support request | طلب دعم للعبة Sorting Puzzle | Subject of the pre-filled support email. | `support_screen.gd` |
| `support.email.body` | Please describe the issue here.\\n\\nDevice/platform:\\nApproximate time:\\n | يرجى وصف المشكلة هنا.\\n\\nالجهاز/المنصة:\\nالوقت التقريبي:\\n | Body template the player fills in. | `support_screen.gd` |
| `support.ad_email.subject` | Sorting Puzzle ad report | بلاغ عن إعلان في Sorting Puzzle | Subject of the ad-report email. | `support_screen.gd` |
| `support.ad_email.body` | Please attach a screenshot and complete the details below.\\n\\nApproximate time:\\nAd placement in the game:\\nAdvertiser or app name:\\nWhy the ad should be reviewed:\\n | يرجى إرفاق لقطة شاشة واستكمال التفاصيل أدناه.\\n\\nالوقت التقريبي:\\nموضع الإعلان في اللعبة:\\nاسم المعلن أو التطبيق:\\nسبب طلب مراجعة الإعلان:\\n | Body template the player fills in. | `support_screen.gd` |
| `deletion.email.subject` | Sorting Puzzle account deletion | حذف حساب Sorting Puzzle | Subject of the deletion help email. | `account_deletion_modal.gd` |
| `deletion.email.body` | Please help me with my account deletion. | يرجى مساعدتي في حذف حسابي. | First line; followed by `Status:`, `Deletion reference:`, `Server reference:` and `Player ID:` lines. | `account_deletion_modal.gd` |


## Arabic plural forms

Arabic uses six cardinal plural categories. For the game's nonnegative integer counts, select the following categories using the raw numeric count, before applying number formatting. The category rules follow [Unicode CLDR's Arabic plural rules](https://www.unicode.org/cldr/charts/48/supplemental/language_plural_rules.html).

| Category | Integer count `n` | Examples |
| --- | --- | --- |
| `zero` | `n = 0` | 0 |
| `one` | `n = 1` | 1 |
| `two` | `n = 2` | 2 |
| `few` | `n % 100` is 3 through 10 | 3, 10, 103, 110 |
| `many` | `n % 100` is 11 through 99 | 11, 99, 111, 199 |
| `other` | All remaining integers | 100, 101, 102, 200, 1000 |

In singular and dual sentences, the numeric placeholder appears in parentheses to preserve the source formatting contract while allowing natural Arabic nouns. No placeholder is dropped or reordered. The bracketed number is intentionally redundant in these categories. The `zero` entries preserve the source message rather than asserting a gameplay state such as automatic unlocking; the relevant screen must still decide when to show the message.

### `chapter.locked_status`

Select by the remaining level count (`%d`). `%s` is the previous chapter's translated title.

| Category | Arabic |
| --- | --- |
| `zero` | تبقى %d من المستويات في «%s» لفتح الفصل |
| `one` | أكمل مستوى إضافيًا (%d) في «%s» لفتح الفصل |
| `two` | أكمل مستويين إضافيين (%d) في «%s» لفتح الفصل |
| `few` | أكمل %d مستويات إضافية في «%s» لفتح الفصل |
| `many` | أكمل %d مستوى إضافيًا في «%s» لفتح الفصل |
| `other` | أكمل %d مستوى إضافي في «%s» لفتح الفصل |

### `shelf_unlock.offer_or_clear`

Select by the raw remaining match count; `%s` contains its formatted value. A match is a triple, so the counted noun here is ثلاثية.

| Category | Arabic |
| --- | --- |
| `zero` | شاهد إعلانًا لفتح هذا الرف الآن، أو أزل %s من الثلاثيات الأخرى. |
| `one` | شاهد إعلانًا لفتح هذا الرف الآن، أو أزل ثلاثية أخرى (%s). |
| `two` | شاهد إعلانًا لفتح هذا الرف الآن، أو أزل ثلاثيتين أخريين (%s). |
| `few` | شاهد إعلانًا لفتح هذا الرف الآن، أو أزل %s ثلاثيات أخرى. |
| `many` | شاهد إعلانًا لفتح هذا الرف الآن، أو أزل %s ثلاثية أخرى. |
| `other` | شاهد إعلانًا لفتح هذا الرف الآن، أو أزل %s ثلاثية أخرى. |

### `starter.coins`

Select by the raw coin count; `%s` contains its formatted value.

| Category | Arabic |
| --- | --- |
| `zero` | %s عملة |
| `one` | عملة واحدة (%s) |
| `two` | عملتان (%s) |
| `few` | %s عملات |
| `many` | %s عملة |
| `other` | %s عملة |

### `booster_chip.claimed`

Select by the booster count (`%d`). `%s` is the fixed booster product name. This chip is a quantity-and-product label rather than a sentence, so all six variants intentionally retain the same template and uninflected product name.

| Category | Arabic |
| --- | --- |
| `zero` | +%d %s |
| `one` | +%d %s |
| `two` | +%d %s |
| `few` | +%d %s |
| `many` | +%d %s |
| `other` | +%d %s |

### `leaderboard.row_tooltip`

Select by the star count (the final `%d`), not by the rank. Placeholders remain rank, player name, stars.

| Category | Arabic |
| --- | --- |
| `zero` | المركز %d، %s، %d نجمة |
| `one` | المركز %d، %s، نجمة واحدة (%d) |
| `two` | المركز %d، %s، نجمتان (%d) |
| `few` | المركز %d، %s، %d نجوم |
| `many` | المركز %d، %s، %d نجمة |
| `other` | المركز %d، %s، %d نجمة |

### `leaderboard.reward.body`

Select by the coin count (the second `%d`), not by the final rank. Placeholders remain rank, coins.

| Category | Arabic |
| --- | --- |
| `zero` | أنهيت الأسبوع الماضي في المركز #%d وربحت %d عملة! |
| `one` | أنهيت الأسبوع الماضي في المركز #%d وربحت عملة واحدة (%d)! |
| `two` | أنهيت الأسبوع الماضي في المركز #%d وربحت عملتين (%d)! |
| `few` | أنهيت الأسبوع الماضي في المركز #%d وربحت %d عملات! |
| `many` | أنهيت الأسبوع الماضي في المركز #%d وربحت %d عملة! |
| `other` | أنهيت الأسبوع الماضي في المركز #%d وربحت %d عملة! |

### `leaderboard.reward_tooltip` — additional count-bearing entry

The inventory does not mark this entry as plural, but Arabic coin agreement still varies with the amount. Select by the raw weekly coin reward; `%s` contains its formatted value.

| Category | Arabic |
| --- | --- |
| `zero` | مكافأة أسبوعية: %s عملة |
| `one` | مكافأة أسبوعية: عملة واحدة (%s) |
| `two` | مكافأة أسبوعية: عملتان (%s) |
| `few` | مكافأة أسبوعية: %s عملات |
| `many` | مكافأة أسبوعية: %s عملة |
| `other` | مكافأة أسبوعية: %s عملة |

## Additional email labels mentioned in the inventory

The source describes four labels appended to `deletion.email.body`, but does not assign them keys. These translations supplement the 251 keyed entries; the values following the labels stay unchanged.

| English label | Arabic label |
| --- | --- |
| Status: | الحالة: |
| Deletion reference: | الرمز المرجعي للحذف: |
| Server reference: | الرمز المرجعي للخادم: |
| Player ID: | معرّف اللاعب: |

## Verification

- Every source key appears exactly once in the main bilingual tables.
- English text, context and source references are preserved from the supplied inventory.
- Placeholder type, count and order match the English source in every translation and plural variant.
- Forced line-break sequences, paragraph breaks and trailing email-template breaks are preserved.
- `AD`, `OFF`, `SortingPuzzle`, the `×` multiplier and the `+` quantity sign are preserved where required.
- Each combo-praise translation contains one or two words.
- The six inventory-marked plural entries each have all six Arabic categories. The weekly-reward tooltip has the same additional coverage.
- No game integration or rendered UI verification is included in this translation document.
