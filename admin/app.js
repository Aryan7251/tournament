const getApiBase = () => {
  if (window.API_BASE) return window.API_BASE;
  const stored = localStorage.getItem('lw_admin_api_base');
  if (stored) return stored;
  const hostname = window.location.hostname || 'localhost';
  if (hostname === 'localhost' || hostname === '127.0.0.1' || window.location.port) {
    return `${window.location.protocol}//${hostname}:5050/api`;
  }
  if (hostname.includes('onrender.com')) {
    return `https://${hostname.replace('admin', 'backend')}/api`;
  }
  return `${window.location.origin}/api`;
};
const API_BASE = getApiBase();

let currentTab = 'overview';
let aviatorPollTimer = null;
let allUsersData = [];
let allDepositsData = [];
let cashFlowChartInstance = null;

// Initialize
document.addEventListener('DOMContentLoaded', () => {
  if (window.lucide) lucide.createIcons();

  let token = localStorage.getItem('lw_admin_token');
  if (!token) {
    token = 'admin-auth-token-session';
    localStorage.setItem('lw_admin_token', token);
  }
  showAppShell();

  // Setup login handler
  const loginForm = document.getElementById('login-form');
  if (loginForm) loginForm.addEventListener('submit', handleLogin);
});

// Toast System
function showToast(message, type = 'success') {
  const container = document.getElementById('toast-container');
  if (!container) return;
  const toast = document.createElement('div');
  const bg = type === 'success' ? 'bg-emerald-600 text-white' : type === 'error' ? 'bg-rose-600 text-white' : 'bg-blue-600 text-white';

  toast.className = `p-3.5 rounded-2xl shadow-xl ${bg} text-xs font-bold flex items-center justify-between pointer-events-auto transform transition duration-300 translate-y-2 opacity-0`;
  toast.innerHTML = `
    <span>${message}</span>
    <button onclick="this.parentElement.remove()" class="ml-3 text-white/80 hover:text-white font-black text-sm">✕</button>
  `;

  container.appendChild(toast);
  setTimeout(() => {
    toast.classList.remove('translate-y-2', 'opacity-0');
  }, 10);

  setTimeout(() => {
    toast.classList.add('opacity-0');
    setTimeout(() => toast.remove(), 300);
  }, 4000);
}

// Modal Helpers
function openModal(id) {
  const modal = document.getElementById(id);
  if (modal) {
    modal.classList.remove('hidden');
    if (window.lucide) lucide.createIcons();
  }
}

function closeModal(id) {
  const modal = document.getElementById(id);
  if (modal) modal.classList.add('hidden');
}

// Authenticated Admin Fetch Wrapper
async function adminFetch(url, options = {}) {
  let token = localStorage.getItem('lw_admin_token') || 'admin-auth-token-session';
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`,
    'x-admin-token': token,
    ...(options.headers || {})
  };

  try {
    const response = await fetch(url, {
      ...options,
      headers
    });

    if (response.status === 401) {
      localStorage.removeItem('lw_admin_token');
      showLoginView();
      showToast('Authentication required. Please log in with admin / admin.', 'error');
    }

    return response;
  } catch (err) {
    console.error('adminFetch error:', err);
    throw err;
  }
}

// Auth Handlers
async function handleLogin(e) {
  e.preventDefault();
  const u = document.getElementById('login-username').value.trim();
  const p = document.getElementById('login-password').value.trim();

  try {
    const res = await fetch(`${API_BASE}/admin/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: u, password: p })
    });
    const json = await res.json();
    if (json.success) {
      localStorage.setItem('lw_admin_token', json.token);
      showToast('Welcome, Super Admin!', 'success');
      showAppShell();
    } else {
      showToast(json.error || 'Authentication failed', 'error');
    }
  } catch (err) {
    showToast('Cannot connect to backend server on port 5050', 'error');
  }
}

function logout() {
  localStorage.removeItem('lw_admin_token');
  clearInterval(aviatorPollTimer);
  showLoginView();
  showToast('Logged out of Admin Portal', 'info');
}

function showLoginView() {
  document.getElementById('login-view').classList.remove('hidden');
  document.getElementById('app-shell').classList.add('hidden');
}

function showAppShell() {
  document.getElementById('login-view').classList.add('hidden');
  document.getElementById('app-shell').classList.remove('hidden');
  switchTab('overview');
}

// Navigation Tabs
function switchTab(tabId) {
  currentTab = tabId;
  document.querySelectorAll('.nav-item').forEach(el => {
    el.classList.remove('active');
    if (el.getAttribute('href') === `#${tabId}`) {
      el.classList.add('active');
    }
  });

  document.querySelectorAll('.tab-pane').forEach(el => el.classList.add('hidden'));
  const target = document.getElementById(`tab-${tabId}`);
  if (target) target.classList.remove('hidden');

  // Title update
  const titles = {
    overview: 'Platform Analytics & Revenue Overview',
    users: 'Player User Management & Accounts',
    kyc: 'Government ID & KYC Verification Queue',
    deposits: 'Deposit Records & Manual Credits',
    withdrawals: 'Player Withdrawal & Payout Requests',
    aviator: 'Live Aviator Crash Engine Cockpit',
    ledger: 'Global Transaction Audit Ledger',
    settings: 'Financial Rules & Limits (Min/Max Deposit & Withdrawal)'
  };
  document.getElementById('section-title').textContent = titles[tabId] || 'Admin Control Panel';

  // Trigger tab data load
  refreshCurrentTab();

  if (tabId === 'aviator') {
    startAviatorPolling();
  } else {
    clearInterval(aviatorPollTimer);
  }

  if (window.lucide) lucide.createIcons();
}

function refreshCurrentTab() {
  if (currentTab === 'overview') loadOverviewStats();
  if (currentTab === 'users') loadUsers();
  if (currentTab === 'kyc') loadKycList();
  if (currentTab === 'deposits') loadDeposits();
  if (currentTab === 'withdrawals') loadWithdrawals();
  if (currentTab === 'aviator') loadAviatorCockpit();
  if (currentTab === 'ledger') loadLedger();
  if (currentTab === 'settings') loadSettings();
}

