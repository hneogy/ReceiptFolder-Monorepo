# Receipt Folder

An almanac of returns & warranties. Scans receipts, tracks every deadline, keeps
it on-device. No servers, no accounts, no subscriptions.

This repository is a monorepo for both halves of the project:

```
.
├── iOS app/   # The native iPhone + iPad app (Swift, SwiftUI, SwiftData)
└── Site/      # The promotional / marketing website (static HTML/CSS/JS)
```

## `iOS app/`

SwiftUI + SwiftData app. iOS 17+. Build with:

```bash
cd "iOS app"
xcodegen generate
xcodebuild -scheme ReceiptFolder \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

10 XCUITests cover the golden flows (add, return, archive, warranty, export,
discard). CI runs them on every PR — see `.github/workflows/ui-tests.yml`.

## `Site/`

Static five-page promotional site. No build step. Serve with any static host,
or locally with:

```bash
cd Site
python3 -m http.server 8090
```

Pages: `index.html`, `faq.html`, `privacy.html`, `terms.html`, `contact.html`.

## License

© 2026 Honorius M. Neogy. All rights reserved.
