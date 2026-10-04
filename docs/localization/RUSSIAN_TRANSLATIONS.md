# Sorting Puzzle — Russian Translations

Locale: `ru` · Prepared: October 4, 2026

Bilingual translation of all 251 keyed strings in **Sorting Puzzle — Translation String Inventory.md** (October 3, 2026; source audit at commit `ade3b3d`). English text, suggested keys, context and source references are retained for review. This document supplies translations; it does not install them in the game.

## Russian terminology

| English | Russian |
| --- | --- |
| Level | Уровень |
| Chapter | Глава |
| Shelf | Полка |
| Item / goods | Предмет / товар |
| Match / triple / set | Тройка одинаковых предметов; тройка when the meaning is already clear |
| Combo | Комбо |
| Booster / ability | Бустер |
| Hammer | Молоток |
| Shuffle | Перемешивание |
| Lantern | Фонарь |
| Freezer | Заморозка |
| Dispenser | Автомат |
| Coins | Монеты |
| Stars | Звёзды |
| Lives | Жизни |
| Reward chest | Сундук с наградой |
| Bundle | Набор |

## Reading the tables

- All `%d` and `%s` placeholders retain their original types and order.
- Line-break markers retain the source document's Markdown escaping (`\\n`); each marker represents one forced line break in the game. Consecutive markers separate paragraphs.
- The six entries marked **Needs plural forms** use the singular form in the main tables. Their complete Russian forms appear in the appendix.
- Address to the player uses polite plural verbs. Combo praise avoids gendered forms and stays within one or two words.
- `SortingPuzzle` / `Sorting Puzzle` stay as the existing brand name. Email addresses, player names, prices and reference codes passed through placeholders are unchanged.
- `Макс.` fits the five-character lives indicator; `СТАРТ` fits the starter badge; `РЕК` is a three-character abbreviation of «реклама» for the ad badge.
- Uppercase titles and banners remain uppercase. The acronym `SFX` is localized as «Звуки» to match the adjacent toggle labels. Bundle names retain title case in their name entries and have an explicit uppercase starter-modal title.
- The support and account-deletion warnings preserve the original meaning, including irreversibility, retained records, the 30-day deadline, blocked states and “nothing was deleted”.
- Text has been checked against the inventory, but has not been rendered in the game. Actual fit and Cyrillic font coverage still need verification during integration.

## Shared buttons, main menu and chapters

Shared buttons appear on several screens and need one translation each, except where the context says the meaning differs. Keys are suggestions for the future translation table.

| Key | English | Russian | Context | Source |
| --- | --- | --- | --- | --- |
| `common.play` | Play | Играть | Button that starts the chapter's next level on a chapter card. | `chapter_cover_card.gd` |
| `common.continue` | Continue | Продолжить | Button that moves on: closes the level-complete screen, the purchase dialog and the reward chest menu; on a chapter card it resumes a chapter already started. | `level_completion_screen.tscn`, `shop_purchase_dialog`, `reward_chest_menu.tscn`, `chapter_cover_card.gd` |
| `common.resume` | Continue | Продолжить | Button on Pause and on the leave confirmation that returns to the running level ("keep playing"). Separate key: some languages use a different verb than for "move on". | `pause_menu.tscn`, `leave_confirmation_menu.tscn` |
| `common.try_again` | Try Again | Повторить | Retries a failed action (ad, purchase, account deletion). | ad modals, `account_deletion_modal.gd`, `starter_bundle_offer_modal.gd` |
| `common.close` | Close | Закрыть | Closes a dialog without doing anything. | `account_deletion_modal.gd` |
| `common.cancel` | Cancel | Отмена | Backs out of account deletion; nothing is deleted. | `account_deletion_modal.tscn` |
| `common.got_it` | Got it | Понятно | Acknowledges an info dialog (ability description, lives already full). | `out_of_lives_menu.tscn`, `shop_screen.gd` |
| `common.get_help` | Get Help | Помощь | Opens a pre-filled email to support. | `account_deletion_modal.gd` |
| `common.save` | SAVE | СОХРАНИТЬ | Confirms profile edits or the chosen language. All caps by design. | `profile_menu`, `language_selection_modal.tscn` |
| `common.loading` | Loading… | Загрузка… | Shown while the Shop or Leaderboard loads its data. | `destination_status_panel.tscn` |
| `common.retry_load` | Retry | Обновить | Reloads the Shop or Leaderboard after a load error. Not the same as replaying a level. | `destination_status_panel.tscn` |
| `menu.level_button` | LEVEL %d | УРОВЕНЬ %d | Big play button on the home screen. `%d` = level number inside the current chapter. | `production_main_menu.gd` |
| `menu.more_levels_coming_soon` | MORE LEVELS COMING SOON | НОВЫЕ УРОВНИ СКОРО | Home play button (disabled) after every level of the chapter is finished. Must fit the button, about 24 characters. | `production_main_menu.gd` |
| `menu.coming_soon` | COMING SOON | СКОРО | Home play button (disabled) when the chapter has no levels yet. | `production_main_menu.gd` |
| `menu.lives_full` | Full | Макс. | Top bar, next to the heart, when lives are at maximum; replaces the refill timer. About 5 characters. | `production_main_menu.gd`, `main_menu_top_status.tscn` |
| `menu.starter_badge` | STARTER | СТАРТ | Small badge on the home screen that opens the Starter Bundle offer. About 8 characters. | `main_menu_starter_bundle_badge.tscn` |
| `nav.shop` | Shop | Магазин | Bottom navigation tab. About 10 characters. | `main_menu_bottom_navigation.tscn` |
| `nav.home` | Home | Главная | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `nav.leaderboard` | Leaderboard | Лидеры | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `chapter.button` | CHAPTER %d | ГЛАВА %d | Home button that opens chapter selection. `%d` = chapter number. | `main_menu_chapter_button.gd` |
| `chapter.button_tooltip` | Choose Chapter %d: %s | Выбрать главу %d: %s | Accessibility tooltip of that button. `%d` = chapter number, `%s` = chapter title. | `main_menu_chapter_button.gd` |
| `chapter.screen_title` | CHAPTERS | ГЛАВЫ | Title of the chapter selection screen. | `chapter_selection_screen.tscn` |
| `chapter.eyebrow` | CHAPTER %d | ГЛАВА %d | Small label above the chapter name on its card. | `chapter_cover_card.gd` |
| `chapter.title.chapter_01` | Grocery Town | Продуктовый городок | Name of chapter 1 (a grocery-store theme). | `configs/chapters.json` |
| `chapter.title.chapter_02` | Candy Corner | Сладкий уголок | Name of chapter 2 (a candy-shop theme). | `configs/chapters.json` |
| `chapter.locked_status` | Complete %d more %s levels to unlock | Пройдите ещё %d уровень главы «%s», чтобы открыть эту главу | Locked chapter card. `%d` = levels still needed, `%s` = previous chapter's name. Needs plural forms. | `chapter_cover_card.gd` |
| `chapter.unlock_progress` | Unlock progress | До открытия | Header over the progress bar on a locked chapter. | `chapter_cover_card.gd` |
| `chapter.current_progress` | Current progress | Текущий прогресс | Header over the progress bar on an unlocked chapter. | `chapter_cover_card.gd` |
| `chapter.locked` | Locked | Закрыто | Disabled button on a locked chapter card. | `chapter_cover_card.gd` |
| `chapter.no_levels_status` | New levels are coming soon | Скоро появятся новые уровни | Card message for a chapter with no levels yet. | `chapter_cover_card.gd` |
| `chapter.coming_soon` | Coming Soon | Скоро | Disabled button on that card. | `chapter_cover_card.gd` |

