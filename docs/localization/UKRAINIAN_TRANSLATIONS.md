# Sorting Puzzle — Ukrainian Translations

Locale: uk · Prepared: October 5, 2026 · Status: draft for review

Bilingual translation of all 251 keyed entries in **Sorting Puzzle — Translation String Inventory.md**, including the October 5 copy updates. English text, keys, context and source references are retained for review. This document supplies Ukrainian text only; it has not been applied to the game.

## Ukrainian terminology

| English | Ukrainian |
| --- | --- |
| Level | Рівень |
| Chapter | Розділ |
| Shelf | Полиця |
| Item / goods | Предмет / товар |
| Match / triple / set | Трійка однакових предметів; трійка, де значення зрозуміле з контексту |
| Combo | Комбо |
| Booster / ability | Бустер |
| Hammer | Молоток |
| Shuffle | Перемішування |
| Lantern | Ліхтар |
| Freezer | Замороження |
| Dispenser | Автомат |
| Coins | Монети |
| Stars | Зірки |
| Lives | Життя |
| Reward chest | Скриня з винагородою |
| Bundle | Набір |
| Account | Акаунт |
| Reward | Винагорода |

## Reading the tables

- All %d and %s placeholders retain their original types and order.
- Line-break markers retain the inventory's Markdown escaping (\\n); each marker represents one forced line break in the game. Consecutive markers separate paragraphs.
- The six count-dependent entries use the one form in the main tables, except the invariant booster pattern. Their full Ukrainian forms appear in the appendix.
- Address to the player uses polite plural verbs. Combo praise avoids gendered forms and stays within one or two words.
- The small BUNDLE badge becomes НАБІР. The full offer name is Стартовий набір, with СТАРТОВИЙ НАБІР for the modal title.
- Do not translate AD on locked shelves or discount tags such as 67% OFF. The shop.discount_off entry remains OFF; the percentage can vary by offer.
- SortingPuzzle / Sorting Puzzle remain the brand name. Native language names, platform names, email addresses, actual player names, IDs, reference codes and platform-supplied prices remain unchanged.
- Макс. keeps the lives indicator short. SFX becomes Звуки. Uppercase titles and banners remain uppercase.
- Support and deletion copy retains irreversibility, retained records, the 30-day deadline, blocked states and “nothing was deleted”.
- The text has been checked against the inventory. Visual fit and font coverage have not been verified in the game, because integration is deferred.

## Shared buttons, main menu and chapters

Shared buttons appear on several screens and need one translation each, except where the context says the meaning differs. Keys are suggestions for the future translation table.

| Key | English | Ukrainian | Context | Source |
| --- | --- | --- | --- | --- |
| `common.play` | Play | Грати | Button that starts the chapter's next level on a chapter card. | `chapter_cover_card.gd` |
| `common.continue` | Continue | Продовжити | Button that moves on: closes the level-complete screen, the purchase dialog and the reward chest menu; on a chapter card it resumes a chapter already started. | `level_completion_screen.tscn`, `shop_purchase_dialog`, `reward_chest_menu.tscn`, `chapter_cover_card.gd` |
| `common.resume` | Continue | Продовжити | Button on Pause and on the leave confirmation that returns to the running level ("keep playing"). Separate key: some languages use a different verb than for "move on". | `pause_menu.tscn`, `leave_confirmation_menu.tscn` |
| `common.try_again` | Try Again | Спробувати ще раз | Retries a failed action (ad, purchase, account deletion). | ad modals, `account_deletion_modal.gd`, `starter_bundle_offer_modal.gd` |
| `common.close` | Close | Закрити | Closes a dialog without doing anything. | `account_deletion_modal.gd` |
| `common.cancel` | Cancel | Скасувати | Backs out of account deletion; nothing is deleted. | `account_deletion_modal.tscn` |
| `common.got_it` | Got it | Зрозуміло | Acknowledges an info dialog (ability description, lives already full). | `out_of_lives_menu.tscn`, `shop_screen.gd` |
| `common.get_help` | Get Help | Допомога | Opens a pre-filled email to support. | `account_deletion_modal.gd` |
| `common.save` | SAVE | ЗБЕРЕГТИ | Confirms profile edits or the chosen language. All caps by design. | `profile_menu`, `language_selection_modal.tscn` |
| `common.loading` | Loading… | Завантаження… | Shown while the Shop or Leaderboard loads its data. | `destination_status_panel.tscn` |
| `common.retry_load` | Retry | Оновити | Reloads the Shop or Leaderboard after a load error. Not the same as replaying a level. | `destination_status_panel.tscn` |
| `menu.level_button` | LEVEL %d | РІВЕНЬ %d | Big play button on the home screen. `%d` = level number inside the current chapter. | `production_main_menu.gd` |
| `menu.more_levels_coming_soon` | MORE LEVELS COMING SOON | НОВІ РІВНІ НЕЗАБАРОМ | Home play button (disabled) after every level of the chapter is finished. Must fit the button, about 24 characters. | `production_main_menu.gd` |
| `menu.coming_soon` | COMING SOON | НЕЗАБАРОМ | Home play button (disabled) when the chapter has no levels yet. | `production_main_menu.gd` |
| `menu.lives_full` | Full | Макс. | Top bar, next to the heart, when lives are at maximum; replaces the refill timer. About 5 characters. | `production_main_menu.gd`, `main_menu_top_status.tscn` |
| `menu.starter_badge` | BUNDLE | НАБІР | Small badge on the home screen that opens the Starter Bundle offer. About 8 characters. The full offer title remains Starter Bundle / Стартовий набір. | `main_menu_starter_bundle_badge.tscn` |
| `nav.shop` | Shop | Магазин | Bottom navigation tab. About 10 characters. | `main_menu_bottom_navigation.tscn` |
| `nav.home` | Home | Головна | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `nav.leaderboard` | Leaderboard | Лідери | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `chapter.button` | CHAPTER %d | РОЗДІЛ %d | Home button that opens chapter selection. `%d` = chapter number. | `main_menu_chapter_button.gd` |
| `chapter.button_tooltip` | Choose Chapter %d: %s | Вибрати розділ %d: %s | Accessibility tooltip of that button. `%d` = chapter number, `%s` = chapter title. | `main_menu_chapter_button.gd` |
| `chapter.screen_title` | CHAPTERS | РОЗДІЛИ | Title of the chapter selection screen. | `chapter_selection_screen.tscn` |
| `chapter.eyebrow` | CHAPTER %d | РОЗДІЛ %d | Small label above the chapter name on its card. | `chapter_cover_card.gd` |
| `chapter.title.chapter_01` | Grocery Town | Продуктове містечко | Name of chapter 1 (a grocery-store theme). | `configs/chapters.json` |
| `chapter.title.chapter_02` | Candy Corner | Солодкий куточок | Name of chapter 2 (a candy-shop theme). | `configs/chapters.json` |
| `chapter.locked_status` | Complete %d more %s levels to unlock | Пройдіть ще %d рівень розділу «%s», щоб відкрити цей розділ | Locked chapter card. `%d` = levels still needed, `%s` = previous chapter's name. Needs plural forms. | `chapter_cover_card.gd` |
| `chapter.unlock_progress` | Unlock progress | До відкриття | Header over the progress bar on a locked chapter. | `chapter_cover_card.gd` |
| `chapter.current_progress` | Current progress | Поточний прогрес | Header over the progress bar on an unlocked chapter. | `chapter_cover_card.gd` |
| `chapter.locked` | Locked | Закрито | Disabled button on a locked chapter card. | `chapter_cover_card.gd` |
| `chapter.no_levels_status` | New levels are coming soon | Незабаром з’являться нові рівні | Card message for a chapter with no levels yet. | `chapter_cover_card.gd` |
| `chapter.coming_soon` | Coming Soon | Незабаром | Disabled button on that card. | `chapter_cover_card.gd` |

