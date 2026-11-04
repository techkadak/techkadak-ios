# Tech Kadak — iPhone app

SwiftUI app for **Tech Kadak** (free & open-source apps ka adda). Data: https://techkadak.github.io/data/apps.json

- Splash animation + intro, Naye apps, Aaj ka app, Kits, categories, Tech Kadak videos
- Search, favourites, share poster, themes (AMOLED / Dark / Light / Liquid Glass)
- "GET" opens each app's official link (iOS can't install other apps)

## Download
Latest unsigned IPA: see **Releases** → `TechKadak-iOS-v1.0.ipa`. Sign/sideload it with your own tool.

Built by GitHub Actions (`.github/workflows/build.yml`): XcodeGen → xcodebuild (no signing) → `Payload/TechKadak.app` → IPA, plus an iOS Simulator launch test.

Developer: Rohit Saini • Instagram [@techkadak](https://www.instagram.com/techkadak/) • [YouTube](https://www.youtube.com/channel/UCpxdwzHB-66cPyssRH5IaTA) • [Telegram](https://t.me/techkadak)
