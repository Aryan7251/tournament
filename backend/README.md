# Gaming Tournament Arena - Node.js Backend

A fast, lightweight Node.js + Express backend powered by Node's in-built SQLite database engine (`node:sqlite`) for zero-configuration, self-contained persistence.

## Features

- **Built-in Database**: Powered by `node:sqlite` (`data/tournament.db`) with zero external DB dependencies required.
- **RESTful API**: Designed and structured specifically for the Flutter frontend (`ApiService` & `AppProvider`).
- **User Authentication & Profile**: Login, register (with ₹100 welcome bonus), password recovery, KYC submission, and payout methods.
- **Wallet & Transactions**: Deposits with promo codes, withdrawals, transaction history, and wallet synchronization.
- **Tournament Arena Management**: Create tournaments, browse live/upcoming arenas, join/leave matches with automated entry fee handling and prize claiming.
- **Real-Time Notifications**: Unread tracking and user notifications for tournaments, deposits, and winnings.

## Setup & Running

### 1. Install Dependencies
```bash
cd backend
npm install
```

### 2. Start the Server
```bash
npm start
```
Or for development mode with automatic reload:
```bash
npm run dev
```

The server runs on **`http://localhost:5050`** by default.

## API Endpoints

### Health Check
- `GET /api/health` - Server health status and uptime

### Full Synchronization
- `GET /api/sync/:userId` - Fetch user profile, wallet, arenas, transactions, withdrawals, and notifications in one atomic request

### Authentication & Account
- `POST /api/auth/login` - Authenticate user
- `POST /api/auth/register` - Create account
- `POST /api/auth/forgot-password` - Request password reset OTP
- `POST /api/auth/reset-password` - Reset password with OTP

### User Profile
- `PUT  /api/user/:userId` - Update user details
- `POST /api/user/:userId/kyc` - Submit KYC documents
- `POST /api/user/:userId/game-id` - Link in-game gamer tag (BGMI, Free Fire, etc.)
- `POST /api/user/:userId/payout` - Save UPI ID or Bank Account

### Wallet & Balance
- `POST /api/wallet/:userId/deposit` - Add cash with optional promo codes (e.g., `LUCKY100`, `FI
- `POST /api/user/:userId/kyc` - Submit KYC documentsRSTWIN`)
- `POST /api/wallet/:userId/withdraw` - Initiate withdrawal to UPI/Bank

### Arenas & Tournaments
- `GET  /api/arenas` - List all arenas with registered players
- `POST /api/arenas` - Create and host a new tournament arena
- `POST /api/arenas/:arenaId/join` - Register for a tournament (deducts entry fee)
- `POST /api/arenas/:arenaId/leave` - Unregister and receive entry fee refund
- `POST /api/arenas/:arenaId/claim-win` - Claim prize money from match victory

### Notifications
- `PUT  /api/notifications/:userId/:id/read` - Mark single notification as read
- `PUT  /api/notifications/:userId/read-all` - Mark all notifications as read