## Gameplay: HUD, level screens and results

These strings show during a level, mostly in modal titles (all caps, short) and action buttons. A "triple" or "match" is three identical items on one shelf, which clears them.

| Key | English | Ukrainian | Context | Source |
| --- | --- | --- | --- | --- |
| `hud.level` | LEVEL %d | РІВЕНЬ %d | Top HUD during play. `%d` = level number inside the chapter. | `level.gd` |
| `hud.combo` | COMBO ×%d | КОМБО ×%d | HUD counter for consecutive quick matches. `%d` = combo size; keep the × sign. | `level_top_hud.gd` |
| `hud.ability_tooltip.hammer` | Hammer -- clears a matching triple | Молоток — прибирає трійку однакових предметів | Accessibility tooltip on the Hammer booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.shuffle` | Shuffle -- reshuffles unlocked items | Перемішування — перемішує незаблоковані предмети | Tooltip on the Shuffle booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.lantern` | Lantern -- highlights a matchable triple | Ліхтар — підсвічує трійку, яку можна зібрати | Tooltip on the Lantern booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.freezer` | Freezer -- pauses the countdown timer | Замороження — зупиняє таймер | Tooltip on the Freezer booster button. | `ability_bar.tscn` |
| `hud.seconds_short` | %ds | %dс | Countdown on an active Lantern or Freezer booster, e.g. "15s". `%d` = seconds; use the local short unit. | `ability_bar.gd` |
| `tip.tap_dispenser` | Tap a dispenser to throw items onto the shelves! | Торкніться автомата, щоб він викинув предмети на полиці! | Tutorial bubble on level 10, where dispensers (machines that throw items onto shelves) first appear. | `configs/gameplay_tips.json` |
| `pause.title` | PAUSE | ПАУЗА | Title of the in-level pause modal. | `pause_menu.gd` |
| `pause.leave` | Leave | Вийти | Pause button that quits the level (asks for confirmation next). | `pause_menu.tscn` |
| `leave.title` | LEAVING THE LEVEL | ВИХІД ІЗ РІВНЯ | Title of the leave confirmation. | `leave_confirmation_menu.gd` |
| `leave.you_will_lose` | You will lose: | Ви втратите: | Followed by icons showing the stars earned this run and one life. Keep the colon (or local equivalent). | `leave_confirmation_menu.tscn` |
| `leave.confirm` | Leave | Вийти | Confirms quitting the level and losing that progress. | `leave_confirmation_menu.tscn` |
| `timeup.title` | TIME'S UP | ЧАС ВИЙШОВ | Title when the level timer reaches zero. | `time_up_extension_modal.gd` |
| `timeup.offer` | Add one minute and keep sorting! | Додайте хвилину й продовжуйте сортувати! | Offer to extend the timer by 60 seconds for coins or an ad. | `time_up_extension_modal.tscn` |
| `timeup.used` | Used | Використано | Shown on the coin price or ad button when that extension was already used this level. | `time_up_extension_modal.gd` |
| `ability_purchase.title` | USE ABILITY | ВИКОРИСТАТИ БУСТЕР | Title of the modal that buys and immediately uses one booster when the player has none. | `ability_purchase_menu.gd` |
| `shelf_unlock.title` | UNLOCK SHELF | ВІДКРИТИ ПОЛИЦЮ | Title of the modal for a locked shelf. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer` | Watch one ad to unlock this shelf now. | Перегляньте рекламу, щоб відкрити цю полицю зараз. | Body when no other way to unlock remains. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer_or_clear` | Watch one ad to unlock this shelf now, or clear %s more. | Перегляньте рекламу, щоб відкрити цю полицю зараз, або зберіть ще %s трійку. | Body when the shelf also unlocks by itself after more matches. `%s` = matches still needed. Needs plural forms. | `shelf_unlock_menu.gd` |
| `shelf_unlock.button` | Watch Ad · Unlock Shelf | Реклама · Відкрити полицю | Ad button in that modal. | `shelf_unlock_menu.gd` |
| `shelf_unlock.ad_unavailable` | Ad unavailable. This shelf stays locked. | Реклама недоступна. Полиця залишається закритою. | Status line when no ad could be shown. | `shelf_unlock_menu.gd` |
| `complete.title` | GREAT JOB! | ЧУДОВА РОБОТА! | Title of the level-complete screen, above the stars earned. | `level_completion_screen.gd` |
| `failed.title` | LEVEL %d | РІВЕНЬ %d | Title of the level-failed screen. `%d` = level number. | `level_failure_screen.gd` |
| `failed.headline` | LEVEL FAILED | РІВЕНЬ НЕ ПРОЙДЕНО | Banner on the level-failed screen. | `level_failure_screen.tscn` |
| `failed.retry` | Retry | Повторити | Replays the same level. | `level_failure_screen.tscn` |

Combo praise pops up above a match during a combo; each word is stronger than the one before, so keep the escalation. The label shrinks its font for long words, but one or two words is the limit.

| Key | English | Ukrainian | Shown at |
| --- | --- | --- | --- |
| `combo.praise.2` | Cool | Круто | Combo ×2 |
| `combo.praise.3` | Great | Чудово | ×3 |
| `combo.praise.4` | Awesome | Супер | ×4 |
| `combo.praise.5` | Amazing | Дивовижно | ×5 |
| `combo.praise.6` | Fantastic | Фантастично | ×6 |
| `combo.praise.7` | Incredible | Неймовірно | ×7 |
| `combo.praise.8` | Spectacular | Вражає! | ×8 |
| `combo.praise.9` | Unstoppable | НЕ СПИНИТИ! | ×9 |
| `combo.praise.10` | Legendary | Легендарно | ×10 |
| `combo.praise.11` | Epic | Епічно | ×11 |
| `combo.praise.12` | Brilliant | Блискуче | ×12 |
| `combo.praise.13` | Masterful | Майстерно | ×13 |
| `combo.praise.14` | Supreme | Неперевершено | ×14 |
| `combo.praise.15` | Phenomenal | Феноменально | ×15 |
| `combo.praise.16` | Mythic | Міфічно | ×16 |
| `combo.praise.17` | Majestic | Велично | ×17 |
| `combo.praise.18` | Radiant | Осяйно | ×18 |
| `combo.praise.19` | Divine | Божественно | ×19 |
| `combo.praise.20` | Transcendent | Позамежно | ×20 and above |

Source: `COMBO_PRAISE_WORDS` in `level.gd`.

## Boosters, ads, lives, rewards and shop

The four boosters (also called abilities in code) are product names: pick one translation per language and reuse it everywhere, including the tooltips in the gameplay section.

| Key | English | Ukrainian | Context | Source |
| --- | --- | --- | --- | --- |
| `ability.hammer.name` | Hammer | Молоток | Booster that smashes away one matching set. | `reward_reveal_row.tscn`, `starter_bundle_offer_modal.tscn`, `shop_screen.gd` |
| `ability.shuffle.name` | Shuffle | Перемішування | Booster that rearranges items. | same |
| `ability.lantern.name` | Lantern | Ліхтар | Booster that lights up a set the player can match (internal id `highlight`). | same |
| `ability.freezer.name` | Freezer | Замороження | Booster that stops the level timer. | same |
| `ability.hammer.description` | Instantly clears one matching set of items off the shelves. | Миттєво прибирає з полиць одну трійку однакових предметів. | Shop info dialog body after tapping the booster icon. | `shop_screen.gd` |
| `ability.shuffle.description` | Shuffles shelf items into new spots to help you find a match. | Переміщує предмети на полицях у нові місця, щоб було легше знайти трійку. | Same dialog. | `shop_screen.gd` |
| `ability.lantern.description` | Highlights a matching triple you can clear for 15 seconds. | На 15 секунд підсвічує трійку однакових предметів, яку можна зібрати. | Same dialog. Keep the number in sync with the game config. | `shop_screen.gd` |
| `ability.freezer.description` | Freezes the level timer for 30 seconds. | Зупиняє таймер рівня на 30 секунд. | Same dialog. | `shop_screen.gd` |
| `ad.watch` | Watch Ad | Дивитися рекламу | Button that plays a rewarded video ad. | ad modals, `out_of_lives_menu`, `ability_purchase_menu.tscn` |
| `ad.loading` | Loading... | Завантаження... | Ad button while the ad loads. | ad modals |
| `ad.verifying` | Verifying... | Перевірка... | Ad button while the server confirms the reward. | ad modals |
| `ad.verify_reward` | Verify Reward | Перевірити винагороду | Ad button to re-check a reward the server has not confirmed yet. | ad modals |
| `ad.reward_pending` | Reward verification is still pending. | Очікуємо підтвердження винагороди. | Status line under that button. | `out_of_lives_menu.gd`, `shelf_unlock_menu.gd` |
| `ad.unavailable_retry` | Ad unavailable. Please try again. | Реклама недоступна. Спробуйте ще раз. | Status line when no ad could be shown. | `out_of_lives_menu` |
| `ad.watch_unavailable` | Watch Ad\\nUnavailable | Реклама\\nНедоступна | Two-line disabled ad button (time-up modal). Keep the line break. | `time_up_extension_modal.gd` |
| `ad.watch_coming_soon` | Watch Ad\\nComing Soon | Реклама\\nНезабаром | Two-line disabled ad button before ads launch. | `time_up_extension_modal.tscn` |
| `ad.badge` | AD | AD | Tiny badge on a locked shelf that an ad can open. Do not translate: keep AD exactly in every language. | `shelf_lock_overlay.tscn`, `shelf_unlock_menu.tscn` |
| `lives.title.out` | OUT OF LIVES | НЕМАЄ ЖИТТІВ | Lives modal title at 0 lives. | `out_of_lives_menu.gd` |
| `lives.title.get_more` | GET MORE LIVES | БІЛЬШЕ ЖИТТІВ | Lives modal title with some lives left. | `out_of_lives_menu.gd` |
| `lives.title.full` | LIVES FULL | МАКСИМУМ ЖИТТІВ | Lives modal title at maximum lives. | `out_of_lives_menu.gd` |
| `lives.next_in` | NEXT LIFE IN | НАСТУПНЕ ЖИТТЯ ЧЕРЕЗ | Label above the refill countdown (mm:ss). | `out_of_lives_menu.tscn` |
| `lives.full_body` | Your lives are full! Play a level to spend them. | У вас максимум життів! Зіграйте рівень, щоб витратити їх. | Body of the lives modal at maximum. | `out_of_lives_menu.tscn` |
| `chest.title` | CHEST REWARDS | ВИНАГОРОДИ ЗІ СКРИНІ | Title of the reward chest modal. | `reward_chest_menu.tscn` |
| `chest.progress_hint` | Collect stars to unlock a chest and claim your reward | Збирайте зірки, щоб відкрити скриню й отримати винагороду | Under the star progress bar (e.g. 12/30). | `reward_chest_menu.tscn` |
| `chest.ready` | A REWARD CHEST AWAITS! | НА ВАС ЧЕКАЄ СКРИНЯ З ВИНАГОРОДОЮ! | Banner when the chest is full and can be opened. | `reward_chest_menu.tscn` |
| `chest.tap_to_open` | Tap to open | Торкніться, щоб відкрити | Prompt under the closed chest in the opening animation. | `reward_chest_open_ceremony.tscn` |
| `purchase.tap_to_collect` | Tap to collect | Торкніться, щоб забрати | Prompt to collect purchased rewards. | `purchase_reward_sequence.tscn` |
| `purchase.complete` | PURCHASE COMPLETE | КУПІВЛЮ ЗАВЕРШЕНО | Banner after a successful purchase. | `purchase_reward_sequence.gd` |
| `shop.title` | SHOP | МАГАЗИН | Shop screen title. | `shop_screen.tscn` |
| `shop.section.bundles` | SPECIAL BUNDLES | ОСОБЛИВІ НАБОРИ | Section header. | `shop_screen.tscn` |
| `shop.section.coins` | COINS | МОНЕТИ | Section header for coin packs. | `shop_screen.tscn` |
| `shop.offer.starter_bundle` | Starter Bundle | Стартовий набір | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.offer.basic_bundle` | Basic Bundle | Базовий набір | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.tag.best_value` | BEST VALUE | НАЙКРАЩА ЦІНА | Ribbon on the best coin pack. | `configs/shop_catalog.json` |
| `shop.discount_off` | OFF | OFF | Second line of the discount badge under "67%". Do not translate: keep the complete 67% OFF tag unchanged in every language; the numeric percentage can vary by offer. | `shop_bundle_card.tscn`, `starter_bundle_offer_modal.tscn` |
| `shop.ability_hint` | Tap an ability to see what it does | Торкніться бустера, щоб дізнатися, що він робить | Hint under a bundle's booster icons. | `shop_bundle_card.tscn` |
| `shop.purchasing` | Purchasing… | Купівля… | Buy button while a purchase is in progress. | shop cards, `production_main_menu.gd` |
| `shop.no_offers` | No shop offers are available for this region. | Для цього регіону немає доступних пропозицій. | Shop error state. | `shop_screen.gd` |
| `shop.load_failed` | Could not load the shop. | Не вдалося завантажити магазин. | Shop error state (fallback text). | `shop_screen.gd` |
| `shop.error.title.purchase` | Purchase unavailable | Купівля недоступна | Error dialog title when buying failed. | `shop_screen.gd` |
| `shop.error.title.reward` | Reward error | Помилка винагороди | Error dialog title when payment went through but rewards were not granted. | `shop_screen.gd` |
| `shop.error.purchase_failed` | The purchase could not be completed. | Не вдалося завершити купівлю. | Error dialog body (fallback). | `shop_screen.gd`, `production_main_menu.gd` |
| `shop.error.grant_failed` | The purchased rewards could not be granted. | Не вдалося нарахувати придбані винагороди. | Error dialog body. | `store/shop_purchase_flow.gd` |
| `shop.error.offer_unavailable` | This shop offer is unavailable. | Ця пропозиція магазину недоступна. | Error dialog body. | `store/store_service.gd` |
| `shop.error.already_bought` | This one-time shop offer has already been purchased. | Цю разову пропозицію вже придбано. | Error dialog body. | `store/store_service.gd` |
| `starter.title` | STARTER BUNDLE | СТАРТОВИЙ НАБІР | Starter offer modal title. | `starter_bundle_offer_modal.gd` |
| `starter.one_time` | ONE-TIME OFFER | РАЗОВА ПРОПОЗИЦІЯ | Ribbon on the starter offer. | `starter_bundle_offer_modal.tscn` |
| `starter.boosters_included` | BOOSTERS INCLUDED | БУСТЕРИ В НАБОРІ | Header over the four booster chips. | `starter_bundle_offer_modal.tscn` |
| `starter.coins` | %s COINS | %s МОНЕТА | Ribbon over the coin art. `%s` = formatted amount, e.g. "1,000". Needs plural forms. | `starter_bundle_offer_modal.gd` |
| `starter.buy_for` | Buy for %s | Купити за %s | Buy button. `%s` = store price, e.g. "$4.99". | `starter_bundle_offer_modal.gd` |
| `starter.checking` | Checking offer… | Перевірка пропозиції… | Status while the store confirms the offer. | `production_main_menu.gd` |
| `starter.checking_short` | Checking… | Перевірка… | Buy button during that check. | `starter_bundle_offer_modal.gd` |
| `starter.no_longer_available` | This offer is no longer available. | Ця пропозиція більше недоступна. | Error status in the starter modal. | `production_main_menu.gd` |
| `starter.unavailable` | Unavailable | Недоступно | Disabled buy button after a non-retryable error. | `starter_bundle_offer_modal.gd` |
| `booster_chip.claimed` | +%d %s | +%d %s | Booster chip after purchase, e.g. "+3 Hammer". `%d` = count, `%s` = booster name. Needs plural forms. | `offer_booster_chip.gd` |

## Profile, leaderboard and settings

Language names in the language picker stay in their own language (English, Español, 日本語…) and are never translated.

| Key | English | Ukrainian | Context | Source |
| --- | --- | --- | --- | --- |
| `profile.title` | EDIT PROFILE | РЕДАГУВАТИ ПРОФІЛЬ | Profile modal title. | `profile_menu.tscn` |
| `profile.name_header` | PLAYER NAME | ІМ’Я ГРАВЦЯ | Header over the name field. | `profile_menu.tscn` |
| `profile.name_placeholder` | Player name | Ім’я гравця | Placeholder inside the empty name field. | `profile_menu.tscn` |
| `profile.edit_name_tooltip` | Edit player name | Змінити ім’я гравця | Accessibility tooltip on the pencil button. | `profile_menu.tscn` |
| `profile.avatar_tab` | AVATAR | АВАТАР | Tab that shows avatar pictures. | `profile_menu.tscn` |
| `profile.frame_tab` | FRAME | РАМКА | Tab that shows decorative frames around the avatar. | `profile_menu.tscn` |
| `profile.unlock.level` | Complete level %d to unlock | Пройдіть рівень %d, щоб відкрити | Toast after tapping a locked frame. `%d` = level number. | `profile_menu.gd` |
| `profile.unlock.combo` | Reach a combo of ×%d in any run to unlock | Досягніть комбо ×%d у будь-якій спробі, щоб відкрити | Same toast. `%d` = combo size. | `profile_menu.gd` |
| `profile.unlock.weekly_first` | Finish 1st on the Weekly leaderboard to unlock | Посядьте 1-ше місце в тижневому рейтингу, щоб відкрити | Same toast for a first-place frame. Today built from two parts; see implementation notes. | `profile_menu.gd` |
| `profile.unlock.weekly_top` | Finish top %d on the Weekly leaderboard to unlock | Увійдіть до топ-%d тижневого рейтингу, щоб відкрити | Same toast. `%d` = rank cutoff (e.g. 10). | `profile_menu.gd` |
| `leaderboard.title` | LEADERBOARD | РЕЙТИНГ | Leaderboard screen title. | `leaderboard_screen.tscn` |
| `leaderboard.tab.weekly` | Weekly | Тиждень | Tab: this week's stars. | `leaderboard_screen.tscn` |
| `leaderboard.tab.country` | Country | Країна | Tab: all-time stars in the player's country. | `leaderboard_screen.tscn` |
| `leaderboard.tab.world` | World | Світ | Tab: all-time stars worldwide. | `leaderboard_screen.tscn` |
| `leaderboard.weekly_reset` | Weekly reset in %s | Оновлення тижневого рейтингу через %s | Under the Weekly tab. `%s` = a duration such as "1d 4h". | `leaderboard_screen.gd` |
| `leaderboard.duration.dh` | %dd %dh | %d д %d год | Duration: days and hours. Use local unit abbreviations. | `leaderboard_screen.gd` |
| `leaderboard.duration.hm` | %dh %dm | %d год %d хв | Duration: hours and minutes. | `leaderboard_screen.gd` |
| `leaderboard.duration.m` | %dm | %d хв | Duration: minutes. | `leaderboard_screen.gd` |
| `leaderboard.country_caption` | Country · All-time stars | Країна · Зірки за весь час | Caption under the Country tab. | `leaderboard_screen.gd` |
| `leaderboard.world_caption` | Worldwide · All-time stars | Увесь світ · Зірки за весь час | Caption under the World tab. | `leaderboard_screen.gd` |
| `leaderboard.load_failed` | Could not load leaderboard. | Не вдалося завантажити таблицю лідерів. | Error state (fallback text). | `leaderboard_screen.gd` |
| `leaderboard.default_name` | Player | Гравець | Name shown for a player without one. | `leaderboard_row.gd` |
| `leaderboard.row_tooltip` | Rank %d, %s, %d stars | Місце %d, %s, %d зірка | Accessibility text of a row. `%d` = rank, `%s` = player name, `%d` = stars. Needs plural forms. | `leaderboard_row.gd` |
| `leaderboard.reward_tooltip` | %s coin weekly reward | Монет у тижневій винагороді: %s | Accessibility text on the coin prize next to top ranks. `%s` = amount. | `leaderboard_rank_reward.gd` |
| `leaderboard.reward.title` | WEEKLY REWARD! | ТИЖНЕВА ВИНАГОРОДА! | Title of the dialog shown after a week ends. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.body` | You finished #%d last week and earned %d coins! | Минулого тижня ви посіли місце №%d й отримали %d монету! | Body. `%d` = final rank, `%d` = coins. Needs plural forms. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.ok` | Nice! | Клас! | Button that closes the reward dialog. | `leaderboard_reward_dialog.tscn` |
| `settings.title` | SETTINGS | НАЛАШТУВАННЯ | Settings modal title (home screen). | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.music` | Music | Музика | Toggle label under an icon. Short, about 8 characters. | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.sfx` | SFX | Звуки | Toggle for sound effects. Use a short local word for "Sounds". | same |
| `settings.vibrate` | Vibrate | Вібрація | Toggle for haptic feedback. | same |
| `settings.support` | Support | Підтримка | Opens the Support screen. | `settings_menu.tscn` |
| `settings.language` | Language | Мова | Opens the language picker. | `settings_menu.tscn`, `language_option_row.tscn` |
| `settings.privacy_policy` | Privacy Policy | Політика конфіденційності | Opens the privacy policy web page. | `settings_menu.tscn`, `production_main_menu.gd` |
| `settings.privacy_choices` | Privacy Choices | Налаштування конфіденційності | Same button when the ad consent form must be offered (EU/UK). | `production_main_menu.gd` |
| `settings.diagnostics` | Version %s • Build %d\\nPlatform: %s • User: %s | Версія %s • Збірка %d\\nПлатформа: %s • Користувач: %s | Small footer for support. Values: app version, build number, OS name, short player id. Translating the four labels is optional. | `pause_menu.gd` |
| `language.title` | LANGUAGE | МОВА | Language picker title. | `language_selection_modal.gd` |

