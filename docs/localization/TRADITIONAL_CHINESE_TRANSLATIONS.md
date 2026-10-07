# Sorting Puzzle — Traditional Chinese Translations

Locale: **繁體中文 (`zh_Hant`)** · Regional wording: **Taiwan (臺灣)**

Translated from the supplied “Sorting Puzzle — Translation String Inventory.md”. All **251 inventory entries** are included below with their original keys and English text. The original document is unchanged.

## Translation conventions

- Short, friendly wording for a casual mobile puzzle game.
- Preserve `%d` and `%s` exactly, including their order, so formatted values remain compatible with the source strings.
- In the tables, `\n` represents a forced line break; `\n\n` separates paragraphs. The companion CSV and JSON contain actual line breaks in the string values, with JSON escaping them as `\n`.
- Keep `AD`, `OFF`, dynamic percentage discount tags, player names, reference-code values and email-address values unchanged.
- Keep the existing brand names `SortingPuzzle` and `Sorting Puzzle`; this translation does not choose a new public app name.
- Chinese has no uppercase/lowercase distinction. Titles and banners use the same Chinese characters as other labels.
- The same Chinese wording works for singular and plural counts.

## Consistent terminology

| English | 繁體中文 |
| --- | --- |
| Level | 關卡 |
| Chapter | 章節 |
| Shelf | 貨架 |
| Item / goods being sorted | 商品 |
| Matching triple / set | 一組相同商品（三個） |
| Clear / match | 消除 |
| Combo | 連擊 |
| Booster / ability / owned inventory item | 道具 |
| Hammer | 槌子 |
| Shuffle | 重排 |
| Lantern | 提燈 |
| Freezer | 冰凍器 |
| Dispenser | 出貨機 |
| Coins | 金幣 |
| Stars | 星星 |
| Lives | 生命 |
| Reward chest | 獎勵寶箱 |
| Bundle | 禮包 |
| Account | 帳號 |
| Player profile | 個人檔案 |

## Translation inventory

### Shared buttons, main menu and chapters

| Key | English | 繁體中文 |
| --- | --- | --- |
| `common.play` | Play | 開始 |
| `common.continue` | Continue | 繼續 |
| `common.resume` | Continue | 繼續遊戲 |
| `common.try_again` | Try Again | 再試一次 |
| `common.close` | Close | 關閉 |
| `common.cancel` | Cancel | 取消 |
| `common.got_it` | Got it | 知道了 |
| `common.get_help` | Get Help | 尋求協助 |
| `common.save` | SAVE | 儲存 |
| `common.loading` | Loading… | 載入中… |
| `common.retry_load` | Retry | 重新載入 |
| `menu.level_button` | LEVEL %d | 第 %d 關 |
| `menu.more_levels_coming_soon` | MORE LEVELS COMING SOON | 更多關卡即將推出 |
| `menu.coming_soon` | COMING SOON | 即將推出 |
| `menu.lives_full` | Full | 已滿 |
| `menu.starter_badge` | BUNDLE | 禮包 |
| `nav.shop` | Shop | 商店 |
| `nav.home` | Home | 首頁 |
| `nav.leaderboard` | Leaderboard | 排行榜 |
| `chapter.button` | CHAPTER %d | 第 %d 章 |
| `chapter.button_tooltip` | Choose Chapter %d: %s | 選擇第 %d 章：%s |
| `chapter.screen_title` | CHAPTERS | 章節 |
| `chapter.eyebrow` | CHAPTER %d | 第 %d 章 |
| `chapter.title.chapter_01` | Grocery Town | 雜貨小鎮 |
| `chapter.title.chapter_02` | Candy Corner | 糖果街角 |
| `chapter.locked_status` | Complete %d more %s levels to unlock | 再完成 %d 個「%s」關卡即可解鎖 |
| `chapter.unlock_progress` | Unlock progress | 解鎖進度 |
| `chapter.current_progress` | Current progress | 目前進度 |
| `chapter.locked` | Locked | 未解鎖 |
| `chapter.no_levels_status` | New levels are coming soon | 新關卡即將推出 |
| `chapter.coming_soon` | Coming Soon | 即將推出 |

