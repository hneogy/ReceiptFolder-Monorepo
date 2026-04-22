# App Store Optimization — Receipt Folder

Living document. Everything here plugs directly into App Store Connect.

## App name + subtitle

Both combined count for ASO weight. Target: keep total under 60 characters,
front-load the two highest-intent keywords.

- **App name:** `Receipt Folder` (15 chars — always renders full)
- **Subtitle:** `Return Windows & Warranties` (29 chars — renders on most devices)
- **Combined:** `Receipt Folder: Return Windows & Warranties` — 43 chars, covers "receipt", "return", "warranty" all as substring matches

## Keywords field (100 characters, comma-separated, no spaces)

```
return,warranty,reminder,tracker,scanner,deadline,refund,exchange,receipt,expire,alert,purchase
```

That's 96 characters. Sorted by search volume priority based on competitor
keyword analysis of SimplyWise, Warranty Wallet, and Shoeboxed. Avoid the
app name and subtitle words (Apple indexes those separately). Singular forms
only — Apple pluralizes automatically.

## Promotional text (170 characters, editable any time without review)

> Track every return window and warranty on-device. Free forever. No accounts. The only app with proof-of-return capture — photo + note the moment you return.

166 characters. Hits the three differentiators: on-device, free, proof-of-return.

## Short description (30 characters)

> Returns & warranties, private

29 chars.

## Full description

Structured as a magazine page — leading with the promise, then the moat.
No marketing buzzwords. Reads like an app built by one person, because it is.

```
Never miss a return. Ever.

Receipt Folder reads the deadline off every receipt, then keeps watch so you
don't have to. All on-device. No accounts. No subscription.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SIX THINGS IT DOES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

I. Scans any receipt in seconds. Store, date, and total are read on-device
by Apple's Vision framework. Photos never leave your phone.

II. Tracks return windows against a built-in database of 100+ retailer
policies. The right deadline appears the moment you save.

III. Reminds you at 14 days, 7 days, 3 days, and the morning of your
deadline. Quiet when it's safe. Loud when it matters.

IV. Watches warranties too. Nudges you at 90, 30, and 7 days before expiry
so you can inspect your product while it's still covered.

V. Return Mode — one screen for the in-store moment. Countdown, map to the
store, return policy, what to bring. Arm's-length legible.

VI. Captures proof of return. When you mark an item returned, take a photo
of the store's receipt and jot a note. If they later dispute the refund,
you have a timestamped record.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PRIVATE BY DEFAULT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

No accounts. No analytics. No third-party SDKs. No servers. The only
network Receipt Folder ever touches is your own iCloud, and only if you've
signed in. Delete the app and every receipt goes with it.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DEEPLY iOS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Siri Shortcuts for every common action. Widgets with tap-to-mark-returned.
Live Activities that put the countdown on your Lock Screen. Calendar
integration. Full Spotlight search. Drag-and-drop receipt images. VoiceOver.
Dynamic Type. Dark mode.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PRICE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Free. Forever. No subscription, no in-app purchase, no trial period.
```

## What's new / Release notes (for each version)

Editorial-style release notes — same voice as the rest of the app. Three to
four short bullet paragraphs, no emoji-heavy changelog.

Template:

```
An almanac for your returns and warranties. This issue adds:

→ [Feature 1 in two sentences]

→ [Feature 2 in two sentences]

→ [Fix / improvement — one sentence]

Filed with care — Honorius.
```

## Screenshots

