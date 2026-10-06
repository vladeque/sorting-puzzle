# Sorting Puzzle — Spanish Translations

Locale: `es` · Prepared October 6, 2026

Neutral Spanish translations of all **251 inventory entries**, intended for players in both Latin America and Spain. The document uses friendly, informal singular address (`tú`) and avoids country-specific slang.

Original English, suggested keys, context, and source references are retained for review. The six entries marked as plural-sensitive use plural wording in the main tables; their singular and plural forms appear in the appendix.

Placeholders (`%d`, `%s`), uppercase titles, symbols, and the source inventory's escaped line-break notation are preserved. Each `\n` marker represents one forced line break; repeated markers separate paragraphs. `AD`, `OFF`, and the current app name `SortingPuzzle` remain unchanged. Discount tags keep their percentage followed by `OFF`. Email addresses, player names, reference codes, and store prices supplied through placeholders remain unchanged.

This is a translation document. The wording has been checked against the supplied inventory; it has not been integrated into the game or verified in rendered screens.

## Terminology

| English | Español |
| --- | --- |
| Level | Nivel |
| Chapter | Capítulo |
| Shelf | Estante |
| Item / goods | Objeto / productos |
| Match / triple / set | Trío (tres objetos iguales) |
| Combo | Combo |
| Booster / ability | Potenciador |
| Hammer | Martillo |
| Shuffle | Mezcla |
| Lantern | Linterna |
| Freezer | Congelador |
| Dispenser | Dispensador |
| Coins | Monedas |
| Stars | Estrellas |
| Lives | Vidas |
| Reward chest | Cofre |
| Bundle | Paquete |
| Leaderboard | Ranking |
| Support | Ayuda / equipo de ayuda |

## Shared buttons, main menu and chapters

| Key | English | Español | Context | Source |
| --- | --- | --- | --- | --- |
| `common.play` | Play | Jugar | Button that starts the chapter's next level on a chapter card. | `chapter_cover_card.gd` |
| `common.continue` | Continue | Continuar | Button that moves on: closes the level-complete screen, the purchase dialog and the reward chest menu; on a chapter card it resumes a chapter already started. | `level_completion_screen.tscn`, `shop_purchase_dialog`, `reward_chest_menu.tscn`, `chapter_cover_card.gd` |
| `common.resume` | Continue | Reanudar | Button on Pause and on the leave confirmation that returns to the running level ("keep playing"). Separate key: some languages use a different verb than for "move on". | `pause_menu.tscn`, `leave_confirmation_menu.tscn` |
| `common.try_again` | Try Again | Reintentar | Retries a failed action (ad, purchase, account deletion). | ad modals, `account_deletion_modal.gd`, `starter_bundle_offer_modal.gd` |
| `common.close` | Close | Cerrar | Closes a dialog without doing anything. | `account_deletion_modal.gd` |
| `common.cancel` | Cancel | Cancelar | Backs out of account deletion; nothing is deleted. | `account_deletion_modal.tscn` |
| `common.got_it` | Got it | Entendido | Acknowledges an info dialog (ability description, lives already full). | `out_of_lives_menu.tscn`, `shop_screen.gd` |
| `common.get_help` | Get Help | Pedir ayuda | Opens a pre-filled email to support. | `account_deletion_modal.gd` |
| `common.save` | SAVE | GUARDAR | Confirms profile edits or the chosen language. All caps by design. | `profile_menu`, `language_selection_modal.tscn` |
| `common.loading` | Loading… | Cargando… | Shown while the Shop or Leaderboard loads its data. | `destination_status_panel.tscn` |
| `common.retry_load` | Retry | Reintentar | Reloads the Shop or Leaderboard after a load error. Not the same as replaying a level. | `destination_status_panel.tscn` |
| `menu.level_button` | LEVEL %d | NIVEL %d | Big play button on the home screen. `%d` = level number inside the current chapter. | `production_main_menu.gd` |
| `menu.more_levels_coming_soon` | MORE LEVELS COMING SOON | MÁS NIVELES MUY PRONTO | Home play button (disabled) after every level of the chapter is finished. Must fit the button, about 24 characters. | `production_main_menu.gd` |
| `menu.coming_soon` | COMING SOON | MUY PRONTO | Home play button (disabled) when the chapter has no levels yet. | `production_main_menu.gd` |
| `menu.lives_full` | Full | Máx. | Top bar, next to the heart, when lives are at maximum; replaces the refill timer. About 5 characters. | `production_main_menu.gd`, `main_menu_top_status.tscn` |
| `menu.starter_badge` | BUNDLE | PAQUETE | Small badge on the home screen that opens the Starter Bundle offer. About 8 characters. Russian: НАБОР. The full offer title remains Starter Bundle / Стартовый набор. | `main_menu_starter_bundle_badge.tscn` |
| `nav.shop` | Shop | Tienda | Bottom navigation tab. About 10 characters. | `main_menu_bottom_navigation.tscn` |
| `nav.home` | Home | Inicio | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `nav.leaderboard` | Leaderboard | Ranking | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `chapter.button` | CHAPTER %d | CAPÍTULO %d | Home button that opens chapter selection. `%d` = chapter number. | `main_menu_chapter_button.gd` |
| `chapter.button_tooltip` | Choose Chapter %d: %s | Elige el capítulo %d: %s | Accessibility tooltip of that button. `%d` = chapter number, `%s` = chapter title. | `main_menu_chapter_button.gd` |
| `chapter.screen_title` | CHAPTERS | CAPÍTULOS | Title of the chapter selection screen. | `chapter_selection_screen.tscn` |
| `chapter.eyebrow` | CHAPTER %d | CAPÍTULO %d | Small label above the chapter name on its card. | `chapter_cover_card.gd` |
| `chapter.title.chapter_01` | Grocery Town | Ciudad del Mercado | Name of chapter 1 (a grocery-store theme). | `configs/chapters.json` |
| `chapter.title.chapter_02` | Candy Corner | Rincón Dulce | Name of chapter 2 (a candy-shop theme). | `configs/chapters.json` |
| `chapter.locked_status` | Complete %d more %s levels to unlock | Completa %d niveles más de «%s» para desbloquear | Locked chapter card. `%d` = levels still needed, `%s` = previous chapter's name. Needs plural forms. | `chapter_cover_card.gd` |
| `chapter.unlock_progress` | Unlock progress | Progreso de desbloqueo | Header over the progress bar on a locked chapter. | `chapter_cover_card.gd` |
| `chapter.current_progress` | Current progress | Progreso actual | Header over the progress bar on an unlocked chapter. | `chapter_cover_card.gd` |
| `chapter.locked` | Locked | Bloqueado | Disabled button on a locked chapter card. | `chapter_cover_card.gd` |
| `chapter.no_levels_status` | New levels are coming soon | Pronto habrá nuevos niveles | Card message for a chapter with no levels yet. | `chapter_cover_card.gd` |
| `chapter.coming_soon` | Coming Soon | Muy pronto | Disabled button on that card. | `chapter_cover_card.gd` |