### Gameplay: HUD, level screens and results

| Key | English | 繁體中文 |
| --- | --- | --- |
| `hud.level` | LEVEL %d | 第 %d 關 |
| `hud.combo` | COMBO ×%d | 連擊 ×%d |
| `hud.ability_tooltip.hammer` | Hammer -- clears a matching triple | 槌子——消除三個相同商品 |
| `hud.ability_tooltip.shuffle` | Shuffle -- reshuffles unlocked items | 重排——重新排列未鎖定的商品 |
| `hud.ability_tooltip.lantern` | Lantern -- highlights a matchable triple | 提燈——標示可消除的三個相同商品 |
| `hud.ability_tooltip.freezer` | Freezer -- pauses the countdown timer | 冰凍器——暫停倒數計時 |
| `hud.seconds_short` | %ds | %d秒 |
| `tip.tap_dispenser` | Tap a dispenser to throw items onto the shelves! | 點一下出貨機，就能把商品送到貨架上！ |
| `pause.title` | PAUSE | 暫停 |
| `pause.leave` | Leave | 離開 |
| `leave.title` | LEAVING THE LEVEL | 離開關卡 |
| `leave.you_will_lose` | You will lose: | 你將失去： |
| `leave.confirm` | Leave | 離開 |
| `timeup.title` | TIME'S UP | 時間到！ |
| `timeup.offer` | Add one minute and keep sorting! | 增加一分鐘，繼續整理！ |
| `timeup.used` | Used | 已使用 |
| `ability_purchase.title` | USE ABILITY | 使用道具 |
| `shelf_unlock.title` | UNLOCK SHELF | 解鎖貨架 |
| `shelf_unlock.offer` | Watch one ad to unlock this shelf now. | 觀看一則廣告，立即解鎖此貨架。 |
| `shelf_unlock.offer_or_clear` | Watch one ad to unlock this shelf now, or clear %s more. | 觀看一則廣告立即解鎖此貨架，或再消除 %s 組商品即可解鎖。 |
| `shelf_unlock.button` | Watch Ad · Unlock Shelf | 觀看廣告 · 解鎖貨架 |
| `shelf_unlock.ad_unavailable` | Ad unavailable. This shelf stays locked. | 廣告目前無法播放，此貨架仍未解鎖。 |
| `complete.title` | GREAT JOB! | 做得好！ |
| `failed.title` | LEVEL %d | 第 %d 關 |
| `failed.headline` | LEVEL FAILED | 闖關失敗 |
| `failed.retry` | Retry | 重新挑戰 |
| `combo.praise.2` | Cool | 酷喔 |
| `combo.praise.3` | Great | 很棒 |
| `combo.praise.4` | Awesome | 超讚 |
| `combo.praise.5` | Amazing | 太厲害了 |
| `combo.praise.6` | Fantastic | 太精彩了 |
| `combo.praise.7` | Incredible | 不可思議 |
| `combo.praise.8` | Spectacular | 震撼全場 |
| `combo.praise.9` | Unstoppable | 勢不可擋 |
| `combo.praise.10` | Legendary | 傳奇表現 |
| `combo.praise.11` | Epic | 史詩表現 |
| `combo.praise.12` | Brilliant | 精彩絕倫 |
| `combo.praise.13` | Masterful | 大師級 |
| `combo.praise.14` | Supreme | 無與倫比 |
| `combo.praise.15` | Phenomenal | 超凡表現 |
| `combo.praise.16` | Mythic | 神級 |
| `combo.praise.17` | Majestic | 氣勢非凡 |
| `combo.praise.18` | Radiant | 光芒四射 |
| `combo.praise.19` | Divine | 神乎其技 |
| `combo.praise.20` | Transcendent | 超越極限 |

### Boosters, ads, lives, rewards and shop

