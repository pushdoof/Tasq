# Tasq: product and implementation notes

Tasq is a personal space for planning, following through, connecting, and eventually reflecting. Its visual language is warm paper, dark ink, hand-drawn boxes and icons, and soft sage, peach, and lilac accents.

## Current experience

- **Today** opens directly onto a routine to start, resume, or review. It also connects to the routine library and Friend Hub.
- **Routines** contains the existing Chartflow editor, starter templates, dynamic planning, search, duplication, and deletion. New routines open directly in the editor. The former five-routine UI limit does not apply here.
- **Focus** emphasizes the current task, countdown, subtasks, and next step. The flowchart remains available while running. Pause/resume, early completion, and a completion screen are accessible without hunting through icons.
- **Friends** uses the existing profiles, requests, search, and chat. The dashboard links to it; this change does not implement shared focus sessions or automatic routine sharing.
- **Settings** remains available from the shared header. New typography respects interface sizing and Dynamic Type; shared doodle components respect the existing motion and contrast settings.

## Planned additions — keep these for later

- **Diary:** a space to reflect on the day. A future completion flow can offer “Write about this” with the routine as context.
- **AI helper:** help turn an intention into an editable routine or adjust a plan. Proposed changes should enter the same routine editing flow.

Both are currently presented as coming later, without live feature buttons. Neither storage for diary entries nor an AI integration has been implemented. Add their real destinations to the shared workspace when those features are ready. Do not turn the home screen back into separate, unrelated app launchers.

## Main code locations

- `Tasq/TasqWorkspaceView.swift`: shared navigation, Today, library, and templates.
- `Tasq/TasqDoodleStyle.swift`: reusable typography, buttons, badges, section titles, and palette.
- `Tasq/ChartEditorView.swift`: planning/focus views and timer interaction.
- `Tasq/RoutineSession.swift`: compatible saved sessions and wall-clock progress calculation.
- `Tasq/DynamicSchedulePlanner.swift`: window-aware planning, pinned starts, validation, and exact minute allocation.
- `Tasq/TasqNotificationRouter.swift`: app-wide notification handling and routine-specific reminder IDs.

Dynamic setup edits a draft and commits only on Done. Invalid plans show the reason they cannot fit. Overnight windows are supported; unfilled gaps become explicit free-time steps. Clock labels represent the planned start time; starting a routine at another time starts its countdown immediately.

## Verification

Run the model tests without an iOS runtime:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./Scripts/test-models.sh
```

The regression suite checks exact schedule duration, minimum allocations, overlapping/out-of-window pins, overnight schedules, restoration after elapsed time, paused snapshot persistence, and older routine decoding.

A full Swift type check passed against the installed iOS Simulator SDK and cached Firebase/Google dependencies, using the project's MainActor isolation settings. On September 12, 2026, the iOS 26.5 runtime registration failure was repaired by downloading the universal runtime through Xcode's command-line installer. The full iPhone 17 Pro simulator build then succeeded, all 11 model tests passed again, and the installed app launched successfully. Its sign-in screen was visually verified. Signed-in flows and physical-device notification delivery remain unverified.

After signing into the simulator, check: first-run setup; create/edit/cancel/duplicate/delete; each Friend Hub section; light/dark and large text; start → lock phone → return; pause/finish; two independent routine reminders; notification taps from a closed app. No Firebase schema or package dependency changes are required by this update.

## Friend Hub groups (September 12)

Friend Hub now opens on gravity-driven group bubbles with a static list for Reduce Motion. Selected friends share a group with one transferable admin, a lounge, optional quiet room, and optional arcade. Your existing layered character art/customizer is used for tap-to-walk avatars, room presence, and reactions. Rooms include group chat, an admin-started shared focus timer, and two-player tic-tac-toe with spectators. New files are `FriendGroupModels.swift`, `FriendGroupStore.swift`, and `FriendGroupViews.swift`.

The simulator build, local model tests, and local Firestore rule checks are documented in `Firebase/README.md`. Live groups require merging/deploying the new rules into the existing named database `default`; the Firebase CLI was signed out, so no production rules were changed. Cross-device production sync still needs verification after that step. The debug launch argument `-friend-hub-preview` opens an isolated visual fixture; release builds cannot use it.