## Support, account deletion and platform text

Support and deletion copy is legal-adjacent: translate meaning exactly, keep "Nothing was deleted" and "You can't undo this" unambiguous, and do not soften the warnings.

### Support screen

| Key | English | Ukrainian | Context | Source |
| --- | --- | --- | --- | --- |
| `support.title` | SUPPORT | ПІДТРИМКА | Support screen title. | `support_screen.tscn` |
| `support.faq_header` | Frequently Asked Questions | Поширені запитання | Section header. | `support_screen.tscn` |
| `support.faq.play.q` | How do I play? | Як грати? | FAQ question (tap to expand). | `support_screen.tscn` |
| `support.faq.play.a` | Move matching goods onto the same shelf. When three identical items are visible together, they clear. Complete the board before time runs out. | Переміщуйте однакові предмети на одну полицю. Коли на полиці опиняються три однакові предмети, вони зникають. Очистьте поле, поки не закінчився час. | FAQ answer. "Goods" = shop items such as snacks and toys. | `support_screen.tscn` |
| `support.faq.contact.q` | How do I contact support? | Як зв’язатися з підтримкою? | FAQ question. | `support_screen.tscn` |
| `support.faq.contact.a` | Email us at %s. Include a short description, your device platform, and when the problem happened. | Напишіть нам на %s. Коротко опишіть проблему, вкажіть платформу пристрою та час, коли вона виникла. | FAQ answer. `%s` = support email address. | `support_screen.gd` |
| `support.faq.contact.action` | Email Support | Звернутися до підтримки | Button that opens a pre-filled email. | `support_screen.tscn` |
| `support.faq.crash.q` | What if the game freezes or crashes? | Що робити, якщо гра зависає або закривається? | FAQ question. | `support_screen.tscn` |
| `support.faq.crash.a` | Close and reopen the game first. If it happens again, restart the device and make sure the game is updated. Contact support with the device model, platform version, and what you were doing before the problem. | Спершу закрийте гру й відкрийте її знову. Якщо проблема повториться, перезапустіть пристрій і перевірте, чи встановлено останню версію гри. Зверніться до підтримки й вкажіть модель пристрою, версію платформи та що ви робили перед виникненням проблеми. | FAQ answer. | `support_screen.tscn` |
| `support.faq.sync.q` | How do I sync progress between devices? | Як синхронізувати прогрес між пристроями? | FAQ question. | `support_screen.tscn` |
| `support.faq.sync.a` | Use the same signed-in platform account on both devices and allow synchronization to finish before playing. If the progress differs, avoid playing on both devices and contact support. | Увійдіть у той самий акаунт платформи на обох пристроях і дочекайтеся завершення синхронізації перед грою. Якщо прогрес відрізняється, не грайте на обох пристроях і зверніться до підтримки. | FAQ answer. "Platform account" = Google Play Games / Game Center. | `support_screen.tscn` |
| `support.faq.bad_ad.q` | How do I report a bad ad? | Як повідомити про проблемну рекламу? | FAQ question. | `support_screen.tscn` |
| `support.faq.bad_ad.a` | 1. Close the ad if you can do so safely.\\n2. Take a screenshot of the ad and any advertiser or app name shown.\\n3. Note the approximate time and where the ad appeared in the game.\\n4. Describe why the ad seemed offensive, misleading, or fraudulent.\\n5. Email these details to %s. Do not include passwords or payment information. | 1. Закрийте рекламу, якщо це можна зробити безпечно.\\n2. Зробіть знімок екрана з рекламою та видимою назвою рекламодавця чи застосунку.\\n3. Запишіть приблизний час і місце появи реклами в грі.\\n4. Опишіть, чому реклама здалася образливою, оманливою чи шахрайською.\\n5. Надішліть ці відомості на %s. Не додавайте паролі чи платіжні дані. | FAQ answer, a five-step list in one string. `%s` = support email. Keep the numbering and line breaks. | `support_screen.gd` |
| `support.faq.bad_ad.action` | Email Ad Report | Надіслати скаргу на рекламу | Button that opens a pre-filled ad-report email. | `support_screen.tscn` |
| `support.account_header` | Account | Акаунт | Section header above the delete button. | `support_screen.tscn` |
| `support.delete_account` | Delete Account | Видалити акаунт | Opens account deletion (player has an online account). | `support_screen.gd` |
| `support.delete_game_data` | Delete Game Data | Видалити дані гри | Same button when only local data exists. | `support_screen.gd` |
| `support.no_secrets` | Please never send passwords or payment information. | Ніколи не надсилайте паролі чи платіжні дані. | Warning at the bottom of the screen. | `support_screen.tscn` |