// TAB 1: OVERVIEW STATS
async function loadOverviewStats() {
  try {
    const res = await adminFetch(`${API_BASE}/admin/stats`);
    const json = await res.json();
    if (!json.success) return;

    const d = json.data;
    const online = d.onlineUsers || 0;
    const total = d.totalUsers || 0;
    const onlinePercent = total > 0 ? Math.round((online / total) * 100) : 0;

    // Real Online Users
    document.getElementById('stat-online-users').textContent = online;
    document.getElementById('stat-online-sub').textContent = `${onlinePercent}% of players online (${online} of ${total})`;
    if (document.getElementById('badge-online-count')) {
      document.getElementById('badge-online-count').textContent = `${online} online`;
    }

    document.getElementById('stat-revenue').textContent = `₹${(d.netRevenue || 0).toLocaleString('en-IN')}`;
    document.getElementById('stat-deposits').textContent = `₹${(d.totalDeposits || 0).toLocaleString('en-IN')}`;
    document.getElementById('stat-pending-deposits').textContent = `${d.pendingDeposits || 0} Pending Review`;
    document.getElementById('stat-withdrawals').textContent = `₹${(d.totalWithdrawals || 0).toLocaleString('en-IN')}`;
    document.getElementById('stat-pending-withdrawals').textContent = `${d.pendingWithdrawalsCount || 0} Pending Payouts (₹${(d.pendingWithdrawalsAmount || 0).toLocaleString('en-IN')})`;
    document.getElementById('stat-users').textContent = d.totalUsers || 0;
    document.getElementById('stat-verified-kyc').textContent = `${d.verifiedKyc || 0} Verified KYC`;

    // Badges in sidebar
    if (document.getElementById('badge-kyc')) document.getElementById('badge-kyc').textContent = d.pendingKyc || 0;
    if (document.getElementById('badge-withdrawals')) document.getElementById('badge-withdrawals').textContent = d.pendingWithdrawalsCount || 0;

    // Reserves
    document.getElementById('res-deposit-bal').textContent = `₹${(d.walletBalances.totalDeposit || 0).toLocaleString('en-IN')}`;
    document.getElementById('res-winning-bal').textContent = `₹${(d.walletBalances.totalWinning || 0).toLocaleString('en-IN')}`;
    document.getElementById('res-aviator-bets').textContent = `₹${(d.totalBetsAmount || 0).toLocaleString('en-IN')} (${d.totalBetsCount || 0} bets)`;
    document.getElementById('res-aviator-rounds').textContent = d.aviatorRoundsCount || 0;

    // Recent table
    const tbody = document.getElementById('overview-txns-tbody');
    tbody.innerHTML = '';
    (d.recentTxns || []).forEach(t => {
      const row = document.createElement('tr');
      row.className = 'hover:bg-dark-700/50';
      row.innerHTML = `
        <td class="py-3 font-mono text-[11px] text-gray-400">${t.id}</td>
        <td class="py-3 font-bold text-white">${t.username || t.user_id}</td>
        <td class="py-3 uppercase text-[10px] font-extrabold text-blue-400">${t.type}</td>
        <td class="py-3 font-black text-emerald-400">₹${(t.amount || 0).toLocaleString('en-IN')}</td>
        <td class="py-3 text-gray-300">${t.title}</td>
        <td class="py-3"><span class="px-2 py-0.5 rounded-full text-[10px] font-extrabold badge-completed">${t.status}</span></td>
        <td class="py-3 text-gray-400 text-[10px]">${new Date(t.timestamp).toLocaleTimeString()}</td>
      `;
      tbody.appendChild(row);
    });

    // Chart.js render
    renderCashFlowChart(d.dailyStats || []);
  } catch (err) {
    console.error('loadOverviewStats err:', err);
  }
}

function renderCashFlowChart(stats) {
  const ctx = document.getElementById('cashflow-chart').getContext('2d');
  const labels = stats.map(s => s.date.slice(5));
  const depData = stats.map(s => s.deposits);
  const wdrData = stats.map(s => s.withdrawals);

  if (cashFlowChartInstance) {
    cashFlowChartInstance.destroy();
  }

  cashFlowChartInstance = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: labels,
      datasets: [
        {
          label: 'Deposits (₹)',
          data: depData,
          backgroundColor: '#22c55e',
          borderRadius: 6
        },
        {
          label: 'Withdrawals (₹)',
          data: wdrData,
          backgroundColor: '#f43f5e',
          borderRadius: 6
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { labels: { color: '#9ca3af', font: { family: 'Plus Jakarta Sans', weight: 'bold', size: 11 } } }
      },
      scales: {
        x: { grid: { color: '#1f2937' }, ticks: { color: '#9ca3af', font: { weight: 'bold' } } },
        y: { grid: { color: '#1f2937' }, ticks: { color: '#9ca3af', font: { weight: 'bold' } } }
      }
    }
  });
}

// TAB 2: USERS MANAGEMENT
async function loadUsers() {
  try {
    const kyc = document.getElementById('user-kyc-filter') ? document.getElementById('user-kyc-filter').value : '';
    const statusFilter = document.getElementById('user-status-filter') ? document.getElementById('user-status-filter').value : '';

    let url = `${API_BASE}/admin/users`;
    const params = [];
    if (kyc) params.push(`kyc=${encodeURIComponent(kyc)}`);
    if (statusFilter === 'online') params.push('online=true');
    if (params.length > 0) url += `?${params.join('&')}`;

    const res = await adminFetch(url);
    const json = await res.json();
    if (!json.success) return;

    allUsersData = json.data;
    let usersToShow = allUsersData;
    if (statusFilter === 'offline') {
      usersToShow = allUsersData.filter(u => !u.isOnline);
    }

    renderUsersTable(usersToShow);
    populateCreditUserSelect(allUsersData);
  } catch (err) {
    console.error('loadUsers err:', err);
  }
}

function filterUsers() {
  const q = document.getElementById('user-search-input').value.toLowerCase();
  const statusFilter = document.getElementById('user-status-filter') ? document.getElementById('user-status-filter').value : '';

  let filtered = allUsersData.filter(u => 
    u.username.toLowerCase().includes(q) ||
    u.fullName.toLowerCase().includes(q) ||
    u.email.toLowerCase().includes(q) ||
    u.phone.includes(q)
  );

  if (statusFilter === 'online') {
    filtered = filtered.filter(u => u.isOnline);
  } else if (statusFilter === 'offline') {
    filtered = filtered.filter(u => !u.isOnline);
  }

  renderUsersTable(filtered);
}

