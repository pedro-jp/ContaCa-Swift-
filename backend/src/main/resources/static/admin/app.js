// ContaCa Admin Panel Client Logic (Cookie & JWT Auth)
const API_BASE = '/api/admin';

// Elementos da DOM - Auth
const adminLoginView = document.getElementById('adminLoginView');
const adminDashboardView = document.getElementById('adminDashboardView');
const loginForm = document.getElementById('loginForm');
const inputUsername = document.getElementById('inputUsername');
const inputPassword = document.getElementById('inputPassword');
const btnSubmitLogin = document.getElementById('btnSubmitLogin');
const loginAlertBox = document.getElementById('loginAlertBox');
const btnLogout = document.getElementById('btnLogout');
const statusIndicator = document.getElementById('statusIndicator');

// Elementos da DOM - Dashboard
const alertBox = document.getElementById('alertBox');
const totalUsersCount = document.getElementById('totalUsersCount');
const totalFoodsCount = document.getElementById('totalFoodsCount');
const totalWorkoutsCount = document.getElementById('totalWorkoutsCount');
const totalAiCount = document.getElementById('totalAiCount');

const maskedKeyDisplay = document.getElementById('maskedKeyDisplay');
const currentModelDisplay = document.getElementById('currentModelDisplay');
const keyStatusBadge = document.getElementById('keyStatusBadge');
const newApiKeyInput = document.getElementById('newApiKeyInput');
const geminiModelSelect = document.getElementById('geminiModelSelect');
const btnSaveKey = document.getElementById('btnSaveKey');
const btnTestKey = document.getElementById('btnTestKey');

const btnRefreshUsers = document.getElementById('btnRefreshUsers');
const usersTableBody = document.getElementById('usersTableBody');
const logsTableBody = document.getElementById('logsTableBody');

// Inicialização
document.addEventListener('DOMContentLoaded', () => {
    checkAuthentication();
    attachEvents();
});

function attachEvents() {
    loginForm.addEventListener('submit', handleLogin);
    btnLogout.addEventListener('click', handleLogout);
    btnSaveKey.addEventListener('click', saveNewKey);
    btnTestKey.addEventListener('click', testKeyConnection);
    btnRefreshUsers.addEventListener('click', loadOverview);
}

// Verifica se já existe sessão válida ativa no Cookie HttpOnly
async function checkAuthentication() {
    try {
        const resp = await fetch(`${API_BASE}/auth-check`, {
            method: 'GET',
            credentials: 'include'
        });

        if (resp.ok) {
            const data = await resp.json();
            showDashboard(data.username || 'admin');
            loadOverview();
        } else {
            showLogin();
        }
    } catch (e) {
        showLogin();
    }
}