### Account deletion modal

One modal switches between states; each state has a title (caps), a headline, a body and up to two buttons.

| Key | English | Ukrainian | Context | Source |
| --- | --- | --- | --- | --- |
| `deletion.title.delete_account` | DELETE ACCOUNT | ВИДАЛИТИ АКАУНТ | Title: confirm, in progress and unavailable states. | `account_deletion_modal.gd` |
| `deletion.title.delete_game_data` | DELETE GAME DATA | ВИДАЛИТИ ДАНІ ГРИ | Title for a player who never had an online account. | same |
| `deletion.title.not_confirmed` | NOT CONFIRMED | НЕ ПІДТВЕРДЖЕНО | Title: request sent, answer lost. | same |
| `deletion.title.status_unconfirmed` | STATUS UNCONFIRMED | СТАТУС НЕ ПІДТВЕРДЖЕНО | Title: server outcome unknown. | same |
| `deletion.title.finishing_up` | FINISHING UP | ЗАВЕРШЕННЯ | Title: local cleanup incomplete. | same |
| `deletion.title.new_game` | NEW GAME | НОВА ГРА | Title while a fresh save is created. | same |
| `deletion.title.status_unknown` | STATUS UNKNOWN | СТАТУС НЕВІДОМИЙ | Title: local deletion record unreadable. | same |
| `deletion.title.not_deleted` | NOT DELETED | НЕ ВИДАЛЕНО | Title after a failed attempt. | same |
| `deletion.title.data_deleted` | DATA DELETED | ДАНІ ВИДАЛЕНО | Title after local data is deleted. | same |
| `deletion.title.accepted` | DELETION ACCEPTED | ЗАПИТ ПРИЙНЯТО | Title after the server accepts the request. | same |
| `deletion.confirm.headline` | This permanently deletes your account. | Це назавжди видалить ваш акаунт. | Confirm step, online account. | same |
| `deletion.confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nIf you sign in again later, you'll start a new account.\\n\\nSome purchase and security records are kept without your name or profile. The rest is removed within 30 days. | Ваш прогрес, монети, предмети й профіль буде видалено. Це неможливо скасувати.\\n\\nЯкщо ви згодом увійдете знову, буде створено новий акаунт.\\n\\nДеякі записи про покупки й безпеку зберігаються без вашого імені чи профілю. Решту буде видалено протягом 30 днів. | Confirm step body. Keep the three paragraphs. | same |
| `deletion.confirm.button` | Delete Account | Видалити акаунт | Red destructive button. | same |
| `deletion.local_confirm.headline` | This deletes your game data on this device. | Це видалить ваші дані гри на цьому пристрої. | Confirm step, local-only player. | same |
| `deletion.local_confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nThis game never created an online account for you, so nothing needs to be deleted from our servers. | Ваш прогрес, монети, предмети й профіль буде видалено. Це неможливо скасувати.\\n\\nДля вас ніколи не створювали онлайн-акаунт у цій грі, тому на наших серверах нічого видаляти не потрібно. | Body for that step. | same |
| `deletion.local_confirm.button` | Delete Data | Видалити дані | Red destructive button. | same |
| `deletion.pending_setup.headline` | Your account is still being set up. | Ваш акаунт ще створюється. | Deletion blocked: first registration not finished. | same |
| `deletion.pending_setup.body` | Connect to the internet and try again in a moment. Nothing was deleted. | Підключіться до інтернету й спробуйте трохи згодом. Нічого не видалено. | Body. | same |
| `deletion.sign_in.headline` | Sign in to the account you want to delete. | Увійдіть в акаунт, який хочете видалити. | Deletion blocked: signed out. | same |
| `deletion.sign_in.body` | If you can't sign in, contact support for help. | Якщо не можете увійти, зверніться до служби підтримки. | Body. | same |
| `deletion.read_failed.headline` | Your game data couldn't be read. | Не вдалося прочитати ваші дані гри. | Deletion blocked: save unreadable. | same |
| `deletion.read_failed.body` | Restart the game, then try again. Nothing was deleted. | Перезапустіть гру й спробуйте ще раз. Нічого не видалено. | Body. | same |
| `deletion.unavailable.headline` | Account deletion isn't available in this version of the game. | Видалення акаунта недоступне в цій версії гри. | Deletion blocked: feature off. Also a failure headline. | same |
| `deletion.unavailable.body` | Update the game, or contact support for help deleting your account. Nothing was deleted. | Оновіть гру або зверніться до служби підтримки, щоб отримати допомогу з видаленням акаунта. Нічого не видалено. | Body. | same |
| `deletion.in_progress.account` | Deleting your account... | Видалення вашого акаунта... | Headline while the request runs. | same |
| `deletion.in_progress.local` | Deleting your game data... | Видалення ваших даних гри... | Same for local-only data. | same |
| `deletion.in_progress.body` | Keep the game open. This only takes a moment. | Залиште гру відкритою. Це займе лише мить. | Body while deleting. | same |
| `deletion.not_confirmed.headline` | We haven't heard back about your deletion yet. | Ми ще не отримали відповіді щодо видалення. | Request sent, answer lost. | same |
| `deletion.not_confirmed.body` | Your request was sent, but the answer didn't arrive. Connect to the internet and try again. The game stays locked until we know the result. | Ваш запит надіслано, але відповідь не надійшла. Підключіться до інтернету й спробуйте ще раз. Гра залишатиметься заблокованою, доки ми не дізнаємося результат. | Body. | same |
| `deletion.unconfirmed.headline` | Deletion status unconfirmed | Статус видалення не підтверджено | Server outcome unknown. | same |
| `deletion.unconfirmed.body` | We couldn't confirm whether your account was deleted. To keep your data safe, the game stays locked. Contact support and include the reference below. | Не вдалося підтвердити, чи видалено ваш акаунт. Задля безпеки ваших даних гра залишається заблокованою. Зверніться до підтримки й додайте наведений нижче код запиту. | Body; a reference code is shown under it. | same |
| `deletion.check_again` | Check Again | Перевірити ще раз | Asks the server again. | same |
| `deletion.cleanup.headline.local` | Your local game data couldn't be fully deleted yet. | Поки що не вдалося повністю видалити ваші локальні дані гри. | Local cleanup incomplete (local-only player). | same |
| `deletion.cleanup.headline.account` | Account deletion accepted; finishing cleanup. | Запит на видалення акаунта прийнято; завершуємо очищення. | Local cleanup incomplete after the server accepted. | same |
| `deletion.cleanup.body` | Some game data couldn't be removed from this device yet. Try again to finish. | Деякі дані гри ще не вдалося видалити з цього пристрою. Спробуйте ще раз, щоб завершити видалення. | Body. | same |
| `deletion.new_game.headline` | Starting a new game... | Починаємо нову гру... | While a fresh save is created. | same |
| `deletion.new_game.body` | This only takes a moment. | Це займе лише мить. | Body. | same |
| `deletion.status_unknown.headline` | We couldn't read the deletion status on this device. | Не вдалося прочитати статус видалення на цьому пристрої. | Local deletion record unreadable. | same |
| `deletion.status_unknown.body` | To keep your data safe, the game stays locked. Contact support for help. | Задля безпеки ваших даних гра залишається заблокованою. Зверніться до служби підтримки. | Body. | same |
| `deletion.fail.offline` | Connect to the internet to delete your account. | Підключіться до інтернету, щоб видалити акаунт. | Failure headline. | same |
| `deletion.fail.rate_limited` | Too many attempts. Wait a moment, then try again. | Забагато спроб. Зачекайте трохи й спробуйте ще раз. | Failure headline. | same |
| `deletion.fail.busy` | Account deletion is busy right now. Try again in a moment. | Видалення акаунта тимчасово недоступне. Спробуйте трохи згодом. | Failure headline (server unavailable). | same |
| `deletion.fail.syncing` | The game is still syncing. Try again in a moment. | Гра ще синхронізується. Спробуйте трохи згодом. | Failure headline. | same |
| `deletion.fail.auth` | We couldn't verify your account. Restart the game, then try again. | Не вдалося підтвердити ваш акаунт. Перезапустіть гру й спробуйте ще раз. | Failure headline. | same |
| `deletion.fail.update` | Update the game to delete your account. | Оновіть гру, щоб видалити акаунт. | Failure headline (client too old). | same |
| `deletion.fail.changed` | Your account changed while we were deleting it. Try again. | Ваш акаунт змінився під час видалення. Спробуйте ще раз. | Failure headline. | same |
| `deletion.fail.storage` | Your device couldn't save the deletion request. Try again. | Не вдалося зберегти запит на видалення на вашому пристрої. Спробуйте ще раз. | Failure headline. | same |
| `deletion.fail.generic` | We couldn't delete your account. Try again later or contact support. | Не вдалося видалити ваш акаунт. Спробуйте згодом або зверніться до підтримки. | Failure headline (fallback). | same |
| `deletion.fail.local` | Your game data couldn't be deleted. Try again. | Не вдалося видалити ваші дані гри. Спробуйте ще раз. | Failure headline, local-only player. | same |
| `deletion.fail.body` | Nothing was deleted, and you can keep playing. | Нічого не видалено. Ви можете продовжити гру. | Body for every failure. | same |
| `deletion.done_local.headline` | Your local game data was deleted. | Ваші локальні дані гри видалено. | Success, local-only player. | same |
| `deletion.done_local.body` | You can start over with a new game. | Ви можете почати нову гру з нуля. | Body. | same |
| `deletion.new_game_failed` | The new game couldn't start. Try again. | Не вдалося почати нову гру. Спробуйте ще раз. | Appended under a success body if the fresh save failed. | same |
| `deletion.accepted.headline` | Your account is no longer accessible. | Ваш акаунт більше недоступний. | Success, online account. | same |
| `deletion.accepted.body` | Your deletion request was accepted. | Ваш запит на видалення прийнято. | Body when no deadline is known. | same |
| `deletion.accepted.body_deadline` | Your deletion request was accepted. Data removal is due by %s. | Ваш запит на видалення прийнято. Дані буде видалено до %s. | Body. `%s` = a date such as "November 2, 2026". | same |
| `deletion.reference` | Reference: %s | Код запиту: %s | Support reference code under the body. `%s` = operation id; never translated. | same |
| `deletion.start_new_game` | Start New Game | Почати нову гру | Button after a successful deletion. | same |

