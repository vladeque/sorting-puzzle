# Sorting Puzzle — Türkçe Translations

Language: Türkçe (`tr`). Prepared 7 October 2026 from the supplied English string inventory.

This is a separate translation document for review. No translations have been applied to the game. The English inventory is unchanged.

All 251 keyed inventory entries are included below, with English and Turkish side by side. Only player-facing strings are translated; audit notes and implementation instructions are not treated as tasks.

Review notes:

- `%d` and `%s` are preserved in their original order. `\n` denotes a forced line break; paragraph breaks and trailing email-template line breaks are preserved.
- All-caps translations use Turkish `İ` and `I`. The bundle card titles should display as `BAŞLANGIÇ PAKETİ` and `TEMEL PAKET` when shown in capitals.
- `AD`, `OFF`, and complete discount tags such as `67% OFF` stay unchanged. Brand names `SortingPuzzle` / `Sorting Puzzle`, language names, email addresses, player names, prices and reference-code values stay unchanged.
- The listed Turkish wording works for every count in the entries marked for plural handling. Nouns following numbers remain singular; reuse the same wording in any required catalog plural slots.
- Compact time units: `sn` = seconds, `dk` = minutes, `sa` = hours, `g` = days. Dates supplied through `%s` should be formatted in Turkish when integrated later, for example `2 Kasım 2026`.
- Actual fit in the game has not been checked because these translations have not been integrated.

## Consistent terminology

| English term | Türkçe |
| --- | --- |
| Level | Seviye |
| Chapter | Bölüm |
| Shelf | Raf |
| Item / goods | Ürün |
| Match | Eşleşme |
| Triple / set | Üçlü |
| Combo | Kombo |
| Booster / ability | Güçlendirici |
| Hammer | Çekiç |
| Shuffle | Karıştır |
| Lantern | Fener |
| Freezer | Dondurucu |
| Dispenser | Dağıtıcı |
| Coins (in-game currency) | Para |
| Stars | Yıldız |
| Lives | Can |
| Reward chest | Ödül sandığı |
| Bundle | Paket |


## Shared buttons, main menu and chapters

| Key | English | Türkçe |
| --- | --- | --- |
| `common.play` | Play | Oyna |
| `common.continue` | Continue | Devam Et |
| `common.resume` | Continue | Oyuna Dön |
| `common.try_again` | Try Again | Tekrar Dene |
| `common.close` | Close | Kapat |
| `common.cancel` | Cancel | İptal |
| `common.got_it` | Got it | Anladım |
| `common.get_help` | Get Help | Yardım Al |
| `common.save` | SAVE | KAYDET |
| `common.loading` | Loading… | Yükleniyor… |
| `common.retry_load` | Retry | Tekrar Yükle |
| `menu.level_button` | LEVEL %d | SEVİYE %d |
| `menu.more_levels_coming_soon` | MORE LEVELS COMING SOON | YENİ SEVİYELER YAKINDA |
| `menu.coming_soon` | COMING SOON | YAKINDA |
| `menu.lives_full` | Full | Dolu |
| `menu.starter_badge` | BUNDLE | PAKET |
| `nav.shop` | Shop | Mağaza |
| `nav.home` | Home | Ana Sayfa |
| `nav.leaderboard` | Leaderboard | Sıralama |
| `chapter.button` | CHAPTER %d | BÖLÜM %d |
| `chapter.button_tooltip` | Choose Chapter %d: %s | %d. bölümü seç: %s |
| `chapter.screen_title` | CHAPTERS | BÖLÜMLER |
| `chapter.eyebrow` | CHAPTER %d | BÖLÜM %d |
| `chapter.title.chapter_01` | Grocery Town | Market Kasabası |
| `chapter.title.chapter_02` | Candy Corner | Şeker Köşesi |
| `chapter.locked_status` | Complete %d more %s levels to unlock | Kilidi açmak için %d “%s” seviyesi daha tamamla |
| `chapter.unlock_progress` | Unlock progress | Kilidi açma ilerlemesi |
| `chapter.current_progress` | Current progress | Mevcut ilerleme |
| `chapter.locked` | Locked | Kilitli |
| `chapter.no_levels_status` | New levels are coming soon | Yeni seviyeler yakında geliyor |
| `chapter.coming_soon` | Coming Soon | Yakında |

