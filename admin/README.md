# LuckyWin - Super Admin Control Center

A modern, high-control Super Administrator Panel for the LuckyWin Gaming & Tournament Arena.

---

## 🔑 Default Admin Credentials
- **Username:** `admin`
- **Password:** `admin`
- **Port:** `4000` (http://localhost:4000)
- **Backend API:** `http://localhost:5050/api`

---

## 🛡️ Admin Capabilities & Features

1. **📊 Analytics & Overview Dashboard**:
   - Total Platform Revenue, Net Margin, Turnover.
   - 7-Day interactive cash flow charts (Chart.js).
   - Live platform reserves (Deposits, Winnings, Aviator Volume).
   - Real-time recent transaction activity feed.

2. **👥 Player & User Management**:
   - View all registered players with wallet balances.
   - Instant search by username, email, phone, or ID.
   - **Add New User** with initial balance and KYC status.
   - **Edit User Profile & Adjust Balances** (Deposit, Winning, Bonus).
   - **Delete User** with complete cascade purge.

3. **🪪 KYC Verification Center**:
   - Review submitted government IDs (PAN Card, Aadhaar, Driving License).
   - **Approve KYC** with instant push notification.
   - **Reject KYC** with custom reason.

4. **💰 Deposit Management**:
   - View all deposit requests and UTR numbers.
   - Search by UTR, reference ID, or username.
   - **Manual Wallet Credit** to deposit or winning balance.

5. **💸 Withdrawal & Payout Management**:
   - Review pending payouts (Bank Transfer / IMPS, UPI, Paytm).
   - **Approve Payout** with custom UTR/Reference ID.
   - **Reject Payout** with automatic refund to winning balance.

6. **🎮 Tournament & Match Arenas**:
   - Host new tournaments across titles (BGMI, Free Fire, COD, etc.).
   - Set/Update **Room ID & Room Password** with 1-click push broadcast.
   - Change match status (Upcoming, Ongoing, Completed).
   - Delete custom matches.

7. **✈️ Live Aviator Crash Engine Cockpit**:
   - Real-time multiplier radar and flight status.
   - **Override Next Target Crash Multiplier** (e.g. 1.10x, 2.50x, 100x).
   - **Force Crash Immediately** with 1-click emergency button.
   - Reset to provably fair mode.
   - Recent flight history ribbon.

8. **📜 Global Audit Ledger**:
   - Searchable, complete immutable transaction audit trail.

---

## 🚀 How to Run the Admin Panel

```bash
cd admin
node server.js # or npm start
```

Access at: **http://localhost:4000**
