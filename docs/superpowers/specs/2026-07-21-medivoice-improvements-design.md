# MediVoice — Features, UI & Flow Improvements

**Date:** 2026-07-21
**Status:** Approved design (pending spec review)
**Branch:** `rework`

## Context

MediVoice is a voice-first Flutter medication-reminder app built for Kawempe
National Referral Hospital. It has three roles — **patient**, **caregiver**,
**admin** — backed by a local SQLite database, with text-to-speech spoken
reminders, local notifications, and SMS alerts to caregivers on missed doses.

The data layer is already rich: `dose_logs` records every dose with a status
(`pending` / `taken` / `missed` / `skipped`), `reminder_schedules` stores per-
medicine times and days-of-week, and `alert_contacts` holds caregiver phone
numbers. **However, almost none of this is surfaced in the UI.** The patient home
screen shows a flat list of medicines with a single "TAKE" button; there is no
sense of what is due now, no progress, and no adherence insight for caregivers.

This spec covers a balanced round of improvements across all three roles plus a
shared design foundation and cleanup of existing rough edges.

## Goals

- Surface the adherence data the app already captures.
- Give each role a clearer, more modern, more purposeful screen.
- Add dark-mode support across the app.
- Reduce duplication and fix concrete existing bugs.
- Provide a proper GitHub-facing README.

## Non-goals

- No backend / cloud sync (app stays fully local).
- No changes to the notification/TTS/SMS scheduling engine beyond what the new
  screens need to read.
- No new roles or authentication changes.
- No database schema changes beyond adding new `app_settings` keys (no new
  tables, no column changes — avoids a migration).

## Key decisions (confirmed with user)

1. **Dark mode: included.** Full dark theme + persisted toggle.
2. **Today logic: schedule-driven.** The patient "Today" dashboard derives
   Due-now / Upcoming / Taken sections from each medicine's saved
   `reminder_schedules` times combined with today's `dose_logs`.
3. **Delivery: phased with a checkpoint.** Build Phase 1 (foundation + patient
   dashboard), user reviews/builds on-device, then continue with the rest.

**Build constraint:** Flutter is not installed in the working environment. All
code is written here; the user builds/runs on their own machine. Therefore each
phase must leave the app in a compiling, runnable state.

## Architecture

Work is grouped into a shared foundation, three role tracks, and cleanup. New
shared widgets and theming live under `lib/core/`; role work stays within the
existing `lib/features/<role>/screens/` structure, with new widgets in a
per-feature `widgets/` folder where a screen grows large.

```
lib/core/
  theme/app_theme.dart        # + darkTheme, ThemeMode wiring
  theme/theme_controller.dart # NEW: ValueNotifier<ThemeMode>, persisted
  widgets/
    pill_visual.dart          # NEW: extracted shared pill/shape widget
    adherence_ring.dart       # NEW: circular progress ring
    section_header.dart       # NEW
    stat_chip.dart            # NEW
  services/adherence_service.dart # NEW: pure functions computing adherence
lib/features/
  patient/screens/patient_home_screen.dart   # redesigned "Today" dashboard
  patient/screens/patient_history_screen.dart # NEW (replaces buggy button)
  caregiver/screens/medication_list_screen.dart # + search/sort
  caregiver/screens/caregiver_profiles_screen.dart # + adherence badge
  caregiver/screens/patient_adherence_screen.dart # NEW overview
  auth/screens/admin_login_screen.dart        # + dashboard after login
```

### Adherence service (shared unit)

A single, testable unit that both patient and caregiver screens depend on. Pure
functions over data read from `DatabaseHelper` — no UI, no side effects.

- `todaysDoses(patientId)` → for each active medicine's enabled schedules whose
  `days_of_week` includes today, produce a list of dose "slots" `{medication,
  scheduledTime, status}` by matching against today's `dose_logs`. A slot with
  no matching log is `pending`.
- Slot bucketing for the dashboard:
  - **Due now** — pending, scheduled time within a window of now (past-due or
    within the next 60 min).
  - **Upcoming today** — pending, scheduled later today.
  - **Taken today** — status `taken`.
  - (Missed/skipped shown with a muted style, not a separate hero section.)
- `adherencePercent(patientId, {days})` → taken ÷ (taken + missed + skipped)
  over the window, from `getDoseLogsByPatient`.
