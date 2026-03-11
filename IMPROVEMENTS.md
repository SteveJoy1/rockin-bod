# RockinBod — Improvement Checklist

> This file lists development best practices to adopt. Do NOT delete this file after
> completing items — update the checkboxes so we can track what's done.

---

## What This Repo Does Well (Keep These)
- **CLAUDE.md** is comprehensive — treat this as the gold standard for all other repos
- **Secrets management** is excellent — Keychain + `Secrets.example.swift` + `.gitignore` exclusion
- **Zero third-party dependencies** — reduces attack surface and maintenance burden
- **Service-injection architecture** — testable, clear dependencies
- **Error types** — custom `LocalizedError` enums for every service
- **7 test files** already exist — more than any other repo in the portfolio

---

## Improvements To Roll In

### 1. Add a README.md
- [ ] Create a basic `README.md` at the repo root (separate from CLAUDE.md)
- Purpose: GitHub landing page, quick overview for non-AI readers
- Should include: one-line description, screenshot, tech stack, how to build

### 2. Pin Dependencies (N/A for this repo, but note the pattern)
- This repo has zero external deps — great. No action needed.

### 3. Expand Test Coverage
- [ ] The existing 7 test files are a great start. Add coverage for:
  - `HealthKitService` (mock HealthKit store)
  - `VideoProcessingService` (frame extraction logic)
  - `DataAggregationService` (weekly/monthly rollups)
  - Navigation flow integration tests
- [ ] Add a test coverage target (e.g., 60% minimum) in CLAUDE.md

### 4. Add SwiftLint
- [ ] Install SwiftLint via Homebrew: `brew install swiftlint`
- [ ] Add a `.swiftlint.yml` with project-specific rules
- [ ] Add a build phase or pre-commit hook to run it
- This should become a standard across all Swift repos (rockin-bod, supreme, Ipad-Notetaker, battery)

### 5. Add Pre-Commit Hooks
- [ ] Add a git pre-commit hook that:
  - Runs SwiftLint
  - Checks for accidental secrets (scan for API key patterns)
  - Runs tests
- Consider using a simple shell script in `.githooks/` and setting `core.hooksPath`

### 6. Complete Stub Implementations
- [ ] `SettingsView.exportData()` is an empty stub — implement JSON/CSV export
- [ ] Notification scheduling — `@AppStorage` toggles exist but `UNUserNotificationCenter` is not wired up
- These are already noted in CLAUDE.md but should be prioritized

### 7. Set Up CI/CD (GitHub Actions)
- [ ] Create `.github/workflows/build.yml` that:
  - Builds the project with `xcodebuild`
  - Runs tests
  - Triggers on push to `main` and on pull requests
- This should become a standard across all repos

### 8. Add Accessibility Audit
- [ ] VoiceOver support for all interactive elements
- [ ] Dynamic Type support
- [ ] Already on the CLAUDE.md roadmap — elevate priority
