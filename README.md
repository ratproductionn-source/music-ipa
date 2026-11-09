# Sdab (ស្ដាប់) — ទាញយកពី YouTube ទុកស្ដាប់ Offline

App iOS (SwiftUI) សម្រាប់ទាញយកសំឡេង ឬវីដេអូពី YouTube ហើយស្ដាប់ពេលគ្មាន internet។

**មុខងារ**
- បិទភ្ជាប់ link (youtube.com, youtu.be, Shorts, music.youtube.com) → ចុច «ទាញយក»
- **សំឡេង M4A** (គុណភាពខ្ពស់បំផុត) ឬ **វីដេអូ MP4** រហូតដល់ 360p / 720p / 1080p
- បណ្ណាល័យ៖ ស្វែងរក, តម្រង សំឡេង/វីដេអូ, ចាក់ទាំងអស់, ចាក់ចៃដន្យ, លុប, ចែករំលែក
- Player៖ ចាក់ពេលចាក់សោអេក្រង់ (background), ប៊ូតុងលើ Lock Screen / Control Center, ល្បឿន 0.75x–2x, លោត ±15 វិនាទី, Repeat, AirPlay/Bluetooth
- ឯកសារមើលឃើញក្នុង app **Files** (On My iPhone › Sdab › Media)
- ផ្ញើ link ពី Share sheet ផ្ទាល់តាមរយៈ Shortcut (មើលផ្នែក ៥)

> ⚠️ លក្ខខណ្ឌរបស់ YouTube មិនអនុញ្ញាតឱ្យទាញយកក្រៅពី YouTube Premium ទេ។ សូមប្រើសម្រាប់ផ្ទាល់ខ្លួន ឬវីដេអូដែលអ្នកមានសិទ្ធិ។ App នេះមិនអាចដាក់លើ App Store បានទេ ត្រូវដំឡើងដោយខ្លួនឯង (sideload)។

---

## ១. បង្កើតឯកសារ .ipa (មិនចាំបាច់មាន Mac)

GitHub មានម៉ាស៊ីន Mac ឥតគិតថ្លៃសម្រាប់ build។