## Gameplay: HUD, level screens and results

| Key | English | Türkçe |
| --- | --- | --- |
| `hud.level` | LEVEL %d | SEVİYE %d |
| `hud.combo` | COMBO ×%d | KOMBO ×%d |
| `hud.ability_tooltip.hammer` | Hammer -- clears a matching triple | Çekiç -- eşleşen bir üçlüyü temizler |
| `hud.ability_tooltip.shuffle` | Shuffle -- reshuffles unlocked items | Karıştır -- kilidi açık ürünlerin yerlerini değiştirir |
| `hud.ability_tooltip.lantern` | Lantern -- highlights a matchable triple | Fener -- eşleştirilebilen bir üçlüyü vurgular |
| `hud.ability_tooltip.freezer` | Freezer -- pauses the countdown timer | Dondurucu -- geri sayımı duraklatır |
| `hud.seconds_short` | %ds | %d sn |
| `tip.tap_dispenser` | Tap a dispenser to throw items onto the shelves! | Ürünleri raflara atmak için dağıtıcıya dokun! |
| `pause.title` | PAUSE | DURAKLATILDI |
| `pause.leave` | Leave | Çık |
| `leave.title` | LEAVING THE LEVEL | SEVİYEDEN ÇIKIŞ |
| `leave.you_will_lose` | You will lose: | Kaybedeceklerin: |
| `leave.confirm` | Leave | Çık |
| `timeup.title` | TIME'S UP | SÜRE DOLDU |
| `timeup.offer` | Add one minute and keep sorting! | Bir dakika ekle ve sıralamaya devam et! |
| `timeup.used` | Used | Kullanıldı |
| `ability_purchase.title` | USE ABILITY | GÜÇLENDİRİCİ KULLAN |
| `shelf_unlock.title` | UNLOCK SHELF | RAFIN KİLİDİNİ AÇ |
| `shelf_unlock.offer` | Watch one ad to unlock this shelf now. | Bu rafın kilidini hemen açmak için bir reklam izle. |
| `shelf_unlock.offer_or_clear` | Watch one ad to unlock this shelf now, or clear %s more. | Bu rafın kilidini hemen açmak için bir reklam izle ya da %s üçlü daha temizle. |
| `shelf_unlock.button` | Watch Ad · Unlock Shelf | Reklam İzle · Rafı Aç |
| `shelf_unlock.ad_unavailable` | Ad unavailable. This shelf stays locked. | Reklam kullanılamıyor. Bu raf kilitli kalacak. |
| `complete.title` | GREAT JOB! | TEBRİKLER! |
| `failed.title` | LEVEL %d | SEVİYE %d |
| `failed.headline` | LEVEL FAILED | SEVİYE GEÇİLEMEDİ |
| `failed.retry` | Retry | Tekrar Oyna |
| `combo.praise.2` | Cool | Güzel |
| `combo.praise.3` | Great | Harika |
| `combo.praise.4` | Awesome | Süper |
| `combo.praise.5` | Amazing | Müthiş |
| `combo.praise.6` | Fantastic | Muhteşem |
| `combo.praise.7` | Incredible | İnanılmaz |
| `combo.praise.8` | Spectacular | Göz Kamaştırıcı |
| `combo.praise.9` | Unstoppable | Durdurulamaz |
| `combo.praise.10` | Legendary | Efsanevi |
| `combo.praise.11` | Epic | Destansı |
| `combo.praise.12` | Brilliant | Dahice |
| `combo.praise.13` | Masterful | Ustaca |
| `combo.praise.14` | Supreme | Rakipsiz |
| `combo.praise.15` | Phenomenal | Olağanüstü |
| `combo.praise.16` | Mythic | Efsane Ötesi |
| `combo.praise.17` | Majestic | Görkemli |
| `combo.praise.18` | Radiant | Işıl Işıl |
| `combo.praise.19` | Divine | Kusursuz |
| `combo.praise.20` | Transcendent | Sınırların Ötesinde |