| Key | English | 繁體中文 |
| --- | --- | --- |
| `ability.hammer.name` | Hammer | 槌子 |
| `ability.shuffle.name` | Shuffle | 重排 |
| `ability.lantern.name` | Lantern | 提燈 |
| `ability.freezer.name` | Freezer | 冰凍器 |
| `ability.hammer.description` | Instantly clears one matching set of items off the shelves. | 立即消除貨架上的一組相同商品。 |
| `ability.shuffle.description` | Shuffles shelf items into new spots to help you find a match. | 重新排列貨架上的商品，幫助你找出可消除的組合。 |
| `ability.lantern.description` | Highlights a matching triple you can clear for 15 seconds. | 標示一組可消除的三個相同商品，持續 15 秒。 |
| `ability.freezer.description` | Freezes the level timer for 30 seconds. | 凍結關卡計時器 30 秒。 |
| `ad.watch` | Watch Ad | 觀看廣告 |
| `ad.loading` | Loading... | 載入中… |
| `ad.verifying` | Verifying... | 驗證中… |
| `ad.verify_reward` | Verify Reward | 驗證獎勵 |
| `ad.reward_pending` | Reward verification is still pending. | 獎勵驗證仍在處理中。 |
| `ad.unavailable_retry` | Ad unavailable. Please try again. | 廣告目前無法播放，請再試一次。 |
| `ad.watch_unavailable` | `Watch Ad\nUnavailable` | `觀看廣告\n暫時無法播放` |
| `ad.watch_coming_soon` | `Watch Ad\nComing Soon` | `觀看廣告\n即將推出` |
| `ad.badge` | AD | AD |
| `lives.title.out` | OUT OF LIVES | 生命已用完 |
| `lives.title.get_more` | GET MORE LIVES | 補充生命 |
| `lives.title.full` | LIVES FULL | 生命已滿 |
| `lives.next_in` | NEXT LIFE IN | 生命恢復倒數 |
| `lives.full_body` | Your lives are full! Play a level to spend them. | 你的生命已滿！開始闖關來使用生命吧。 |
| `chest.title` | CHEST REWARDS | 寶箱獎勵 |
| `chest.progress_hint` | Collect stars to unlock a chest and claim your reward | 收集星星，解鎖寶箱並領取獎勵 |
| `chest.ready` | A REWARD CHEST AWAITS! | 獎勵寶箱等你開啟！ |
| `chest.tap_to_open` | Tap to open | 點一下開啟 |
| `purchase.tap_to_collect` | Tap to collect | 點一下領取 |
| `purchase.complete` | PURCHASE COMPLETE | 購買完成 |
| `shop.title` | SHOP | 商店 |
| `shop.section.bundles` | SPECIAL BUNDLES | 特別禮包 |
| `shop.section.coins` | COINS | 金幣 |
| `shop.offer.starter_bundle` | Starter Bundle | 新手禮包 |
| `shop.offer.basic_bundle` | Basic Bundle | 基礎禮包 |
| `shop.tag.best_value` | BEST VALUE | 最划算 |
| `shop.discount_off` | OFF | OFF |
| `shop.ability_hint` | Tap an ability to see what it does | 點一下道具，查看它的效果 |
| `shop.purchasing` | Purchasing… | 購買中… |
| `shop.no_offers` | No shop offers are available for this region. | 此地區目前沒有可購買的商品。 |
| `shop.load_failed` | Could not load the shop. | 無法載入商店。 |
| `shop.error.title.purchase` | Purchase unavailable | 無法購買 |
| `shop.error.title.reward` | Reward error | 獎勵錯誤 |
| `shop.error.purchase_failed` | The purchase could not be completed. | 無法完成購買。 |
| `shop.error.grant_failed` | The purchased rewards could not be granted. | 無法發放已購買的獎勵。 |
| `shop.error.offer_unavailable` | This shop offer is unavailable. | 此商店優惠目前無法購買。 |
| `shop.error.already_bought` | This one-time shop offer has already been purchased. | 此優惠限購一次，且你已購買過。 |
| `starter.title` | STARTER BUNDLE | 新手禮包 |
| `starter.one_time` | ONE-TIME OFFER | 限購一次 |
| `starter.boosters_included` | BOOSTERS INCLUDED | 內含道具 |
| `starter.coins` | %s COINS | %s 枚金幣 |
| `starter.buy_for` | Buy for %s | 用 %s 購買 |
| `starter.checking` | Checking offer… | 正在確認優惠… |
| `starter.checking_short` | Checking… | 確認中… |
| `starter.no_longer_available` | This offer is no longer available. | 此優惠已無法購買。 |
| `starter.unavailable` | Unavailable | 無法購買 |
| `booster_chip.claimed` | +%d %s | +%d %s |