## Gameplay: HUD, level screens and results

| Key | English | Español | Context | Source |
| --- | --- | --- | --- | --- |
| `hud.level` | LEVEL %d | NIVEL %d | Top HUD during play. `%d` = level number inside the chapter. | `level.gd` |
| `hud.combo` | COMBO ×%d | COMBO ×%d | HUD counter for consecutive quick matches. `%d` = combo size; keep the × sign. | `level_top_hud.gd` |
| `hud.ability_tooltip.hammer` | Hammer -- clears a matching triple | Martillo -- elimina un trío de objetos iguales | Accessibility tooltip on the Hammer booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.shuffle` | Shuffle -- reshuffles unlocked items | Mezcla -- reorganiza los objetos desbloqueados | Tooltip on the Shuffle booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.lantern` | Lantern -- highlights a matchable triple | Linterna -- resalta un trío que puedes combinar | Tooltip on the Lantern booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.freezer` | Freezer -- pauses the countdown timer | Congelador -- pausa la cuenta atrás | Tooltip on the Freezer booster button. | `ability_bar.tscn` |
| `hud.seconds_short` | %ds | %ds | Countdown on an active Lantern or Freezer booster, e.g. "15s". `%d` = seconds; use the local short unit. | `ability_bar.gd` |
| `tip.tap_dispenser` | Tap a dispenser to throw items onto the shelves! | ¡Toca un dispensador para lanzar objetos a los estantes! | Tutorial bubble on level 10, where dispensers (machines that throw items onto shelves) first appear. | `configs/gameplay_tips.json` |
| `pause.title` | PAUSE | PAUSA | Title of the in-level pause modal. | `pause_menu.gd` |
| `pause.leave` | Leave | Salir | Pause button that quits the level (asks for confirmation next). | `pause_menu.tscn` |
| `leave.title` | LEAVING THE LEVEL | SALIR DEL NIVEL | Title of the leave confirmation. | `leave_confirmation_menu.gd` |
| `leave.you_will_lose` | You will lose: | Perderás: | Followed by icons showing the stars earned this run and one life. Keep the colon (or local equivalent). | `leave_confirmation_menu.tscn` |
| `leave.confirm` | Leave | Salir | Confirms quitting the level and losing that progress. | `leave_confirmation_menu.tscn` |
| `timeup.title` | TIME'S UP | TIEMPO AGOTADO | Title when the level timer reaches zero. | `time_up_extension_modal.gd` |
| `timeup.offer` | Add one minute and keep sorting! | ¡Añade un minuto y sigue ordenando! | Offer to extend the timer by 60 seconds for coins or an ad. | `time_up_extension_modal.tscn` |
| `timeup.used` | Used | Usado | Shown on the coin price or ad button when that extension was already used this level. | `time_up_extension_modal.gd` |
| `ability_purchase.title` | USE ABILITY | USAR POTENCIADOR | Title of the modal that buys and immediately uses one booster when the player has none. | `ability_purchase_menu.gd` |
| `shelf_unlock.title` | UNLOCK SHELF | DESBLOQUEAR ESTANTE | Title of the modal for a locked shelf. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer` | Watch one ad to unlock this shelf now. | Mira un anuncio para desbloquear este estante ahora. | Body when no other way to unlock remains. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer_or_clear` | Watch one ad to unlock this shelf now, or clear %s more. | Mira un anuncio para desbloquear este estante ahora o elimina %s tríos más. | Body when the shelf also unlocks by itself after more matches. `%s` = matches still needed. Needs plural forms. | `shelf_unlock_menu.gd` |
| `shelf_unlock.button` | Watch Ad · Unlock Shelf | Ver anuncio · Desbloquear estante | Ad button in that modal. | `shelf_unlock_menu.gd` |
| `shelf_unlock.ad_unavailable` | Ad unavailable. This shelf stays locked. | Anuncio no disponible. Este estante sigue bloqueado. | Status line when no ad could be shown. | `shelf_unlock_menu.gd` |
| `complete.title` | GREAT JOB! | ¡BUEN TRABAJO! | Title of the level-complete screen, above the stars earned. | `level_completion_screen.gd` |
| `failed.title` | LEVEL %d | NIVEL %d | Title of the level-failed screen. `%d` = level number. | `level_failure_screen.gd` |
| `failed.headline` | LEVEL FAILED | NIVEL FALLIDO | Banner on the level-failed screen. | `level_failure_screen.tscn` |
| `failed.retry` | Retry | Reintentar | Replays the same level. | `level_failure_screen.tscn` |

### Combo praise

The praise refers to the combo and follows the source sequence; it does not address the player's gender. Source: `COMBO_PRAISE_WORDS` in `level.gd`.

| Key | English | Español | Shown at |
| --- | --- | --- | --- |
| `combo.praise.2` | Cool | Genial | Combo ×2 |
| `combo.praise.3` | Great | Estupendo | ×3 |
| `combo.praise.4` | Awesome | Asombroso | ×4 |
| `combo.praise.5` | Amazing | Impresionante | ×5 |
| `combo.praise.6` | Fantastic | Fantástico | ×6 |
| `combo.praise.7` | Incredible | Increíble | ×7 |
| `combo.praise.8` | Spectacular | Espectacular | ×8 |
| `combo.praise.9` | Unstoppable | Imparable | ×9 |
| `combo.praise.10` | Legendary | Legendario | ×10 |
| `combo.praise.11` | Epic | Épico | ×11 |
| `combo.praise.12` | Brilliant | Brillante | ×12 |
| `combo.praise.13` | Masterful | Magistral | ×13 |
| `combo.praise.14` | Supreme | Supremo | ×14 |
| `combo.praise.15` | Phenomenal | Fenomenal | ×15 |
| `combo.praise.16` | Mythic | Mítico | ×16 |
| `combo.praise.17` | Majestic | Majestuoso | ×17 |
| `combo.praise.18` | Radiant | Radiante | ×18 |
| `combo.praise.19` | Divine | Divino | ×19 |
| `combo.praise.20` | Transcendent | Trascendente | ×20 and above |

## Boosters, ads, lives, rewards and shop

| Key | English | Español | Context | Source |
| --- | --- | --- | --- | --- |
| `ability.hammer.name` | Hammer | Martillo | Booster that smashes away one matching set. | `reward_reveal_row.tscn`, `starter_bundle_offer_modal.tscn`, `shop_screen.gd` |
| `ability.shuffle.name` | Shuffle | Mezcla | Booster that rearranges items. | same |
| `ability.lantern.name` | Lantern | Linterna | Booster that lights up a set the player can match (internal id `highlight`). | same |
| `ability.freezer.name` | Freezer | Congelador | Booster that stops the level timer. | same |
| `ability.hammer.description` | Instantly clears one matching set of items off the shelves. | Elimina al instante un trío de objetos iguales de los estantes. | Shop info dialog body after tapping the booster icon. | `shop_screen.gd` |
| `ability.shuffle.description` | Shuffles shelf items into new spots to help you find a match. | Reorganiza los objetos de los estantes para ayudarte a encontrar un trío. | Same dialog. | `shop_screen.gd` |
| `ability.lantern.description` | Highlights a matching triple you can clear for 15 seconds. | Resalta durante 15 segundos un trío de objetos iguales que puedes eliminar. | Same dialog. Keep the number in sync with the game config. | `shop_screen.gd` |
| `ability.freezer.description` | Freezes the level timer for 30 seconds. | Congela el temporizador del nivel durante 30 segundos. | Same dialog. | `shop_screen.gd` |
| `ad.watch` | Watch Ad | Ver anuncio | Button that plays a rewarded video ad. | ad modals, `out_of_lives_menu`, `ability_purchase_menu.tscn` |
| `ad.loading` | Loading... | Cargando... | Ad button while the ad loads. | ad modals |
| `ad.verifying` | Verifying... | Verificando... | Ad button while the server confirms the reward. | ad modals |
| `ad.verify_reward` | Verify Reward | Verificar recompensa | Ad button to re-check a reward the server has not confirmed yet. | ad modals |
| `ad.reward_pending` | Reward verification is still pending. | La verificación de la recompensa sigue pendiente. | Status line under that button. | `out_of_lives_menu.gd`, `shelf_unlock_menu.gd` |
| `ad.unavailable_retry` | Ad unavailable. Please try again. | Anuncio no disponible. Vuelve a intentarlo. | Status line when no ad could be shown. | `out_of_lives_menu` |
| `ad.watch_unavailable` | Watch Ad\\nUnavailable | Ver anuncio\\nNo disponible | Two-line disabled ad button (time-up modal). Keep the line break. | `time_up_extension_modal.gd` |
| `ad.watch_coming_soon` | Watch Ad\\nComing Soon | Ver anuncio\\nMuy pronto | Two-line disabled ad button before ads launch. | `time_up_extension_modal.tscn` |
| `ad.badge` | AD | AD | Tiny badge on a locked shelf that an ad can open. Do not translate: keep AD exactly in every language. | `shelf_lock_overlay.tscn`, `shelf_unlock_menu.tscn` |
| `lives.title.out` | OUT OF LIVES | SIN VIDAS | Lives modal title at 0 lives. | `out_of_lives_menu.gd` |
| `lives.title.get_more` | GET MORE LIVES | CONSEGUIR VIDAS | Lives modal title with some lives left. | `out_of_lives_menu.gd` |
| `lives.title.full` | LIVES FULL | VIDAS AL MÁXIMO | Lives modal title at maximum lives. | `out_of_lives_menu.gd` |
| `lives.next_in` | NEXT LIFE IN | PRÓXIMA VIDA EN | Label above the refill countdown (mm:ss). | `out_of_lives_menu.tscn` |
| `lives.full_body` | Your lives are full! Play a level to spend them. | ¡Tienes el máximo de vidas! Juega un nivel para usarlas. | Body of the lives modal at maximum. | `out_of_lives_menu.tscn` |
| `chest.title` | CHEST REWARDS | RECOMPENSAS DEL COFRE | Title of the reward chest modal. | `reward_chest_menu.tscn` |
| `chest.progress_hint` | Collect stars to unlock a chest and claim your reward | Reúne estrellas para desbloquear un cofre y obtener tu recompensa | Under the star progress bar (e.g. 12/30). | `reward_chest_menu.tscn` |
| `chest.ready` | A REWARD CHEST AWAITS! | ¡TE ESPERA UN COFRE! | Banner when the chest is full and can be opened. | `reward_chest_menu.tscn` |
| `chest.tap_to_open` | Tap to open | Toca para abrir | Prompt under the closed chest in the opening animation. | `reward_chest_open_ceremony.tscn` |
| `purchase.tap_to_collect` | Tap to collect | Toca para recoger | Prompt to collect purchased rewards. | `purchase_reward_sequence.tscn` |
| `purchase.complete` | PURCHASE COMPLETE | COMPRA COMPLETADA | Banner after a successful purchase. | `purchase_reward_sequence.gd` |
| `shop.title` | SHOP | TIENDA | Shop screen title. | `shop_screen.tscn` |
| `shop.section.bundles` | SPECIAL BUNDLES | PAQUETES ESPECIALES | Section header. | `shop_screen.tscn` |
| `shop.section.coins` | COINS | MONEDAS | Section header for coin packs. | `shop_screen.tscn` |
| `shop.offer.starter_bundle` | Starter Bundle | Paquete inicial | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.offer.basic_bundle` | Basic Bundle | Paquete básico | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.tag.best_value` | BEST VALUE | MEJOR OFERTA | Ribbon on the best coin pack. | `configs/shop_catalog.json` |
| `shop.discount_off` | OFF | OFF | Second line of the discount badge under "67%". Do not translate: keep the complete 67% OFF tag unchanged in every language; the numeric percentage can vary by offer. | `shop_bundle_card.tscn`, `starter_bundle_offer_modal.tscn` |
| `shop.ability_hint` | Tap an ability to see what it does | Toca un potenciador para ver qué hace | Hint under a bundle's booster icons. | `shop_bundle_card.tscn` |
| `shop.purchasing` | Purchasing… | Comprando… | Buy button while a purchase is in progress. | shop cards, `production_main_menu.gd` |
| `shop.no_offers` | No shop offers are available for this region. | No hay ofertas disponibles en la tienda para esta región. | Shop error state. | `shop_screen.gd` |
| `shop.load_failed` | Could not load the shop. | No se pudo cargar la tienda. | Shop error state (fallback text). | `shop_screen.gd` |
| `shop.error.title.purchase` | Purchase unavailable | Compra no disponible | Error dialog title when buying failed. | `shop_screen.gd` |
| `shop.error.title.reward` | Reward error | Error de recompensa | Error dialog title when payment went through but rewards were not granted. | `shop_screen.gd` |
| `shop.error.purchase_failed` | The purchase could not be completed. | No se pudo completar la compra. | Error dialog body (fallback). | `shop_screen.gd`, `production_main_menu.gd` |
| `shop.error.grant_failed` | The purchased rewards could not be granted. | No se pudieron entregar las recompensas compradas. | Error dialog body. | `store/shop_purchase_flow.gd` |
| `shop.error.offer_unavailable` | This shop offer is unavailable. | Esta oferta de la tienda no está disponible. | Error dialog body. | `store/store_service.gd` |
| `shop.error.already_bought` | This one-time shop offer has already been purchased. | Ya has comprado esta oferta de compra única. | Error dialog body. | `store/store_service.gd` |
| `starter.title` | STARTER BUNDLE | PAQUETE INICIAL | Starter offer modal title. | `starter_bundle_offer_modal.gd` |
| `starter.one_time` | ONE-TIME OFFER | OFERTA DE COMPRA ÚNICA | Ribbon on the starter offer. | `starter_bundle_offer_modal.tscn` |
| `starter.boosters_included` | BOOSTERS INCLUDED | POTENCIADORES INCLUIDOS | Header over the four booster chips. | `starter_bundle_offer_modal.tscn` |
| `starter.coins` | %s COINS | %s MONEDAS | Ribbon over the coin art. `%s` = formatted amount, e.g. "1,000". Needs plural forms. | `starter_bundle_offer_modal.gd` |
| `starter.buy_for` | Buy for %s | Comprar por %s | Buy button. `%s` = store price, e.g. "$4.99". | `starter_bundle_offer_modal.gd` |
| `starter.checking` | Checking offer… | Comprobando oferta… | Status while the store confirms the offer. | `production_main_menu.gd` |
| `starter.checking_short` | Checking… | Comprobando… | Buy button during that check. | `starter_bundle_offer_modal.gd` |
| `starter.no_longer_available` | This offer is no longer available. | Esta oferta ya no está disponible. | Error status in the starter modal. | `production_main_menu.gd` |
| `starter.unavailable` | Unavailable | No disponible | Disabled buy button after a non-retryable error. | `starter_bundle_offer_modal.gd` |
| `booster_chip.claimed` | +%d %s | +%d %s | Booster chip after purchase, e.g. "+3 Hammer". `%d` = count, `%s` = booster name. Needs plural forms. | `offer_booster_chip.gd` |

## Profile, leaderboard and settings

| Key | English | Español | Context | Source |
| --- | --- | --- | --- | --- |
| `profile.title` | EDIT PROFILE | EDITAR PERFIL | Profile modal title. | `profile_menu.tscn` |
| `profile.name_header` | PLAYER NAME | NOMBRE DEL JUGADOR | Header over the name field. | `profile_menu.tscn` |
| `profile.name_placeholder` | Player name | Nombre del jugador | Placeholder inside the empty name field. | `profile_menu.tscn` |
| `profile.edit_name_tooltip` | Edit player name | Editar nombre del jugador | Accessibility tooltip on the pencil button. | `profile_menu.tscn` |
| `profile.avatar_tab` | AVATAR | AVATAR | Tab that shows avatar pictures. | `profile_menu.tscn` |
| `profile.frame_tab` | FRAME | MARCO | Tab that shows decorative frames around the avatar. | `profile_menu.tscn` |
| `profile.unlock.level` | Complete level %d to unlock | Completa el nivel %d para desbloquear | Toast after tapping a locked frame. `%d` = level number. | `profile_menu.gd` |
| `profile.unlock.combo` | Reach a combo of ×%d in any run to unlock | Consigue un combo de ×%d en cualquier partida para desbloquear | Same toast. `%d` = combo size. | `profile_menu.gd` |
| `profile.unlock.weekly_first` | Finish 1st on the Weekly leaderboard to unlock | Queda en primer lugar en el ranking semanal para desbloquear | Same toast for a first-place frame. Today built from two parts; see implementation notes. | `profile_menu.gd` |
| `profile.unlock.weekly_top` | Finish top %d on the Weekly leaderboard to unlock | Queda entre los %d mejores del ranking semanal para desbloquear | Same toast. `%d` = rank cutoff (e.g. 10). | `profile_menu.gd` |
| `leaderboard.title` | LEADERBOARD | RANKING | Leaderboard screen title. | `leaderboard_screen.tscn` |
| `leaderboard.tab.weekly` | Weekly | Semanal | Tab: this week's stars. | `leaderboard_screen.tscn` |
| `leaderboard.tab.country` | Country | País | Tab: all-time stars in the player's country. | `leaderboard_screen.tscn` |
| `leaderboard.tab.world` | World | Mundo | Tab: all-time stars worldwide. | `leaderboard_screen.tscn` |
| `leaderboard.weekly_reset` | Weekly reset in %s | Reinicio semanal en %s | Under the Weekly tab. `%s` = a duration such as "1d 4h". | `leaderboard_screen.gd` |
| `leaderboard.duration.dh` | %dd %dh | %dd %dh | Duration: days and hours. Use local unit abbreviations. | `leaderboard_screen.gd` |
| `leaderboard.duration.hm` | %dh %dm | %dh %dmin | Duration: hours and minutes. | `leaderboard_screen.gd` |
| `leaderboard.duration.m` | %dm | %dmin | Duration: minutes. | `leaderboard_screen.gd` |
| `leaderboard.country_caption` | Country · All-time stars | País · Estrellas totales | Caption under the Country tab. | `leaderboard_screen.gd` |
| `leaderboard.world_caption` | Worldwide · All-time stars | Mundo · Estrellas totales | Caption under the World tab. | `leaderboard_screen.gd` |
| `leaderboard.load_failed` | Could not load leaderboard. | No se pudo cargar el ranking. | Error state (fallback text). | `leaderboard_screen.gd` |
| `leaderboard.default_name` | Player | Jugador | Name shown for a player without one. | `leaderboard_row.gd` |
| `leaderboard.row_tooltip` | Rank %d, %s, %d stars | Puesto %d, %s, %d estrellas | Accessibility text of a row. `%d` = rank, `%s` = player name, `%d` = stars. Needs plural forms. | `leaderboard_row.gd` |
| `leaderboard.reward_tooltip` | %s coin weekly reward | Recompensa semanal: %s monedas | Accessibility text on the coin prize next to top ranks. `%s` = amount. | `leaderboard_rank_reward.gd` |
| `leaderboard.reward.title` | WEEKLY REWARD! | ¡RECOMPENSA SEMANAL! | Title of the dialog shown after a week ends. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.body` | You finished #%d last week and earned %d coins! | ¡La semana pasada quedaste en el puesto #%d y ganaste %d monedas! | Body. `%d` = final rank, `%d` = coins. Needs plural forms. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.ok` | Nice! | ¡Genial! | Button that closes the reward dialog. | `leaderboard_reward_dialog.tscn` |
| `settings.title` | SETTINGS | AJUSTES | Settings modal title (home screen). | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.music` | Music | Música | Toggle label under an icon. Short, about 8 characters. | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.sfx` | SFX | Sonidos | Toggle for sound effects. Use a short local word for "Sounds". | same |
| `settings.vibrate` | Vibrate | Vibración | Toggle for haptic feedback. | same |
| `settings.support` | Support | Ayuda | Opens the Support screen. | `settings_menu.tscn` |
| `settings.language` | Language | Idioma | Opens the language picker. | `settings_menu.tscn`, `language_option_row.tscn` |
| `settings.privacy_policy` | Privacy Policy | Política de privacidad | Opens the privacy policy web page. | `settings_menu.tscn`, `production_main_menu.gd` |
| `settings.privacy_choices` | Privacy Choices | Opciones de privacidad | Same button when the ad consent form must be offered (EU/UK). | `production_main_menu.gd` |
| `settings.diagnostics` | Version %s • Build %d\\nPlatform: %s • User: %s | Versión %s • Compilación %d\\nPlataforma: %s • Usuario: %s | Small footer for support. Values: app version, build number, OS name, short player id. Translating the four labels is optional. | `pause_menu.gd` |
| `language.title` | LANGUAGE | IDIOMA | Language picker title. | `language_selection_modal.gd` |