## Gameplay: HUD, level screens and results

These strings show during a level, mostly in modal titles (all caps, short) and action buttons. A "triple" or "match" is three identical items on one shelf, which clears them.

| Key | English | Russian | Context | Source |
| --- | --- | --- | --- | --- |
| `hud.level` | LEVEL %d | УРОВЕНЬ %d | Top HUD during play. `%d` = level number inside the chapter. | `level.gd` |
| `hud.combo` | COMBO ×%d | КОМБО ×%d | HUD counter for consecutive quick matches. `%d` = combo size; keep the × sign. | `level_top_hud.gd` |
| `hud.ability_tooltip.hammer` | Hammer -- clears a matching triple | Молоток — убирает одну тройку одинаковых предметов | Accessibility tooltip on the Hammer booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.shuffle` | Shuffle -- reshuffles unlocked items | Перемешивание — перемешивает предметы на открытых полках | Tooltip on the Shuffle booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.lantern` | Lantern -- highlights a matchable triple | Фонарь — подсвечивает тройку, которую можно собрать | Tooltip on the Lantern booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.freezer` | Freezer -- pauses the countdown timer | Заморозка — останавливает таймер | Tooltip on the Freezer booster button. | `ability_bar.tscn` |
| `hud.seconds_short` | %ds | %dс | Countdown on an active Lantern or Freezer booster, e.g. "15s". `%d` = seconds; use the local short unit. | `ability_bar.gd` |
| `tip.tap_dispenser` | Tap a dispenser to throw items onto the shelves! | Нажмите на автомат, чтобы он выбросил предметы на полки! | Tutorial bubble on level 10, where dispensers (machines that throw items onto shelves) first appear. | `configs/gameplay_tips.json` |
| `pause.title` | PAUSE | ПАУЗА | Title of the in-level pause modal. | `pause_menu.gd` |
| `pause.leave` | Leave | Выйти | Pause button that quits the level (asks for confirmation next). | `pause_menu.tscn` |
| `leave.title` | LEAVING THE LEVEL | ВЫХОД ИЗ УРОВНЯ | Title of the leave confirmation. | `leave_confirmation_menu.gd` |
| `leave.you_will_lose` | You will lose: | Вы потеряете: | Followed by icons showing the stars earned this run and one life. Keep the colon (or local equivalent). | `leave_confirmation_menu.tscn` |
| `leave.confirm` | Leave | Выйти | Confirms quitting the level and losing that progress. | `leave_confirmation_menu.tscn` |
| `timeup.title` | TIME'S UP | ВРЕМЯ ВЫШЛО | Title when the level timer reaches zero. | `time_up_extension_modal.gd` |
| `timeup.offer` | Add one minute and keep sorting! | Добавьте минуту и продолжайте сортировать! | Offer to extend the timer by 60 seconds for coins or an ad. | `time_up_extension_modal.tscn` |
| `timeup.used` | Used | Использовано | Shown on the coin price or ad button when that extension was already used this level. | `time_up_extension_modal.gd` |
| `ability_purchase.title` | USE ABILITY | ПРИМЕНИТЬ БУСТЕР | Title of the modal that buys and immediately uses one booster when the player has none. | `ability_purchase_menu.gd` |
| `shelf_unlock.title` | UNLOCK SHELF | ОТКРЫТЬ ПОЛКУ | Title of the modal for a locked shelf. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer` | Watch one ad to unlock this shelf now. | Посмотрите рекламу, чтобы открыть эту полку сейчас. | Body when no other way to unlock remains. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer_or_clear` | Watch one ad to unlock this shelf now, or clear %s more. | Посмотрите рекламу, чтобы открыть эту полку сейчас, или соберите ещё %s тройку. | Body when the shelf also unlocks by itself after more matches. `%s` = matches still needed. Needs plural forms. | `shelf_unlock_menu.gd` |
| `shelf_unlock.button` | Watch Ad · Unlock Shelf | Реклама · Открыть полку | Ad button in that modal. | `shelf_unlock_menu.gd` |
| `shelf_unlock.ad_unavailable` | Ad unavailable. This shelf stays locked. | Реклама недоступна. Полка остаётся закрытой. | Status line when no ad could be shown. | `shelf_unlock_menu.gd` |
| `complete.title` | GREAT JOB! | ОТЛИЧНО! | Title of the level-complete screen, above the stars earned. | `level_completion_screen.gd` |
| `failed.title` | LEVEL %d | УРОВЕНЬ %d | Title of the level-failed screen. `%d` = level number. | `level_failure_screen.gd` |
| `failed.headline` | LEVEL FAILED | УРОВЕНЬ НЕ ПРОЙДЕН | Banner on the level-failed screen. | `level_failure_screen.tscn` |
| `failed.retry` | Retry | Повторить | Replays the same level. | `level_failure_screen.tscn` |

Combo praise pops up above a match during a combo; each word is stronger than the one before, so keep the escalation. The label shrinks its font for long words, but one or two words is the limit.

| Key | English | Russian | Shown at |
| --- | --- | --- | --- |
| `combo.praise.2` | Cool | Класс | Combo ×2 |
| `combo.praise.3` | Great | Здорово | ×3 |
| `combo.praise.4` | Awesome | Круто | ×4 |
| `combo.praise.5` | Amazing | Потрясающе | ×5 |
| `combo.praise.6` | Fantastic | Фантастика | ×6 |
| `combo.praise.7` | Incredible | Невероятно | ×7 |
| `combo.praise.8` | Spectacular | Сногсшибательно | ×8 |
| `combo.praise.9` | Unstoppable | Не остановить | ×9 |
| `combo.praise.10` | Legendary | Легендарно | ×10 |
| `combo.praise.11` | Epic | Эпично | ×11 |
| `combo.praise.12` | Brilliant | Блестяще | ×12 |
| `combo.praise.13` | Masterful | Мастерски | ×13 |
| `combo.praise.14` | Supreme | Непревзойдённо | ×14 |
| `combo.praise.15` | Phenomenal | Феноменально | ×15 |
| `combo.praise.16` | Mythic | Сказочно | ×16 |
| `combo.praise.17` | Majestic | Величественно | ×17 |
| `combo.praise.18` | Radiant | Ослепительно | ×18 |
| `combo.praise.19` | Divine | Божественно | ×19 |
| `combo.praise.20` | Transcendent | Запредельно | ×20 and above |

Source: `COMBO_PRAISE_WORDS` in `level.gd`.

## Boosters, ads, lives, rewards and shop

The four boosters (also called abilities in code) are product names: pick one translation per language and reuse it everywhere, including the tooltips in the gameplay section.

| Key | English | Russian | Context | Source |
| --- | --- | --- | --- | --- |
| `ability.hammer.name` | Hammer | Молоток | Booster that smashes away one matching set. | `reward_reveal_row.tscn`, `starter_bundle_offer_modal.tscn`, `shop_screen.gd` |
| `ability.shuffle.name` | Shuffle | Перемешивание | Booster that rearranges items. | same |
| `ability.lantern.name` | Lantern | Фонарь | Booster that lights up a set the player can match (internal id `highlight`). | same |
| `ability.freezer.name` | Freezer | Заморозка | Booster that stops the level timer. | same |
| `ability.hammer.description` | Instantly clears one matching set of items off the shelves. | Мгновенно убирает с полок одну тройку одинаковых предметов. | Shop info dialog body after tapping the booster icon. | `shop_screen.gd` |
| `ability.shuffle.description` | Shuffles shelf items into new spots to help you find a match. | Перемешивает предметы на полках, чтобы было проще собрать тройку. | Same dialog. | `shop_screen.gd` |
| `ability.lantern.description` | Highlights a matching triple you can clear for 15 seconds. | На 15 секунд подсвечивает тройку одинаковых предметов, которую можно собрать. | Same dialog. Keep the number in sync with the game config. | `shop_screen.gd` |
| `ability.freezer.description` | Freezes the level timer for 30 seconds. | Останавливает таймер уровня на 30 секунд. | Same dialog. | `shop_screen.gd` |
| `ad.watch` | Watch Ad | Смотреть рекламу | Button that plays a rewarded video ad. | ad modals, `out_of_lives_menu`, `ability_purchase_menu.tscn` |
| `ad.loading` | Loading... | Загрузка... | Ad button while the ad loads. | ad modals |
| `ad.verifying` | Verifying... | Проверка... | Ad button while the server confirms the reward. | ad modals |
| `ad.verify_reward` | Verify Reward | Проверить награду | Ad button to re-check a reward the server has not confirmed yet. | ad modals |
| `ad.reward_pending` | Reward verification is still pending. | Награда ещё не подтверждена. | Status line under that button. | `out_of_lives_menu.gd`, `shelf_unlock_menu.gd` |
| `ad.unavailable_retry` | Ad unavailable. Please try again. | Реклама недоступна. Повторите попытку. | Status line when no ad could be shown. | `out_of_lives_menu` |
| `ad.watch_unavailable` | Watch Ad\\nUnavailable | Реклама\\nНедоступна | Two-line disabled ad button (time-up modal). Keep the line break. | `time_up_extension_modal.gd` |
| `ad.watch_coming_soon` | Watch Ad\\nComing Soon | Реклама\\nСкоро | Two-line disabled ad button before ads launch. | `time_up_extension_modal.tscn` |
| `ad.badge` | AD | РЕК | Tiny badge on a locked shelf that an ad can open. 2–3 characters. | `shelf_lock_overlay.tscn`, `shelf_unlock_menu.tscn` |
| `lives.title.out` | OUT OF LIVES | ЖИЗНИ ЗАКОНЧИЛИСЬ | Lives modal title at 0 lives. | `out_of_lives_menu.gd` |
| `lives.title.get_more` | GET MORE LIVES | ПОПОЛНИТЬ ЖИЗНИ | Lives modal title with some lives left. | `out_of_lives_menu.gd` |
| `lives.title.full` | LIVES FULL | МАКСИМУМ ЖИЗНЕЙ | Lives modal title at maximum lives. | `out_of_lives_menu.gd` |
| `lives.next_in` | NEXT LIFE IN | НОВАЯ ЖИЗНЬ ЧЕРЕЗ | Label above the refill countdown (mm:ss). | `out_of_lives_menu.tscn` |
| `lives.full_body` | Your lives are full! Play a level to spend them. | У вас максимум жизней! Начните уровень, чтобы их использовать. | Body of the lives modal at maximum. | `out_of_lives_menu.tscn` |
| `chest.title` | CHEST REWARDS | НАГРАДЫ ИЗ СУНДУКА | Title of the reward chest modal. | `reward_chest_menu.tscn` |
| `chest.progress_hint` | Collect stars to unlock a chest and claim your reward | Собирайте звёзды, чтобы открыть сундук и получить награду | Under the star progress bar (e.g. 12/30). | `reward_chest_menu.tscn` |
| `chest.ready` | A REWARD CHEST AWAITS! | ВАС ЖДЁТ СУНДУК С НАГРАДОЙ! | Banner when the chest is full and can be opened. | `reward_chest_menu.tscn` |
| `chest.tap_to_open` | Tap to open | Нажмите, чтобы открыть | Prompt under the closed chest in the opening animation. | `reward_chest_open_ceremony.tscn` |
| `purchase.tap_to_collect` | Tap to collect | Нажмите, чтобы забрать | Prompt to collect purchased rewards. | `purchase_reward_sequence.tscn` |
| `purchase.complete` | PURCHASE COMPLETE | ПОКУПКА ЗАВЕРШЕНА | Banner after a successful purchase. | `purchase_reward_sequence.gd` |
| `shop.title` | SHOP | МАГАЗИН | Shop screen title. | `shop_screen.tscn` |
| `shop.section.bundles` | SPECIAL BUNDLES | ОСОБЫЕ НАБОРЫ | Section header. | `shop_screen.tscn` |
| `shop.section.coins` | COINS | МОНЕТЫ | Section header for coin packs. | `shop_screen.tscn` |
| `shop.offer.starter_bundle` | Starter Bundle | Стартовый набор | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.offer.basic_bundle` | Basic Bundle | Базовый набор | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.tag.best_value` | BEST VALUE | САМОЕ ВЫГОДНОЕ | Ribbon on the best coin pack. | `configs/shop_catalog.json` |
| `shop.discount_off` | OFF | СКИДКА | Second line of the discount badge under "67%". Word order differs by language; see implementation notes. | `shop_bundle_card.tscn`, `starter_bundle_offer_modal.tscn` |
| `shop.ability_hint` | Tap an ability to see what it does | Нажмите на бустер, чтобы узнать, как он работает | Hint under a bundle's booster icons. | `shop_bundle_card.tscn` |
| `shop.purchasing` | Purchasing… | Покупка… | Buy button while a purchase is in progress. | shop cards, `production_main_menu.gd` |
| `shop.no_offers` | No shop offers are available for this region. | В вашем регионе нет доступных предложений магазина. | Shop error state. | `shop_screen.gd` |
| `shop.load_failed` | Could not load the shop. | Не удалось загрузить магазин. | Shop error state (fallback text). | `shop_screen.gd` |
| `shop.error.title.purchase` | Purchase unavailable | Покупка недоступна | Error dialog title when buying failed. | `shop_screen.gd` |
| `shop.error.title.reward` | Reward error | Ошибка выдачи награды | Error dialog title when payment went through but rewards were not granted. | `shop_screen.gd` |
| `shop.error.purchase_failed` | The purchase could not be completed. | Не удалось завершить покупку. | Error dialog body (fallback). | `shop_screen.gd`, `production_main_menu.gd` |
| `shop.error.grant_failed` | The purchased rewards could not be granted. | Не удалось выдать купленные награды. | Error dialog body. | `store/shop_purchase_flow.gd` |
| `shop.error.offer_unavailable` | This shop offer is unavailable. | Это предложение магазина недоступно. | Error dialog body. | `store/store_service.gd` |
| `shop.error.already_bought` | This one-time shop offer has already been purchased. | Это разовое предложение уже куплено. | Error dialog body. | `store/store_service.gd` |
| `starter.title` | STARTER BUNDLE | СТАРТОВЫЙ НАБОР | Starter offer modal title. | `starter_bundle_offer_modal.gd` |
| `starter.one_time` | ONE-TIME OFFER | РАЗОВОЕ ПРЕДЛОЖЕНИЕ | Ribbon on the starter offer. | `starter_bundle_offer_modal.tscn` |
| `starter.boosters_included` | BOOSTERS INCLUDED | БУСТЕРЫ В НАБОРЕ | Header over the four booster chips. | `starter_bundle_offer_modal.tscn` |
| `starter.coins` | %s COINS | %s МОНЕТА | Ribbon over the coin art. `%s` = formatted amount, e.g. "1,000". Needs plural forms. | `starter_bundle_offer_modal.gd` |
| `starter.buy_for` | Buy for %s | Купить за %s | Buy button. `%s` = store price, e.g. "$4.99". | `starter_bundle_offer_modal.gd` |
| `starter.checking` | Checking offer… | Проверка предложения… | Status while the store confirms the offer. | `production_main_menu.gd` |
| `starter.checking_short` | Checking… | Проверка… | Buy button during that check. | `starter_bundle_offer_modal.gd` |
| `starter.no_longer_available` | This offer is no longer available. | Это предложение больше недоступно. | Error status in the starter modal. | `production_main_menu.gd` |
| `starter.unavailable` | Unavailable | Недоступно | Disabled buy button after a non-retryable error. | `starter_bundle_offer_modal.gd` |
| `booster_chip.claimed` | +%d %s | +%d %s | Booster chip after purchase, e.g. "+3 Hammer". `%d` = count, `%s` = booster name. Needs plural forms. | `offer_booster_chip.gd` |

## Profile, leaderboard and settings

Language names in the language picker stay in their own language (English, Español, 日本語…) and are never translated.

| Key | English | Russian | Context | Source |
| --- | --- | --- | --- | --- |
| `profile.title` | EDIT PROFILE | ИЗМЕНИТЬ ПРОФИЛЬ | Profile modal title. | `profile_menu.tscn` |
| `profile.name_header` | PLAYER NAME | ИМЯ ИГРОКА | Header over the name field. | `profile_menu.tscn` |
| `profile.name_placeholder` | Player name | Имя игрока | Placeholder inside the empty name field. | `profile_menu.tscn` |
| `profile.edit_name_tooltip` | Edit player name | Изменить имя игрока | Accessibility tooltip on the pencil button. | `profile_menu.tscn` |
| `profile.avatar_tab` | AVATAR | АВАТАР | Tab that shows avatar pictures. | `profile_menu.tscn` |
| `profile.frame_tab` | FRAME | РАМКА | Tab that shows decorative frames around the avatar. | `profile_menu.tscn` |
| `profile.unlock.level` | Complete level %d to unlock | Пройдите уровень %d, чтобы открыть | Toast after tapping a locked frame. `%d` = level number. | `profile_menu.gd` |
| `profile.unlock.combo` | Reach a combo of ×%d in any run to unlock | Соберите комбо ×%d в любой попытке, чтобы открыть | Same toast. `%d` = combo size. | `profile_menu.gd` |
| `profile.unlock.weekly_first` | Finish 1st on the Weekly leaderboard to unlock | Займите 1-е место в недельном рейтинге, чтобы открыть | Same toast for a first-place frame. Today built from two parts; see implementation notes. | `profile_menu.gd` |
| `profile.unlock.weekly_top` | Finish top %d on the Weekly leaderboard to unlock | Войдите в топ-%d недельного рейтинга, чтобы открыть | Same toast. `%d` = rank cutoff (e.g. 10). | `profile_menu.gd` |
| `leaderboard.title` | LEADERBOARD | ЛИДЕРЫ | Leaderboard screen title. | `leaderboard_screen.tscn` |
| `leaderboard.tab.weekly` | Weekly | Неделя | Tab: this week's stars. | `leaderboard_screen.tscn` |
| `leaderboard.tab.country` | Country | Страна | Tab: all-time stars in the player's country. | `leaderboard_screen.tscn` |
| `leaderboard.tab.world` | World | Мир | Tab: all-time stars worldwide. | `leaderboard_screen.tscn` |
| `leaderboard.weekly_reset` | Weekly reset in %s | Недельный рейтинг обновится через %s | Under the Weekly tab. `%s` = a duration such as "1d 4h". | `leaderboard_screen.gd` |
| `leaderboard.duration.dh` | %dd %dh | %dд %dч | Duration: days and hours. Use local unit abbreviations. | `leaderboard_screen.gd` |
| `leaderboard.duration.hm` | %dh %dm | %dч %dм | Duration: hours and minutes. | `leaderboard_screen.gd` |
| `leaderboard.duration.m` | %dm | %dм | Duration: minutes. | `leaderboard_screen.gd` |
| `leaderboard.country_caption` | Country · All-time stars | Страна · Звёзды за всё время | Caption under the Country tab. | `leaderboard_screen.gd` |
| `leaderboard.world_caption` | Worldwide · All-time stars | Весь мир · Звёзды за всё время | Caption under the World tab. | `leaderboard_screen.gd` |
| `leaderboard.load_failed` | Could not load leaderboard. | Не удалось загрузить рейтинг. | Error state (fallback text). | `leaderboard_screen.gd` |
| `leaderboard.default_name` | Player | Игрок | Name shown for a player without one. | `leaderboard_row.gd` |
| `leaderboard.row_tooltip` | Rank %d, %s, %d stars | Место %d, %s, %d звезда | Accessibility text of a row. `%d` = rank, `%s` = player name, `%d` = stars. Needs plural forms. | `leaderboard_row.gd` |
| `leaderboard.reward_tooltip` | %s coin weekly reward | Количество монет в награду за неделю: %s | Accessibility text on the coin prize next to top ranks. `%s` = amount. | `leaderboard_rank_reward.gd` |
| `leaderboard.reward.title` | WEEKLY REWARD! | НАГРАДА ЗА НЕДЕЛЮ! | Title of the dialog shown after a week ends. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.body` | You finished #%d last week and earned %d coins! | На прошлой неделе вы заняли %d-е место и получили %d монету! | Body. `%d` = final rank, `%d` = coins. Needs plural forms. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.ok` | Nice! | Здорово! | Button that closes the reward dialog. | `leaderboard_reward_dialog.tscn` |
| `settings.title` | SETTINGS | НАСТРОЙКИ | Settings modal title (home screen). | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.music` | Music | Музыка | Toggle label under an icon. Short, about 8 characters. | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.sfx` | SFX | Звуки | Toggle for sound effects. Use a short local word for "Sounds". | same |
| `settings.vibrate` | Vibrate | Вибрация | Toggle for haptic feedback. | same |
| `settings.support` | Support | Поддержка | Opens the Support screen. | `settings_menu.tscn` |
| `settings.language` | Language | Язык | Opens the language picker. | `settings_menu.tscn`, `language_option_row.tscn` |
| `settings.privacy_policy` | Privacy Policy | Политика конфиденциальности | Opens the privacy policy web page. | `settings_menu.tscn`, `production_main_menu.gd` |
| `settings.privacy_choices` | Privacy Choices | Настройки конфиденциальности | Same button when the ad consent form must be offered (EU/UK). | `production_main_menu.gd` |
| `settings.diagnostics` | Version %s • Build %d\\nPlatform: %s • User: %s | Версия %s • Сборка %d\\nПлатформа: %s • Игрок: %s | Small footer for support. Values: app version, build number, OS name, short player id. Translating the four labels is optional. | `pause_menu.gd` |
| `language.title` | LANGUAGE | ЯЗЫК | Language picker title. | `language_selection_modal.gd` |