### Profile, leaderboard and settings

| Key | English | 繁體中文 |
| --- | --- | --- |
| `profile.title` | EDIT PROFILE | 編輯個人檔案 |
| `profile.name_header` | PLAYER NAME | 玩家名稱 |
| `profile.name_placeholder` | Player name | 玩家名稱 |
| `profile.edit_name_tooltip` | Edit player name | 編輯玩家名稱 |
| `profile.avatar_tab` | AVATAR | 頭像 |
| `profile.frame_tab` | FRAME | 頭像框 |
| `profile.unlock.level` | Complete level %d to unlock | 完成第 %d 關即可解鎖 |
| `profile.unlock.combo` | Reach a combo of ×%d in any run to unlock | 在任一場遊戲中達成 ×%d 連擊即可解鎖 |
| `profile.unlock.weekly_first` | Finish 1st on the Weekly leaderboard to unlock | 在每週排行榜獲得第 1 名即可解鎖 |
| `profile.unlock.weekly_top` | Finish top %d on the Weekly leaderboard to unlock | 在每週排行榜進入前 %d 名即可解鎖 |
| `leaderboard.title` | LEADERBOARD | 排行榜 |
| `leaderboard.tab.weekly` | Weekly | 每週 |
| `leaderboard.tab.country` | Country | 國內 |
| `leaderboard.tab.world` | World | 全球 |
| `leaderboard.weekly_reset` | Weekly reset in %s | 每週排名將於 %s 後重置 |
| `leaderboard.duration.dh` | %dd %dh | %d天 %d小時 |
| `leaderboard.duration.hm` | %dh %dm | %d小時 %d分 |
| `leaderboard.duration.m` | %dm | %d分 |
| `leaderboard.country_caption` | Country · All-time stars | 國內 · 累計星星 |
| `leaderboard.world_caption` | Worldwide · All-time stars | 全球 · 累計星星 |
| `leaderboard.load_failed` | Could not load leaderboard. | 無法載入排行榜。 |
| `leaderboard.default_name` | Player | 玩家 |
| `leaderboard.row_tooltip` | Rank %d, %s, %d stars | 第 %d 名，%s，%d 顆星星 |
| `leaderboard.reward_tooltip` | %s coin weekly reward | 每週獎勵：%s 枚金幣 |
| `leaderboard.reward.title` | WEEKLY REWARD! | 每週獎勵！ |
| `leaderboard.reward.body` | You finished #%d last week and earned %d coins! | 你上週獲得第 %d 名，贏得 %d 枚金幣！ |
| `leaderboard.reward.ok` | Nice! | 太棒了！ |
| `settings.title` | SETTINGS | 設定 |
| `settings.music` | Music | 音樂 |
| `settings.sfx` | SFX | 音效 |
| `settings.vibrate` | Vibrate | 震動 |
| `settings.support` | Support | 客服 |
| `settings.language` | Language | 語言 |
| `settings.privacy_policy` | Privacy Policy | 隱私權政策 |
| `settings.privacy_choices` | Privacy Choices | 隱私權選項 |
| `settings.diagnostics` | `Version %s • Build %d\nPlatform: %s • User: %s` | `版本 %s • 組建 %d\n平台：%s • 使用者：%s` |
| `language.title` | LANGUAGE | 語言 |

### Support screen