function renderUsersTable(users) {
  const tbody = document.getElementById('users-tbody');
  tbody.innerHTML = '';

  if (users.length === 0) {
    tbody.innerHTML = `<tr><td colspan="7" class="p-8 text-center text-gray-500 font-bold">No user accounts found matching query.</td></tr>`;
    return;
  }

  users.forEach(u => {
    const kycClass = u.kycStatus === 'verified' ? 'badge-verified' : u.kycStatus === 'pending' ? 'badge-pending' : 'badge-rejected';
    
    // Online Presence Indicator
    let presenceBadge = '';
    if (u.isOnline) {
      presenceBadge = `
        <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-black bg-emerald-500/20 text-emerald-400 border border-emerald-500/40 shadow-sm shadow-emerald-500/10">
          <span class="w-2 h-2 rounded-full bg-emerald-400 animate-ping"></span>
          <span>ONLINE NOW</span>
        </span>
      `;
    } else {
      let lastSeenStr = 'Never';
      if (u.lastSeenSecondsAgo !== null) {
        if (u.lastSeenSecondsAgo < 60) lastSeenStr = `${u.lastSeenSecondsAgo}s ago`;
        else if (u.lastSeenSecondsAgo < 3600) lastSeenStr = `${Math.floor(u.lastSeenSecondsAgo / 60)}m ago`;
        else if (u.lastSeenSecondsAgo < 86400) lastSeenStr = `${Math.floor(u.lastSeenSecondsAgo / 3600)}h ago`;
        else lastSeenStr = `${Math.floor(u.lastSeenSecondsAgo / 86400)}d ago`;
      }
      presenceBadge = `
        <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[10px] font-bold bg-dark-900 text-gray-400 border border-dark-700">
          <span class="w-1.5 h-1.5 rounded-full bg-gray-500"></span>
          <span>Offline (${lastSeenStr})</span>
        </span>
      `;
    }

    const row = document.createElement('tr');
    row.className = 'hover:bg-dark-700/50';
    row.innerHTML = `
      <td class="p-4">
        <div class="font-extrabold text-white text-sm flex items-center gap-2">
          <span>${u.username}</span>
          ${u.isOnline ? '<span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>' : ''}
        </div>
        <div class="text-[11px] text-gray-400">${u.fullName}</div>
        <div class="font-mono text-[9px] text-gray-500">${u.id}</div>
      </td>
      <td class="p-4">
        ${presenceBadge}
      </td>
      <td class="p-4">
        <div class="text-gray-300 font-medium">${u.email}</div>
        <div class="text-[11px] text-gray-400">${u.phone}</div>
      </td>
      <td class="p-4">
        <div class="text-emerald-400 font-black text-xs">₹${(u.wallet.totalBalance || 0).toLocaleString('en-IN')} Total</div>
        <div class="text-[10px] text-gray-400">Dep: ₹${u.wallet.depositBalance} | Win: ₹${u.wallet.winningBalance}</div>
      </td>
      <td class="p-4">
        <span class="px-2.5 py-0.5 rounded-full text-[10px] font-extrabold ${kycClass}">
          ${u.kycStatus.toUpperCase()}
        </span>
      </td>
      <td class="p-4 text-[11px] text-gray-400">${new Date(u.joinedAt).toLocaleDateString()}</td>
      <td class="p-4 text-right space-x-1.5 whitespace-nowrap">
        <button onclick="openEditUserModal('${u.id}')" class="px-2.5 py-1 bg-blue-600/20 hover:bg-blue-600/30 text-blue-400 border border-blue-500/30 font-bold rounded-lg text-[11px] transition">
          Edit
        </button>
        <button onclick="deleteUserPrompt('${u.id}', '${u.username}')" class="px-2.5 py-1 bg-rose-600/20 hover:bg-rose-600/30 text-rose-400 border border-rose-500/30 font-bold rounded-lg text-[11px] transition">
          Delete
        </button>
      </td>
    `;
    tbody.appendChild(row);
  });
}

function openAddUserModal() {
  document.getElementById('add-user-form').reset();
  openModal('modal-add-user');
}