## Support, account deletion and platform text

Support and deletion copy is legal-adjacent: translate meaning exactly, keep "Nothing was deleted" and "You can't undo this" unambiguous, and do not soften the warnings.

### Support screen

| Key | English | Russian | Context | Source |
| --- | --- | --- | --- | --- |
| `support.title` | SUPPORT | ПОДДЕРЖКА | Support screen title. | `support_screen.tscn` |
| `support.faq_header` | Frequently Asked Questions | Частые вопросы | Section header. | `support_screen.tscn` |
| `support.faq.play.q` | How do I play? | Как играть? | FAQ question (tap to expand). | `support_screen.tscn` |
| `support.faq.play.a` | Move matching goods onto the same shelf. When three identical items are visible together, they clear. Complete the board before time runs out. | Перемещайте одинаковые предметы на одну полку. Когда на одной полке видны три одинаковых предмета, они исчезают. Уберите все предметы до того, как закончится время. | FAQ answer. "Goods" = shop items such as snacks and toys. | `support_screen.tscn` |
| `support.faq.contact.q` | How do I contact support? | Как связаться с поддержкой? | FAQ question. | `support_screen.tscn` |
| `support.faq.contact.a` | Email us at %s. Include a short description, your device platform, and when the problem happened. | Напишите нам по адресу %s. Кратко опишите проблему, укажите платформу вашего устройства и время, когда возникла проблема. | FAQ answer. `%s` = support email address. | `support_screen.gd` |
| `support.faq.contact.action` | Email Support | Написать в поддержку | Button that opens a pre-filled email. | `support_screen.tscn` |
| `support.faq.crash.q` | What if the game freezes or crashes? | Что делать, если игра зависает или вылетает? | FAQ question. | `support_screen.tscn` |
| `support.faq.crash.a` | Close and reopen the game first. If it happens again, restart the device and make sure the game is updated. Contact support with the device model, platform version, and what you were doing before the problem. | Сначала закройте и снова откройте игру. Если проблема повторится, перезагрузите устройство и убедитесь, что игра обновлена. Напишите в поддержку: укажите модель устройства, версию операционной системы и что вы делали перед возникновением проблемы. | FAQ answer. | `support_screen.tscn` |
| `support.faq.sync.q` | How do I sync progress between devices? | Как синхронизировать прогресс между устройствами? | FAQ question. | `support_screen.tscn` |
| `support.faq.sync.a` | Use the same signed-in platform account on both devices and allow synchronization to finish before playing. If the progress differs, avoid playing on both devices and contact support. | На обоих устройствах войдите в один и тот же аккаунт игровой платформы и дождитесь завершения синхронизации, прежде чем играть. Если прогресс различается, не играйте на обоих устройствах и обратитесь в поддержку. | FAQ answer. "Platform account" = Google Play Games / Game Center. | `support_screen.tscn` |
| `support.faq.bad_ad.q` | How do I report a bad ad? | Как пожаловаться на рекламу? | FAQ question. | `support_screen.tscn` |
| `support.faq.bad_ad.a` | 1. Close the ad if you can do so safely.\\n2. Take a screenshot of the ad and any advertiser or app name shown.\\n3. Note the approximate time and where the ad appeared in the game.\\n4. Describe why the ad seemed offensive, misleading, or fraudulent.\\n5. Email these details to %s. Do not include passwords or payment information. | 1. Закройте рекламу, если это можно сделать безопасно.\\n2. Сделайте скриншот рекламы, включая название рекламодателя или приложения, если оно показано.\\n3. Запишите примерное время и место появления рекламы в игре.\\n4. Опишите, почему реклама показалась вам оскорбительной, вводящей в заблуждение или мошеннической.\\n5. Отправьте эти сведения на %s. Не указывайте пароли или платёжные данные. | FAQ answer, a five-step list in one string. `%s` = support email. Keep the numbering and line breaks. | `support_screen.gd` |
| `support.faq.bad_ad.action` | Email Ad Report | Пожаловаться на рекламу | Button that opens a pre-filled ad-report email. | `support_screen.tscn` |
| `support.account_header` | Account | Аккаунт | Section header above the delete button. | `support_screen.tscn` |
| `support.delete_account` | Delete Account | Удалить аккаунт | Opens account deletion (player has an online account). | `support_screen.gd` |
| `support.delete_game_data` | Delete Game Data | Удалить данные игры | Same button when only local data exists. | `support_screen.gd` |
| `support.no_secrets` | Please never send passwords or payment information. | Никогда не отправляйте пароли или платёжные данные. | Warning at the bottom of the screen. | `support_screen.tscn` |

