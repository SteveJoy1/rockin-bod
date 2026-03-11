# RockinBod - AI Fitness Coaching App

## Session Startup

**Before starting any work, run:**
```bash
git fetch origin && git status
```
If the local branch is behind origin/main, run `git pull --rebase` to sync.
Alert the user if there are merge conflicts.

## Overview
RockinBod is an iOS fitness app that combines workout tracking, nutrition monitoring, body composition progress, and AI-powered coaching via the Anthropic Claude API. It integrates with Apple Health, Hevy, Cronometer, and Renpho.

## Tech Stack
- **Language:** Swift 5.9
- **UI:** SwiftUI (no UIKit)
- **Persistence:** SwiftData (iOS 17+)
- **Minimum deployment:** iOS 17.0
- **Build system:** Xcode 15+ / XcodeGen (`project.yml`)
- **Dependencies:** Zero third-party packages — Apple frameworks only (HealthKit, Charts, AVFoundation, PhotosUI, Security)
- **AI:** Direct Anthropic Messages API (claude-sonnet-4-20250514), no SDK wrapper

## Architecture

### Pattern
Service-injection with SwiftUI + SwiftData. No MVVM view models — services are `@Observable` (Swift Observation, not `ObservableObject`) and passed as `let` properties from the app root.

### Boot Flow
```
RockinBodApp (creates ModelContainer + all services)
  └── ContentView
        ├── !hasCompletedOnboarding → OnboardingView
        └── hasCompletedOnboarding  → MainTabView (5 tabs)
              ├── Dashboard
              ├── Nutrition
              ├── Workouts
              ├── Progress
              └── Coach
              + ⚙️ Settings (toolbar gear icon → sheet on every tab)
```

### Services (all in `RockinBod/Services/`)
| Service | Purpose |
|---------|---------|
| `HealthKitService` | Reads/writes Apple Health (workouts, nutrition, body metrics, sleep, steps, HR) |
| `DataAggregationService` | Syncs HealthKit → SwiftData, builds daily/weekly snapshots |
| `AICoachService` | Claude API calls: photo analysis, form check, weekly review, chat |
| `HevyService` | Hevy REST API v1 workout import (optional; HealthKit is primary path) |
| `CronometerService` | CSV import parser + HealthKit nutrition sync detection |
| `RenphoService` | Body composition via HealthKit (no direct Renpho API) |
| `KeychainService` | Static enum for Keychain CRUD (API keys stored here) |
| `VideoProcessingService` | Static enum for video frame extraction (form check) |

### Models (all SwiftData `@Model` in `RockinBod/Models/`)
`UserProfile`, `WorkoutSession`, `ExerciseSet`, `NutritionEntry`, `BodyMeasurement`, `ProgressPhoto`, `FormCheckResult`, `WeeklyReport`, `CoachMessage`, `DailySnapshot` (struct, not persisted)

### Key Conventions
- Views use `@Query` for SwiftData reads and `@Environment(\.modelContext)` for writes
- Services are instantiated once in `RockinBodApp.init()` and passed down explicitly
- API key resolution: `Secrets.swift` (embedded, gitignored) → Keychain fallback
- Hevy integration emphasizes Apple Health sync as the primary path; API key is in an "Advanced" disclosure group
- Claude API key is embedded (not user-facing); users never see or enter it

## File Structure
```
RockinBod/
├── App/           ContentView.swift, RockinBodApp.swift
├── Models/        9 SwiftData models + DailySnapshot struct
├── Services/      8 service files
├── Views/
│   ├── Dashboard/ DashboardView, MetricCardView, TrendChartView
│   ├── Nutrition/ NutritionView, MacroRingView, MicronutrientListView
│   ├── Workouts/  WorkoutsView, WorkoutDetailView, ExerciseProgressChartView
│   ├── Progress/  ProgressTrackingView, PhotoCaptureView, PhotoComparisonView, BodyMetricsChartView
│   ├── Coach/     CoachView, ChatBubbleView, FormCheckView, WeeklyReviewView
│   ├── Settings/  SettingsView, IntegrationSettingsView
│   └── Onboarding/ OnboardingView
├── Utilities/     Constants.swift, Extensions.swift, Secrets.swift (gitignored), Secrets.example.swift
└── Assets.xcassets/
```