## Support, account deletion and platform text

### Support screen

| Key | English | Español | Context | Source |
| --- | --- | --- | --- | --- |
| `support.title` | SUPPORT | AYUDA | Support screen title. | `support_screen.tscn` |
| `support.faq_header` | Frequently Asked Questions | Preguntas frecuentes | Section header. | `support_screen.tscn` |
| `support.faq.play.q` | How do I play? | ¿Cómo se juega? | FAQ question (tap to expand). | `support_screen.tscn` |
| `support.faq.play.a` | Move matching goods onto the same shelf. When three identical items are visible together, they clear. Complete the board before time runs out. | Mueve los productos iguales al mismo estante. Cuando tres objetos iguales estén visibles juntos, desaparecerán. Despeja el tablero antes de que se agote el tiempo. | FAQ answer. "Goods" = shop items such as snacks and toys. | `support_screen.tscn` |
| `support.faq.contact.q` | How do I contact support? | ¿Cómo contacto con el equipo de ayuda? | FAQ question. | `support_screen.tscn` |
| `support.faq.contact.a` | Email us at %s. Include a short description, your device platform, and when the problem happened. | Escríbenos a %s. Incluye una breve descripción, la plataforma de tu dispositivo y cuándo ocurrió el problema. | FAQ answer. `%s` = support email address. | `support_screen.gd` |
| `support.faq.contact.action` | Email Support | Contactar por correo | Button that opens a pre-filled email. | `support_screen.tscn` |
| `support.faq.crash.q` | What if the game freezes or crashes? | ¿Qué hago si el juego se bloquea o se cierra? | FAQ question. | `support_screen.tscn` |
| `support.faq.crash.a` | Close and reopen the game first. If it happens again, restart the device and make sure the game is updated. Contact support with the device model, platform version, and what you were doing before the problem. | Primero, cierra y vuelve a abrir el juego. Si vuelve a ocurrir, reinicia el dispositivo y comprueba que el juego esté actualizado. Contacta con el equipo de ayuda e indica el modelo del dispositivo, la versión de la plataforma y qué hacías antes del problema. | FAQ answer. | `support_screen.tscn` |
| `support.faq.sync.q` | How do I sync progress between devices? | ¿Cómo sincronizo mi progreso entre dispositivos? | FAQ question. | `support_screen.tscn` |
| `support.faq.sync.a` | Use the same signed-in platform account on both devices and allow synchronization to finish before playing. If the progress differs, avoid playing on both devices and contact support. | Inicia sesión con la misma cuenta de la plataforma en ambos dispositivos y espera a que termine la sincronización antes de jugar. Si el progreso es distinto, evita jugar en ambos dispositivos y contacta con el equipo de ayuda. | FAQ answer. "Platform account" = Google Play Games / Game Center. | `support_screen.tscn` |
| `support.faq.bad_ad.q` | How do I report a bad ad? | ¿Cómo denuncio un anuncio inapropiado? | FAQ question. | `support_screen.tscn` |
| `support.faq.bad_ad.a` | 1. Close the ad if you can do so safely.\\n2. Take a screenshot of the ad and any advertiser or app name shown.\\n3. Note the approximate time and where the ad appeared in the game.\\n4. Describe why the ad seemed offensive, misleading, or fraudulent.\\n5. Email these details to %s. Do not include passwords or payment information. | 1. Cierra el anuncio si puedes hacerlo de forma segura.\\n2. Haz una captura de pantalla del anuncio y de cualquier nombre de anunciante o aplicación que aparezca.\\n3. Anota la hora aproximada y dónde apareció el anuncio en el juego.\\n4. Explica por qué el anuncio te pareció ofensivo, engañoso o fraudulento.\\n5. Envía estos datos por correo a %s. No incluyas contraseñas ni información de pago. | FAQ answer, a five-step list in one string. `%s` = support email. Keep the numbering and line breaks. | `support_screen.gd` |
| `support.faq.bad_ad.action` | Email Ad Report | Denunciar por correo | Button that opens a pre-filled ad-report email. | `support_screen.tscn` |
| `support.account_header` | Account | Cuenta | Section header above the delete button. | `support_screen.tscn` |
| `support.delete_account` | Delete Account | Eliminar cuenta | Opens account deletion (player has an online account). | `support_screen.gd` |
| `support.delete_game_data` | Delete Game Data | Eliminar datos del juego | Same button when only local data exists. | `support_screen.gd` |
| `support.no_secrets` | Please never send passwords or payment information. | Nunca envíes contraseñas ni información de pago. | Warning at the bottom of the screen. | `support_screen.tscn` |