async function handleLogin(e) {
    e.preventDefault();
    loginAlertBox.classList.add('hidden');
    btnSubmitLogin.disabled = true;
    btnSubmitLogin.innerHTML = '<span>Verificando credenciais...</span>';

    const username = inputUsername.value.trim();
    const password = inputPassword.value.trim();

    try {
        const resp = await fetch(`${API_BASE}/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include', // Salva e envia o cookie HttpOnly contaca_admin_token
            body: JSON.stringify({ username, password })
        });

        const data = await resp.json();

        if (resp.ok) {
            showDashboard(data.username || username);
            loadOverview();
            showAlert('Login de administrador realizado com sucesso!', true);
        } else {
            showLoginError(data.error || 'Credenciais inválidas.');
        }
    } catch (err) {
        showLoginError('Erro de conexão com o servidor.');
    } finally {
        btnSubmitLogin.disabled = false;
        btnSubmitLogin.innerHTML = '<span>Acessar Painel</span>';
    }
}

async function handleLogout() {
    try {
        await fetch(`${API_BASE}/logout`, {
            method: 'POST',
            credentials: 'include'
        });
    } catch (ignored) {}

    showLogin();
}

function showDashboard(username) {
    adminLoginView.classList.add('hidden');
    adminDashboardView.classList.remove('hidden');
    statusIndicator.textContent = `🟢 Conectado (${username})`;
    statusIndicator.className = 'status-pill status-online';
}

function showLogin() {
    adminDashboardView.classList.add('hidden');
    adminLoginView.classList.remove('hidden');
    inputPassword.value = '';
    loginAlertBox.classList.add('hidden');
}

function showLoginError(msg) {
    loginAlertBox.textContent = msg;
    loginAlertBox.classList.remove('hidden');
}

function showAlert(message, isSuccess = true) {
    alertBox.textContent = message;
    alertBox.className = `alert-box ${isSuccess ? 'alert-success' : 'alert-error'}`;
    alertBox.classList.remove('hidden');
    setTimeout(() => {
        alertBox.classList.add('hidden');
    }, 6000);
}

// Carregamento dos dados gerais
async function loadOverview() {
    try {
        const response = await fetch(`${API_BASE}/overview`, {
            method: 'GET',
            credentials: 'include'
        });

        if (response.status === 401) {
            showLogin();
            return;
        }

        if (!response.ok) {
            showAlert('Erro ao carregar dados do painel.', false);
            return;
        }

        const data = await response.json();

        // Atualiza contadores
        totalUsersCount.textContent = (data.totalUsers || 0).toLocaleString();
        totalFoodsCount.textContent = (data.totalFoods || 0).toLocaleString();
        totalWorkoutsCount.textContent = (data.totalWorkouts || 0).toLocaleString();
        totalAiCount.textContent = (data.totalAiRequests || 0).toLocaleString();

        // Atualiza status da chave Gemini
        maskedKeyDisplay.textContent = data.activeApiKeyMasked || 'Não configurada';
        currentModelDisplay.textContent = data.geminiModel || 'gemini-3.8-flash';

        if (data.hasValidApiKey) {
            keyStatusBadge.textContent = 'Ativa & Operacional';
            keyStatusBadge.className = 'badge badge-success';
        } else {
            keyStatusBadge.textContent = 'Não configurada';
            keyStatusBadge.className = 'badge badge-warning';
        }

        // Carrega a lista completa de modelos disponíveis via API
        await loadAvailableModels(data.geminiModel || 'gemini-3.8-flash');

        // Renderiza tabelas
        renderUsersTable(data.recentUsers || []);
        renderLogsTable(data.recentLogs || []);

    } catch (e) {
        console.error('Erro na requisição overview:', e);
    }
}

// Carrega os modelos suportados pelo Gemini (dinâmico via backend)
async function loadAvailableModels(activeModel) {
    try {
        const resp = await fetch(`${API_BASE}/models`, {
            method: 'GET',
            credentials: 'include'
        });

        if (!resp.ok) return;

        const data = await resp.json();
        const models = data.models || [];
        const current = data.currentModel || activeModel || 'gemini-3.8-flash';

        if (models.length > 0) {
            geminiModelSelect.innerHTML = '';
            models.forEach(m => {
                const opt = document.createElement('option');
                opt.value = m.id;
                opt.textContent = m.displayName || m.id;
                if (m.id === current) {
                    opt.selected = true;
                }
                geminiModelSelect.appendChild(opt);
            });
            currentModelDisplay.textContent = current;
        }
    } catch (err) {
        console.warn('Não foi possível carregar a lista dinâmica de modelos:', err);
    }
}

// Salva nova chave Gemini ou novo modelo selecionado
async function saveNewKey() {
    const apiKey = newApiKeyInput.value.trim();
    const model = geminiModelSelect.value;

    btnSaveKey.disabled = true;
    btnSaveKey.textContent = 'Salvando...';

    const payload = { model };
    if (apiKey) {
        payload.apiKey = apiKey;
    }

    try {
        const resp = await fetch(`${API_BASE}/key`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify(payload)
        });

        const data = await resp.json();

        if (resp.ok) {
            showAlert('Configuração do Gemini salva com sucesso (Modelo: ' + (data.model || model) + ')!', true);
            newApiKeyInput.value = '';
            loadOverview();
        } else {
            showAlert(data.error || 'Erro ao salvar configuração.', false);
        }
    } catch (e) {
        showAlert('Erro de conexão ao salvar configuração.', false);
    } finally {
        btnSaveKey.disabled = false;
        btnSaveKey.textContent = 'Salvar Configuração (Chave / Modelo)';
    }
}

// Testa a chave do Gemini
async function testKeyConnection() {
    const inputKey = newApiKeyInput.value.trim();
    const model = geminiModelSelect.value;

    btnTestKey.disabled = true;
    btnTestKey.textContent = 'Testando ping com Gemini...';

    const payload = {};
    if (inputKey) payload.apiKey = inputKey;
    if (model) payload.model = model;

    try {
        const resp = await fetch(`${API_BASE}/test-key`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify(payload)
        });

        const data = await resp.json();

        if (resp.ok) {
            showAlert(data.message || 'Chave validada com sucesso!', true);
        } else {
            showAlert(data.message || data.error || 'Falha ao testar chave.', false);
        }
    } catch (e) {
        showAlert('Erro de conexão ao testar chave.', false);
    } finally {
        btnTestKey.disabled = false;
        btnTestKey.textContent = 'Testar Conexão & Modelo';
    }
}

function renderUsersTable(users) {
    if (!users || users.length === 0) {
        usersTableBody.innerHTML = '<tr><td colspan="6" class="text-center">Nenhum usuário cadastrado ainda.</td></tr>';
        return;
    }

    usersTableBody.innerHTML = users.map(u => {
        const created = u.createdAt ? new Date(u.createdAt).toLocaleString('pt-BR') : '--';
        const lastLogin = u.lastLoginAt ? new Date(u.lastLoginAt).toLocaleString('pt-BR') : '--';
        const lastSync = u.lastSyncedAt ? new Date(u.lastSyncedAt).toLocaleString('pt-BR') : 'Nunca';

        const providerBadge = u.authProvider === 'APPLE'
            ? '<span class="status-pill status-apple">🍎 Apple</span>'
            : (u.authProvider === 'GOOGLE'
                ? '<span class="status-pill status-google">🔵 Google</span>'
                : '<span class="status-pill status-email">✉️ E-mail</span>');

        return `
            <tr>
                <td><strong>${escapeHtml(u.name || 'Sem nome')}</strong></td>
                <td><code>${escapeHtml(u.email || '--')}</code></td>
                <td>${providerBadge}</td>
                <td>${created}</td>
                <td>${lastLogin}</td>
                <td>${lastSync}</td>
            </tr>
        `;
    }).join('');
}

function renderLogsTable(logs) {
    if (!logs || logs.length === 0) {
        logsTableBody.innerHTML = '<tr><td colspan="5" class="text-center">Nenhum log de IA registrado.</td></tr>';
        return;
    }

    logsTableBody.innerHTML = logs.map(l => {
        const created = l.createdAt ? new Date(l.createdAt).toLocaleTimeString('pt-BR') : '--';
        const duration = l.durationMs != null ? `${l.durationMs}ms` : '--';
        const statusBadge = l.status === 'SUCCESS'
            ? '<span class="badge badge-success">200 OK</span>'
            : `<span class="badge badge-error">${escapeHtml(l.status || 'ERROR')}</span>`;

        return `
            <tr>
                <td>${created}</td>
                <td><code>${escapeHtml(l.endpoint || '--')}</code></td>
                <td>${escapeHtml(l.promptSummary || '--')}</td>
                <td>${duration}</td>
                <td>${statusBadge}</td>
            </tr>
        `;
    }).join('');
}

function escapeHtml(text) {
    if (!text) return '';
    return String(text)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}