### Account deletion modal

One modal switches between states; each state has a title (caps), a headline, a body and up to two buttons.

| Key | English | Russian | Context | Source |
| --- | --- | --- | --- | --- |
| `deletion.title.delete_account` | DELETE ACCOUNT | УДАЛИТЬ АККАУНТ | Title: confirm, in progress and unavailable states. | `account_deletion_modal.gd` |
| `deletion.title.delete_game_data` | DELETE GAME DATA | УДАЛИТЬ ДАННЫЕ ИГРЫ | Title for a player who never had an online account. | same |
| `deletion.title.not_confirmed` | NOT CONFIRMED | НЕ ПОДТВЕРЖДЕНО | Title: request sent, answer lost. | same |
| `deletion.title.status_unconfirmed` | STATUS UNCONFIRMED | СТАТУС НЕ ПОДТВЕРЖДЁН | Title: server outcome unknown. | same |
| `deletion.title.finishing_up` | FINISHING UP | ЗАВЕРШЕНИЕ | Title: local cleanup incomplete. | same |
| `deletion.title.new_game` | NEW GAME | НОВАЯ ИГРА | Title while a fresh save is created. | same |
| `deletion.title.status_unknown` | STATUS UNKNOWN | СТАТУС НЕИЗВЕСТЕН | Title: local deletion record unreadable. | same |
| `deletion.title.not_deleted` | NOT DELETED | НЕ УДАЛЕНО | Title after a failed attempt. | same |
| `deletion.title.data_deleted` | DATA DELETED | ДАННЫЕ УДАЛЕНЫ | Title after local data is deleted. | same |
| `deletion.title.accepted` | DELETION ACCEPTED | ЗАПРОС ПРИНЯТ | Title after the server accepts the request. | same |
| `deletion.confirm.headline` | This permanently deletes your account. | Ваш аккаунт будет удалён навсегда. | Confirm step, online account. | same |
| `deletion.confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nIf you sign in again later, you'll start a new account.\\n\\nSome purchase and security records are kept without your name or profile. The rest is removed within 30 days. | Ваш прогресс, монеты, предметы и профиль будут удалены. Это действие нельзя отменить.\\n\\nЕсли позже вы снова войдёте в игру, будет создан новый аккаунт.\\n\\nНекоторые записи о покупках и безопасности сохраняются без вашего имени и профиля. Остальные данные будут удалены в течение 30 дней. | Confirm step body. Keep the three paragraphs. | same |
| `deletion.confirm.button` | Delete Account | Удалить аккаунт | Red destructive button. | same |
| `deletion.local_confirm.headline` | This deletes your game data on this device. | Ваши данные игры на этом устройстве будут удалены. | Confirm step, local-only player. | same |
| `deletion.local_confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nThis game never created an online account for you, so nothing needs to be deleted from our servers. | Ваш прогресс, монеты, предметы и профиль будут удалены. Это действие нельзя отменить.\\n\\nВ этой игре для вас не создавался онлайн-аккаунт, поэтому на наших серверах ничего удалять не нужно. | Body for that step. | same |
| `deletion.local_confirm.button` | Delete Data | Удалить данные | Red destructive button. | same |
| `deletion.pending_setup.headline` | Your account is still being set up. | Ваш аккаунт ещё создаётся. | Deletion blocked: first registration not finished. | same |
| `deletion.pending_setup.body` | Connect to the internet and try again in a moment. Nothing was deleted. | Подключитесь к интернету и повторите попытку через некоторое время. Ничего не удалено. | Body. | same |
| `deletion.sign_in.headline` | Sign in to the account you want to delete. | Войдите в аккаунт, который хотите удалить. | Deletion blocked: signed out. | same |
| `deletion.sign_in.body` | If you can't sign in, contact support for help. | Если не удаётся войти, обратитесь за помощью в поддержку. | Body. | same |
| `deletion.read_failed.headline` | Your game data couldn't be read. | Не удалось прочитать ваши данные игры. | Deletion blocked: save unreadable. | same |
| `deletion.read_failed.body` | Restart the game, then try again. Nothing was deleted. | Перезапустите игру и повторите попытку. Ничего не удалено. | Body. | same |
| `deletion.unavailable.headline` | Account deletion isn't available in this version of the game. | В этой версии игры удаление аккаунта недоступно. | Deletion blocked: feature off. Also a failure headline. | same |
| `deletion.unavailable.body` | Update the game, or contact support for help deleting your account. Nothing was deleted. | Обновите игру или обратитесь в поддержку за помощью в удалении аккаунта. Ничего не удалено. | Body. | same |
| `deletion.in_progress.account` | Deleting your account... | Удаляем ваш аккаунт... | Headline while the request runs. | same |
| `deletion.in_progress.local` | Deleting your game data... | Удаляем ваши данные игры... | Same for local-only data. | same |
| `deletion.in_progress.body` | Keep the game open. This only takes a moment. | Не закрывайте игру. Это займёт совсем немного времени. | Body while deleting. | same |
| `deletion.not_confirmed.headline` | We haven't heard back about your deletion yet. | Ответ на запрос на удаление пока не получен. | Request sent, answer lost. | same |
| `deletion.not_confirmed.body` | Your request was sent, but the answer didn't arrive. Connect to the internet and try again. The game stays locked until we know the result. | Ваш запрос отправлен, но ответ не получен. Подключитесь к интернету и повторите попытку. Игра останется заблокированной, пока результат не станет известен. | Body. | same |
| `deletion.unconfirmed.headline` | Deletion status unconfirmed | Статус удаления не подтверждён | Server outcome unknown. | same |
| `deletion.unconfirmed.body` | We couldn't confirm whether your account was deleted. To keep your data safe, the game stays locked. Contact support and include the reference below. | Не удалось подтвердить, удалён ли ваш аккаунт. Для защиты ваших данных игра остаётся заблокированной. Обратитесь в поддержку и укажите код запроса ниже. | Body; a reference code is shown under it. | same |
| `deletion.check_again` | Check Again | Проверить снова | Asks the server again. | same |
| `deletion.cleanup.headline.local` | Your local game data couldn't be fully deleted yet. | Пока не удалось полностью удалить ваши локальные данные игры. | Local cleanup incomplete (local-only player). | same |
| `deletion.cleanup.headline.account` | Account deletion accepted; finishing cleanup. | Запрос на удаление аккаунта принят; завершаем очистку данных. | Local cleanup incomplete after the server accepted. | same |
| `deletion.cleanup.body` | Some game data couldn't be removed from this device yet. Try again to finish. | Пока не удалось удалить часть данных игры с этого устройства. Повторите попытку, чтобы завершить удаление. | Body. | same |
| `deletion.new_game.headline` | Starting a new game... | Начинаем новую игру... | While a fresh save is created. | same |
| `deletion.new_game.body` | This only takes a moment. | Это займёт совсем немного времени. | Body. | same |
| `deletion.status_unknown.headline` | We couldn't read the deletion status on this device. | Не удалось прочитать статус удаления на этом устройстве. | Local deletion record unreadable. | same |
| `deletion.status_unknown.body` | To keep your data safe, the game stays locked. Contact support for help. | Для защиты ваших данных игра остаётся заблокированной. Обратитесь за помощью в поддержку. | Body. | same |
| `deletion.fail.offline` | Connect to the internet to delete your account. | Подключитесь к интернету, чтобы удалить аккаунт. | Failure headline. | same |
| `deletion.fail.rate_limited` | Too many attempts. Wait a moment, then try again. | Слишком много попыток. Немного подождите и повторите попытку. | Failure headline. | same |
| `deletion.fail.busy` | Account deletion is busy right now. Try again in a moment. | Сервис удаления аккаунта сейчас недоступен. Повторите попытку через некоторое время. | Failure headline (server unavailable). | same |
| `deletion.fail.syncing` | The game is still syncing. Try again in a moment. | Игра ещё синхронизируется. Повторите попытку через некоторое время. | Failure headline. | same |
| `deletion.fail.auth` | We couldn't verify your account. Restart the game, then try again. | Не удалось подтвердить ваш аккаунт. Перезапустите игру и повторите попытку. | Failure headline. | same |
| `deletion.fail.update` | Update the game to delete your account. | Обновите игру, чтобы удалить аккаунт. | Failure headline (client too old). | same |
| `deletion.fail.changed` | Your account changed while we were deleting it. Try again. | Ваш аккаунт изменился во время удаления. Повторите попытку. | Failure headline. | same |
| `deletion.fail.storage` | Your device couldn't save the deletion request. Try again. | Не удалось сохранить запрос на удаление на устройстве. Повторите попытку. | Failure headline. | same |
| `deletion.fail.generic` | We couldn't delete your account. Try again later or contact support. | Не удалось удалить ваш аккаунт. Повторите попытку позже или обратитесь в поддержку. | Failure headline (fallback). | same |
| `deletion.fail.local` | Your game data couldn't be deleted. Try again. | Не удалось удалить ваши данные игры. Повторите попытку. | Failure headline, local-only player. | same |
| `deletion.fail.body` | Nothing was deleted, and you can keep playing. | Ничего не удалено. Вы можете продолжить играть. | Body for every failure. | same |
| `deletion.done_local.headline` | Your local game data was deleted. | Ваши локальные данные игры удалены. | Success, local-only player. | same |
| `deletion.done_local.body` | You can start over with a new game. | Вы можете начать новую игру с самого начала. | Body. | same |
| `deletion.new_game_failed` | The new game couldn't start. Try again. | Не удалось начать новую игру. Повторите попытку. | Appended under a success body if the fresh save failed. | same |
| `deletion.accepted.headline` | Your account is no longer accessible. | Ваш аккаунт больше недоступен. | Success, online account. | same |
| `deletion.accepted.body` | Your deletion request was accepted. | Ваш запрос на удаление принят. | Body when no deadline is known. | same |
| `deletion.accepted.body_deadline` | Your deletion request was accepted. Data removal is due by %s. | Ваш запрос на удаление принят. Данные должны быть удалены не позднее %s. | Body. `%s` = a date such as "November 2, 2026". | same |
| `deletion.reference` | Reference: %s | Код запроса: %s | Support reference code under the body. `%s` = operation id; never translated. | same |
| `deletion.start_new_game` | Start New Game | Начать новую игру | Button after a successful deletion. | same |