async function submitAddUser(e) {
  e.preventDefault();
  const payload = {
    username: document.getElementById('add-username').value.trim(),
    fullName: document.getElementById('add-fullname').value.trim(),
    email: document.getElementById('add-email').value.trim(),
    phone: document.getElementById('add-phone').value.trim(),
    depositBalance: document.getElementById('add-deposit').value,
    winningBalance: document.getElementById('add-winnings').value,
    kycStatus: document.getElementById('add-kyc').value
  };

  try {
    const res = await adminFetch(`${API_BASE}/admin/users`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const json = await res.json();
    if (json.success) {
      showToast(`User ${payload.username} created successfully!`, 'success');
      closeModal('modal-add-user');
      loadUsers();
    } else {
      showToast(json.error || 'Failed to create user', 'error');
    }
  } catch (err) {
    showToast('Error creating user', 'error');
  }
}

function openEditUserModal(userId) {
  const u = allUsersData.find(x => x.id === userId);
  if (!u) return;

  document.getElementById('edit-user-id').value = u.id;
  document.getElementById('edit-username').value = u.username;
  document.getElementById('edit-fullname').value = u.fullName;
  document.getElementById('edit-email').value = u.email;
  document.getElementById('edit-phone').value = u.phone;
  document.getElementById('edit-deposit').value = u.wallet.depositBalance;
  document.getElementById('edit-winnings').value = u.wallet.winningBalance;
  document.getElementById('edit-kyc').value = u.kycStatus;

  openModal('modal-edit-user');
}

async function submitEditUser(e) {
  e.preventDefault();
  const userId = document.getElementById('edit-user-id').value;
  const payload = {
    username: document.getElementById('edit-username').value.trim(),
    fullName: document.getElementById('edit-fullname').value.trim(),
    email: document.getElementById('edit-email').value.trim(),
    phone: document.getElementById('edit-phone').value.trim(),
    depositBalance: document.getElementById('edit-deposit').value,
    winningBalance: document.getElementById('edit-winnings').value,
    kycStatus: document.getElementById('edit-kyc').value
  };

  try {
    const res = await adminFetch(`${API_BASE}/admin/users/${userId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const json = await res.json();
    if (json.success) {
      showToast('User updated successfully!', 'success');
      closeModal('modal-edit-user');
      loadUsers();
    } else {
      showToast(json.error || 'Failed to update user', 'error');
    }
  } catch (err) {
    showToast('Error updating user', 'error');
  }
}

async function deleteUserPrompt(userId, username) {
  if (!confirm(`Are you sure you want to permanently delete user "${username}"? All wallet balances and tournament history will be purged.`)) {
    return;
  }

  try {
    const res = await adminFetch(`${API_BASE}/admin/users/${userId}`, { method: 'DELETE' });
    const json = await res.json();
    if (json.success) {
      showToast(`User ${username} deleted`, 'success');
      loadUsers();
    } else {
      showToast(json.error || 'Failed to delete user', 'error');
    }
  } catch (err) {
    showToast('Error deleting user', 'error');
  }
}

// TAB 3: KYC VERIFICATION (Zero-Latency Optimistic State Management)
let allKycData = [];

async function loadKycList() {
  try {
    const filter = document.getElementById('kyc-status-filter').value;
    let url = `${API_BASE}/admin/kyc`;
    if (filter) url += `?status=${filter}`;

    const res = await adminFetch(url);
    const json = await res.json();
    if (!json.success) return;

    allKycData = json.data;
    renderKycTable(allKycData);
  } catch (err) {
    console.error('loadKycList err:', err);
  }
}

function renderKycTable(list) {
  const tbody = document.getElementById('kyc-tbody');
  tbody.innerHTML = '';

  if (list.length === 0) {
    tbody.innerHTML = `<tr><td colspan="6" class="p-8 text-center text-gray-500 font-bold">No KYC verification documents found.</td></tr>`;
    return;
  }

  list.forEach(item => {
    const row = document.createElement('tr');
    row.id = `kyc-row-${item.id}`;
    row.className = 'hover:bg-dark-700/50 transition-colors duration-150';
    row.innerHTML = `
      <td class="p-4">
        <div class="font-extrabold text-white text-sm">${item.username}</div>
        <div class="text-[11px] text-gray-400">${item.full_name}</div>
        <div class="font-mono text-[9px] text-gray-500">${item.id}</div>
      </td>
      <td class="p-4 font-bold text-amber-400 text-xs">${item.kyc_document_type || 'N/A'}</td>
      <td class="p-4 font-mono font-bold text-gray-200 text-xs">${item.kyc_document_number || 'N/A'}</td>
      <td class="p-4" id="kyc-status-cell-${item.id}">
        ${getKycBadgeHtml(item.kyc_status)}
      </td>
      <td class="p-4 text-[11px] text-gray-400">${new Date(item.updated_at).toLocaleString()}</td>
      <td class="p-4 text-right whitespace-nowrap" id="kyc-actions-cell-${item.id}">
        ${getKycActionsHtml(item)}
      </td>
    `;
    tbody.appendChild(row);
  });
}

function getKycBadgeHtml(status) {
  if (status === 'verified') {
    return `<span class="px-2.5 py-1 rounded-full text-[10px] font-black badge-verified inline-flex items-center gap-1 shadow-sm shadow-emerald-500/20"><span>APPROVED</span><span>✅</span></span>`;
  } else if (status === 'rejected') {
    return `<span class="px-2.5 py-1 rounded-full text-[10px] font-black badge-rejected inline-flex items-center gap-1 shadow-sm shadow-rose-500/20"><span>REJECTED</span><span>❌</span></span>`;
  } else {
    return `<span class="px-2.5 py-1 rounded-full text-[10px] font-black badge-pending inline-flex items-center gap-1 shadow-sm shadow-amber-500/20"><span>PENDING</span><span>⏳</span></span>`;
  }
}

function getKycActionsHtml(item) {
  return `
    <div class="inline-flex items-center gap-1.5">
      ${item.kyc_status !== 'verified' ? `
        <button onclick="applyKycDecisionOptimistic('${item.id}', '${item.username}', 'verified')" title="Instant Approve (0ms)" class="px-2.5 py-1.5 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-lg text-[11px] transition flex items-center gap-1 shadow-sm shadow-emerald-600/30">
          <span>Approve</span>
        </button>
      ` : ''}
      ${item.kyc_status !== 'rejected' ? `
        <button onclick="applyKycDecisionOptimistic('${item.id}', '${item.username}', 'rejected')" title="Instant Reject (0ms)" class="px-2.5 py-1.5 bg-rose-600/20 hover:bg-rose-600/40 text-rose-400 border border-rose-500/30 font-bold rounded-lg text-[11px] transition flex items-center gap-1">
          <span>Reject</span>
        </button>
      ` : ''}
      <button onclick="openReviewKycModal('${item.id}', '${item.username}', '${item.kyc_document_type}', '${item.kyc_document_number}')" title="Detailed Review" class="px-2 py-1.5 bg-dark-700 hover:bg-dark-600 text-gray-300 border border-dark-600 font-bold rounded-lg text-[11px] transition">
        Details
      </button>
    </div>
  `;
}

function openReviewKycModal(userId, username, docType, docNum) {
  document.getElementById('kyc-review-user-id').value = userId;
  document.getElementById('kyc-review-username').textContent = username;
  document.getElementById('kyc-review-doctype').textContent = docType || 'Government ID';
  document.getElementById('kyc-review-docnum').textContent = docNum || 'Document Submitted';
  document.getElementById('kyc-reject-reason').value = '';
  openModal('modal-review-kyc');
}

// 0-LATENCY OPTIMISTIC KYC DECISION
function submitKycDecision(status) {
  const userId = document.getElementById('kyc-review-user-id').value;
  const username = document.getElementById('kyc-review-username').textContent;
  const reason = document.getElementById('kyc-reject-reason').value.trim();
  closeModal('modal-review-kyc');
  applyKycDecisionOptimistic(userId, username, status, reason);
}

function applyKycDecisionOptimistic(userId, username, status, reason = '') {
  // 1. INSTANT 0-LATENCY UI UPDATE (synchronous DOM mutations)
  const item = allKycData.find(x => x.id === userId);
  const oldStatus = item ? item.kyc_status : 'pending';
  if (item) item.kyc_status = status;

  // Update user in allUsersData if present
  const user = allUsersData.find(u => u.id === userId);
  if (user) user.kycStatus = status;

  // Instantly update badge and buttons in the row
  const statusCell = document.getElementById(`kyc-status-cell-${userId}`);
  if (statusCell) {
    statusCell.innerHTML = getKycBadgeHtml(status);
  }

  const actionsCell = document.getElementById(`kyc-actions-cell-${userId}`);
  if (actionsCell && item) {
    actionsCell.innerHTML = getKycActionsHtml(item);
  }

  // Update sidebar counter badge instantly
  const pendingCount = allKycData.filter(x => x.kyc_status === 'pending').length;
  const badgeKyc = document.getElementById('badge-kyc');
  if (badgeKyc) badgeKyc.textContent = pendingCount;

  // Immediate feedback toast (0 latency)
  const label = status === 'verified' ? 'APPROVED ✅' : 'REJECTED ❌';
  showToast(`KYC for ${username || 'User'} marked as ${label} (Instant)`, status === 'verified' ? 'success' : 'error');

  // 2. PERSIST TO BACKEND IN BACKGROUND
  adminFetch(`${API_BASE}/admin/kyc/${userId}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ status, reason })
  }).then(res => res.json()).then(json => {
    if (!json.success) {
      // Revert if server rejected
      if (item) item.kyc_status = oldStatus;
      if (statusCell) statusCell.innerHTML = getKycBadgeHtml(oldStatus);
      if (actionsCell && item) actionsCell.innerHTML = getKycActionsHtml(item);
      showToast(json.error || 'Failed to persist KYC change', 'error');
    }
  }).catch(() => {
    // Revert on network error
    if (item) item.kyc_status = oldStatus;
    if (statusCell) statusCell.innerHTML = getKycBadgeHtml(oldStatus);
    if (actionsCell && item) actionsCell.innerHTML = getKycActionsHtml(item);
    showToast('Network error updating KYC', 'error');
  });
}

