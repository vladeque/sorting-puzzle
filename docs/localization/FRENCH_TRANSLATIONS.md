# Sorting Puzzle — French Translations

Locale: `fr` · Prepared October 6, 2026

French translations of all **251 inventory entries**, using standard French and friendly, polite address (`vous`).

Original English, suggested keys, context, and source references are retained for review. The six entries marked as plural-sensitive use plural wording in the main tables; their singular and plural forms appear in the appendix.

Placeholders (`%d`, `%s`), uppercase titles, symbols, and the inventory’s escaped line-break notation are preserved. Each `\\n` marker represents one forced line break; repeated markers separate paragraphs. `AD`, `OFF`, and the current app name `SortingPuzzle` remain unchanged. Discount tags retain their percentage followed by `OFF`. Email addresses, player names, reference codes, and store prices supplied through placeholders remain unchanged.

This is a translation document. The strings have been checked against the supplied inventory; they have not been integrated into the game or verified in rendered screens.

## Terminology

| English | Français |
| --- | --- |
| Level | Niveau |
| Chapter | Chapitre |
| Shelf | Étagère |
| Item / goods | Objet / objets |
| Match / triple / set | Trio (trois objets identiques) |
| Combo | Combo |
| Booster / ability | Booster |
| Hammer | Marteau |
| Shuffle | Mélange |
| Lantern | Lanterne |
| Freezer | Gel |
| Dispenser | Distributeur |
| Coins | Pièces |
| Stars | Étoiles |
| Lives | Vies |
| Reward chest | Coffre |
| Bundle | Pack |
| Leaderboard | Classement |
| Support | Assistance |

## Shared buttons, main menu and chapters

Shared buttons appear on several screens and need one translation each, except where the context says the meaning differs. Keys are suggestions for the future translation table.

| Key | English | Français | Context | Source |
| --- | --- | --- | --- | --- |
| `common.play` | Play | Jouer | Button that starts the chapter's next level on a chapter card. | `chapter_cover_card.gd` |
| `common.continue` | Continue | Continuer | Button that moves on: closes the level-complete screen, the purchase dialog and the reward chest menu; on a chapter card it resumes a chapter already started. | `level_completion_screen.tscn`, `shop_purchase_dialog`, `reward_chest_menu.tscn`, `chapter_cover_card.gd` |
| `common.resume` | Continue | Reprendre | Button on Pause and on the leave confirmation that returns to the running level ("keep playing"). Separate key: some languages use a different verb than for "move on". | `pause_menu.tscn`, `leave_confirmation_menu.tscn` |
| `common.try_again` | Try Again | Réessayer | Retries a failed action (ad, purchase, account deletion). | ad modals, `account_deletion_modal.gd`, `starter_bundle_offer_modal.gd` |
| `common.close` | Close | Fermer | Closes a dialog without doing anything. | `account_deletion_modal.gd` |
| `common.cancel` | Cancel | Annuler | Backs out of account deletion; nothing is deleted. | `account_deletion_modal.tscn` |
| `common.got_it` | Got it | Compris | Acknowledges an info dialog (ability description, lives already full). | `out_of_lives_menu.tscn`, `shop_screen.gd` |
| `common.get_help` | Get Help | Obtenir de l’aide | Opens a pre-filled email to support. | `account_deletion_modal.gd` |
| `common.save` | SAVE | ENREGISTRER | Confirms profile edits or the chosen language. All caps by design. | `profile_menu`, `language_selection_modal.tscn` |
| `common.loading` | Loading… | Chargement… | Shown while the Shop or Leaderboard loads its data. | `destination_status_panel.tscn` |
| `common.retry_load` | Retry | Réessayer | Reloads the Shop or Leaderboard after a load error. Not the same as replaying a level. | `destination_status_panel.tscn` |
| `menu.level_button` | LEVEL %d | NIVEAU %d | Big play button on the home screen. `%d` = level number inside the current chapter. | `production_main_menu.gd` |
| `menu.more_levels_coming_soon` | MORE LEVELS COMING SOON | NOUVEAUX NIVEAUX BIENTÔT | Home play button (disabled) after every level of the chapter is finished. Must fit the button, about 24 characters. | `production_main_menu.gd` |
| `menu.coming_soon` | COMING SOON | BIENTÔT | Home play button (disabled) when the chapter has no levels yet. | `production_main_menu.gd` |
| `menu.lives_full` | Full | Max | Top bar, next to the heart, when lives are at maximum; replaces the refill timer. About 5 characters. | `production_main_menu.gd`, `main_menu_top_status.tscn` |
| `menu.starter_badge` | BUNDLE | PACK | Small badge on the home screen that opens the Starter Bundle offer. About 8 characters. Russian: НАБОР. The full offer title remains Starter Bundle / Стартовый набор. | `main_menu_starter_bundle_badge.tscn` |
| `nav.shop` | Shop | Boutique | Bottom navigation tab. About 10 characters. | `main_menu_bottom_navigation.tscn` |
| `nav.home` | Home | Accueil | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `nav.leaderboard` | Leaderboard | Classement | Bottom navigation tab. | `main_menu_bottom_navigation.tscn` |
| `chapter.button` | CHAPTER %d | CHAPITRE %d | Home button that opens chapter selection. `%d` = chapter number. | `main_menu_chapter_button.gd` |
| `chapter.button_tooltip` | Choose Chapter %d: %s | Choisir le chapitre %d : %s | Accessibility tooltip of that button. `%d` = chapter number, `%s` = chapter title. | `main_menu_chapter_button.gd` |
| `chapter.screen_title` | CHAPTERS | CHAPITRES | Title of the chapter selection screen. | `chapter_selection_screen.tscn` |
| `chapter.eyebrow` | CHAPTER %d | CHAPITRE %d | Small label above the chapter name on its card. | `chapter_cover_card.gd` |
| `chapter.title.chapter_01` | Grocery Town | Quartier des épiceries | Name of chapter 1 (a grocery-store theme). | `configs/chapters.json` |
| `chapter.title.chapter_02` | Candy Corner | Coin des bonbons | Name of chapter 2 (a candy-shop theme). | `configs/chapters.json` |
| `chapter.locked_status` | Complete %d more %s levels to unlock | Terminez encore %d niveaux de « %s » pour débloquer | Locked chapter card. `%d` = levels still needed, `%s` = previous chapter's name. Needs plural forms. | `chapter_cover_card.gd` |
| `chapter.unlock_progress` | Unlock progress | Déblocage | Header over the progress bar on a locked chapter. | `chapter_cover_card.gd` |
| `chapter.current_progress` | Current progress | Progression actuelle | Header over the progress bar on an unlocked chapter. | `chapter_cover_card.gd` |
| `chapter.locked` | Locked | Verrouillé | Disabled button on a locked chapter card. | `chapter_cover_card.gd` |
| `chapter.no_levels_status` | New levels are coming soon | De nouveaux niveaux arrivent bientôt | Card message for a chapter with no levels yet. | `chapter_cover_card.gd` |
| `chapter.coming_soon` | Coming Soon | Bientôt | Disabled button on that card. | `chapter_cover_card.gd` |