### Account deletion modal

| Key | English | Español | Context | Source |
| --- | --- | --- | --- | --- |
| `deletion.title.delete_account` | DELETE ACCOUNT | ELIMINAR CUENTA | Title: confirm, in progress and unavailable states. | `account_deletion_modal.gd` |
| `deletion.title.delete_game_data` | DELETE GAME DATA | ELIMINAR DATOS DEL JUEGO | Title for a player who never had an online account. | same |
| `deletion.title.not_confirmed` | NOT CONFIRMED | SIN CONFIRMAR | Title: request sent, answer lost. | same |
| `deletion.title.status_unconfirmed` | STATUS UNCONFIRMED | ESTADO SIN CONFIRMAR | Title: server outcome unknown. | same |
| `deletion.title.finishing_up` | FINISHING UP | FINALIZANDO | Title: local cleanup incomplete. | same |
| `deletion.title.new_game` | NEW GAME | NUEVA PARTIDA | Title while a fresh save is created. | same |
| `deletion.title.status_unknown` | STATUS UNKNOWN | ESTADO DESCONOCIDO | Title: local deletion record unreadable. | same |
| `deletion.title.not_deleted` | NOT DELETED | NO SE ELIMINÓ | Title after a failed attempt. | same |
| `deletion.title.data_deleted` | DATA DELETED | DATOS ELIMINADOS | Title after local data is deleted. | same |
| `deletion.title.accepted` | DELETION ACCEPTED | ELIMINACIÓN ACEPTADA | Title after the server accepts the request. | same |
| `deletion.confirm.headline` | This permanently deletes your account. | Esto elimina tu cuenta de forma permanente. | Confirm step, online account. | same |
| `deletion.confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nIf you sign in again later, you'll start a new account.\\n\\nSome purchase and security records are kept without your name or profile. The rest is removed within 30 days. | Perderás tu progreso, monedas, objetos y perfil. Esta acción no se puede deshacer.\\n\\nSi vuelves a iniciar sesión más adelante, empezarás con una cuenta nueva.\\n\\nSe conservan algunos registros de compras y seguridad sin tu nombre ni perfil. El resto se elimina en un plazo de 30 días. | Confirm step body. Keep the three paragraphs. | same |
| `deletion.confirm.button` | Delete Account | Eliminar cuenta | Red destructive button. | same |
| `deletion.local_confirm.headline` | This deletes your game data on this device. | Esto elimina los datos del juego de este dispositivo. | Confirm step, local-only player. | same |
| `deletion.local_confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nThis game never created an online account for you, so nothing needs to be deleted from our servers. | Perderás tu progreso, monedas, objetos y perfil. Esta acción no se puede deshacer.\\n\\nEste juego nunca creó una cuenta en línea para ti, por lo que no hay nada que eliminar de nuestros servidores. | Body for that step. | same |
| `deletion.local_confirm.button` | Delete Data | Eliminar datos | Red destructive button. | same |
| `deletion.pending_setup.headline` | Your account is still being set up. | Tu cuenta todavía se está creando. | Deletion blocked: first registration not finished. | same |
| `deletion.pending_setup.body` | Connect to the internet and try again in a moment. Nothing was deleted. | Conéctate a internet y vuelve a intentarlo en un momento. No se ha eliminado nada. | Body. | same |
| `deletion.sign_in.headline` | Sign in to the account you want to delete. | Inicia sesión en la cuenta que quieres eliminar. | Deletion blocked: signed out. | same |
| `deletion.sign_in.body` | If you can't sign in, contact support for help. | Si no puedes iniciar sesión, contacta con el equipo de ayuda. | Body. | same |
| `deletion.read_failed.headline` | Your game data couldn't be read. | No se pudieron leer los datos del juego. | Deletion blocked: save unreadable. | same |
| `deletion.read_failed.body` | Restart the game, then try again. Nothing was deleted. | Reinicia el juego y vuelve a intentarlo. No se ha eliminado nada. | Body. | same |
| `deletion.unavailable.headline` | Account deletion isn't available in this version of the game. | La eliminación de cuentas no está disponible en esta versión del juego. | Deletion blocked: feature off. Also a failure headline. | same |
| `deletion.unavailable.body` | Update the game, or contact support for help deleting your account. Nothing was deleted. | Actualiza el juego o contacta con el equipo de ayuda para eliminar tu cuenta. No se ha eliminado nada. | Body. | same |
| `deletion.in_progress.account` | Deleting your account... | Eliminando tu cuenta... | Headline while the request runs. | same |
| `deletion.in_progress.local` | Deleting your game data... | Eliminando los datos del juego... | Same for local-only data. | same |
| `deletion.in_progress.body` | Keep the game open. This only takes a moment. | Mantén el juego abierto. Solo tardará un momento. | Body while deleting. | same |
| `deletion.not_confirmed.headline` | We haven't heard back about your deletion yet. | Todavía no hemos recibido una respuesta sobre tu solicitud de eliminación. | Request sent, answer lost. | same |
| `deletion.not_confirmed.body` | Your request was sent, but the answer didn't arrive. Connect to the internet and try again. The game stays locked until we know the result. | Tu solicitud se envió, pero no llegó la respuesta. Conéctate a internet y vuelve a intentarlo. El juego seguirá bloqueado hasta que sepamos el resultado. | Body. | same |
| `deletion.unconfirmed.headline` | Deletion status unconfirmed | Estado de eliminación sin confirmar | Server outcome unknown. | same |
| `deletion.unconfirmed.body` | We couldn't confirm whether your account was deleted. To keep your data safe, the game stays locked. Contact support and include the reference below. | No pudimos confirmar si se eliminó tu cuenta. Para proteger tus datos, el juego seguirá bloqueado. Contacta con el equipo de ayuda e incluye la referencia que aparece abajo. | Body; a reference code is shown under it. | same |
| `deletion.check_again` | Check Again | Comprobar de nuevo | Asks the server again. | same |
| `deletion.cleanup.headline.local` | Your local game data couldn't be fully deleted yet. | Todavía no se pudieron eliminar todos los datos locales del juego. | Local cleanup incomplete (local-only player). | same |
| `deletion.cleanup.headline.account` | Account deletion accepted; finishing cleanup. | Eliminación de cuenta aceptada; finalizando la limpieza. | Local cleanup incomplete after the server accepted. | same |
| `deletion.cleanup.body` | Some game data couldn't be removed from this device yet. Try again to finish. | Todavía no se pudieron eliminar algunos datos del juego de este dispositivo. Vuelve a intentarlo para terminar. | Body. | same |
| `deletion.new_game.headline` | Starting a new game... | Iniciando una nueva partida... | While a fresh save is created. | same |
| `deletion.new_game.body` | This only takes a moment. | Solo tardará un momento. | Body. | same |
| `deletion.status_unknown.headline` | We couldn't read the deletion status on this device. | No pudimos leer el estado de eliminación en este dispositivo. | Local deletion record unreadable. | same |
| `deletion.status_unknown.body` | To keep your data safe, the game stays locked. Contact support for help. | Para proteger tus datos, el juego seguirá bloqueado. Contacta con el equipo de ayuda. | Body. | same |
| `deletion.fail.offline` | Connect to the internet to delete your account. | Conéctate a internet para eliminar tu cuenta. | Failure headline. | same |
| `deletion.fail.rate_limited` | Too many attempts. Wait a moment, then try again. | Demasiados intentos. Espera un momento y vuelve a intentarlo. | Failure headline. | same |
| `deletion.fail.busy` | Account deletion is busy right now. Try again in a moment. | El servicio de eliminación de cuentas está ocupado. Vuelve a intentarlo en un momento. | Failure headline (server unavailable). | same |
| `deletion.fail.syncing` | The game is still syncing. Try again in a moment. | El juego todavía se está sincronizando. Vuelve a intentarlo en un momento. | Failure headline. | same |
| `deletion.fail.auth` | We couldn't verify your account. Restart the game, then try again. | No pudimos verificar tu cuenta. Reinicia el juego y vuelve a intentarlo. | Failure headline. | same |
| `deletion.fail.update` | Update the game to delete your account. | Actualiza el juego para eliminar tu cuenta. | Failure headline (client too old). | same |
| `deletion.fail.changed` | Your account changed while we were deleting it. Try again. | Tu cuenta cambió mientras la eliminábamos. Vuelve a intentarlo. | Failure headline. | same |
| `deletion.fail.storage` | Your device couldn't save the deletion request. Try again. | Tu dispositivo no pudo guardar la solicitud de eliminación. Vuelve a intentarlo. | Failure headline. | same |
| `deletion.fail.generic` | We couldn't delete your account. Try again later or contact support. | No pudimos eliminar tu cuenta. Inténtalo más tarde o contacta con el equipo de ayuda. | Failure headline (fallback). | same |
| `deletion.fail.local` | Your game data couldn't be deleted. Try again. | No se pudieron eliminar los datos del juego. Vuelve a intentarlo. | Failure headline, local-only player. | same |
| `deletion.fail.body` | Nothing was deleted, and you can keep playing. | No se ha eliminado nada y puedes seguir jugando. | Body for every failure. | same |
| `deletion.done_local.headline` | Your local game data was deleted. | Se eliminaron los datos locales del juego. | Success, local-only player. | same |
| `deletion.done_local.body` | You can start over with a new game. | Puedes empezar de cero con una nueva partida. | Body. | same |
| `deletion.new_game_failed` | The new game couldn't start. Try again. | No se pudo iniciar la nueva partida. Vuelve a intentarlo. | Appended under a success body if the fresh save failed. | same |
| `deletion.accepted.headline` | Your account is no longer accessible. | Ya no puedes acceder a tu cuenta. | Success, online account. | same |
| `deletion.accepted.body` | Your deletion request was accepted. | Tu solicitud de eliminación ha sido aceptada. | Body when no deadline is known. | same |
| `deletion.accepted.body_deadline` | Your deletion request was accepted. Data removal is due by %s. | Tu solicitud de eliminación ha sido aceptada. Los datos se eliminarán a más tardar el %s. | Body. `%s` = a date such as "November 2, 2026". | same |
| `deletion.reference` | Reference: %s | Referencia: %s | Support reference code under the body. `%s` = operation id; never translated. | same |
| `deletion.start_new_game` | Start New Game | Iniciar nueva partida | Button after a successful deletion. | same |