## Boosters, ads, lives, rewards and shop

| Key | English | Türkçe |
| --- | --- | --- |
| `ability.hammer.name` | Hammer | Çekiç |
| `ability.shuffle.name` | Shuffle | Karıştır |
| `ability.lantern.name` | Lantern | Fener |
| `ability.freezer.name` | Freezer | Dondurucu |
| `ability.hammer.description` | Instantly clears one matching set of items off the shelves. | Raflardaki eşleşen bir ürün üçlüsünü anında temizler. |
| `ability.shuffle.description` | Shuffles shelf items into new spots to help you find a match. | Eşleşme bulmana yardımcı olmak için raflardaki ürünlerin yerlerini değiştirir. |
| `ability.lantern.description` | Highlights a matching triple you can clear for 15 seconds. | Temizleyebileceğin eşleşen bir üçlüyü 15 saniye boyunca vurgular. |
| `ability.freezer.description` | Freezes the level timer for 30 seconds. | Seviye süresini 30 saniye boyunca dondurur. |
| `ad.watch` | Watch Ad | Reklam İzle |
| `ad.loading` | Loading... | Yükleniyor... |
| `ad.verifying` | Verifying... | Doğrulanıyor... |
| `ad.verify_reward` | Verify Reward | Ödülü Doğrula |
| `ad.reward_pending` | Reward verification is still pending. | Ödül doğrulaması hâlâ beklemede. |
| `ad.unavailable_retry` | Ad unavailable. Please try again. | Reklam kullanılamıyor. Lütfen tekrar dene. |
| `ad.watch_unavailable` | `Watch Ad\nUnavailable` | `Reklam İzle\nKullanılamıyor` |
| `ad.watch_coming_soon` | `Watch Ad\nComing Soon` | `Reklam İzle\nYakında` |
| `ad.badge` | AD | AD |
| `lives.title.out` | OUT OF LIVES | CAN KALMADI |
| `lives.title.get_more` | GET MORE LIVES | DAHA FAZLA CAN AL |
| `lives.title.full` | LIVES FULL | CANLAR DOLU |
| `lives.next_in` | NEXT LIFE IN | YENİ CANA KALAN SÜRE |
| `lives.full_body` | Your lives are full! Play a level to spend them. | Canların dolu! Onları kullanmak için bir seviye oyna. |
| `chest.title` | CHEST REWARDS | SANDIK ÖDÜLLERİ |
| `chest.progress_hint` | Collect stars to unlock a chest and claim your reward | Sandığın kilidini açmak ve ödülünü almak için yıldız topla |
| `chest.ready` | A REWARD CHEST AWAITS! | ÖDÜL SANDIĞIN HAZIR! |
| `chest.tap_to_open` | Tap to open | Açmak için dokun |
| `purchase.tap_to_collect` | Tap to collect | Almak için dokun |
| `purchase.complete` | PURCHASE COMPLETE | SATIN ALMA TAMAMLANDI |
| `shop.title` | SHOP | MAĞAZA |
| `shop.section.bundles` | SPECIAL BUNDLES | ÖZEL PAKETLER |
| `shop.section.coins` | COINS | PARA |
| `shop.offer.starter_bundle` | Starter Bundle | Başlangıç Paketi |
| `shop.offer.basic_bundle` | Basic Bundle | Temel Paket |
| `shop.tag.best_value` | BEST VALUE | EN AVANTAJLI |
| `shop.discount_off` | OFF | OFF |
| `shop.ability_hint` | Tap an ability to see what it does | Ne yaptığını görmek için güçlendiriciye dokun |
| `shop.purchasing` | Purchasing… | Satın alınıyor… |
| `shop.no_offers` | No shop offers are available for this region. | Bu bölge için mağaza teklifi bulunmuyor. |
| `shop.load_failed` | Could not load the shop. | Mağaza yüklenemedi. |
| `shop.error.title.purchase` | Purchase unavailable | Satın alma yapılamıyor |
| `shop.error.title.reward` | Reward error | Ödül hatası |
| `shop.error.purchase_failed` | The purchase could not be completed. | Satın alma tamamlanamadı. |
| `shop.error.grant_failed` | The purchased rewards could not be granted. | Satın alınan ödüller verilemedi. |
| `shop.error.offer_unavailable` | This shop offer is unavailable. | Bu mağaza teklifi mevcut değil. |
| `shop.error.already_bought` | This one-time shop offer has already been purchased. | Bu tek seferlik mağaza teklifi zaten satın alındı. |
| `starter.title` | STARTER BUNDLE | BAŞLANGIÇ PAKETİ |
| `starter.one_time` | ONE-TIME OFFER | TEK SEFERLİK TEKLİF |
| `starter.boosters_included` | BOOSTERS INCLUDED | GÜÇLENDİRİCİLER DAHİL |
| `starter.coins` | %s COINS | %s PARA |
| `starter.buy_for` | Buy for %s | %s karşılığında al |
| `starter.checking` | Checking offer… | Teklif kontrol ediliyor… |
| `starter.checking_short` | Checking… | Kontrol ediliyor… |
| `starter.no_longer_available` | This offer is no longer available. | Bu teklif artık mevcut değil. |
| `starter.unavailable` | Unavailable | Mevcut Değil |
| `booster_chip.claimed` | +%d %s | +%d %s |