- `currentStreak(patientId)` → consecutive days back from today where every
  scheduled dose was taken.

## Feature detail

### Phase 1 — Shared foundation + Patient dashboard (checkpoint here)

**Foundation**
- `ThemeController` (a `ValueNotifier<ThemeMode>`) initialized from a new
  `theme_mode` setting in `app_settings`; `main.dart` rebuilds `MaterialApp`
  via `ValueListenableBuilder`. Default = system.
- `AppTheme.darkTheme` mirroring the light theme with dark surfaces; introduce
  semantic color getters so screens stop hardcoding `Colors.white` / greys.
- Extract `PillVisual` widget from the two duplicated copies (patient home +
  caregiver list) into `core/widgets/pill_visual.dart`; both screens use it.
- Add `AdherenceRing`, `SectionHeader`, `StatChip` shared widgets.
- Add green gradient(s) to `AppColors`; replace hardcoded gradients.

**Patient "Today" dashboard** (`patient_home_screen.dart`)
- Header: greeting + avatar + today's `AdherenceRing` (taken/total today) +
  streak chip. Dark-mode toggle moves into an overflow/settings affordance.
- Body sections via `AdherenceService.todaysDoses`: **Due now**, **Upcoming
  today**, **Taken today**. Empty-state when nothing scheduled.
- Each dose card keeps the large, high-contrast "TAKE" affordance → opens the
  existing `DoseConfirmationScreen`.
- **Bug fix:** replace the header history button (which always opened only the
  first medicine) with a `patient_history_screen.dart` listing all medicines,
  each tappable into the existing per-med `DoseHistoryScreen`.

### Phase 2 — Caregiver
- Medication list: search field (filter by name) + sort (name / recently
  added). Preserve existing edit/delete/history actions.
- Profiles screen: async adherence badge per patient card
  (`adherencePercent(..., days: 7)`), color-coded (green/amber/red).
- `patient_adherence_screen.dart`: today ring + 7-day and 30-day percentages +
  a list of recent missed/skipped doses. Reachable from the med list app bar.

### Phase 3 — Admin
- After successful PIN login, show a simple dashboard: total active patients,
  total active medications, and today's aggregate adherence across all
  patients. Reuse `StatChip` and `AdherenceService`.

### Phase 4 — Cleanup + README
- Rewrite `README.md` as a GitHub showcase: project description, feature list
  by role, tech stack, screenshots placeholder section, project structure,
  build/run instructions (Android/iOS), and permissions notes (notifications,
  SMS, mic, camera). Remove the stale "Aspirin/Vitamin D sample data" content.
- Remove any remaining duplicated pill code; confirm gradient/color unification.
- Consistency pass on back/logout affordances.

## Data flow

Screens call `AdherenceService`, which reads via `DatabaseHelper` (existing
methods: `getMedicationsByPatient`, `getSchedulesByMedication`,
`getDoseLogsByPatient`, `getCaregiverPatients`, `getDevicePatients`). No writes
are added except the `theme_mode` setting. Dose confirmation continues to flow
through the existing `DoseConfirmationScreen`.

## Error handling

- All DB reads wrapped in try/catch with a graceful empty/error state (matching
  the existing screens' pattern).
- Missing/invalid schedule times are skipped rather than crashing the dashboard.
- Adherence over an empty set returns 100% "nothing due" rather than 0% or NaN.
- File-backed images (pill/profile photos) keep the existing `existsSync` guard.

## Testing

- Unit tests for `AdherenceService` (pure functions): bucketing of slots given
  fixed "now", percentage math including the empty-set case, and streak
  counting. These run without a device.
- Widget smoke test that the patient dashboard builds with sample data and shows
  the three sections. (Existing `test/widget_test.dart` is a template and will
  be updated.)
- Manual on-device verification by the user at each phase checkpoint, since
  Flutter cannot run in this environment.

## Risks

- **Dark mode reach:** many colors are hardcoded; the theme pass must catch them
  or dark mode will look broken on some screens. Mitigated by routing colors
  through semantic getters and reviewing each screen in Phase 1/4.
- **Schedule/timezone edge cases** in "Today" bucketing; mitigated by unit tests
  with fixed clock values.
- **No local build:** regressions only surface on the user's machine; mitigated
  by keeping each phase compiling and self-contained.
