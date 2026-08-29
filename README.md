# 🎮 LuckyWin Gaming Tournament & Aviator Platform

A full-stack competitive esports and gaming tournament platform featuring real-time wallet operations, KYC verification, Aviator crash game, admin management dashboard, and player frontend.

---

## 🏗 Project Architecture

| Component | Path | Technology | Default Local Port |
| :--- | :--- | :--- | :--- |
| **Backend API** | `/backend` | Node.js (v22+), Express, SQLite (`node:sqlite`) | `5050` |
| **Player Frontend** | `/frontend` | Flutter Web, Node.js static runtime | `3000` |
| **Admin Dashboard** | `/admin` | Tailwind CSS, JavaScript SPA, Node.js runtime | `4000` |

---

## 🚀 Deploying to Render

### Option A: 1-Click Render Blueprint (Recommended)

1. Log into your [Render Dashboard](https://dashboard.render.com).
2. Click **New +** → **Blueprint**.
3. Connect your GitHub repository: `tournament`.
4. Render will automatically detect [`render.yaml`](render.yaml) and configure all 3 services:
   - **`tournament-backend`** (Node.js API Web Service)
   - **`tournament-admin`** (Super Admin Dashboard Web Service)
   - **`tournament-frontend`** (Player Web App Web Service)
5. Click **Apply** to launch the deployment.

---

### Option B: Manual Web Service Deployment on Render

If creating services manually:

#### 1. Backend Web Service (`tournament-backend`)
- **Root Directory**: `backend`
- **Environment**: `Node`
- **Node Version**: `22.14.0` (Set environment variable `NODE_VERSION=22.14.0`)
- **Build Command**: `npm install`
- **Start Command**: `npm start`
- **Health Check Path**: `/api/health`

#### 2. Admin Dashboard (`tournament-admin`)
- **Root Directory**: `admin`
- **Environment**: `Node`
- **Build Command**: `npm install`
- **Start Command**: `node server.js`

#### 3. Frontend Web App (`tournament-frontend`)
- **Root Directory**: `frontend`
- **Environment**: `Node`
- **Build Command**: `npm install`
- **Start Command**: `node server.js`

---

## 🛠 Local Development

```bash
# 1. Start all services locally
./manage-services.sh start

# 2. Check service statuses
./manage-services.sh status

# 3. View live logs
./manage-services.sh logs backend
./manage-services.sh logs frontend
./manage-services.sh logs admin
```

---

## 🔐 Default Credentials

- **Admin Dashboard**: `http://localhost:4000`
  - **Username**: `admin`
  - **Password**: `admin`
- **Backend API**: `http://localhost:5050/api`
  - **Health check**: `http://localhost:5050/api/health`