1. បង្កើតគណនី [github.com](https://github.com) (បើមិនទាន់មាន)
2. ចុច **New repository** → ដាក់ឈ្មោះ `Sdab` → ជ្រើស **Private** → **Create repository**
3. ចុច **uploading an existing file** → ពន្លា (unzip) folder `Sdab` រួចទាញ **ឯកសារ និង folder ទាំងអស់ដែលនៅខាងក្នុង** ចូល (ត្រូវមាន `project.yml` នៅខាងលើគេ)
   - Folder `.github` ត្រូវបានលាក់នៅលើ Mac/Windows។ បើវាមិនចូល៖ ចុច **Add file › Create new file** វាយឈ្មោះ `.github/workflows/build-ipa.yml` ហើយ copy ខ្លឹមសារពីឯកសារនោះដាក់
4. ចុច **Commit changes** → ចូល tab **Actions** → វានឹង build ដោយស្វ័យប្រវត្តិ (~៥–១០ នាទី)
   - បើមិនឃើញវាដំណើរការ៖ ចុច **Build IPA › Run workflow**
5. ពេលឃើញសញ្ញា ✅ ចុចលើការ build នោះ → ក្នុងផ្នែក **Artifacts** ទាញយក **Sdab-ipa** → ពន្លា zip → បានឯកសារ `Sdab.ipa`

ឯកសារនេះមិនទាន់មានហត្ថលេខា (unsigned) — ជំហានបន្ទាប់នឹងចុះហត្ថលេខាដោយ Apple ID របស់អ្នក។

## ២. ដំឡើងលើ iPhone

### ជម្រើស A — Sideloadly (Windows ឬ Mac, ងាយបំផុត)
1. ដំឡើង [Sideloadly](https://sideloadly.io) (Windows ត្រូវមាន iTunes ពី apple.com, មិនមែនពី Microsoft Store)
2. ភ្ជាប់ iPhone ទៅកុំព្យូទ័រតាមខ្សែ → ចុច **Trust** លើ iPhone
3. ទាញ `Sdab.ipa` ចូល Sideloadly → វាយ Apple ID → ចុច **Start**
4. នៅលើ iPhone៖
   - **Settings › General › VPN & Device Management** → ចុចលើ Apple ID របស់អ្នក → **Trust**
   - iOS 16 ឡើងទៅ៖ **Settings › Privacy & Security › Developer Mode** → បើក → iPhone នឹង restart

> Apple ID ឥតគិតថ្លៃ៖ app ដំណើរការបាន **៧ ថ្ងៃ** បន្ទាប់មកត្រូវដំឡើងម្ដងទៀតដោយ Sideloadly (ឯកសារដែលទាញយករួចមិនបាត់ទេ ប្រសិនបើប្រើ Apple ID ដដែល)។ គណនី Apple Developer ($99/ឆ្នាំ) ដំណើរការបាន ១ ឆ្នាំ។ បើព្រួយបារម្ភពីការវាយ Apple ID ក្នុង app ផ្សេង អាចបង្កើត Apple ID ថ្មីសម្រាប់ការនេះ។

### ជម្រើស B — AltStore / SideStore
ដំឡើង [AltStore](https://altstore.io) ឬ [SideStore](https://sidestore.io) ម្ដង រួចបើក `Sdab.ipa` ជាមួយវា។ វាអាចបន្តអាយុ ៧ ថ្ងៃដោយស្វ័យប្រវត្តិ (SideStore ធ្វើបានដោយមិនចាំបាច់ភ្ជាប់កុំព្យូទ័រ)។

## ៣. បើមាន Mac (build ដោយ Xcode ផ្ទាល់)

```bash
brew install xcodegen
cd Sdab
xcodegen generate
open Sdab.xcodeproj
```
ក្នុង Xcode៖ ជ្រើស target **Sdab › Signing & Capabilities** → ជ្រើស **Team** (Apple ID របស់អ្នក) → ប្ដូរ Bundle Identifier ឱ្យខុសពីគេ (ឧ. `com.yourname.sdab`) → ភ្ជាប់ iPhone → ចុច ▶︎ Run។

## ៤. របៀបប្រើ

1. បើក YouTube → **Share › Copy link**
2. បើក Sdab → tab **ទាញយក** → ចុច **Paste**
3. ជ្រើស **សំឡេង (M4A)** ឬ **វីដេអូ (MP4)** → ចុច **ទាញយក**
4. ពេលរួចរាល់ វានឹងនៅក្នុង tab **បណ្ណាល័យ** → ចុចដើម្បីស្ដាប់
   - ចុចសង្កត់លើបទ៖ មើលវីដេអូ, ចែករំលែក/រក្សាទុក, លុប
   - ចុចលើរបារ player ខាងក្រោម ដើម្បីបើក player ពេញអេក្រង់

**ចំណាំ៖** សូមបើក app ទុកពេលកំពុងទាញយក។ iOS អនុញ្ញាតឱ្យទាញយកបន្តតែមួយរយៈខ្លីប៉ុណ្ណោះពេលចេញពី app។

## ៥. (ជម្រើស) ផ្ញើ link ពី Share sheet តែម្ដង

បង្កើត Shortcut មួយ ដើម្បីចុច **Share › Sdab** ក្នុង app YouTube ដោយមិនចាំបាច់ copy/paste៖

1. បើក app **Shortcuts** → **+**
2. ចុច ⓘ (ឬ settings) → បើក **Show in Share Sheet** → Share Sheet Types៖ ជ្រើសតែ **URLs** និង **Text**
3. បន្ថែម action **URL Encode** (input = Shortcut Input)
4. បន្ថែម action **Open URLs** ហើយវាយ៖
   ```
   sdab://download?url=[URL Encoded Text]&kind=audio
   ```
   (`[URL Encoded Text]` គឺជា variable ពីជំហានទី ៣ — ចុចដើម្បីជ្រើសវា។ ប្ដូរ `audio` ទៅ `video` បើចង់បានវីដេអូ)
5. ដាក់ឈ្មោះ Shortcut ថា **Sdab**

## ៦. ពេលវាឈប់ដំណើរការ

YouTube ផ្លាស់ប្ដូរប្រព័ន្ធរបស់ខ្លួនជាញឹកញាប់។ App ប្រើ library [YouTubeKit](https://github.com/alexeichhorn/YouTubeKit) ហើយមានមុខងារ remote fallback ដែលជួយបន្តដំណើរការមួយរយៈ។ បើនៅតែទាញយកមិនបាន៖
- ចូល GitHub › **Actions › Build IPA › Run workflow** ដើម្បី build ម្ដងទៀតជាមួយ YouTubeKit ថ្មីបំផុត
- ដំឡើង `Sdab.ipa` ថ្មីជាន់លើ app ចាស់ (ឯកសារដែលបានទាញយករួចនៅដដែល)

**ដែនកំណត់**
- មិនទាន់គាំទ្រ playlist ទាំងមូល (ទាញយកម្ដងមួយវីដេអូ)
- វីដេអូ private, សម្រាប់សមាជិក ឬកំណត់អាយុ មិនអាចទាញយកបាន
- ឯកសារ M4A ចាក់បានក្នុង app នេះ, Files, VLC ជាដើម

## រចនាសម្ព័ន្ធ code

```
Sdab/
├── project.yml                     XcodeGen (បង្កើត Sdab.xcodeproj)
├── .github/workflows/build-ipa.yml GitHub Actions → Sdab.ipa
└── Sdab/
    ├── App/SdabApp.swift
    ├── Models/       Track, Library (JSON), Storage, YouTubeLink (parse link)
    ├── Download/     DownloadManager (YouTubeKit), ChunkedDownloader (Range 2MB), MediaMerger (720p/1080p)
    ├── Player/       AudioPlayer (background, Lock Screen, queue)
    └── Views/        Library, Download, Mini player, Now Playing, Video
```