### Platform and system text

| Key | English | Ukrainian | Context | Source |
| --- | --- | --- | --- | --- |
| `app.name` | SortingPuzzle | SortingPuzzle | App name under the home-screen icon; today the internal project name. Decide the public name per store first. | `project.godot`, `export_presets.cfg` |
| `support.email.subject` | Sorting Puzzle support request | Sorting Puzzle: звернення до підтримки | Subject of the pre-filled support email. | `support_screen.gd` |
| `support.email.body` | Please describe the issue here.\\n\\nDevice/platform:\\nApproximate time:\\n | Опишіть проблему тут.\\n\\nПристрій/платформа:\\nПриблизний час:\\n | Body template the player fills in. | `support_screen.gd` |
| `support.ad_email.subject` | Sorting Puzzle ad report | Sorting Puzzle: скарга на рекламу | Subject of the ad-report email. | `support_screen.gd` |
| `support.ad_email.body` | Please attach a screenshot and complete the details below.\\n\\nApproximate time:\\nAd placement in the game:\\nAdvertiser or app name:\\nWhy the ad should be reviewed:\\n | Додайте знімок екрана й заповніть наведені нижче поля.\\n\\nПриблизний час:\\nМісце появи реклами в грі:\\nНазва рекламодавця чи застосунку:\\nЧому рекламу слід перевірити:\\n | Body template the player fills in. | `support_screen.gd` |
| `deletion.email.subject` | Sorting Puzzle account deletion | Sorting Puzzle: видалення акаунта | Subject of the deletion help email. | `account_deletion_modal.gd` |
| `deletion.email.body` | Please help me with my account deletion. | Допоможіть мені видалити акаунт. | First line; followed by `Status:`, `Deletion reference:`, `Server reference:` and `Player ID:` lines. | `account_deletion_modal.gd` |