## Profile, leaderboard and settings

| Key | English | Türkçe |
| --- | --- | --- |
| `profile.title` | EDIT PROFILE | PROFİLİ DÜZENLE |
| `profile.name_header` | PLAYER NAME | OYUNCU ADI |
| `profile.name_placeholder` | Player name | Oyuncu adı |
| `profile.edit_name_tooltip` | Edit player name | Oyuncu adını düzenle |
| `profile.avatar_tab` | AVATAR | AVATAR |
| `profile.frame_tab` | FRAME | ÇERÇEVE |
| `profile.unlock.level` | Complete level %d to unlock | Kilidi açmak için %d. seviyeyi tamamla |
| `profile.unlock.combo` | Reach a combo of ×%d in any run to unlock | Kilidi açmak için herhangi bir denemede ×%d kombo yap |
| `profile.unlock.weekly_first` | Finish 1st on the Weekly leaderboard to unlock | Kilidi açmak için haftalık sıralamayı 1. sırada bitir |
| `profile.unlock.weekly_top` | Finish top %d on the Weekly leaderboard to unlock | Kilidi açmak için haftalık sıralamayı ilk %d oyuncu arasında bitir |
| `leaderboard.title` | LEADERBOARD | SIRALAMA |
| `leaderboard.tab.weekly` | Weekly | Haftalık |
| `leaderboard.tab.country` | Country | Ülke |
| `leaderboard.tab.world` | World | Dünya |
| `leaderboard.weekly_reset` | Weekly reset in %s | Haftalık sıfırlamaya %s kaldı |
| `leaderboard.duration.dh` | %dd %dh | %dg %dsa |
| `leaderboard.duration.hm` | %dh %dm | %dsa %ddk |
| `leaderboard.duration.m` | %dm | %ddk |
| `leaderboard.country_caption` | Country · All-time stars | Ülke · Toplam yıldız |
| `leaderboard.world_caption` | Worldwide · All-time stars | Dünya · Toplam yıldız |
| `leaderboard.load_failed` | Could not load leaderboard. | Sıralama yüklenemedi. |
| `leaderboard.default_name` | Player | Oyuncu |
| `leaderboard.row_tooltip` | Rank %d, %s, %d stars | Sıra %d, %s, %d yıldız |
| `leaderboard.reward_tooltip` | %s coin weekly reward | Haftalık ödül: %s para |
| `leaderboard.reward.title` | WEEKLY REWARD! | HAFTALIK ÖDÜL! |
| `leaderboard.reward.body` | You finished #%d last week and earned %d coins! | Geçen haftayı %d. sırada bitirip %d para kazandın! |
| `leaderboard.reward.ok` | Nice! | Süper! |
| `settings.title` | SETTINGS | AYARLAR |
| `settings.music` | Music | Müzik |
| `settings.sfx` | SFX | Sesler |
| `settings.vibrate` | Vibrate | Titreşim |
| `settings.support` | Support | Destek |
| `settings.language` | Language | Dil |
| `settings.privacy_policy` | Privacy Policy | Gizlilik Politikası |
| `settings.privacy_choices` | Privacy Choices | Gizlilik Tercihleri |
| `settings.diagnostics` | `Version %s • Build %d\nPlatform: %s • User: %s` | `Sürüm %s • Derleme %d\nPlatform: %s • Kullanıcı: %s` |
| `language.title` | LANGUAGE | DİL |