## Gameplay: HUD, level screens and results

These strings show during a level, mostly in modal titles (all caps, short) and action buttons. A "triple" or "match" is three identical items on one shelf, which clears them.

| Key | English | Français | Context | Source |
| --- | --- | --- | --- | --- |
| `hud.level` | LEVEL %d | NIVEAU %d | Top HUD during play. `%d` = level number inside the chapter. | `level.gd` |
| `hud.combo` | COMBO ×%d | COMBO ×%d | HUD counter for consecutive quick matches. `%d` = combo size; keep the × sign. | `level_top_hud.gd` |
| `hud.ability_tooltip.hammer` | Hammer -- clears a matching triple | Marteau -- élimine un trio d’objets identiques | Accessibility tooltip on the Hammer booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.shuffle` | Shuffle -- reshuffles unlocked items | Mélange -- réorganise les objets déverrouillés | Tooltip on the Shuffle booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.lantern` | Lantern -- highlights a matchable triple | Lanterne -- met en évidence un trio à former | Tooltip on the Lantern booster button. | `ability_bar.tscn` |
| `hud.ability_tooltip.freezer` | Freezer -- pauses the countdown timer | Gel -- met le compte à rebours en pause | Tooltip on the Freezer booster button. | `ability_bar.tscn` |
| `hud.seconds_short` | %ds | %d s | Countdown on an active Lantern or Freezer booster, e.g. "15s". `%d` = seconds; use the local short unit. | `ability_bar.gd` |
| `tip.tap_dispenser` | Tap a dispenser to throw items onto the shelves! | Touchez un distributeur pour envoyer des objets sur les étagères ! | Tutorial bubble on level 10, where dispensers (machines that throw items onto shelves) first appear. | `configs/gameplay_tips.json` |
| `pause.title` | PAUSE | PAUSE | Title of the in-level pause modal. | `pause_menu.gd` |
| `pause.leave` | Leave | Quitter | Pause button that quits the level (asks for confirmation next). | `pause_menu.tscn` |
| `leave.title` | LEAVING THE LEVEL | QUITTER LE NIVEAU | Title of the leave confirmation. | `leave_confirmation_menu.gd` |
| `leave.you_will_lose` | You will lose: | Vous perdrez : | Followed by icons showing the stars earned this run and one life. Keep the colon (or local equivalent). | `leave_confirmation_menu.tscn` |
| `leave.confirm` | Leave | Quitter | Confirms quitting the level and losing that progress. | `leave_confirmation_menu.tscn` |
| `timeup.title` | TIME'S UP | TEMPS ÉCOULÉ | Title when the level timer reaches zero. | `time_up_extension_modal.gd` |
| `timeup.offer` | Add one minute and keep sorting! | Ajoutez une minute et continuez à trier ! | Offer to extend the timer by 60 seconds for coins or an ad. | `time_up_extension_modal.tscn` |
| `timeup.used` | Used | Utilisé | Shown on the coin price or ad button when that extension was already used this level. | `time_up_extension_modal.gd` |
| `ability_purchase.title` | USE ABILITY | UTILISER UN BOOSTER | Title of the modal that buys and immediately uses one booster when the player has none. | `ability_purchase_menu.gd` |
| `shelf_unlock.title` | UNLOCK SHELF | DÉBLOQUER L’ÉTAGÈRE | Title of the modal for a locked shelf. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer` | Watch one ad to unlock this shelf now. | Regardez une publicité pour débloquer cette étagère maintenant. | Body when no other way to unlock remains. | `shelf_unlock_menu.gd` |
| `shelf_unlock.offer_or_clear` | Watch one ad to unlock this shelf now, or clear %s more. | Regardez une publicité pour débloquer cette étagère maintenant, ou éliminez encore %s trios. | Body when the shelf also unlocks by itself after more matches. `%s` = matches still needed. Needs plural forms. | `shelf_unlock_menu.gd` |
| `shelf_unlock.button` | Watch Ad · Unlock Shelf | Voir une pub · Débloquer | Ad button in that modal. | `shelf_unlock_menu.gd` |
| `shelf_unlock.ad_unavailable` | Ad unavailable. This shelf stays locked. | Publicité indisponible. Cette étagère reste verrouillée. | Status line when no ad could be shown. | `shelf_unlock_menu.gd` |
| `complete.title` | GREAT JOB! | BRAVO ! | Title of the level-complete screen, above the stars earned. | `level_completion_screen.gd` |
| `failed.title` | LEVEL %d | NIVEAU %d | Title of the level-failed screen. `%d` = level number. | `level_failure_screen.gd` |
| `failed.headline` | LEVEL FAILED | NIVEAU RATÉ | Banner on the level-failed screen. | `level_failure_screen.tscn` |
| `failed.retry` | Retry | Rejouer | Replays the same level. | `level_failure_screen.tscn` |

Combo praise pops up above a match during a combo; each word is stronger than the one before, so keep the escalation. The label shrinks its font for long words, but one or two words is the limit.

| Key | English | Français | Shown at |
| --- | --- | --- | --- |
| `combo.praise.2` | Cool | Cool | Combo ×2 |
| `combo.praise.3` | Great | Super | ×3 |
| `combo.praise.4` | Awesome | Génial | ×4 |
| `combo.praise.5` | Amazing | Formidable | ×5 |
| `combo.praise.6` | Fantastic | Fantastique | ×6 |
| `combo.praise.7` | Incredible | Incroyable | ×7 |
| `combo.praise.8` | Spectacular | Spectaculaire | ×8 |
| `combo.praise.9` | Unstoppable | Inarrêtable | ×9 |
| `combo.praise.10` | Legendary | Épique | ×10 |
| `combo.praise.11` | Epic | Légendaire | ×11 |
| `combo.praise.12` | Brilliant | Extraordinaire | ×12 |
| `combo.praise.13` | Masterful | Magistral | ×13 |
| `combo.praise.14` | Supreme | Suprême | ×14 |
| `combo.praise.15` | Phenomenal | Phénoménal | ×15 |
| `combo.praise.16` | Mythic | Mythique | ×16 |
| `combo.praise.17` | Majestic | Majestueux | ×17 |
| `combo.praise.18` | Radiant | Éclatant | ×18 |
| `combo.praise.19` | Divine | Divin | ×19 |
| `combo.praise.20` | Transcendent | Transcendant | ×20 and above |

Source: `COMBO_PRAISE_WORDS` in `level.gd`.

## Boosters, ads, lives, rewards and shop

The four boosters (also called abilities in code) are product names: pick one translation per language and reuse it everywhere, including the tooltips in the gameplay section.

| Key | English | Français | Context | Source |
| --- | --- | --- | --- | --- |
| `ability.hammer.name` | Hammer | Marteau | Booster that smashes away one matching set. | `reward_reveal_row.tscn`, `starter_bundle_offer_modal.tscn`, `shop_screen.gd` |
| `ability.shuffle.name` | Shuffle | Mélange | Booster that rearranges items. | same |
| `ability.lantern.name` | Lantern | Lanterne | Booster that lights up a set the player can match (internal id `highlight`). | same |
| `ability.freezer.name` | Freezer | Gel | Booster that stops the level timer. | same |
| `ability.hammer.description` | Instantly clears one matching set of items off the shelves. | Élimine instantanément un trio d’objets identiques des étagères. | Shop info dialog body after tapping the booster icon. | `shop_screen.gd` |
| `ability.shuffle.description` | Shuffles shelf items into new spots to help you find a match. | Déplace les objets des étagères pour vous aider à former un trio. | Same dialog. | `shop_screen.gd` |
| `ability.lantern.description` | Highlights a matching triple you can clear for 15 seconds. | Met en évidence pendant 15 secondes un trio d’objets identiques que vous pouvez éliminer. | Same dialog. Keep the number in sync with the game config. | `shop_screen.gd` |
| `ability.freezer.description` | Freezes the level timer for 30 seconds. | Gèle le compte à rebours du niveau pendant 30 secondes. | Same dialog. | `shop_screen.gd` |
| `ad.watch` | Watch Ad | Voir une pub | Button that plays a rewarded video ad. | ad modals, `out_of_lives_menu`, `ability_purchase_menu.tscn` |
| `ad.loading` | Loading... | Chargement… | Ad button while the ad loads. | ad modals |
| `ad.verifying` | Verifying... | Vérification… | Ad button while the server confirms the reward. | ad modals |
| `ad.verify_reward` | Verify Reward | Vérifier la récompense | Ad button to re-check a reward the server has not confirmed yet. | ad modals |
| `ad.reward_pending` | Reward verification is still pending. | La vérification de la récompense est toujours en attente. | Status line under that button. | `out_of_lives_menu.gd`, `shelf_unlock_menu.gd` |
| `ad.unavailable_retry` | Ad unavailable. Please try again. | Publicité indisponible. Veuillez réessayer. | Status line when no ad could be shown. | `out_of_lives_menu` |
| `ad.watch_unavailable` | Watch Ad\\nUnavailable | Voir une pub\\nIndisponible | Two-line disabled ad button (time-up modal). Keep the line break. | `time_up_extension_modal.gd` |
| `ad.watch_coming_soon` | Watch Ad\\nComing Soon | Voir une pub\\nBientôt | Two-line disabled ad button before ads launch. | `time_up_extension_modal.tscn` |
| `ad.badge` | AD | AD | Tiny badge on a locked shelf that an ad can open. Do not translate: keep AD exactly in every language. | `shelf_lock_overlay.tscn`, `shelf_unlock_menu.tscn` |
| `lives.title.out` | OUT OF LIVES | PLUS DE VIES | Lives modal title at 0 lives. | `out_of_lives_menu.gd` |
| `lives.title.get_more` | GET MORE LIVES | OBTENIR DES VIES | Lives modal title with some lives left. | `out_of_lives_menu.gd` |
| `lives.title.full` | LIVES FULL | VIES AU MAXIMUM | Lives modal title at maximum lives. | `out_of_lives_menu.gd` |
| `lives.next_in` | NEXT LIFE IN | PROCHAINE VIE DANS | Label above the refill countdown (mm:ss). | `out_of_lives_menu.tscn` |
| `lives.full_body` | Your lives are full! Play a level to spend them. | Vos vies sont au maximum ! Jouez un niveau pour les utiliser. | Body of the lives modal at maximum. | `out_of_lives_menu.tscn` |
| `chest.title` | CHEST REWARDS | RÉCOMPENSES DU COFFRE | Title of the reward chest modal. | `reward_chest_menu.tscn` |
| `chest.progress_hint` | Collect stars to unlock a chest and claim your reward | Collectez des étoiles pour débloquer un coffre et récupérer votre récompense | Under the star progress bar (e.g. 12/30). | `reward_chest_menu.tscn` |
| `chest.ready` | A REWARD CHEST AWAITS! | UN COFFRE VOUS ATTEND ! | Banner when the chest is full and can be opened. | `reward_chest_menu.tscn` |
| `chest.tap_to_open` | Tap to open | Touchez pour ouvrir | Prompt under the closed chest in the opening animation. | `reward_chest_open_ceremony.tscn` |
| `purchase.tap_to_collect` | Tap to collect | Touchez pour récupérer | Prompt to collect purchased rewards. | `purchase_reward_sequence.tscn` |
| `purchase.complete` | PURCHASE COMPLETE | ACHAT EFFECTUÉ | Banner after a successful purchase. | `purchase_reward_sequence.gd` |
| `shop.title` | SHOP | BOUTIQUE | Shop screen title. | `shop_screen.tscn` |
| `shop.section.bundles` | SPECIAL BUNDLES | PACKS SPÉCIAUX | Section header. | `shop_screen.tscn` |
| `shop.section.coins` | COINS | PIÈCES | Section header for coin packs. | `shop_screen.tscn` |
| `shop.offer.starter_bundle` | Starter Bundle | Pack de départ | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.offer.basic_bundle` | Basic Bundle | Pack de base | Bundle name; shown in caps on its card. | `configs/shop_catalog.json` |
| `shop.tag.best_value` | BEST VALUE | MEILLEURE OFFRE | Ribbon on the best coin pack. | `configs/shop_catalog.json` |
| `shop.discount_off` | OFF | OFF | Second line of the discount badge under "67%". Do not translate: keep the complete 67% OFF tag unchanged in every language; the numeric percentage can vary by offer. | `shop_bundle_card.tscn`, `starter_bundle_offer_modal.tscn` |
| `shop.ability_hint` | Tap an ability to see what it does | Touchez un booster pour découvrir son effet | Hint under a bundle's booster icons. | `shop_bundle_card.tscn` |
| `shop.purchasing` | Purchasing… | Achat en cours… | Buy button while a purchase is in progress. | shop cards, `production_main_menu.gd` |
| `shop.no_offers` | No shop offers are available for this region. | Aucune offre n’est disponible dans cette région. | Shop error state. | `shop_screen.gd` |
| `shop.load_failed` | Could not load the shop. | Impossible de charger la boutique. | Shop error state (fallback text). | `shop_screen.gd` |
| `shop.error.title.purchase` | Purchase unavailable | Achat indisponible | Error dialog title when buying failed. | `shop_screen.gd` |
| `shop.error.title.reward` | Reward error | Erreur de récompense | Error dialog title when payment went through but rewards were not granted. | `shop_screen.gd` |
| `shop.error.purchase_failed` | The purchase could not be completed. | L’achat n’a pas pu être effectué. | Error dialog body (fallback). | `shop_screen.gd`, `production_main_menu.gd` |
| `shop.error.grant_failed` | The purchased rewards could not be granted. | Les récompenses achetées n’ont pas pu être attribuées. | Error dialog body. | `store/shop_purchase_flow.gd` |
| `shop.error.offer_unavailable` | This shop offer is unavailable. | Cette offre de la boutique est indisponible. | Error dialog body. | `store/store_service.gd` |
| `shop.error.already_bought` | This one-time shop offer has already been purchased. | Cette offre ne peut être achetée qu’une fois et vous l’avez déjà achetée. | Error dialog body. | `store/store_service.gd` |
| `starter.title` | STARTER BUNDLE | PACK DE DÉPART | Starter offer modal title. | `starter_bundle_offer_modal.gd` |
| `starter.one_time` | ONE-TIME OFFER | OFFRE UNIQUE | Ribbon on the starter offer. | `starter_bundle_offer_modal.tscn` |
| `starter.boosters_included` | BOOSTERS INCLUDED | BOOSTERS INCLUS | Header over the four booster chips. | `starter_bundle_offer_modal.tscn` |
| `starter.coins` | %s COINS | %s PIÈCES | Ribbon over the coin art. `%s` = formatted amount, e.g. "1,000". Needs plural forms. | `starter_bundle_offer_modal.gd` |
| `starter.buy_for` | Buy for %s | Acheter pour %s | Buy button. `%s` = store price, e.g. "$4.99". | `starter_bundle_offer_modal.gd` |
| `starter.checking` | Checking offer… | Vérification de l’offre… | Status while the store confirms the offer. | `production_main_menu.gd` |
| `starter.checking_short` | Checking… | Vérification… | Buy button during that check. | `starter_bundle_offer_modal.gd` |
| `starter.no_longer_available` | This offer is no longer available. | Cette offre n’est plus disponible. | Error status in the starter modal. | `production_main_menu.gd` |
| `starter.unavailable` | Unavailable | Indisponible | Disabled buy button after a non-retryable error. | `starter_bundle_offer_modal.gd` |
| `booster_chip.claimed` | +%d %s | +%d × %s | Booster chip after purchase, e.g. "+3 Hammer". `%d` = count, `%s` = booster name. Needs plural forms. | `offer_booster_chip.gd` |