### Platform and system text

| Key | English | Russian | Context | Source |
| --- | --- | --- | --- | --- |
| `app.name` | SortingPuzzle | SortingPuzzle | App name under the home-screen icon; today the internal project name. Decide the public name per store first. | `project.godot`, `export_presets.cfg` |
| `support.email.subject` | Sorting Puzzle support request | Sorting Puzzle: обращение в поддержку | Subject of the pre-filled support email. | `support_screen.gd` |
| `support.email.body` | Please describe the issue here.\\n\\nDevice/platform:\\nApproximate time:\\n | Опишите проблему.\\n\\nУстройство/платформа:\\nПримерное время:\\n | Body template the player fills in. | `support_screen.gd` |
| `support.ad_email.subject` | Sorting Puzzle ad report | Sorting Puzzle: жалоба на рекламу | Subject of the ad-report email. | `support_screen.gd` |
| `support.ad_email.body` | Please attach a screenshot and complete the details below.\\n\\nApproximate time:\\nAd placement in the game:\\nAdvertiser or app name:\\nWhy the ad should be reviewed:\\n | Прикрепите скриншот и заполните сведения ниже.\\n\\nПримерное время:\\nМесто показа рекламы в игре:\\nНазвание рекламодателя или приложения:\\nПочему рекламу нужно проверить:\\n | Body template the player fills in. | `support_screen.gd` |
| `deletion.email.subject` | Sorting Puzzle account deletion | Sorting Puzzle: удаление аккаунта | Subject of the deletion help email. | `account_deletion_modal.gd` |
| `deletion.email.body` | Please help me with my account deletion. | Помогите мне удалить аккаунт. | First line; followed by `Status:`, `Deletion reference:`, `Server reference:` and `Player ID:` lines. | `account_deletion_modal.gd` |