## Support, account deletion and platform text

### Support screen

| Key | English | Türkçe |
| --- | --- | --- |
| `support.title` | SUPPORT | DESTEK |
| `support.faq_header` | Frequently Asked Questions | Sıkça Sorulan Sorular |
| `support.faq.play.q` | How do I play? | Nasıl oynarım? |
| `support.faq.play.a` | Move matching goods onto the same shelf. When three identical items are visible together, they clear. Complete the board before time runs out. | Eşleşen ürünleri aynı rafa taşı. Aynı rafta üç özdeş ürün bir araya geldiğinde temizlenir. Süre dolmadan tüm ürünleri temizle. |
| `support.faq.contact.q` | How do I contact support? | Destekle nasıl iletişime geçerim? |
| `support.faq.contact.a` | Email us at %s. Include a short description, your device platform, and when the problem happened. | Bize ulaşmak için %s adresine e-posta gönder. Kısa bir açıklama, cihazının platformunu ve sorunun ne zaman yaşandığını belirt. |
| `support.faq.contact.action` | Email Support | Desteğe Yaz |
| `support.faq.crash.q` | What if the game freezes or crashes? | Oyun donarsa veya çökerse ne yapmalıyım? |
| `support.faq.crash.a` | Close and reopen the game first. If it happens again, restart the device and make sure the game is updated. Contact support with the device model, platform version, and what you were doing before the problem. | Önce oyunu kapatıp yeniden aç. Sorun tekrarlanırsa cihazını yeniden başlat ve oyunun güncel olduğundan emin ol. Cihaz modelini, platform sürümünü ve sorun ortaya çıkmadan önce ne yaptığını belirterek destekle iletişime geç. |
| `support.faq.sync.q` | How do I sync progress between devices? | İlerlememi cihazlar arasında nasıl senkronize ederim? |
| `support.faq.sync.a` | Use the same signed-in platform account on both devices and allow synchronization to finish before playing. If the progress differs, avoid playing on both devices and contact support. | Her iki cihazda da aynı platform hesabında oturum aç ve oynamadan önce senkronizasyonun tamamlanmasını bekle. İlerleme farklıysa iki cihazda birden oynamaktan kaçın ve destekle iletişime geç. |
| `support.faq.bad_ad.q` | How do I report a bad ad? | Uygunsuz bir reklamı nasıl bildiririm? |
| `support.faq.bad_ad.a` | `1. Close the ad if you can do so safely.\n2. Take a screenshot of the ad and any advertiser or app name shown.\n3. Note the approximate time and where the ad appeared in the game.\n4. Describe why the ad seemed offensive, misleading, or fraudulent.\n5. Email these details to %s. Do not include passwords or payment information.` | `1. Güvenli bir şekilde yapabiliyorsan reklamı kapat.\n2. Reklamın ve gösterilen reklamveren veya uygulama adının ekran görüntüsünü al.\n3. Yaklaşık zamanı ve reklamın oyunda nerede göründüğünü not et.\n4. Reklamın neden rahatsız edici, yanıltıcı veya dolandırıcılık amaçlı göründüğünü açıkla.\n5. Bu bilgileri %s adresine e-posta ile gönder. Şifre veya ödeme bilgisi ekleme.` |
| `support.faq.bad_ad.action` | Email Ad Report | Reklamı Bildir |
| `support.account_header` | Account | Hesap |
| `support.delete_account` | Delete Account | Hesabı Sil |
| `support.delete_game_data` | Delete Game Data | Oyun Verilerini Sil |
| `support.no_secrets` | Please never send passwords or payment information. | Lütfen asla şifre veya ödeme bilgisi gönderme. |