## Ukrainian plural forms

For whole-number counts, Ukrainian uses three forms. Use the underlying numeric count before it is formatted as %s.

| Form | Counts |
| --- | --- |
| one | Last digit is 1 and last two digits are not 11: 1, 21, 31, 101… |
| few | Last digit is 2–4 and last two digits are not 12–14: 2, 3, 4, 22, 23, 24… |
| many | All other integers: 0, 5–20, 25–30, 100… |

### Chapter unlock — chapter.locked_status

Controlling count: the remaining levels, %d. Keep the chapter name %s in quotation marks to avoid changing its grammatical case.

| Form | Ukrainian |
| --- | --- |
| one | Пройдіть ще %d рівень розділу «%s», щоб відкрити цей розділ |
| few | Пройдіть ще %d рівні розділу «%s», щоб відкрити цей розділ |
| many | Пройдіть ще %d рівнів розділу «%s», щоб відкрити цей розділ |

### Shelf unlock — shelf_unlock.offer_or_clear

Controlling count: the remaining triples, supplied as %s.

| Form | Ukrainian |
| --- | --- |
| one | Перегляньте рекламу, щоб відкрити цю полицю зараз, або зберіть ще %s трійку. |
| few | Перегляньте рекламу, щоб відкрити цю полицю зараз, або зберіть ще %s трійки. |
| many | Перегляньте рекламу, щоб відкрити цю полицю зараз, або зберіть ще %s трійок. |