Eight per device family (iPhone 6.7", iPhone 6.5", iPad 12.9"). Each
screenshot has a headline + a subhead above the device frame. Headlines
follow the Editorial voice: serif title + italic signal-red accent. Dark
background for most shots, one light to break rhythm.

### Order (narrative flow)

1. **"Never miss a *return.*"** — Vault masthead with 3–4 receipts, one in
   red urgency. Shows the ledger aesthetic + the urgency system.
2. **"Scan. *Done.*"** — The 128pt serif countdown on an item detail screen.
   Drop caption: "Point at any receipt. The deadline appears."
3. **"14 *days left.*"** — Lock Screen widget + Live Activity on a real
   Lock Screen. "Interactive. Tap to mark returned without opening the app."
4. **"Return *Mode.*"** — The in-store screen — 144pt countdown, store map,
   what-to-bring checklist. "The single screen built for the return counter."
5. **"Proof of *return.*"** — The new proof-capture flow with a photo and
   note. "If the store later disputes the refund, you have evidence."
6. **"100+ retailers, *zero servers.*"** — Directory view showing the
   alphabetized store policies. Subhead: "All bundled. All on-device."
7. **"One tap to *Siri.*"** — Siri prompt: "Show expiring items." Subhead:
   "Three shortcuts built in. More via the Shortcuts app."
8. **"Free. *Forever.*"** — Settings → Colophon. "No accounts. No
   subscription. Delete the app and every receipt goes with it."

### Screenshot design specs

- Device frame: iPhone 17 Pro Max, paper-cream background (`#F5F1E8`) or
  ink background (`#151210`) depending on shot
- Headline font: New York serif, 80–100pt, weight regular, italic accent
  in `#C8392B` (signal red)
- Subhead: 24–28pt, italic, color `#6E665A` (mute)
- 2-3% padding around the device frame
- Generated with [Rotato](https://rotato.app/) or [Screenshots.pro](https://screenshots.pro/)

## App Preview video (30 seconds, no voiceover)

Silent. Editorial title cards between live app captures, matching the
Editorial design language.

```
0:00–0:03  Title card: "Never miss a return." (serif, red accent)
0:03–0:07  App capture: scanning a physical receipt (camera UI → review)
0:07–0:10  Title card: "Every deadline tracked."
0:10–0:15  App capture: Vault scrolling, showing the urgency pills
0:15–0:18  Title card: "Return Mode."
0:18–0:23  App capture: item detail → Return Mode with 144pt countdown
0:23–0:26  Title card: "Proof of return."
0:26–0:29  App capture: marking returned → proof capture sheet
0:29–0:30  Logo + "Free. Forever."
```

## Launch tactics (Month 3)

1. **TestFlight beta** — 50 seats, recruited from r/iOS and a short thread
   on Mastodon. Collect real bug reports for 2 weeks before App Store submit.
2. **Product Hunt** — Launch on a Tuesday or Wednesday. Title: "Receipt
   Folder — Never miss a return again." Tagline: "Private, free receipt &
   warranty tracker for iPhone and Mac." Hunter: the developer.
3. **Show HN** — Post-launch, same week. Title: "Show HN: Receipt Folder —
   an iOS receipt tracker built like a newspaper." Focus on the editorial
   design angle; HN likes the craft story.
4. **Mastodon / Twitter thread** — Lead with a single gorgeous screenshot
   of the Vault or the 128pt countdown. Thread the features.
5. **iOS newsletter outreach** — iOS Dev Weekly, MacStories, Indie Apps,
   The Sweet Setup. One-paragraph pitch, press kit link, 4 representative
   screenshots. Don't mass-blast — 5 hand-written emails.
6. **Comparison article** — publish `site/compare.html` on launch day with
   the explicit "SimplyWise alternative" angle for organic search.

## Measuring success

Key App Store Connect metrics to watch (weekly):

- **Rating average** — target 4.7+ within 90 days
- **Rating velocity** — 10+ reviews per week in Month 1, 5+/week steady-state
- **Impressions → Tap rate** — screenshots work if >5% of viewers tap
- **Tap → Download rate** — the title/subtitle work if >30% of tappers install
- **Keyword rank** — track rank for: "receipt tracker", "return reminder",
  "warranty tracker", "receipt scanner privacy" (via AppFigures or SensorTower)

## Review response strategy

Respond to every App Store review within 48 hours. Three templates:

**5-star, no question:**
> Thank you — knowing Receipt Folder saved you a return genuinely makes my
> week. If you think of a feature you'd love, write to me at
> honorius@neogy.dev. Real human, real reply.

**Bug report (any stars):**
> Thanks for flagging this. I'll look at [specific bug] right away — could
> you email honorius@neogy.dev with your iPhone model and iOS version? I'll
> reply personally.

**Feature request (any stars):**
> [Feature] is a great idea — I'm tracking it on the roadmap at
> receiptfolder.pages.dev. If you'd be willing to share more about your use
> case over email (honorius@neogy.dev), I'd love to hear it.

Never use "we". Always first-person. Editorial voice matches the app.