## Profile, leaderboard and settings

Language names in the language picker stay in their own language (English, Español, 日本語…) and are never translated.

| Key | English | Français | Context | Source |
| --- | --- | --- | --- | --- |
| `profile.title` | EDIT PROFILE | MODIFIER LE PROFIL | Profile modal title. | `profile_menu.tscn` |
| `profile.name_header` | PLAYER NAME | NOM DU JOUEUR | Header over the name field. | `profile_menu.tscn` |
| `profile.name_placeholder` | Player name | Nom du joueur | Placeholder inside the empty name field. | `profile_menu.tscn` |
| `profile.edit_name_tooltip` | Edit player name | Modifier le nom du joueur | Accessibility tooltip on the pencil button. | `profile_menu.tscn` |
| `profile.avatar_tab` | AVATAR | AVATAR | Tab that shows avatar pictures. | `profile_menu.tscn` |
| `profile.frame_tab` | FRAME | CADRE | Tab that shows decorative frames around the avatar. | `profile_menu.tscn` |
| `profile.unlock.level` | Complete level %d to unlock | Terminez le niveau %d pour débloquer | Toast after tapping a locked frame. `%d` = level number. | `profile_menu.gd` |
| `profile.unlock.combo` | Reach a combo of ×%d in any run to unlock | Atteignez un combo de ×%d dans une partie pour débloquer | Same toast. `%d` = combo size. | `profile_menu.gd` |
| `profile.unlock.weekly_first` | Finish 1st on the Weekly leaderboard to unlock | Obtenez la première place du classement hebdomadaire pour débloquer | Same toast for a first-place frame. Today built from two parts; see implementation notes. | `profile_menu.gd` |
| `profile.unlock.weekly_top` | Finish top %d on the Weekly leaderboard to unlock | Terminez parmi les %d premiers du classement hebdomadaire pour débloquer | Same toast. `%d` = rank cutoff (e.g. 10). | `profile_menu.gd` |
| `leaderboard.title` | LEADERBOARD | CLASSEMENT | Leaderboard screen title. | `leaderboard_screen.tscn` |
| `leaderboard.tab.weekly` | Weekly | Semaine | Tab: this week's stars. | `leaderboard_screen.tscn` |
| `leaderboard.tab.country` | Country | Pays | Tab: all-time stars in the player's country. | `leaderboard_screen.tscn` |
| `leaderboard.tab.world` | World | Monde | Tab: all-time stars worldwide. | `leaderboard_screen.tscn` |
| `leaderboard.weekly_reset` | Weekly reset in %s | Remise à zéro dans %s | Under the Weekly tab. `%s` = a duration such as "1d 4h". | `leaderboard_screen.gd` |
| `leaderboard.duration.dh` | %dd %dh | %d j %d h | Duration: days and hours. Use local unit abbreviations. | `leaderboard_screen.gd` |
| `leaderboard.duration.hm` | %dh %dm | %d h %d min | Duration: hours and minutes. | `leaderboard_screen.gd` |
| `leaderboard.duration.m` | %dm | %d min | Duration: minutes. | `leaderboard_screen.gd` |
| `leaderboard.country_caption` | Country · All-time stars | Pays · Total des étoiles | Caption under the Country tab. | `leaderboard_screen.gd` |
| `leaderboard.world_caption` | Worldwide · All-time stars | Monde · Total des étoiles | Caption under the World tab. | `leaderboard_screen.gd` |
| `leaderboard.load_failed` | Could not load leaderboard. | Impossible de charger le classement. | Error state (fallback text). | `leaderboard_screen.gd` |
| `leaderboard.default_name` | Player | Joueur | Name shown for a player without one. | `leaderboard_row.gd` |
| `leaderboard.row_tooltip` | Rank %d, %s, %d stars | Rang %d, %s, %d étoiles | Accessibility text of a row. `%d` = rank, `%s` = player name, `%d` = stars. Needs plural forms. | `leaderboard_row.gd` |
| `leaderboard.reward_tooltip` | %s coin weekly reward | Récompense hebdomadaire en pièces : %s | Accessibility text on the coin prize next to top ranks. `%s` = amount. | `leaderboard_rank_reward.gd` |
| `leaderboard.reward.title` | WEEKLY REWARD! | RÉCOMPENSE HEBDOMADAIRE ! | Title of the dialog shown after a week ends. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.body` | You finished #%d last week and earned %d coins! | Vous avez fini n° %d la semaine dernière et gagné %d pièces ! | Body. `%d` = final rank, `%d` = coins. Needs plural forms. | `leaderboard_reward_dialog.gd` |
| `leaderboard.reward.ok` | Nice! | Super ! | Button that closes the reward dialog. | `leaderboard_reward_dialog.tscn` |
| `settings.title` | SETTINGS | PARAMÈTRES | Settings modal title (home screen). | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.music` | Music | Musique | Toggle label under an icon. Short, about 8 characters. | `settings_menu.tscn`, `pause_menu.tscn` |
| `settings.sfx` | SFX | Sons | Toggle for sound effects. Use a short local word for "Sounds". | same |
| `settings.vibrate` | Vibrate | Vibrations | Toggle for haptic feedback. | same |
| `settings.support` | Support | Assistance | Opens the Support screen. | `settings_menu.tscn` |
| `settings.language` | Language | Langue | Opens the language picker. | `settings_menu.tscn`, `language_option_row.tscn` |
| `settings.privacy_policy` | Privacy Policy | Politique de confidentialité | Opens the privacy policy web page. | `settings_menu.tscn`, `production_main_menu.gd` |
| `settings.privacy_choices` | Privacy Choices | Options de confidentialité | Same button when the ad consent form must be offered (EU/UK). | `production_main_menu.gd` |
| `settings.diagnostics` | Version %s • Build %d\\nPlatform: %s • User: %s | Version %s • Build %d\\nPlateforme : %s • Utilisateur : %s | Small footer for support. Values: app version, build number, OS name, short player id. Translating the four labels is optional. | `pause_menu.gd` |
| `language.title` | LANGUAGE | LANGUE | Language picker title. | `language_selection_modal.gd` |