## Russian plural forms

For integer counts, use these three forms:

| Form | Counts |
| --- | --- |
| one | Last digit is 1 and last two digits are not 11: 1, 21, 31, 101… |
| few | Last digit is 2–4 and last two digits are not 12–14: 2, 3, 4, 22, 23, 24… |
| many | All other integers: 0, 5–20, 25–30, 100… |

Choose the form from the underlying numeric count, before formatting it as `%s`. For entries with several numeric placeholders, the controlling count is specified below.

### Chapter unlock — `chapter.locked_status`

Plural count: the remaining levels, `%d`. Keep the chapter name `%s` in quotation marks so its grammatical case does not need to change.

| Form | Russian |
| --- | --- |
| one | Пройдите ещё %d уровень главы «%s», чтобы открыть эту главу |
| few | Пройдите ещё %d уровня главы «%s», чтобы открыть эту главу |
| many | Пройдите ещё %d уровней главы «%s», чтобы открыть эту главу |

### Shelf unlock — `shelf_unlock.offer_or_clear`

Plural count: the remaining triples, supplied as `%s`.

| Form | Russian |
| --- | --- |
| one | Посмотрите рекламу, чтобы открыть эту полку сейчас, или соберите ещё %s тройку. |
| few | Посмотрите рекламу, чтобы открыть эту полку сейчас, или соберите ещё %s тройки. |
| many | Посмотрите рекламу, чтобы открыть эту полку сейчас, или соберите ещё %s троек. |