## Build & Deploy
- **Bundle ID:** `com.rockinbod8374.app`
- **Team:** W4L4G6JKTJ (automatic signing)
- **Archive:** `xcodebuild -project RockinBod.xcodeproj -scheme RockinBod -sdk iphoneos -configuration Release -archivePath build/RockinBod.xcarchive archive -allowProvisioningUpdates`
- **Export:** `xcodebuild -exportArchive -archivePath build/RockinBod.xcarchive -exportPath build/export -exportOptionsPlist ExportOptions.plist -allowProvisioningUpdates`
- **Upload:** `xcrun altool --upload-app -f build/export/RockinBod.ipa -t ios -u <apple-id> -p <app-specific-password>`
- **TestFlight:** App exists in App Store Connect; builds go through processing (~15-30 min) then appear in TestFlight

## Secrets
- `RockinBod/Utilities/Secrets.swift` is **gitignored** — contains the Anthropic API key
- `RockinBod/Utilities/Secrets.example.swift` is committed as a template
- Never commit `Secrets.swift` or any file matching `*.secret` / `.env`

## Testing
- **Test target:** `RockinBodTests/` with 70+ tests across 8 test files
- **Run tests:** `xcodebuild test -scheme RockinBod -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- **Test files:**
  - `AICoachParsingTests` — JSON parsing, code fence removal, fallback behavior
  - `CronometerServiceTests` — CSV parsing, date parsing, value extraction
  - `HevyServiceTests` — date parsing, workout type inference
  - `DataAggregationServiceTests` — mock HealthKit, heart rate mocking
  - `ScoreDisplayTests` — score gauge fraction and color mapping
  - `UnitConversionTests` — kg/lbs, cm/inches, formatted display helpers
  - `ModelTests` — SwiftData model creation and relationships
  - `AICoachServiceTests` — service configuration

### Testability
- Private methods made `internal` for `@testable import`: `AICoachService.cleanJSONString`, `parseWeeklyReviewResult`, `parseFormAnalysisResult`, `parsePhotoAnalysisResult`; `CronometerService.parseCSVRows`, `parseDate`, `doubleValue`; `HevyService.inferWorkoutType`, `parseDate`
- `HealthKitServiceProtocol` enables mock-based testing of `DataAggregationService`

## Known Issues & Incomplete Items
- **Export Data:** `SettingsView.exportData()` is a stub (empty method body)
- **Notifications:** `@AppStorage` toggles exist in Settings but no `UNUserNotificationCenter` scheduling code
- **Cronometer API key:** `KeychainService.cronometerAPIKey` constant exists but is unused (Cronometer uses CSV + HealthKit only)
- **RenphoService:** Methods retained for future direct Renpho API integration; currently reads via HealthKit only
- **HealthKitService.saveBodyMass:** Available for future manual weight entry feature
- **iPad:** `TARGETED_DEVICE_FAMILY: "1"` (iPhone only); iPad orientations added to Info.plist for App Store validation but not a target platform

## Recently Fixed (Bug Audit)
- [x] Nested NavigationStacks in all 5 tab child views (caused double navigation bars)
- [x] Dashboard score gauge dividing by 100 instead of 10
- [x] CSV parser \r\n handling (Swift grapheme cluster issue)
- [x] Double `HealthKitService()` initialization in RockinBodApp
- [x] Duplicate `saveAPIKeys()` call in OnboardingView
- [x] Hevy workout UUID leaking into user-visible Notes field
- [x] AI Coach always showing "Connected" regardless of API key
- [x] Hevy integration status conflating HealthKit authorization
- [x] Cronometer always showing "Not Connected" in settings
- [x] Heart rate always nil for synced workouts
- [x] Body fat percentage not passed to weekly review AI summary
- [x] Metric/Imperial toggle having no effect on displayed values
- [x] AI JSON parse fallback showing blank sections
- [x] Silent error swallowing in PhotoCaptureView, CoachView, WeeklyReviewView

## Roadmap / Future Work
- [ ] Implement actual notification scheduling (UNUserNotificationCenter)
- [ ] Data export functionality (JSON/CSV export of all user data)
- [ ] Progress photo analysis UI entry point (analyze button in photo detail)
- [ ] Widget extension for daily summary on home screen
- [ ] Watch companion for workout tracking
- [ ] Push notifications via APNs for weekly review reminders
- [ ] Onboarding flow refinement (currently functional but basic)
- [ ] Dark mode polish pass
- [ ] Accessibility audit (VoiceOver, Dynamic Type)