// TAB 4: DEPOSITS
async function loadDeposits() {
  try {
    const res = await adminFetch(`${API_BASE}/admin/deposits`);
    const json = await res.json();
    if (!json.success) return;

    allDepositsData = json.data;
    renderDepositsTable(allDepositsData);
  } catch (err) {
    console.error('loadDeposits err:', err);
  }
}

function filterDeposits() {
  const q = document.getElementById('deposit-search-input').value.toLowerCase();
  const filtered = allDepositsData.filter(d => 
    (d.reference_id && d.reference_id.toLowerCase().includes(q)) ||
    (d.username && d.username.toLowerCase().includes(q)) ||
    d.id.toLowerCase().includes(q)
  );
  renderDepositsTable(filtered);
}

function renderDepositsTable(deposits) {
  const tbody = document.getElementById('deposits-tbody');
  tbody.innerHTML = '';

  if (deposits.length === 0) {
    tbody.innerHTML = `<tr><td colspan="7" class="p-8 text-center text-gray-500 font-bold">No deposit transactions logged yet.</td></tr>`;
    return;
  }

  deposits.forEach(d => {
    const row = document.createElement('tr');
    row.className = 'hover:bg-dark-700/50';
    row.innerHTML = `
      <td class="p-4 font-mono text-[11px] text-gray-400">${d.id}</td>
      <td class="p-4">
        <div class="font-extrabold text-white text-xs">${d.username || d.user_id}</div>
        <div class="text-[10px] text-gray-400">${d.full_name || ''}</div>
      </td>
      <td class="p-4 font-black text-emerald-400 text-sm">₹${(d.amount || 0).toLocaleString('en-IN')}</td>
      <td class="p-4 font-mono text-xs font-bold text-gray-300">${d.reference_id || 'N/A'}</td>
      <td class="p-4 text-gray-400 text-xs">${d.payment_method || 'UPI Gateway'}</td>
      <td class="p-4"><span class="px-2.5 py-0.5 rounded-full text-[10px] font-extrabold badge-completed">${d.status}</span></td>
      <td class="p-4 text-gray-400 text-[11px]">${new Date(d.timestamp).toLocaleString()}</td>
    `;
    tbody.appendChild(row);
  });
}

function populateCreditUserSelect(users) {
  const sel = document.getElementById('credit-user-select');
  if (!sel) return;
  sel.innerHTML = '';
  users.forEach(u => {
    const opt = document.createElement('option');
    opt.value = u.id;
    opt.textContent = `${u.username} (${u.fullName}) - Balance: ₹${u.wallet.totalBalance}`;
    sel.appendChild(opt);
  });
}

function openManualCreditModal() {
  document.getElementById('manual-credit-form').reset();
  openModal('modal-manual-credit');
}