### Platform and system text

| Key | English | Español | Context | Source |
| --- | --- | --- | --- | --- |
| `app.name` | SortingPuzzle | SortingPuzzle | App name under the home-screen icon; today the internal project name. Decide the public name per store first. | `project.godot`, `export_presets.cfg` |
| `support.email.subject` | Sorting Puzzle support request | Solicitud de ayuda de Sorting Puzzle | Subject of the pre-filled support email. | `support_screen.gd` |
| `support.email.body` | Please describe the issue here.\\n\\nDevice/platform:\\nApproximate time:\\n | Describe aquí el problema.\\n\\nDispositivo/plataforma:\\nHora aproximada:\\n | Body template the player fills in. | `support_screen.gd` |
| `support.ad_email.subject` | Sorting Puzzle ad report | Denuncia de anuncio en Sorting Puzzle | Subject of the ad-report email. | `support_screen.gd` |
| `support.ad_email.body` | Please attach a screenshot and complete the details below.\\n\\nApproximate time:\\nAd placement in the game:\\nAdvertiser or app name:\\nWhy the ad should be reviewed:\\n | Adjunta una captura de pantalla y completa los datos siguientes.\\n\\nHora aproximada:\\nUbicación del anuncio en el juego:\\nNombre del anunciante o de la aplicación:\\nMotivo por el que se debe revisar el anuncio:\\n | Body template the player fills in. | `support_screen.gd` |
| `deletion.email.subject` | Sorting Puzzle account deletion | Eliminación de cuenta de Sorting Puzzle | Subject of the deletion help email. | `account_deletion_modal.gd` |
| `deletion.email.body` | Please help me with my account deletion. | Necesito ayuda para eliminar mi cuenta. | First line; followed by `Status:`, `Deletion reference:`, `Server reference:` and `Player ID:` lines. | `account_deletion_modal.gd` |