| Key | English | 繁體中文 |
| --- | --- | --- |
| `support.title` | SUPPORT | 客服 |
| `support.faq_header` | Frequently Asked Questions | 常見問題 |
| `support.faq.play.q` | How do I play? | 要怎麼玩？ |
| `support.faq.play.a` | Move matching goods onto the same shelf. When three identical items are visible together, they clear. Complete the board before time runs out. | 將相同商品移到同一個貨架。當三個相同商品同時出現在貨架上，就會消除。在時間用完前，清空所有商品即可過關。 |
| `support.faq.contact.q` | How do I contact support? | 如何聯絡客服？ |
| `support.faq.contact.a` | Email us at %s. Include a short description, your device platform, and when the problem happened. | 請寄電子郵件至 %s，簡短說明問題、裝置平台及問題發生的時間。 |
| `support.faq.contact.action` | Email Support | 寄信給客服 |
| `support.faq.crash.q` | What if the game freezes or crashes? | 遊戲卡住或閃退時該怎麼辦？ |
| `support.faq.crash.a` | Close and reopen the game first. If it happens again, restart the device and make sure the game is updated. Contact support with the device model, platform version, and what you were doing before the problem. | 請先關閉並重新開啟遊戲。如果再次發生，請重新啟動裝置，並確認遊戲已更新。聯絡客服時，請提供裝置型號、平台版本，以及問題發生前你正在進行的操作。 |
| `support.faq.sync.q` | How do I sync progress between devices? | 如何在不同裝置間同步進度？ |
| `support.faq.sync.a` | Use the same signed-in platform account on both devices and allow synchronization to finish before playing. If the progress differs, avoid playing on both devices and contact support. | 請在兩台裝置上登入同一個平台帳號，並等同步完成後再開始遊戲。如果進度不同，請先不要在任一裝置上繼續遊玩，並聯絡客服。 |
| `support.faq.bad_ad.q` | How do I report a bad ad? | 如何檢舉不當廣告？ |
| `support.faq.bad_ad.a` | `1. Close the ad if you can do so safely.\n2. Take a screenshot of the ad and any advertiser or app name shown.\n3. Note the approximate time and where the ad appeared in the game.\n4. Describe why the ad seemed offensive, misleading, or fraudulent.\n5. Email these details to %s. Do not include passwords or payment information.` | `1. 如果能安全關閉廣告，請先關閉。\n2. 擷取廣告畫面，以及畫面中顯示的廣告主或應用程式名稱。\n3. 記下大約時間，以及廣告在遊戲中出現的位置。\n4. 說明你認為廣告含有冒犯、誤導或詐騙內容的原因。\n5. 將上述資訊寄至 %s。請勿附上密碼或付款資訊。` |
| `support.faq.bad_ad.action` | Email Ad Report | 寄信檢舉廣告 |
| `support.account_header` | Account | 帳號 |
| `support.delete_account` | Delete Account | 刪除帳號 |
| `support.delete_game_data` | Delete Game Data | 刪除遊戲資料 |
| `support.no_secrets` | Please never send passwords or payment information. | 請勿提供密碼或付款資訊。 |

### Account deletion modal