async function submitManualCredit(e) {
  e.preventDefault();
  const payload = {
    userId: document.getElementById('credit-user-select').value,
    amount: document.getElementById('credit-amount').value,
    balanceType: document.getElementById('credit-balance-type').value,
    title: 'Admin Manual Credit',
    description: document.getElementById('credit-note').value || 'Manual Wallet Adjustment by Admin'
  };

  try {
    const res = await adminFetch(`${API_BASE}/admin/deposits/manual`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const json = await res.json();
    if (json.success) {
      showToast(json.message, 'success');
      closeModal('modal-manual-credit');
      loadDeposits();
      loadUsers();
    } else {
      showToast(json.error || 'Failed to credit amount', 'error');
    }
  } catch (err) {
    showToast('Error executing manual credit', 'error');
  }
}

// TAB 5: WITHDRAWALS
async function loadWithdrawals() {
  try {
    const filter = document.getElementById('withdrawal-filter').value;
    let url = `${API_BASE}/admin/withdrawals`;
    if (filter) url += `?status=${filter}`;

    const res = await adminFetch(url);
    const json = await res.json();
    if (!json.success) return;

    const tbody = document.getElementById('withdrawals-tbody');
    tbody.innerHTML = '';

    if (json.data.length === 0) {
      tbody.innerHTML = `<tr><td colspan="8" class="p-8 text-center text-gray-500 font-bold">No withdrawal requests found.</td></tr>`;
      return;
    }

    json.data.forEach(w => {
      let statusBadge = '';
      if (w.status === 'completed') {
        statusBadge = `<span class="px-2.5 py-0.5 rounded-full text-[10px] font-extrabold badge-completed">SETTLED ✅</span>`;
      } else if (w.status === 'rejected') {
        statusBadge = `<span class="px-2.5 py-0.5 rounded-full text-[10px] font-extrabold badge-rejected">REFUNDED ❌</span>`;
      } else if (w.status === 'processing') {
        statusBadge = `<span class="px-2.5 py-0.5 rounded-full text-[10px] font-extrabold bg-blue-500/20 text-blue-400 border border-blue-500/30">PROCESSING ⏳</span>`;
      } else {
        // requested (4h hold)
        const holdText = w.remainingMinutes > 0 ? `${Math.floor(w.remainingMinutes / 60)}h ${w.remainingMinutes % 60}m` : '0m';
        statusBadge = `<span class="px-2.5 py-0.5 rounded-full text-[10px] font-extrabold badge-pending" title="4h security verification hold">REQUESTED 🕒 (${holdText})</span>`;
      }

      const kycClass = w.kyc_status === 'verified' ? 'text-emerald-400 font-bold' : 'text-amber-400 font-bold';

      const row = document.createElement('tr');
      row.className = 'hover:bg-dark-700/50';
      row.innerHTML = `
        <td class="p-4 font-mono text-[11px] text-gray-400">${w.id}</td>
        <td class="p-4">
          <div class="font-extrabold text-white text-xs">${w.username}</div>
          <div class="text-[10px] text-gray-400">Win Balance: ₹${w.winning_balance}</div>
        </td>
        <td class="p-4 font-black text-rose-400 text-sm">₹${(w.amount || 0).toLocaleString('en-IN')}</td>
        <td class="p-4">
          <div class="font-bold text-white text-xs">${w.method}</div>
          <div class="font-mono text-[11px] text-gray-400">${w.account_details}</div>
        </td>
        <td class="p-4 text-xs ${kycClass}">${w.kyc_status.toUpperCase()}</td>
        <td class="p-4">${statusBadge}</td>
        <td class="p-4 text-[11px] text-gray-400">${new Date(w.created_at).toLocaleString()}</td>
        <td class="p-4 text-right space-x-1.5 whitespace-nowrap">
          ${w.status === 'requested' ? `
            <button onclick="fastTrackWithdrawal('${w.id}')" title="Bypass 4h hold and move to processing now" class="px-2 py-1 bg-amber-600/20 hover:bg-amber-600/30 text-amber-400 border border-amber-500/30 font-bold rounded-lg text-[11px] transition">
              ⚡ Fast-Track
            </button>
            <button onclick="approveWithdrawal('${w.id}', ${w.amount})" class="px-2.5 py-1 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-lg text-[11px] transition shadow-sm shadow-emerald-600/20">
              Approve
            </button>
            <button onclick="rejectWithdrawal('${w.id}', ${w.amount})" class="px-2.5 py-1 bg-rose-600/20 hover:bg-rose-600/30 text-rose-400 border border-rose-500/30 font-bold rounded-lg text-[11px] transition">
              Reject
            </button>
          ` : w.status === 'processing' ? `
            <button onclick="approveWithdrawal('${w.id}', ${w.amount})" class="px-2.5 py-1 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-lg text-[11px] transition shadow-sm shadow-emerald-600/20">
              Approve Payout
            </button>
            <button onclick="rejectWithdrawal('${w.id}', ${w.amount})" class="px-2.5 py-1 bg-rose-600/20 hover:bg-rose-600/30 text-rose-400 border border-rose-500/30 font-bold rounded-lg text-[11px] transition">
              Reject & Refund
            </button>
          ` : `<span class="text-xs text-gray-500 font-bold">Settled</span>`}
        </td>
      `;
      tbody.appendChild(row);
    });
  } catch (err) {
    console.error('loadWithdrawals err:', err);
  }
}

async function fastTrackWithdrawal(id) {
  try {
    const res = await adminFetch(`${API_BASE}/admin/withdrawals/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'fast_track' })
    });
    const json = await res.json();
    if (json.success) {
      showToast('Withdrawal moved to PROCESSING state (Ready for payout)!', 'info');
      loadWithdrawals();
    } else {
      showToast(json.error || 'Failed to fast-track', 'error');
    }
  } catch (err) {
    showToast('Error fast-tracking withdrawal', 'error');
  }
}

async function approveWithdrawal(id, amount) {
  const ref = prompt(`Enter Payment UTR / IMPS Reference number for ₹${amount} payout:`, `PAY_IMPS_${Date.now()}`);
  if (!ref) return;

  try {
    const res = await adminFetch(`${API_BASE}/admin/withdrawals/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'approve', utrRef: ref })
    });
    const json = await res.json();
    if (json.success) {
      showToast(json.message, 'success');
      loadWithdrawals();
    } else {
      showToast(json.error || 'Failed to approve withdrawal', 'error');
    }
  } catch (err) {
    showToast('Error approving withdrawal', 'error');
  }
}