### Account deletion modal

| Key | English | Türkçe |
| --- | --- | --- |
| `deletion.title.delete_account` | DELETE ACCOUNT | HESABI SİL |
| `deletion.title.delete_game_data` | DELETE GAME DATA | OYUN VERİLERİNİ SİL |
| `deletion.title.not_confirmed` | NOT CONFIRMED | DOĞRULANMADI |
| `deletion.title.status_unconfirmed` | STATUS UNCONFIRMED | DURUM DOĞRULANMADI |
| `deletion.title.finishing_up` | FINISHING UP | TAMAMLANIYOR |
| `deletion.title.new_game` | NEW GAME | YENİ OYUN |
| `deletion.title.status_unknown` | STATUS UNKNOWN | DURUM BİLİNMİYOR |
| `deletion.title.not_deleted` | NOT DELETED | SİLİNMEDİ |
| `deletion.title.data_deleted` | DATA DELETED | VERİLER SİLİNDİ |
| `deletion.title.accepted` | DELETION ACCEPTED | SİLME İSTEĞİ KABUL EDİLDİ |
| `deletion.confirm.headline` | This permanently deletes your account. | Bu işlem hesabını kalıcı olarak siler. |
| `deletion.confirm.body` | `Your progress, coins, items, and profile will be gone. You can't undo this.\n\nIf you sign in again later, you'll start a new account.\n\nSome purchase and security records are kept without your name or profile. The rest is removed within 30 days.` | `İlerlemen, paran, ürünlerin ve profilin silinecek. Bu işlemi geri alamazsın.\n\nDaha sonra yeniden oturum açarsan yeni bir hesapla başlayacaksın.\n\nBazı satın alma ve güvenlik kayıtları, adınla veya profilinle ilişkilendirilmeden saklanır. Diğer veriler 30 gün içinde silinir.` |
| `deletion.confirm.button` | Delete Account | Hesabı Sil |
| `deletion.local_confirm.headline` | This deletes your game data on this device. | Bu işlem bu cihazdaki oyun verilerini siler. |
| `deletion.local_confirm.body` | `Your progress, coins, items, and profile will be gone. You can't undo this.\n\nThis game never created an online account for you, so nothing needs to be deleted from our servers.` | `İlerlemen, paran, ürünlerin ve profilin silinecek. Bu işlemi geri alamazsın.\n\nBu oyun senin için hiç çevrimiçi hesap oluşturmadı, bu yüzden sunucularımızdan silinecek bir şey yok.` |
| `deletion.local_confirm.button` | Delete Data | Verileri Sil |
| `deletion.pending_setup.headline` | Your account is still being set up. | Hesabın hâlâ oluşturuluyor. |
| `deletion.pending_setup.body` | Connect to the internet and try again in a moment. Nothing was deleted. | İnternete bağlan ve biraz sonra tekrar dene. Hiçbir şey silinmedi. |
| `deletion.sign_in.headline` | Sign in to the account you want to delete. | Silmek istediğin hesapta oturum aç. |
| `deletion.sign_in.body` | If you can't sign in, contact support for help. | Oturum açamıyorsan yardım almak için destekle iletişime geç. |
| `deletion.read_failed.headline` | Your game data couldn't be read. | Oyun verilerin okunamadı. |
| `deletion.read_failed.body` | Restart the game, then try again. Nothing was deleted. | Oyunu yeniden başlat, ardından tekrar dene. Hiçbir şey silinmedi. |
| `deletion.unavailable.headline` | Account deletion isn't available in this version of the game. | Oyunun bu sürümünde hesap silme özelliği kullanılamıyor. |
| `deletion.unavailable.body` | Update the game, or contact support for help deleting your account. Nothing was deleted. | Oyunu güncelle veya hesabını silmek için destekten yardım al. Hiçbir şey silinmedi. |
| `deletion.in_progress.account` | Deleting your account... | Hesabın siliniyor... |
| `deletion.in_progress.local` | Deleting your game data... | Oyun verilerin siliniyor... |
| `deletion.in_progress.body` | Keep the game open. This only takes a moment. | Oyunu açık tut. Bu işlem yalnızca kısa bir süre alır. |
| `deletion.not_confirmed.headline` | We haven't heard back about your deletion yet. | Silme isteğinle ilgili henüz yanıt almadık. |
| `deletion.not_confirmed.body` | Your request was sent, but the answer didn't arrive. Connect to the internet and try again. The game stays locked until we know the result. | İsteğin gönderildi, ancak yanıt ulaşmadı. İnternete bağlan ve tekrar dene. Sonucu öğrenene kadar oyun kilitli kalacak. |
| `deletion.unconfirmed.headline` | Deletion status unconfirmed | Silme durumu doğrulanmadı |
| `deletion.unconfirmed.body` | We couldn't confirm whether your account was deleted. To keep your data safe, the game stays locked. Contact support and include the reference below. | Hesabının silinip silinmediğini doğrulayamadık. Verilerini güvende tutmak için oyun kilitli kalacak. Destekle iletişime geç ve aşağıdaki referansı belirt. |
| `deletion.check_again` | Check Again | Tekrar Kontrol Et |
| `deletion.cleanup.headline.local` | Your local game data couldn't be fully deleted yet. | Yerel oyun verilerin henüz tamamen silinemedi. |
| `deletion.cleanup.headline.account` | Account deletion accepted; finishing cleanup. | Hesap silme isteği kabul edildi; son işlemler tamamlanıyor. |
| `deletion.cleanup.body` | Some game data couldn't be removed from this device yet. Try again to finish. | Bazı oyun verileri henüz bu cihazdan silinemedi. Tamamlamak için tekrar dene. |
| `deletion.new_game.headline` | Starting a new game... | Yeni oyun başlatılıyor... |
| `deletion.new_game.body` | This only takes a moment. | Bu işlem yalnızca kısa bir süre alır. |
| `deletion.status_unknown.headline` | We couldn't read the deletion status on this device. | Bu cihazdaki silme durumunu okuyamadık. |
| `deletion.status_unknown.body` | To keep your data safe, the game stays locked. Contact support for help. | Verilerini güvende tutmak için oyun kilitli kalacak. Yardım almak için destekle iletişime geç. |
| `deletion.fail.offline` | Connect to the internet to delete your account. | Hesabını silmek için internete bağlan. |
| `deletion.fail.rate_limited` | Too many attempts. Wait a moment, then try again. | Çok fazla deneme yapıldı. Biraz bekle, ardından tekrar dene. |
| `deletion.fail.busy` | Account deletion is busy right now. Try again in a moment. | Hesap silme sistemi şu anda yoğun. Biraz sonra tekrar dene. |
| `deletion.fail.syncing` | The game is still syncing. Try again in a moment. | Oyun hâlâ senkronize ediliyor. Biraz sonra tekrar dene. |
| `deletion.fail.auth` | We couldn't verify your account. Restart the game, then try again. | Hesabını doğrulayamadık. Oyunu yeniden başlat, ardından tekrar dene. |
| `deletion.fail.update` | Update the game to delete your account. | Hesabını silmek için oyunu güncelle. |
| `deletion.fail.changed` | Your account changed while we were deleting it. Try again. | Silme işlemi sırasında hesabın değişti. Tekrar dene. |
| `deletion.fail.storage` | Your device couldn't save the deletion request. Try again. | Cihazın silme isteğini kaydedemedi. Tekrar dene. |
| `deletion.fail.generic` | We couldn't delete your account. Try again later or contact support. | Hesabını silemedik. Daha sonra tekrar dene veya destekle iletişime geç. |
| `deletion.fail.local` | Your game data couldn't be deleted. Try again. | Oyun verilerin silinemedi. Tekrar dene. |
| `deletion.fail.body` | Nothing was deleted, and you can keep playing. | Hiçbir şey silinmedi ve oynamaya devam edebilirsin. |
| `deletion.done_local.headline` | Your local game data was deleted. | Yerel oyun verilerin silindi. |
| `deletion.done_local.body` | You can start over with a new game. | Yeni bir oyunla baştan başlayabilirsin. |
| `deletion.new_game_failed` | The new game couldn't start. Try again. | Yeni oyun başlatılamadı. Tekrar dene. |
| `deletion.accepted.headline` | Your account is no longer accessible. | Hesabına artık erişilemiyor. |
| `deletion.accepted.body` | Your deletion request was accepted. | Silme isteğin kabul edildi. |
| `deletion.accepted.body_deadline` | Your deletion request was accepted. Data removal is due by %s. | Silme isteğin kabul edildi. Verilerin silinmesi için son tarih: %s. |
| `deletion.reference` | Reference: %s | Referans: %s |
| `deletion.start_new_game` | Start New Game | Yeni Oyun Başlat |