| Key | English | 繁體中文 |
| --- | --- | --- |
| `deletion.title.delete_account` | DELETE ACCOUNT | 刪除帳號 |
| `deletion.title.delete_game_data` | DELETE GAME DATA | 刪除遊戲資料 |
| `deletion.title.not_confirmed` | NOT CONFIRMED | 尚未確認 |
| `deletion.title.status_unconfirmed` | STATUS UNCONFIRMED | 狀態尚未確認 |
| `deletion.title.finishing_up` | FINISHING UP | 正在完成清除 |
| `deletion.title.new_game` | NEW GAME | 新遊戲 |
| `deletion.title.status_unknown` | STATUS UNKNOWN | 狀態不明 |
| `deletion.title.not_deleted` | NOT DELETED | 未刪除 |
| `deletion.title.data_deleted` | DATA DELETED | 資料已刪除 |
| `deletion.title.accepted` | DELETION ACCEPTED | 刪除申請已受理 |
| `deletion.confirm.headline` | This permanently deletes your account. | 這將永久刪除你的帳號。 |
| `deletion.confirm.body` | `Your progress, coins, items, and profile will be gone. You can't undo this.\n\nIf you sign in again later, you'll start a new account.\n\nSome purchase and security records are kept without your name or profile. The rest is removed within 30 days.` | `你的進度、金幣、道具及個人檔案將全部刪除。此操作無法復原。\n\n如果日後再次登入，將會建立新帳號。\n\n部分購買及安全紀錄會保留，但不含你的姓名或個人檔案。其餘資料將於 30 天內刪除。` |
| `deletion.confirm.button` | Delete Account | 刪除帳號 |
| `deletion.local_confirm.headline` | This deletes your game data on this device. | 這將刪除此裝置上的遊戲資料。 |
| `deletion.local_confirm.body` | `Your progress, coins, items, and profile will be gone. You can't undo this.\n\nThis game never created an online account for you, so nothing needs to be deleted from our servers.` | `你的進度、金幣、道具及個人檔案將全部刪除。此操作無法復原。\n\n本遊戲從未為你建立線上帳號，因此無須從我們的伺服器刪除任何資料。` |
| `deletion.local_confirm.button` | Delete Data | 刪除資料 |
| `deletion.pending_setup.headline` | Your account is still being set up. | 你的帳號仍在建立中。 |
| `deletion.pending_setup.body` | Connect to the internet and try again in a moment. Nothing was deleted. | 請連上網路，稍後再試。未刪除任何資料。 |
| `deletion.sign_in.headline` | Sign in to the account you want to delete. | 請登入你要刪除的帳號。 |
| `deletion.sign_in.body` | If you can't sign in, contact support for help. | 如果無法登入，請聯絡客服尋求協助。 |
| `deletion.read_failed.headline` | Your game data couldn't be read. | 無法讀取你的遊戲資料。 |
| `deletion.read_failed.body` | Restart the game, then try again. Nothing was deleted. | 請重新啟動遊戲後再試。未刪除任何資料。 |
| `deletion.unavailable.headline` | Account deletion isn't available in this version of the game. | 此遊戲版本不支援刪除帳號。 |
| `deletion.unavailable.body` | Update the game, or contact support for help deleting your account. Nothing was deleted. | 請更新遊戲，或聯絡客服協助刪除帳號。未刪除任何資料。 |
| `deletion.in_progress.account` | Deleting your account... | 正在刪除你的帳號… |
| `deletion.in_progress.local` | Deleting your game data... | 正在刪除你的遊戲資料… |
| `deletion.in_progress.body` | Keep the game open. This only takes a moment. | 請保持遊戲開啟，這只需要片刻。 |
| `deletion.not_confirmed.headline` | We haven't heard back about your deletion yet. | 我們尚未收到你的刪除申請結果。 |
| `deletion.not_confirmed.body` | Your request was sent, but the answer didn't arrive. Connect to the internet and try again. The game stays locked until we know the result. | 你的申請已送出，但尚未收到回覆。請連上網路後再試。確認結果前，遊戲會保持鎖定。 |
| `deletion.unconfirmed.headline` | Deletion status unconfirmed | 刪除狀態尚未確認 |
| `deletion.unconfirmed.body` | We couldn't confirm whether your account was deleted. To keep your data safe, the game stays locked. Contact support and include the reference below. | 我們無法確認你的帳號是否已刪除。為保護你的資料，遊戲會保持鎖定。請聯絡客服，並提供下方的參考編號。 |
| `deletion.check_again` | Check Again | 再次確認 |
| `deletion.cleanup.headline.local` | Your local game data couldn't be fully deleted yet. | 你的本機遊戲資料尚未完全刪除。 |
| `deletion.cleanup.headline.account` | Account deletion accepted; finishing cleanup. | 帳號刪除申請已受理，正在完成清除。 |
| `deletion.cleanup.body` | Some game data couldn't be removed from this device yet. Try again to finish. | 此裝置上的部分遊戲資料尚未移除。請再試一次以完成清除。 |
| `deletion.new_game.headline` | Starting a new game... | 正在開始新遊戲… |
| `deletion.new_game.body` | This only takes a moment. | 這只需要片刻。 |
| `deletion.status_unknown.headline` | We couldn't read the deletion status on this device. | 我們無法讀取此裝置上的刪除狀態。 |
| `deletion.status_unknown.body` | To keep your data safe, the game stays locked. Contact support for help. | 為保護你的資料，遊戲會保持鎖定。請聯絡客服尋求協助。 |
| `deletion.fail.offline` | Connect to the internet to delete your account. | 請連上網路以刪除帳號。 |
| `deletion.fail.rate_limited` | Too many attempts. Wait a moment, then try again. | 嘗試次數過多，請稍後再試。 |
| `deletion.fail.busy` | Account deletion is busy right now. Try again in a moment. | 帳號刪除服務目前忙碌中，請稍後再試。 |
| `deletion.fail.syncing` | The game is still syncing. Try again in a moment. | 遊戲仍在同步中，請稍後再試。 |
| `deletion.fail.auth` | We couldn't verify your account. Restart the game, then try again. | 我們無法驗證你的帳號。請重新啟動遊戲後再試。 |
| `deletion.fail.update` | Update the game to delete your account. | 請更新遊戲以刪除帳號。 |
| `deletion.fail.changed` | Your account changed while we were deleting it. Try again. | 刪除過程中，你的帳號發生變更。請再試一次。 |
| `deletion.fail.storage` | Your device couldn't save the deletion request. Try again. | 你的裝置無法儲存刪除申請。請再試一次。 |
| `deletion.fail.generic` | We couldn't delete your account. Try again later or contact support. | 我們無法刪除你的帳號。請稍後再試，或聯絡客服。 |
| `deletion.fail.local` | Your game data couldn't be deleted. Try again. | 無法刪除你的遊戲資料。請再試一次。 |
| `deletion.fail.body` | Nothing was deleted, and you can keep playing. | 未刪除任何資料，你可以繼續遊戲。 |
| `deletion.done_local.headline` | Your local game data was deleted. | 你的本機遊戲資料已刪除。 |
| `deletion.done_local.body` | You can start over with a new game. | 你可以開始新遊戲，從頭再來。 |
| `deletion.new_game_failed` | The new game couldn't start. Try again. | 無法開始新遊戲。請再試一次。 |
| `deletion.accepted.headline` | Your account is no longer accessible. | 你已無法再存取此帳號。 |
| `deletion.accepted.body` | Your deletion request was accepted. | 你的刪除申請已受理。 |
| `deletion.accepted.body_deadline` | Your deletion request was accepted. Data removal is due by %s. | 你的刪除申請已受理。資料最遲將於 %s 刪除。 |
| `deletion.reference` | Reference: %s | 參考編號：%s |
| `deletion.start_new_game` | Start New Game | 開始新遊戲 |

