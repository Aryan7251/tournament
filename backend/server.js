require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const { initDatabase, db } = require('./src/config/database');
const apiRoutes = require('./src/routes');

const app = express();
const PORT = process.env.PORT || 5050;

// Initialize Database & Schema
initDatabase();

// Enable Unrestricted CORS for Flutter Frontend (port 3000) and Admin Panel (port 4000)
app.use(cors({
  origin: true,
  credentials: true
}));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

// API Routes
app.use('/api', apiRoutes);

// Root route
app.get('/', (req, res) => {
  res.json({
    name: 'Gaming Tournament Backend API',
    version: '1.0.0',
    status: 'online',
    healthCheck: '/api/health',
    documentation: {
      endpoints: [
        'GET  /api/health',
        'POST /api/auth/login',
        'POST /api/auth/register',
        'POST /api/auth/forgot-password',
        'POST /api/auth/reset-password',
        'GET  /api/sync/:userId',
        'PUT  /api/user/:userId',
        'POST /api/user/:userId/kyc',
        'POST /api/user/:userId/game-id',
        'POST /api/user/:userId/payout',
        'POST /api/wallet/:userId/deposit',
        'POST /api/wallet/:userId/withdraw',
        'GET  /api/arenas',
        'POST /api/arenas',
        'POST /api/arenas/:arenaId/join',
        'POST /api/arenas/:arenaId/leave',
        'POST /api/arenas/:arenaId/claim-win',
        'PUT  /api/notifications/:userId/:id/read',
        'PUT  /api/notifications/:userId/read-all'
      ]
    }
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: `Route not found: ${req.method} ${req.originalUrl}`
  });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('Unhandled server error:', err);
  res.status(500).json({
    success: false,
    error: err.message || 'Internal Server Error'
  });
});

// Start Server
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`===========================================`);
  console.log(`  Tournament Backend Server is Running!`);
  console.log(`  URL: http://localhost:${PORT}`);
  console.log(`  API: http://localhost:${PORT}/api`);
  console.log(`  Health: http://localhost:${PORT}/api/health`);
  console.log(`  Database: Built-in SQLite (data/tournament.db)`);
  console.log(`===========================================`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\nClosing server and database connection...');
  server.close(() => {
    try {
      db.close();
    } catch (_) {}
    console.log('Server stopped safely.');
    process.exit(0);
  });
});
