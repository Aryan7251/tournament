# LuckyWin - Tournament Arena (Flutter Frontend)

A high-performance, mobile-first esports tournament frontend built with **Flutter 3 (Dart 3)** supporting **Android, iOS, Web, Linux, macOS, and Windows**. Designed with a clean flat minimalist aesthetic featuring warm cream backgrounds, crisp white cards, and high-contrast accents.

---

## ✨ Features & Architecture

- **🎮 Tournaments & Matches Section**:
  - Live, Upcoming, and Registered match lobbies across top titles (BGMI, Free Fire, COD Mobile, Ludo King, Chess, Valorant, Clash Royale).
  - Detailed prize pool breakdowns (1st, 2nd, 3rd place, and per-kill bounties).
  - Interactive Slot booking & registration system with real-time wallet validation.
  - Live Room ID & Password credential unlocking with 1-click clipboard copy.
  - Host / Publish custom tournaments with custom match rules, formats (Solo, Duo, Squad), entry fees, and slot limits.
  - Match Result submission and victory prize claiming with instant wallet winning credit.

- **💳 Deposit Cash Section**:
  - Add Cash workflow with presets (+₹50, +₹100, +₹200, +₹500, +₹1000, +₹2000).
  - Coupon system (`LUCKY100` for 20% bonus, `FIRSTWIN` for ₹50 cash bonus).
  - Payment Gateways: Instant UPI Apps (GPay, PhonePe, Paytm, BHIM), Dynamic UPI QR Code, Debit/Credit Cards, and Net Banking.
  - Deposit transaction logging with instant balance updates.

- **💸 Withdraw Winnings Section**:
  - Real-time Withdrawable Winnings Balance breakdown.
  - Instant payout destinations: UPI ID (VPA), Direct Bank Transfer (IMPS with Account & IFSC), and Paytm Wallet.
  - Quick percentage withdrawal buttons (25%, 50%, 75%, 100%).
  - Minimum payout validation (₹50) and 0% platform fee calculation.
  - Instant automated settlement with reference tracking and withdrawal log.

- **👤 Profile & KYC Section**:
  - User identity, level stats, and customizable profile editor.
  - Verified KYC integration (PAN Card, Aadhaar, Driving License).
  - In-game Game IDs manager (BGMI Character ID, Free Fire UID, COD IGN, etc.).
  - Multi-category Transaction Ledger (Deposits, Withdrawals, Entry Fees, Winnings, Refunds, Bonus).
  - State reset to clean defaults.

---

## 🏗️ Code Structure

```
frontend/
├── lib/
│   ├── main.dart                      # App entry point & provider injection
│   ├── theme/
│   │   └── app_theme.dart             # Color palette & Material 3 theme config
│   ├── models/
│   │   ├── tournament.dart            # Tournament & registered player models
│   │   ├── user_profile.dart          # UserProfile, BankAccount & KYC models
│   │   ├── wallet.dart                # Wallet balances model
│   │   ├── transaction.dart           # Transaction ledger models
│   │   ├── withdrawal_request.dart    # Payout request model
│   │   └── notification_item.dart     # Notification item model
│   ├── providers/
│   │   └── app_provider.dart          # Central State & SharedPreferences persistence
│   ├── widgets/
│   │   ├── app_header.dart            # App bar with brand, wallet pill & notifications
│   │   ├── bottom_nav_bar.dart        # Bottom tab navigation bar
│   │   ├── tournament_card.dart       # Match lobby cards with slot progress
│   │   ├── tournament_detail_dialog.dart # Full match details & join modal
│   │   ├── room_access_dialog.dart    # Room ID & password credential modal
│   │   ├── claim_win_dialog.dart      # Match result & prize claim modal
│   │   ├── create_tournament_dialog.dart # Custom tournament creation modal
│   │   ├── kyc_dialog.dart            # KYC verification modal
│   │   ├── edit_profile_dialog.dart   # Profile details editor
│   │   ├── notifications_sheet.dart   # Slide-up notifications bottom sheet
│   │   └── empty_state.dart           # Clean empty states
│   └── screens/
│       ├── home_screen.dart           # Responsive home layout container
│       ├── tournaments_screen.dart    # Matches & tournament lobby screen
│       ├── deposit_screen.dart        # Deposit & payment options screen
│       ├── withdraw_screen.dart       # Instant withdrawal & IMPS screen
│       └── profile_screen.dart        # User profile, KYC & transaction ledger
└── test/
    └── widget_test.dart               # Smoke tests
```

---

## 🚀 Running the Flutter App

```bash
# 1. Install dependencies
flutter pub get

# 2. Run on Web (Port 3000 default)
npm start # or python3 -m http.server 3000 --directory build/web
# Or for live development:
npm run dev # flutter run -d web-server --web-port=3000 --web-hostname=0.0.0.0

# 3. Run on Chrome (Web)
flutter run -d chrome --web-port=3000

# 4. Run on Android Device / Emulator
flutter run -d android

# 5. Run on Linux Desktop
flutter run -d linux
```