### Platform and system text

| Key | English | 繁體中文 |
| --- | --- | --- |
| `app.name` | SortingPuzzle | SortingPuzzle |
| `support.email.subject` | Sorting Puzzle support request | Sorting Puzzle 客服支援請求 |
| `support.email.body` | `Please describe the issue here.\n\nDevice/platform:\nApproximate time:\n` | `請在此描述問題。\n\n裝置／平台：\n大約發生時間：\n` |
| `support.ad_email.subject` | Sorting Puzzle ad report | Sorting Puzzle 廣告檢舉 |
| `support.ad_email.body` | `Please attach a screenshot and complete the details below.\n\nApproximate time:\nAd placement in the game:\nAdvertiser or app name:\nWhy the ad should be reviewed:\n` | `請附上螢幕截圖，並填寫以下資訊。\n\n大約發生時間：\n廣告在遊戲中出現的位置：\n廣告主或應用程式名稱：\n需要審查此廣告的原因：\n` |
| `deletion.email.subject` | Sorting Puzzle account deletion | Sorting Puzzle 帳號刪除 |
| `deletion.email.body` | Please help me with my account deletion. | 請協助我刪除帳號。 |

## Delivery notes

- Markdown: bilingual review document, with all 251 keys in the source order.
- CSV: UTF-8 catalog with `keys,en,zh_Hant` columns; multiline values are quoted CSV fields.
- JSON: UTF-8 key-to-translation mapping for `zh_Hant`.
- The deletion email body row translates only the sentence present in the source inventory. If its additional labels are later added as separate keys, use `Status:` → `狀態：`, `Deletion reference:` → `刪除參考編號：`, `Server reference:` → `伺服器參考編號：`, and `Player ID:` → `玩家 ID：`.
- Placeholder types and order, forced line-break counts, key coverage and protected markers have been checked against the supplied inventory.
- This delivery translates the supplied inventory. In-game font coverage and rendered UI layout still need to be checked when the translations are integrated.