### Bundle coins — starter.coins

Controlling count: the coin amount, supplied as %s.

| Form | Ukrainian |
| --- | --- |
| one | %s МОНЕТА |
| few | %s МОНЕТИ |
| many | %s МОНЕТ |

### Claimed boosters — booster_chip.claimed

The pattern is +%d %s in all three forms. Select the inflected booster name for %s using the count %d. Standalone names stay capitalized; names after counts use lowercase.

| Booster | one | few | many |
| --- | --- | --- | --- |
| Hammer | молоток | молотки | молотків |
| Shuffle | перемішування | перемішування | перемішувань |
| Lantern | ліхтар | ліхтарі | ліхтарів |
| Freezer | замороження | замороження | заморожень |

Examples: +1 молоток, +2 молотки, +5 молотків, +21 молоток.

### Leaderboard row — leaderboard.row_tooltip

Controlling count: the stars, the second %d. The first %d is the rank; %s is the player's name.

| Form | Ukrainian |
| --- | --- |
| one | Місце %d, %s, %d зірка |
| few | Місце %d, %s, %d зірки |
| many | Місце %d, %s, %d зірок |

### Weekly reward — leaderboard.reward.body

Controlling count: the coins, the second %d. The first %d is the rank. The №%d notation works for any rank without an ordinal suffix.

