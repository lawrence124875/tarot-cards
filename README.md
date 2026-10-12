# 塔羅 Tarot · LC Lab

以七十八張塔羅牌為題材的學習與自我反思 App（Flutter，套件名稱 `com.lclab.tarot`）。
抽牌、牌義解讀、塔羅日記、今日一張、認牌學習與呼吸音景；解讀全部預先寫好，不使用 AI，使用者寫下的文字只存在手機本機。

- 隱私權政策：[`docs/privacy.html`](docs/privacy.html)（GitHub Pages 由 `docs/` 發佈）

## 這個 repo 放什麼

本 repo 是**公開的，只放程式碼**。牌義解讀內容與牌面圖片放在私人 repo **tarot-content**，
建置時由 `scripts/import_content.sh <tarot-content 路徑>` 複製進來：

- `assets/content/<語言>/`：`00.json`–`77.json`（每張牌）、`spreads.json`、`atmosphere.json`、`lessons.json`
- `assets/decks/`：`decks.json` 與各牌面組的 `deck.json`、`00.webp`–`77.webp`、`back.webp`

這些檔案不進公開 repo；腳本在 CI 紀錄裡只印數量，不印檔名或內容。

## 建置（CI）

- **測試版 APK** 由 tarot-content 自己的 workflow 建置，並發佈為 tarot-content 的 Releases。
- 本 repo 的 `.github/workflows/build_android.yml` 目前**只能手動執行**（workflow_dispatch），
  需要 Secret `BUILDS_REPO_TOKEN`（讀取私人內容、發佈到 tarot-content 的 Release）。
- `scripts/patch_*.sh` 在 CI 中補上 Android／iOS、Firebase 與 AdMob 的平台設定。

## 架構

```
lib/
  main.dart            進入點
  app/                 App 外殼：主題、首頁、服務組裝（services.dart）
    feature_registry.dart  功能註冊表：增減功能＝增減一行；可用 Remote Config（tr_feature_<id>）遠端關閉
  core/                不依賴畫面的邏輯
    tarot/             78 張牌、牌陣、抽牌（洗牌／正逆位）、牌陣氣氛規則（atmosphere）
    content/           解讀內容來源（ContentSource，預設讀 assets）
    deck/              牌面組來源（DeckSource，策略模式；缺圖時改用程式畫的牌面）
    journal/           塔羅日記：儲存、備份還原、回顧提醒
    daily/             今日一張
    learn/             認牌小測驗
    soundscape/ audio/ 呼吸音景的合成與播放
    reminders/         本機通知
    telemetry/ firebase/ feedback/  匿名統計、Remote Config、意見回饋
    admob/ revenuecat/ monetization/  廣告、訂閱、免費版次數限制
    settings/ onboarding/ events/
  features/            各功能畫面：draw、daily、learn、journal、breath、
                       settings、share、intro、feedback
  reading/             解讀頁（單張牌詳情、牌陣氣氛、保存到日記）
  shared/              共用元件與格式化
  l10n/                介面翻譯
```

## 介面翻譯

以 ARB 管理，共 11 種語言（zh、zh_Hans、en、ja、ko、vi、es、pt、id、th、ar），
範本為 `lib/l10n/app_zh.arb`（設定見 `l10n.yaml`）。產生的 `app_localizations*.dart`
由 `flutter gen-l10n`／`flutter pub get` 產生。

## 授權與牌面

1909 年原版牌的掃描圖屬公眾領域；選用的 AI 生成牌面在 App 內有清楚標示。

---

LC Lab · lawrence124875@gmail.com