async function rejectWithdrawal(id, amount) {
  const reason = prompt(`Reason for rejecting ₹${amount} withdrawal (Amount will be refunded to user winning wallet):`, 'Invalid Bank Account / IFSC mismatch');
  if (!reason) return;

  try {
    const res = await adminFetch(`${API_BASE}/admin/withdrawals/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'reject', reason })
    });
    const json = await res.json();
    if (json.success) {
      showToast(json.message, 'success');
      loadWithdrawals();
    } else {
      showToast(json.error || 'Failed to reject withdrawal', 'error');
    }
  } catch (err) {
    showToast('Error rejecting withdrawal', 'error');
  }
}

// Background Auto-Sync for Live Dashboard (Every 2.5 seconds)
let globalAdminSyncTimer = null;

function startGlobalAdminSync() {
  if (globalAdminSyncTimer) clearInterval(globalAdminSyncTimer);
  globalAdminSyncTimer = setInterval(() => {
    // Only background sync if logged in and not typing in an input
    const activeEl = document.activeElement;
    const isTyping = activeEl && (activeEl.tagName === 'INPUT' || activeEl.tagName === 'SELECT' || activeEl.tagName === 'TEXTAREA');
    if (isTyping) return;

    // Keep online user counters fresh
    if (currentTab === 'overview') {
      loadOverviewStats();
    } else {
      // Light background poll for stats
      adminFetch(`${API_BASE}/admin/stats`)
        .then(r => r.json())
        .then(json => {
          if (json.success && json.data) {
            const online = json.data.onlineUsers || 0;
            if (document.getElementById('badge-online-count')) {
              document.getElementById('badge-online-count').textContent = `${online} online`;
            }
          }
        })
        .catch(() => {});
    }

    if (currentTab === 'users') loadUsers();
    if (currentTab === 'deposits') loadDeposits();
    if (currentTab === 'withdrawals') loadWithdrawals();
    if (currentTab === 'kyc') loadKycList();
  }, 2500);
}

// Start global auto sync when showing app shell
startGlobalAdminSync();

// TAB 7: AVIATOR CRASH ENGINE COCKPIT
function startAviatorPolling() {
  clearInterval(aviatorPollTimer);
  loadAviatorCockpit();
  aviatorPollTimer = setInterval(loadAviatorCockpit, 1000);
}

async function loadAviatorCockpit() {
  try {
    const res = await adminFetch(`${API_BASE}/admin/aviator`);
    const json = await res.json();
    if (!json.success) return;

    const d = json.data;
    const badge = document.getElementById('aviator-state-badge');
    const mult = document.getElementById('aviator-live-multiplier');
    const statusText = document.getElementById('aviator-status-text');

    badge.textContent = d.currentState.toUpperCase();
    if (d.currentState === 'flying') {
      badge.className = 'px-3 py-1 rounded-full text-xs font-black uppercase bg-emerald-500/20 border border-emerald-500/30 text-emerald-400';
      mult.className = 'text-6xl sm:text-7xl font-black text-emerald-400 tracking-tight drop-shadow-2xl';
      mult.textContent = `${d.currentMultiplier.toFixed(2)}x`;
      statusText.textContent = '✈️ Plane in Flight';
    } else if (d.currentState === 'crashed') {
      badge.className = 'px-3 py-1 rounded-full text-xs font-black uppercase bg-red-500/20 border border-red-500/30 text-red-400';
      mult.className = 'text-6xl sm:text-7xl font-black text-red-500 tracking-tight drop-shadow-2xl';
      mult.textContent = `CRASHED @ ${d.currentMultiplier.toFixed(2)}x`;
      statusText.textContent = '💥 Flight Terminated';
    } else {
      badge.className = 'px-3 py-1 rounded-full text-xs font-black uppercase bg-dark-900 border border-dark-600 text-gray-300';
      mult.className = 'text-6xl sm:text-7xl font-black text-white tracking-tight drop-shadow-2xl';
      mult.textContent = '1.00x';
      statusText.textContent = 'Preparing next round...';
    }

    document.getElementById('aviator-target-display').textContent = d.forcedTarget ? `${d.forcedTarget.toFixed(2)}x (FORCED)` : `${d.targetCrashMultiplier.toFixed(2)}x (Fair)`;

    // History ribbon
    const ribbon = document.getElementById('aviator-history-ribbon');
    ribbon.innerHTML = '';
    (d.history || []).slice(0, 15).forEach(m => {
      const color = m >= 10.0 ? 'bg-purple-900/40 text-purple-400 border-purple-700' : m >= 2.0 ? 'bg-emerald-900/40 text-emerald-400 border-emerald-700' : 'bg-blue-900/40 text-blue-400 border-blue-700';
      const pill = document.createElement('span');
      pill.className = `px-2 py-0.5 rounded-md text-[10px] font-black border ${color}`;
      pill.textContent = `${m.toFixed(2)}x`;
      ribbon.appendChild(pill);
    });
  } catch (err) {
    // Silent catch on poll
  }
}

function setPresetMultiplier(val) {
  document.getElementById('aviator-override-input').value = val;
  applyMultiplierOverride();
}

async function applyMultiplierOverride() {
  const val = document.getElementById('aviator-override-input').value;
  if (!val || parseFloat(val) < 1.0) {
    showToast('Enter valid target multiplier (>= 1.00)', 'error');
    return;
  }

  try {
    const res = await adminFetch(`${API_BASE}/admin/aviator/control`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'set_target', targetMultiplier: val })
    });
    const json = await res.json();
    if (json.success) {
      showToast(json.message, 'success');
      loadAviatorCockpit();
    } else {
      showToast(json.error || 'Failed to set target', 'error');
    }
  } catch (err) {
    showToast('Error setting target', 'error');
  }
}

async function forceCrashNow() {
  try {
    const res = await adminFetch(`${API_BASE}/admin/aviator/control`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'force_crash' })
    });
    const json = await res.json();
    if (json.success) {
      showToast(json.message, 'error');
      loadAviatorCockpit();
    } else {
      showToast(json.error || 'Failed to crash plane', 'error');
    }
  } catch (err) {
    showToast('Error sending force crash', 'error');
  }
}

async function resetFairMode() {
  try {
    const res = await adminFetch(`${API_BASE}/admin/aviator/control`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: 'reset_fair' })
    });
    const json = await res.json();
    if (json.success) {
      showToast(json.message, 'success');
      loadAviatorCockpit();
    }
  } catch (err) {
    showToast('Error resetting mode', 'error');
  }
}

// TAB 8: GLOBAL AUDIT LEDGER
async function loadLedger() {
  try {
    const res = await adminFetch(`${API_BASE}/admin/stats`);
    const json = await res.json();
    if (!json.success) return;

    const tbody = document.getElementById('ledger-tbody');
    tbody.innerHTML = '';

    (json.data.recentTxns || []).forEach(t => {
      const row = document.createElement('tr');
      row.className = 'hover:bg-dark-700/50';
      row.innerHTML = `
        <td class="p-4 font-mono text-[11px] text-gray-400">${t.id}</td>
        <td class="p-4 font-extrabold text-white text-xs">${t.username || t.user_id}</td>
        <td class="p-4 uppercase text-[10px] font-extrabold text-indigo-400">${t.type}</td>
        <td class="p-4 font-black text-white text-xs">₹${(t.amount || 0).toLocaleString('en-IN')}</td>
        <td class="p-4">
          <div class="font-bold text-gray-200 text-xs">${t.title}</div>
          <div class="text-[10px] text-gray-400">${t.description || ''}</div>
        </td>
        <td class="p-4"><span class="px-2.5 py-0.5 rounded-full text-[10px] font-extrabold badge-completed">${t.status}</span></td>
        <td class="p-4 text-[11px] text-gray-400">${new Date(t.timestamp).toLocaleString()}</td>
      `;
      tbody.appendChild(row);
    });
  } catch (err) {
    console.error('loadLedger err:', err);
  }
}

// TAB 9: FINANCIAL LIMITS & SETTINGS
async function loadSettings() {
  try {
    const res = await adminFetch(`${API_BASE}/admin/settings`);
    const json = await res.json();
    if (!json.success) return;

    const d = json.data;
    // Update live stat displays
    document.getElementById('stat-min-deposit').textContent = `₹${(d.minDeposit || 50).toLocaleString('en-IN')}`;
    document.getElementById('stat-min-withdrawal').textContent = `₹${(d.minWithdrawal || 50).toLocaleString('en-IN')}`;
    document.getElementById('stat-max-deposit').textContent = `₹${(d.maxDeposit || 50000).toLocaleString('en-IN')}`;
    document.getElementById('stat-max-withdrawal').textContent = `₹${(d.maxWithdrawal || 100000).toLocaleString('en-IN')}`;

    // Update financial input form fields only if not currently focused
    const minDepInp = document.getElementById('setting-min-deposit');
    const minWthInp = document.getElementById('setting-min-withdrawal');
    const maxDepInp = document.getElementById('setting-max-deposit');
    const maxWthInp = document.getElementById('setting-max-withdrawal');

    if (minDepInp && document.activeElement !== minDepInp) minDepInp.value = d.minDeposit || 50;
    if (minWthInp && document.activeElement !== minWthInp) minWthInp.value = d.minWithdrawal || 50;
    if (maxDepInp && document.activeElement !== maxDepInp) maxDepInp.value = d.maxDeposit || 50000;
    if (maxWthInp && document.activeElement !== maxWthInp) maxWthInp.value = d.maxWithdrawal || 100000;

    // Update Razorpay fields
    const rzpEnabled = document.getElementById('setting-razorpay-enabled');
    const rzpKeyId = document.getElementById('setting-razorpay-key-id');
    const rzpKeySecret = document.getElementById('setting-razorpay-key-secret');
    const rzpWebhookSecret = document.getElementById('setting-razorpay-webhook-secret');
    const rzpStatusBadge = document.getElementById('rzp-status-badge');

    if (rzpEnabled) rzpEnabled.checked = d.razorpayEnabled !== false;
    if (rzpKeyId && document.activeElement !== rzpKeyId) rzpKeyId.value = d.razorpayKeyId || '';
    if (rzpKeySecret && document.activeElement !== rzpKeySecret) rzpKeySecret.value = d.razorpayKeySecret || '';
    if (rzpWebhookSecret && document.activeElement !== rzpWebhookSecret) rzpWebhookSecret.value = d.razorpayWebhookSecret || '';

    // Update webhook endpoint URL with dynamic host
    const webhookInp = document.getElementById('setting-rzp-webhook-url');
    if (webhookInp) {
      webhookInp.value = `${window.location.protocol}//${window.location.hostname || 'localhost'}:5050/api/wallet/razorpay/webhook`;
    }

    if (rzpStatusBadge) {
      if (d.razorpayEnabled === false) {
        rzpStatusBadge.className = 'px-2.5 py-0.5 rounded-full text-[10px] font-black bg-gray-500/20 text-gray-400 border border-gray-500/30';
        rzpStatusBadge.textContent = 'GATEWAY DISABLED';
      } else if (!d.razorpayKeyId || d.razorpayKeyId.length < 5 || d.razorpayKeyId === 'rzp_test_YOUR_KEY_ID') {
        rzpStatusBadge.className = 'px-2.5 py-0.5 rounded-full text-[10px] font-black bg-amber-500/20 text-amber-400 border border-amber-500/30';
        rzpStatusBadge.textContent = 'NOT CONFIGURED';
      } else {
        rzpStatusBadge.className = 'px-2.5 py-0.5 rounded-full text-[10px] font-black bg-emerald-500/20 text-emerald-400 border border-emerald-500/30';
        rzpStatusBadge.textContent = 'GATEWAY ACTIVE';
      }
    }
  } catch (err) {
    console.error('loadSettings error:', err);
  }
}