| Form | Ukrainian |
| --- | --- |
| one | Минулого тижня ви посіли місце №%d й отримали %d монету! |
| few | Минулого тижня ви посіли місце №%d й отримали %d монети! |
| many | Минулого тижня ви посіли місце №%d й отримали %d монет! |

## Additional labels mentioned in the source context

These email field labels are referenced in the inventory's context rather than listed as separate keyed strings.

| English | Ukrainian |
| --- | --- |
| Status: | Статус: |
| Deletion reference: | Код запиту на видалення: |
| Server reference: | Код запиту на сервері: |
| Player ID: | ID гравця: |

## Notes for eventual integration

- The existing two-line discount badge must keep the percentage on its first line and OFF on its second. If it is combined later, retain the same %d%% OFF pattern for every locale. Keep AD unchanged as well.
- leaderboard.reward_tooltip uses “Монет у тижневій винагороді: %s”, which works for every whole-number amount without adding more plural forms.
- Format counts separately, for example 1 000. Keep platform-formatted prices unchanged.
- Dates supplied as %s need Ukrainian formatting. Example: 2 листопада 2026 р. Use the genitive month names below.
- Check the long booster names Перемішування and Замороження, modal headings, privacy buttons and the Реклама / Недоступна two-line state when integrating. This document makes no claim about rendered fit.
- Ukrainian is not yet registered in the game. Any later integration will need a uk locale option and catalog; neither is changed by this document.

| Month | Ukrainian date form |
| --- | --- |
| January | січня |
| February | лютого |
| March | березня |
| April | квітня |
| May | травня |
| June | червня |
| July | липня |
| August | серпня |
| September | вересня |
| October | жовтня |
| November | листопада |
| December | грудня |