### Starter coins — `starter.coins`

Plural count: the coin amount, supplied as `%s`.

| Form | Russian |
| --- | --- |
| one | %s МОНЕТА |
| few | %s МОНЕТЫ |
| many | %s МОНЕТ |

### Claimed boosters — `booster_chip.claimed`

The pattern is `+%d %s` in all three forms. Choose the inflected booster name for `%s` using the count `%d`; a fixed dictionary-form product name is insufficient.

| Booster | one | few | many |
| --- | --- | --- | --- |
| Hammer | молоток | молотка | молотков |
| Shuffle | перемешивание | перемешивания | перемешиваний |
| Lantern | фонарь | фонаря | фонарей |
| Freezer | заморозка | заморозки | заморозок |

Examples: `+1 молоток`, `+2 молотка`, `+5 молотков`, `+21 молоток`. Standalone product names remain capitalized as listed in the main tables; names after a count use lowercase.

### Leaderboard row — `leaderboard.row_tooltip`

Plural count: the stars, the **second** `%d`. The first `%d` remains the rank; `%s` remains the player's name.

| Form | Russian |
| --- | --- |
| one | Место %d, %s, %d звезда |
| few | Место %d, %s, %d звезды |
| many | Место %d, %s, %d звёзд |

### Weekly reward — `leaderboard.reward.body`