## Plural variants

For these integer counts, use the singular form for 1 and the plural form for 0 or more than 1. Select the form using the numeric count before formatting it for display. Every variant preserves the original placeholders.

| Key | Singular (1) | Plural (0 or more than 1) | Count |
| --- | --- | --- | --- |
| `chapter.locked_status` | Completa %d nivel más de «%s» para desbloquear | Completa %d niveles más de «%s» para desbloquear | Remaining levels (`%d`) |
| `shelf_unlock.offer_or_clear` | Mira un anuncio para desbloquear este estante ahora o elimina %s trío más. | Mira un anuncio para desbloquear este estante ahora o elimina %s tríos más. | Remaining triples (formatted as `%s`) |
| `starter.coins` | %s MONEDA | %s MONEDAS | Coins (formatted as `%s`) |
| `booster_chip.claimed` | +%d %s | +%d %s | Booster quantity (`%d`); select the corresponding booster-name form |
| `leaderboard.row_tooltip` | Puesto %d, %s, %d estrella | Puesto %d, %s, %d estrellas | Stars (second `%d`, not rank) |
| `leaderboard.reward.body` | ¡La semana pasada quedaste en el puesto #%d y ganaste %d moneda! | ¡La semana pasada quedaste en el puesto #%d y ganaste %d monedas! | Coins (second `%d`, not rank) |