## Support, account deletion and platform text

Support and deletion copy is legal-adjacent: translate meaning exactly, keep "Nothing was deleted" and "You can't undo this" unambiguous, and do not soften the warnings.

### Support screen

| Key | English | Français | Context | Source |
| --- | --- | --- | --- | --- |
| `support.title` | SUPPORT | ASSISTANCE | Support screen title. | `support_screen.tscn` |
| `support.faq_header` | Frequently Asked Questions | Questions fréquentes | Section header. | `support_screen.tscn` |
| `support.faq.play.q` | How do I play? | Comment jouer ? | FAQ question (tap to expand). | `support_screen.tscn` |
| `support.faq.play.a` | Move matching goods onto the same shelf. When three identical items are visible together, they clear. Complete the board before time runs out. | Déplacez les objets identiques sur la même étagère. Lorsque trois objets identiques sont visibles ensemble, ils disparaissent. Videz toutes les étagères avant la fin du temps imparti. | FAQ answer. "Goods" = shop items such as snacks and toys. | `support_screen.tscn` |
| `support.faq.contact.q` | How do I contact support? | Comment contacter l’assistance ? | FAQ question. | `support_screen.tscn` |
| `support.faq.contact.a` | Email us at %s. Include a short description, your device platform, and when the problem happened. | Écrivez-nous à %s. Indiquez brièvement le problème, la plateforme de votre appareil et le moment où le problème est survenu. | FAQ answer. `%s` = support email address. | `support_screen.gd` |
| `support.faq.contact.action` | Email Support | Écrire à l’assistance | Button that opens a pre-filled email. | `support_screen.tscn` |
| `support.faq.crash.q` | What if the game freezes or crashes? | Que faire si le jeu se bloque ou plante ? | FAQ question. | `support_screen.tscn` |
| `support.faq.crash.a` | Close and reopen the game first. If it happens again, restart the device and make sure the game is updated. Contact support with the device model, platform version, and what you were doing before the problem. | Fermez d’abord le jeu, puis rouvrez-le. Si le problème se reproduit, redémarrez votre appareil et vérifiez que le jeu est à jour. Contactez l’assistance en indiquant le modèle de l’appareil, la version de la plateforme et ce que vous faisiez avant le problème. | FAQ answer. | `support_screen.tscn` |
| `support.faq.sync.q` | How do I sync progress between devices? | Comment synchroniser ma progression entre appareils ? | FAQ question. | `support_screen.tscn` |
| `support.faq.sync.a` | Use the same signed-in platform account on both devices and allow synchronization to finish before playing. If the progress differs, avoid playing on both devices and contact support. | Connectez-vous au même compte de plateforme sur les deux appareils et attendez la fin de la synchronisation avant de jouer. Si la progression diffère, évitez de jouer sur les deux appareils et contactez l’assistance. | FAQ answer. "Platform account" = Google Play Games / Game Center. | `support_screen.tscn` |
| `support.faq.bad_ad.q` | How do I report a bad ad? | Comment signaler une publicité inappropriée ? | FAQ question. | `support_screen.tscn` |
| `support.faq.bad_ad.a` | 1. Close the ad if you can do so safely.\\n2. Take a screenshot of the ad and any advertiser or app name shown.\\n3. Note the approximate time and where the ad appeared in the game.\\n4. Describe why the ad seemed offensive, misleading, or fraudulent.\\n5. Email these details to %s. Do not include passwords or payment information. | 1. Fermez la publicité si vous pouvez le faire sans risque.\\n2. Faites une capture d’écran de la publicité et de tout nom d’annonceur ou d’application affiché.\\n3. Notez l’heure approximative et l’endroit où la publicité est apparue dans le jeu.\\n4. Expliquez pourquoi la publicité vous a semblé choquante, trompeuse ou frauduleuse.\\n5. Envoyez ces informations par e-mail à %s. N’incluez aucun mot de passe ni aucune information de paiement. | FAQ answer, a five-step list in one string. `%s` = support email. Keep the numbering and line breaks. | `support_screen.gd` |
| `support.faq.bad_ad.action` | Email Ad Report | Signaler une pub par e-mail | Button that opens a pre-filled ad-report email. | `support_screen.tscn` |
| `support.account_header` | Account | Compte | Section header above the delete button. | `support_screen.tscn` |
| `support.delete_account` | Delete Account | Supprimer le compte | Opens account deletion (player has an online account). | `support_screen.gd` |
| `support.delete_game_data` | Delete Game Data | Supprimer les données du jeu | Same button when only local data exists. | `support_screen.gd` |
| `support.no_secrets` | Please never send passwords or payment information. | N’envoyez jamais de mots de passe ni d’informations de paiement. | Warning at the bottom of the screen. | `support_screen.tscn` |

