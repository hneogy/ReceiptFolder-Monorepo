# TestFlight — Household Sharing End-to-End Test Plan

Two-device, two-iCloud-account test plan for the household sharing
feature. Run this any time the household code path is touched.

Automated unit tests cover the pure logic (`HouseholdReceiptTests`,
`EmailReceiptParserTests`), but the cross-device CKShare flow can only
be validated with real accounts. Budget 30–45 minutes.

## Prerequisites

- **Two physical devices** (simulator doesn't fully simulate CKShare
  acceptance). An iPhone and an iPad count as two devices if signed into
  different Apple IDs. A Mac signed into a third account is a nice add.
- **Two Apple IDs**: A (the "owner") and B (the "guest"). Both signed
  into iCloud; Receipt Folder's Mail-backed invitation flow needs each
  account's associated contact method reachable.
- **TestFlight build** of the `main` branch (or a local Xcode install on
  both devices).
- Ideally one of the devices runs iOS 26 so the FoundationModels
  fallback is exercised during email-import checks.

## 1. Setup (5 min)

### Device A (owner)

1. Install Receipt Folder. Sign into iCloud with account A.
2. Add two private receipts to establish a non-empty vault:
   - "Sony WH-1000XM5 Headphones" at Best Buy, $349.99, purchased
     today, 30-day return window.
   - "AirPods Pro" at Apple, $249.00, purchased yesterday, 14-day
     return window.
3. Confirm both appear in the vault.

### Device B (guest)

1. Install Receipt Folder. Sign into iCloud with account B.
2. Add one receipt so the vault isn't empty (to prove the household
   section merges cleanly with existing private data):
   - "Kindle Paperwhite" at Amazon, $139.99, 30-day return window.
3. Confirm it's the only receipt in the vault.

## 2. Create household (5 min)

1. On **Device A**: Settings → Family sharing.
2. Verify: masthead shows "HOUSEHOLD · SHARING" with no role chip.
3. Tap **Create Household**.
4. System sharing sheet appears. Send invite to B's iCloud email or
   phone (prefer Messages for fastest delivery).
5. After the sheet dismisses, verify:
   - Role chip shows **OWNER**
   - Participant list shows account A as OWNER (accepted) and account
     B's invitee line as **PENDING**
   - An **Invite Another Member** button is visible below

## 3. Accept household (3 min)

1. On **Device B**: open the invite (Messages tap, or follow the URL).
2. System sheet prompts "Accept shared content from Receipt Folder?"
   with A's display name. Tap **Accept**.
3. Receipt Folder launches (or foregrounds).
4. In Settings → Family sharing on B, verify:
   - Role chip shows **MEMBER**
   - Participant list shows A (OWNER, accepted) and B (MEMBER, accepted)

## 4. Share a receipt (5 min)

1. On **Device A**: open Sony WH-1000XM5.
2. Tap ⋯ → **Share with Household**.
3. Verify: menu label flips to "Stop Sharing with Household" on next
   open.
4. Wait ~5 seconds (silent push propagation).
5. On **Device B**: open the vault.
6. Verify:
   - New **Household** section at the bottom of the vault scroll.
   - "Sony WH-1000XM5" row appears in that section.
   - Row shows **SHARED · \<A's display name\>** in signal red above
     the product title.
   - Tapping the row opens `HouseholdReceiptDetailView` — read-mostly,
     with one **Mark as Returned** button.
7. On **Device A**: the AirPods should *not* appear on B — only items
   explicitly toggled.

## 5. Photo mirroring (3 min)

1. On **Device A**: add or edit the Sony item to include a receipt
   photo (camera or photo picker).
2. Wait ~10 seconds.
3. On **Device B**: open the household Sony row.
4. Verify: the "RECEIPT" section appears with the photo rendered.

## 6. Live edit sync (3 min)

1. On **Device A**: rename the Sony item to "Sony WH-1000XM5 Noise-
   Cancelling Headphones".
2. Wait ~5 seconds.
3. On **Device B**: return to the vault, pull-to-refresh if needed.
4. Verify: the household row now shows the new product name.

## 7. Mark-returned from the guest side (4 min)

1. On **Device B**: open the household Sony row.
2. Tap **Mark as Returned**.
3. Verify:
   - Button shows "Marking returned…" briefly, then sheet dismisses.
   - Row returns to the household section with **RETURNED** treatment
     (strikethrough, timestamp if available).
4. On **Device A**: wait ~5 seconds, pull vault to refresh.
5. Verify:
   - Sony row on A now shows `isReturned = true` (RETURNED stamp on
     the detail view, strikethrough on the row).
   - No notifications fire for the (already-returned) item.

## 8. Un-share cascade (3 min)

1. On **Device A**: open AirPods, toggle **Share with Household** on.
2. Wait ~5 seconds; verify on B that AirPods appears in household.
3. On **Device A**: open AirPods, tap ⋯ → **Stop Sharing with
   Household**.
4. Wait ~5 seconds.
5. On **Device B**: verify AirPods disappears from the Household
   section.
6. On **Device A**: verify AirPods remains in the private vault with
   the toggle back to "Share with Household".

## 9. Archive cascade (2 min)

1. On **Device A**: open Sony (which is still shared).
2. Tap ⋯ → **Archive**.
3. Wait ~5 seconds.
4. On **Device B**: verify Sony disappears from the Household section
   (archiving an item should not leak into co-owners' vaults).

## 10. End household (3 min)

1. On **Device A**: Settings → Family sharing → scroll to **Danger
   zone** → **End household sharing**. Confirm the alert.
2. Verify:
   - View resets to the empty state with **Create Household** button.
   - No participant list.
3. On **Device B**: Settings → Family sharing.
4. Verify:
   - Within 30 seconds (possibly longer — revocation is server-side),
     the view shows no membership (empty state).
   - Previously-shared items disappear from B's vault Household
     section.

## 11. Cold-launch recovery (3 min)

1. On both devices: fully force-quit Receipt Folder (swipe from app
   switcher).
2. Re-launch.
3. Verify:
   - Vault populates within ~2 seconds.
   - No stale household records appear (household section is empty
     after step 10; otherwise matches last state).
   - No error banners.

## 12. Push latency sanity check (5 min)

Leave Device B with Receipt Folder in the background or on the Lock
Screen. On Device A, toggle three receipts' Share with Household
flags in quick succession. Expect B's vault to reflect all three
changes within ~30 seconds of foregrounding — confirming that silent
`CKDatabaseSubscription` pushes are wired through
`application(_:didReceiveRemoteNotification:)`.

## Failure modes to watch

| Symptom | Likely cause | Where to look |
|---|---|---|
| Household section empty on B after step 4 | Subscription not registered; silent push never arrived | Check `HouseholdStore.registerSubscriptionsIfNeeded` logs; verify `UIBackgroundModes` includes `remote-notification` |
| Photos missing on B | CKAsset upload failed (usually quota or network) | Check `FamilySharingService.makeAsset` error logs; try a smaller image |
| Name shows as "Shared" instead of owner's name | `participantDisplayName` couldn't resolve the CKShare participants | Expected for accounts without published contact info; not a bug |
| "Mark as returned" fails on B | Participant lacks write permission on the CKShare | FamilySharingService should set `availablePermissions = [.allowReadWrite, .allowPrivate]`; verify on the UICloudSharingController step |
| Sony appears twice on A after sharing | De-dup by origin not working | Check `rebuildRecordsFromCache` — .owned should win over .participant |

## Sign-off

Record the date, build, and pass/fail of each step in a GitHub issue
or Notion page before cutting a household-sharing release candidate.
Any step failure blocks the ship.