The booster-chip pattern stays `+%d %s` in both forms. Supply a booster name that agrees with the quantity:

| Booster | Singular (1) | Plural (0 or more than 1) |
| --- | --- | --- |
| Hammer | Martillo | Martillos |
| Shuffle | Mezcla | Mezclas |
| Lantern | Linterna | Linternas |
| Freezer | Congelador | Congeladores |

For example, `+1 Martillo` / `+3 Martillos` and `+1 Linterna` / `+3 Linternas`. A fixed singular product name supplied as `%s` cannot produce the correct plural; the quantity-aware name must be selected during any future integration.

The inventory does not mark `leaderboard.reward_tooltip` as plural-sensitive. If a reward of exactly one coin is possible, use `Recompensa semanal: %s moneda` for that case; otherwise use the main-table wording.

## Additional email labels

These four labels are mentioned in the inventory's deletion-email context but have no proposed keys.

| English | Español |
| --- | --- |
| Status: | Estado: |
| Deletion reference: | Referencia de eliminación: |
| Server reference: | Referencia del servidor: |
| Player ID: | ID del jugador: |

## Review notes

- `Máx.` has four characters (target: approximately five for the lives indicator); `PAQUETE` has seven (target: approximately eight for the home badge). `MÁS NIVELES MUY PRONTO` stays within the approximately 24-character home-button target.
- `Ranking` is used consistently for the leaderboard; its seven characters keep the navigation label short.
- The shop offer names are `Paquete inicial` and `Paquete básico`. Their uppercase card forms are `PAQUETE INICIAL` and `PAQUETE BÁSICO`.
- Format a date inserted into `deletion.accepted.body_deadline` in Spanish, for example `2 de noviembre de 2026`. The translation keeps the `%s` placeholder.
- The deletion warnings retain permanent loss, the inability to undo deletion, unnamed retained purchase and security records, the 30-day removal period, locked states, and explicit statements that nothing was deleted.
- Longer labels such as `POTENCIADORES INCLUIDOS`, `ELIMINAR DATOS DEL JUEGO`, and `Ver anuncio · Desbloquear estante` will need layout review if integrated. This document makes no claim about their rendered fit.

Coverage checked against the supplied inventory: **251 distinct keys**, with matching placeholder sequences and escaped line breaks. Singular and plural variants have also been checked for placeholder preservation.