### Account deletion modal

One modal switches between states; each state has a title (caps), a headline, a body and up to two buttons.

| Key | English | Français | Context | Source |
| --- | --- | --- | --- | --- |
| `deletion.title.delete_account` | DELETE ACCOUNT | SUPPRIMER LE COMPTE | Title: confirm, in progress and unavailable states. | `account_deletion_modal.gd` |
| `deletion.title.delete_game_data` | DELETE GAME DATA | SUPPRIMER LES DONNÉES DU JEU | Title for a player who never had an online account. | same |
| `deletion.title.not_confirmed` | NOT CONFIRMED | NON CONFIRMÉ | Title: request sent, answer lost. | same |
| `deletion.title.status_unconfirmed` | STATUS UNCONFIRMED | STATUT NON CONFIRMÉ | Title: server outcome unknown. | same |
| `deletion.title.finishing_up` | FINISHING UP | FINALISATION | Title: local cleanup incomplete. | same |
| `deletion.title.new_game` | NEW GAME | NOUVELLE PARTIE | Title while a fresh save is created. | same |
| `deletion.title.status_unknown` | STATUS UNKNOWN | STATUT INCONNU | Title: local deletion record unreadable. | same |
| `deletion.title.not_deleted` | NOT DELETED | NON SUPPRIMÉ | Title after a failed attempt. | same |
| `deletion.title.data_deleted` | DATA DELETED | DONNÉES SUPPRIMÉES | Title after local data is deleted. | same |
| `deletion.title.accepted` | DELETION ACCEPTED | SUPPRESSION ACCEPTÉE | Title after the server accepts the request. | same |
| `deletion.confirm.headline` | This permanently deletes your account. | Cette action supprime définitivement votre compte. | Confirm step, online account. | same |
| `deletion.confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nIf you sign in again later, you'll start a new account.\\n\\nSome purchase and security records are kept without your name or profile. The rest is removed within 30 days. | Votre progression, vos pièces, vos objets et votre profil seront perdus. Cette action est irréversible.\\n\\nSi vous vous reconnectez plus tard, un nouveau compte sera créé.\\n\\nCertaines données liées aux achats et à la sécurité sont conservées sans votre nom ni votre profil. Les autres données sont supprimées dans un délai de 30 jours. | Confirm step body. Keep the three paragraphs. | same |
| `deletion.confirm.button` | Delete Account | Supprimer le compte | Red destructive button. | same |
| `deletion.local_confirm.headline` | This deletes your game data on this device. | Cette action supprime vos données de jeu sur cet appareil. | Confirm step, local-only player. | same |
| `deletion.local_confirm.body` | Your progress, coins, items, and profile will be gone. You can't undo this.\\n\\nThis game never created an online account for you, so nothing needs to be deleted from our servers. | Votre progression, vos pièces, vos objets et votre profil seront perdus. Cette action est irréversible.\\n\\nCe jeu n’a jamais créé de compte en ligne pour vous. Aucune donnée ne doit donc être supprimée de nos serveurs. | Body for that step. | same |
| `deletion.local_confirm.button` | Delete Data | Supprimer les données | Red destructive button. | same |
| `deletion.pending_setup.headline` | Your account is still being set up. | La création de votre compte est toujours en cours. | Deletion blocked: first registration not finished. | same |
| `deletion.pending_setup.body` | Connect to the internet and try again in a moment. Nothing was deleted. | Connectez-vous à Internet et réessayez dans un instant. Rien n’a été supprimé. | Body. | same |
| `deletion.sign_in.headline` | Sign in to the account you want to delete. | Connectez-vous au compte que vous souhaitez supprimer. | Deletion blocked: signed out. | same |
| `deletion.sign_in.body` | If you can't sign in, contact support for help. | Si vous ne pouvez pas vous connecter, contactez l’assistance pour obtenir de l’aide. | Body. | same |
| `deletion.read_failed.headline` | Your game data couldn't be read. | Vos données de jeu n’ont pas pu être lues. | Deletion blocked: save unreadable. | same |
| `deletion.read_failed.body` | Restart the game, then try again. Nothing was deleted. | Redémarrez le jeu, puis réessayez. Rien n’a été supprimé. | Body. | same |
| `deletion.unavailable.headline` | Account deletion isn't available in this version of the game. | La suppression de compte n’est pas disponible dans cette version du jeu. | Deletion blocked: feature off. Also a failure headline. | same |
| `deletion.unavailable.body` | Update the game, or contact support for help deleting your account. Nothing was deleted. | Mettez le jeu à jour ou contactez l’assistance pour obtenir de l’aide concernant la suppression de votre compte. Rien n’a été supprimé. | Body. | same |
| `deletion.in_progress.account` | Deleting your account... | Suppression de votre compte… | Headline while the request runs. | same |
| `deletion.in_progress.local` | Deleting your game data... | Suppression de vos données de jeu… | Same for local-only data. | same |
| `deletion.in_progress.body` | Keep the game open. This only takes a moment. | Gardez le jeu ouvert. Cela ne prend qu’un instant. | Body while deleting. | same |
| `deletion.not_confirmed.headline` | We haven't heard back about your deletion yet. | Nous n’avons pas encore reçu de réponse concernant votre demande de suppression. | Request sent, answer lost. | same |
| `deletion.not_confirmed.body` | Your request was sent, but the answer didn't arrive. Connect to the internet and try again. The game stays locked until we know the result. | Votre demande a été envoyée, mais la réponse n’est pas arrivée. Connectez-vous à Internet et réessayez. Le jeu reste verrouillé tant que nous ne connaissons pas le résultat. | Body. | same |
| `deletion.unconfirmed.headline` | Deletion status unconfirmed | Statut de suppression non confirmé | Server outcome unknown. | same |
| `deletion.unconfirmed.body` | We couldn't confirm whether your account was deleted. To keep your data safe, the game stays locked. Contact support and include the reference below. | Nous n’avons pas pu confirmer si votre compte a été supprimé. Pour protéger vos données, le jeu reste verrouillé. Contactez l’assistance et indiquez la référence ci-dessous. | Body; a reference code is shown under it. | same |
| `deletion.check_again` | Check Again | Revérifier | Asks the server again. | same |
| `deletion.cleanup.headline.local` | Your local game data couldn't be fully deleted yet. | Vos données de jeu locales n’ont pas encore pu être entièrement supprimées. | Local cleanup incomplete (local-only player). | same |
| `deletion.cleanup.headline.account` | Account deletion accepted; finishing cleanup. | Suppression du compte acceptée ; finalisation en cours. | Local cleanup incomplete after the server accepted. | same |
| `deletion.cleanup.body` | Some game data couldn't be removed from this device yet. Try again to finish. | Certaines données de jeu n’ont pas encore pu être supprimées de cet appareil. Réessayez pour terminer. | Body. | same |
| `deletion.new_game.headline` | Starting a new game... | Démarrage d’une nouvelle partie… | While a fresh save is created. | same |
| `deletion.new_game.body` | This only takes a moment. | Cela ne prend qu’un instant. | Body. | same |
| `deletion.status_unknown.headline` | We couldn't read the deletion status on this device. | Nous n’avons pas pu lire le statut de suppression sur cet appareil. | Local deletion record unreadable. | same |
| `deletion.status_unknown.body` | To keep your data safe, the game stays locked. Contact support for help. | Pour protéger vos données, le jeu reste verrouillé. Contactez l’assistance pour obtenir de l’aide. | Body. | same |
| `deletion.fail.offline` | Connect to the internet to delete your account. | Connectez-vous à Internet pour supprimer votre compte. | Failure headline. | same |
| `deletion.fail.rate_limited` | Too many attempts. Wait a moment, then try again. | Trop de tentatives. Patientez un instant, puis réessayez. | Failure headline. | same |
| `deletion.fail.busy` | Account deletion is busy right now. Try again in a moment. | Le service de suppression de compte est temporairement indisponible. Réessayez dans un instant. | Failure headline (server unavailable). | same |
| `deletion.fail.syncing` | The game is still syncing. Try again in a moment. | Le jeu est toujours en cours de synchronisation. Réessayez dans un instant. | Failure headline. | same |
| `deletion.fail.auth` | We couldn't verify your account. Restart the game, then try again. | Nous n’avons pas pu vérifier votre compte. Redémarrez le jeu, puis réessayez. | Failure headline. | same |
| `deletion.fail.update` | Update the game to delete your account. | Mettez le jeu à jour pour supprimer votre compte. | Failure headline (client too old). | same |
| `deletion.fail.changed` | Your account changed while we were deleting it. Try again. | Votre compte a été modifié pendant la suppression. Réessayez. | Failure headline. | same |
| `deletion.fail.storage` | Your device couldn't save the deletion request. Try again. | Votre appareil n’a pas pu enregistrer la demande de suppression. Réessayez. | Failure headline. | same |
| `deletion.fail.generic` | We couldn't delete your account. Try again later or contact support. | Nous n’avons pas pu supprimer votre compte. Réessayez plus tard ou contactez l’assistance. | Failure headline (fallback). | same |
| `deletion.fail.local` | Your game data couldn't be deleted. Try again. | Vos données de jeu n’ont pas pu être supprimées. Réessayez. | Failure headline, local-only player. | same |
| `deletion.fail.body` | Nothing was deleted, and you can keep playing. | Rien n’a été supprimé et vous pouvez continuer à jouer. | Body for every failure. | same |
| `deletion.done_local.headline` | Your local game data was deleted. | Vos données de jeu locales ont été supprimées. | Success, local-only player. | same |
| `deletion.done_local.body` | You can start over with a new game. | Vous pouvez recommencer avec une nouvelle partie. | Body. | same |
| `deletion.new_game_failed` | The new game couldn't start. Try again. | La nouvelle partie n’a pas pu démarrer. Réessayez. | Appended under a success body if the fresh save failed. | same |
| `deletion.accepted.headline` | Your account is no longer accessible. | Votre compte n’est plus accessible. | Success, online account. | same |
| `deletion.accepted.body` | Your deletion request was accepted. | Votre demande de suppression a été acceptée. | Body when no deadline is known. | same |
| `deletion.accepted.body_deadline` | Your deletion request was accepted. Data removal is due by %s. | Votre demande de suppression a été acceptée. Les données seront supprimées au plus tard le %s. | Body. `%s` = a date such as "November 2, 2026". | same |
| `deletion.reference` | Reference: %s | Référence : %s | Support reference code under the body. `%s` = operation id; never translated. | same |
| `deletion.start_new_game` | Start New Game | Nouvelle partie | Button after a successful deletion. | same |

### Platform and system text

| Key | English | Français | Context | Source |
| --- | --- | --- | --- | --- |
| `app.name` | SortingPuzzle | SortingPuzzle | App name under the home-screen icon; today the internal project name. Decide the public name per store first. | `project.godot`, `export_presets.cfg` |
| `support.email.subject` | Sorting Puzzle support request | Demande d’assistance – Sorting Puzzle | Subject of the pre-filled support email. | `support_screen.gd` |
| `support.email.body` | Please describe the issue here.\\n\\nDevice/platform:\\nApproximate time:\\n | Veuillez décrire le problème ici.\\n\\nAppareil/plateforme :\\nHeure approximative :\\n | Body template the player fills in. | `support_screen.gd` |
| `support.ad_email.subject` | Sorting Puzzle ad report | Signalement d’une publicité – Sorting Puzzle | Subject of the ad-report email. | `support_screen.gd` |
| `support.ad_email.body` | Please attach a screenshot and complete the details below.\\n\\nApproximate time:\\nAd placement in the game:\\nAdvertiser or app name:\\nWhy the ad should be reviewed:\\n | Veuillez joindre une capture d’écran et compléter les informations ci-dessous.\\n\\nHeure approximative :\\nEmplacement de la publicité dans le jeu :\\nNom de l’annonceur ou de l’application :\\nMotif du signalement :\\n | Body template the player fills in. | `support_screen.gd` |
| `deletion.email.subject` | Sorting Puzzle account deletion | Suppression du compte – Sorting Puzzle | Subject of the deletion help email. | `account_deletion_modal.gd` |
| `deletion.email.body` | Please help me with my account deletion. | Veuillez m’aider à supprimer mon compte. | First line; followed by `Status:`, `Deletion reference:`, `Server reference:` and `Player ID:` lines. | `account_deletion_modal.gd` |

## French plural forms

For the whole-number counts in these strings, use the singular form for 0 or 1 and the plural form for 2 or more (the usual French gettext rule: `nplurals=2; plural=(n > 1);`). Select the form using the original numeric count, even when `%s` contains a formatted number. In the leaderboard row and weekly-reward message, plural selection depends on the final count (stars or coins), not the rank.

| Key | Singular (0 or 1) | Plural (2 or more) |
| --- | --- | --- |
| `chapter.locked_status` | Terminez encore %d niveau de « %s » pour débloquer | Terminez encore %d niveaux de « %s » pour débloquer |
| `shelf_unlock.offer_or_clear` | Regardez une publicité pour débloquer cette étagère maintenant, ou éliminez encore %s trio. | Regardez une publicité pour débloquer cette étagère maintenant, ou éliminez encore %s trios. |
| `starter.coins` | %s PIÈCE | %s PIÈCES |
| `booster_chip.claimed` | +%d × %s | +%d × %s |
| `leaderboard.row_tooltip` | Rang %d, %s, %d étoile | Rang %d, %s, %d étoiles |
| `leaderboard.reward.body` | Vous avez fini n° %d la semaine dernière et gagné %d pièce ! | Vous avez fini n° %d la semaine dernière et gagné %d pièces ! |

`booster_chip.claimed` uses the same pattern in both forms. Treat `%s` as a product label and keep the four booster names unchanged after the quantity. The multiplication sign avoids awkward French pluralization: `+1 × Marteau`, `+3 × Marteau`, `+2 × Gel`. This keeps names consistent with the inventory’s product-name convention. The unmarked `leaderboard.reward_tooltip` avoids a count-dependent noun by naming the currency first: `Récompense hebdomadaire en pièces : %s`.

## Copy and implementation notes

- The short home badge is `PACK`; the full starter offer is `Pack de départ` / `PACK DE DÉPART`.
- The four booster names are `Marteau`, `Mélange`, `Lanterne`, and `Gel` in every tooltip, description, reward row, and offer.
- `common.resume` is `Reprendre` when returning to the running level. `common.continue` is `Continuer` when moving on. A failed level uses `Rejouer`; retrying an operation or a data load uses `Réessayer`.
- `ad.watch` uses the compact `Voir une pub`; explanatory bodies use `publicité`. The locked-shelf marker remains `AD`.
- `menu.more_levels_coming_soon` has 24 characters; `menu.lives_full` has 3; `menu.starter_badge` has 4; navigation labels have 7–10. Accented capitals are intentional.
- Chapter names are localized as `Quartier des épiceries` and `Coin des bonbons`; dynamic chapter titles are enclosed in French quotation marks in the unlock sentence.
- The shop offer names are title case in their catalog entries, matching the source. Their displayed card forms are `PACK DE DÉPART` and `PACK DE BASE`.
- The app name is preserved as `SortingPuzzle`, and support-email subjects preserve the brand spelling `Sorting Puzzle`. This document does not choose a new public store name.
- Account-deletion warnings retain permanent deletion, irreversibility, the 30-day removal period, retained purchase/security records without the name or profile, locked states, and every explicit statement that nothing was deleted.
- A dynamic deletion deadline should arrive in French date format, for example `2 novembre 2026`; the `%s` placeholder is preserved. Likewise, number and price formatting belongs to the locale-aware formatter, not these strings.
- Four deletion-help email labels mentioned in the inventory’s context are translated below. They are supplemental fragments, not extra inventory keys.

| English fragment | Français |
| --- | --- |
| Status: | Statut : |
| Deletion reference: | Référence de suppression : |
| Server reference: | Référence du serveur : |
| Player ID: | Identifiant du joueur : |

Layout verification remains part of a future integration: capture affected screens at the project’s representative portrait resolutions, especially the smallest viewport and longer modal titles such as `RÉCOMPENSE HEBDOMADAIRE !` and `SUPPRIMER LES DONNÉES DU JEU`.