### Platform and system text

| Key | English | Türkçe |
| --- | --- | --- |
| `app.name` | SortingPuzzle | SortingPuzzle |
| `support.email.subject` | Sorting Puzzle support request | Sorting Puzzle destek talebi |
| `support.email.body` | `Please describe the issue here.\n\nDevice/platform:\nApproximate time:\n` | `Lütfen sorunu burada açıkla.\n\nCihaz/platform:\nYaklaşık zaman:\n` |
| `support.ad_email.subject` | Sorting Puzzle ad report | Sorting Puzzle reklam bildirimi |
| `support.ad_email.body` | `Please attach a screenshot and complete the details below.\n\nApproximate time:\nAd placement in the game:\nAdvertiser or app name:\nWhy the ad should be reviewed:\n` | `Lütfen bir ekran görüntüsü ekle ve aşağıdaki bilgileri doldur.\n\nYaklaşık zaman:\nReklamın oyundaki yeri:\nReklamveren veya uygulama adı:\nReklamın neden incelenmesi gerektiği:\n` |
| `deletion.email.subject` | Sorting Puzzle account deletion | Sorting Puzzle hesap silme talebi |
| `deletion.email.body` | Please help me with my account deletion. | Lütfen hesabımı silme konusunda bana yardımcı olun. |

## Additional labels mentioned in the inventory

These four deletion-help email labels are mentioned in the context for `deletion.email.body`, without separate inventory keys. Reference and player-ID values remain unchanged.

| English label | Türkçe |
| --- | --- |
| Status: | Durum: |
| Deletion reference: | Silme referansı: |
| Server reference: | Sunucu referansı: |
| Player ID: | Oyuncu kimliği: |