async function saveFinancialSettings(e) {
  e.preventDefault();
  const minDeposit = parseInt(document.getElementById('setting-min-deposit').value, 10);
  const minWithdrawal = parseInt(document.getElementById('setting-min-withdrawal').value, 10);
  const maxDeposit = parseInt(document.getElementById('setting-max-deposit').value, 10);
  const maxWithdrawal = parseInt(document.getElementById('setting-max-withdrawal').value, 10);

  const razorpayEnabled = document.getElementById('setting-razorpay-enabled') ? document.getElementById('setting-razorpay-enabled').checked : true;
  const razorpayKeyId = document.getElementById('setting-razorpay-key-id') ? document.getElementById('setting-razorpay-key-id').value.trim() : '';
  const razorpayKeySecret = document.getElementById('setting-razorpay-key-secret') ? document.getElementById('setting-razorpay-key-secret').value.trim() : '';
  const razorpayWebhookSecret = document.getElementById('setting-razorpay-webhook-secret') ? document.getElementById('setting-razorpay-webhook-secret').value.trim() : '';

  if (isNaN(minDeposit) || minDeposit < 1) {
    showToast('Minimum deposit must be at least ₹1', 'error');
    return;
  }
  if (isNaN(minWithdrawal) || minWithdrawal < 1) {
    showToast('Minimum withdrawal must be at least ₹1', 'error');
    return;
  }

  try {
    const res = await adminFetch(`${API_BASE}/admin/settings`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        minDeposit,
        minWithdrawal,
        maxDeposit,
        maxWithdrawal,
        razorpayEnabled,
        razorpayKeyId,
        razorpayKeySecret,
        razorpayWebhookSecret
      })
    });
    const json = await res.json();
    if (json.success) {
      showToast('Razorpay configuration & financial limits saved successfully!', 'success');
      loadSettings();
    } else {
      showToast(json.error || 'Failed to save settings', 'error');
    }
  } catch (err) {
    showToast('Error saving settings', 'error');
  }
}

function toggleSecretVisibility(inputId) {
  const input = document.getElementById(inputId);
  if (!input) return;
  input.type = input.type === 'password' ? 'text' : 'password';
}

function copyWebhookUrl() {
  const urlInp = document.getElementById('setting-rzp-webhook-url');
  if (!urlInp) return;
  urlInp.select();
  navigator.clipboard.writeText(urlInp.value).then(() => {
    showToast('Webhook URL copied to clipboard!', 'success');
  }).catch(() => {
    showToast('Webhook URL: ' + urlInp.value, 'info');
  });
}

