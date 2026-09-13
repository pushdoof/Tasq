# Friend Hub groups

The iOS app uses the existing project `tasq-30132` and named Firestore database `default` (not `(default)`). The local Firebase CLI was signed out during implementation, so the deployed database edition and existing rules could not be inspected. The added code uses native Firestore SDK operations supported by both Standard and Enterprise Native editions; no database was created or changed.

## Enabling live groups

1. Authenticate the Firebase CLI and inspect the existing `default` database and its deployed rules.
2. Merge the helpers and `friendHubGroups` match from `firestore.groups.rules` into that database's existing rules. Preserve the app's profile, username, friend request, direct chat, and user-progress rules. **Do not replace the deployed rules with this standalone test file**: unrelated collections deliberately have no grants in it. Check for broad existing wildcard grants, because Firestore combines matching grants with OR.
3. Review the merged rules, run the emulator suite, and deploy to the named `default` database.
4. Sign into two app installations with different existing friends. Create a group containing both; verify movement, room switching, chat, a full game, admin transfer, removal, disabled rooms, and background/reconnect behavior. This cross-device production check remains outstanding.

These are prototype rules. They have passed local adversarial tests but are not a claim of a full production security audit. Existing direct-chat client text validation is reused for group messages; server-side content moderation and rate limits are not added by this change.

## Schema and synchronization

- `friendHubGroups/{groupID}`: name, adminID, memberIDs (1–20), memberNames, gamesEnabled, focusEnabled, immutable id and createdAt. Creation permits the creator and their existing friends. Admins select additional friends, remove people, toggle optional rooms, and transfer ownership. Members can leave themselves; admins must transfer first. Settings use a transaction to reject edits based on an outdated group.
- `presence/{sessionID}`: authenticated userID, sprite configuration, roomID, normalized x/y, movement state, reaction, reactionAt and server lastSeen. Each visit has a unique document. Movement publishes at most roughly three updates/second plus its final step; presence refreshes every 20 seconds. Only the newest session per member renders. Sessions older than 60 seconds are hidden; initial queries exclude old documents. Normal exit/background deletes the visit. Crash leftovers may be periodically removed by a future retention job.
- `messages/{messageID}`: immutable sender ID/name, text (1–500 characters), server timestamp. The UI listens to the latest 80 messages in chronological display order. Chat is shared across the group's rooms.
- `activities/tictactoe`: nine cells, X/O seats, turn. Transactions prevent competing joins and moves from overwriting one another. Rules verify a single legal cell change and player turn, block moves after a win/draw, and allow completed-round or admin reset. Spectators can watch.
- `activities/focus`: shared endsAt. The admin starts/ends a 25-minute timer; all members derive remaining time from that timestamp.

No composite indexes or new iOS package dependencies are required. The app does not fabricate remote players. A debug-only local visual fixture is available with the launch argument `-friend-hub-preview`; add `-empty-groups` to check the first-group screen with space reserved for the surrounding navigation. It does not save changes or contact the group backend.

## Local checks

Verified on September 12, 2026: iPhone 17 Pro simulator build succeeded, 16 Swift model tests passed, and 18 Firestore emulator scenarios passed. The bubble hub, lounge, tap-to-walk behavior, arcade, and membership settings were inspected in the simulator using the local fixture. Production cross-device behavior was not tested.

With Java 21+, Node, and npm available:

```sh
cd Firebase
npm install
npm test
```

The emulator config targets `demo-tasq-groups` and port 8188. It never deploys rules or writes production data. `groups.rules.test.cjs` tests real Firebase SDK calls against the emulator's rule engine. Run the Swift model suite from the repository root with `./Scripts/test-models.sh`.

## Access review

| Attempt | Expected protection / coverage |
|---|---|
| Anonymous collection listing; unrestricted private group query | Denied; tested |
| Outsider reads/writes; removed member access | Denied; tested |
| Profile-based privilege escalation; member changes admin/settings | Authority comes from existing group admin; denied/tested |
| Forged creator, presence owner or chat sender | Auth UID checks; denied/tested |
| Create valid then update oversized/wrong type/missing fields | Validators on both write paths; tested |
| Change immutable IDs/timestamps; add unknown fields | Denied; tested |
| Huge names, extra members, invalid avatar numbers | Bounded strings, map keys, group size, numeric fields; tested |
| Remove another member as ordinary member | Exact self-removal transition; denied/tested |
| Change game seats, play twice/out of turn, overwrite cells, move after win | Transaction plus rule transition checks; tested |
| Replay an already used game move | No valid single-cell transition; denied/tested |
| Join or act inside a disabled room | Feature setting checked server-side; denied/tested |
| Orphan subcollection or unknown activity access | Existing parent membership required; denied/tested |
| Query does not match security rules | Actual membership, presence cutoff, chat ordering/limit queries tested |
| Full game or 20-member group exceeds evaluation budget | Complete nine-move draw and maximum group size tested |
| Monetary counters, file paths, public mixed-content records | Not present in the new schema |

Existing project-wide rules and production retention/moderation require a separate review after authenticated access is available.

### Native presence encoding regression

Room presence uses the Unix epoch for an empty reaction's timestamp. `Date.distantPast` is outside the native Firebase SDK's supported timestamp range and raises an Objective-C exception during encoding, before any network request; Swift `do/catch` cannot recover from it. `FriendRoomPresenceTests` exercises the production presence model through `Firestore.Encoder` for initial joins, movement, and reactions. These native tests are separate from the Foundation-only model script and JavaScript rule tests:

```sh
xcodebuild -project Tasq.xcodeproj -scheme Tasq -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:TasqTests/FriendRoomPresenceTests test
```

Verified September 13, 2026: the iOS build and both native presence-encoding regression tests passed on Xcode's iPhone 17 Pro simulator clone. No backend migration or rules change is required for this timestamp correction.