Plural count: the coins, the **second** `%d`. The first `%d` is the final rank; `-е место` works for every positive integer rank.

| Form | Russian |
| --- | --- |
| one | На прошлой неделе вы заняли %d-е место и получили %d монету! |
| few | На прошлой неделе вы заняли %d-е место и получили %d монеты! |
| many | На прошлой неделе вы заняли %d-е место и получили %d монет! |

## Additional labels mentioned in the source context

These email field labels are referenced in the inventory's context rather than listed as separate keyed strings.

| English | Russian |
| --- | --- |
| Status: | Статус: |
| Deletion reference: | Код запроса на удаление: |
| Server reference: | Код сервера: |
| Player ID: | ID игрока: |

## Notes for eventual integration

The existing two-line discount badge can use `СКИДКА` for `shop.discount_off`. If it is later changed to one formatted string, use `СКИДКА %d%%` (for example, «СКИДКА 67%»), preserving `%%` in the formatting pattern.

`leaderboard.reward_tooltip` uses «Количество монет в награду за неделю: %s», which works for every integer amount without an extra plural-dependent noun after the placeholder.

Date and numeric values supplied through placeholders must be localized separately. An appropriate Russian date looks like «2 ноября 2026 г.»; a formatted count may look like «1 000». These examples describe value formatting and are not additional inventory keys.
