// Configuration injected from Terraform
const CONFIG = {
    cognitoDomain: '${cognito_domain}',
    clientId: '${client_id}',
    region: '${aws_region}',
    // Use current page URL - CloudFront provides HTTPS so this will work
    // Just use origin (no path) to match Cognito callback URLs exactly
    callbackUrl: window.location.origin
};

// Initialize configuration from window location or use defaults
function initConfig() {
    // Try to get config from URL parameters or use defaults
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('cognito_domain')) {
        CONFIG.cognitoDomain = urlParams.get('cognito_domain');
    }
    if (urlParams.get('client_id')) {
        CONFIG.clientId = urlParams.get('client_id');
    }
    if (urlParams.get('region')) {
        CONFIG.region = urlParams.get('region');
    }

    // If not in URL, try to construct from known patterns or use localStorage
    if (!CONFIG.cognitoDomain || !CONFIG.clientId) {
        const stored = localStorage.getItem('cognito_config');
        if (stored) {
            const config = JSON.parse(stored);
            CONFIG.cognitoDomain = config.cognitoDomain;
            CONFIG.clientId = config.clientId;
            CONFIG.region = config.region;
        }
    }
}

// Generate PKCE code verifier and challenge
async function generatePKCE() {
    const codeVerifier = btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32))))
        .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');

    const encoder = new TextEncoder();
    const data = encoder.encode(codeVerifier);
    const digest = await crypto.subtle.digest('SHA-256', data);
    const codeChallenge = btoa(String.fromCharCode(...new Uint8Array(digest)))
        .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');

    return { codeVerifier, codeChallenge };
}

// Parse URL for OAuth callback (authorization code flow)
function parseCallback() {
    const params = new URLSearchParams(window.location.search);
    const code = params.get('code');
    const error = params.get('error');
    const errorDescription = params.get('error_description');

    if (error) {
        showError(error, errorDescription);
        return null;
    }

    return code;
}

// Exchange authorization code for tokens
async function exchangeCodeForTokens(code, codeVerifier) {
    const tokenUrl = `https://$${CONFIG.cognitoDomain}.auth.$${CONFIG.region}.amazoncognito.com/oauth2/token`;

    const params = new URLSearchParams({
        grant_type: 'authorization_code',
        client_id: CONFIG.clientId,
        code: code,
        redirect_uri: CONFIG.callbackUrl,
        code_verifier: codeVerifier
    });

    try {
        const response = await fetch(tokenUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: params
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.error_description || error.error || 'Token exchange failed');
        }

        const data = await response.json();
        return {
            accessToken: data.access_token,
            idToken: data.id_token
        };
    } catch (error) {
        console.error('Token exchange error:', error);
        showError('Token Exchange Failed', error.message);
        return null;
    }
}

// Decode JWT token
function decodeJWT(token) {
    try {
        const base64Url = token.split('.')[1];
        const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
        const jsonPayload = decodeURIComponent(atob(base64).split('').map(function(c) {
            return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
        }).join(''));
        return JSON.parse(jsonPayload);
    } catch (e) {
        console.error('Error decoding JWT:', e);
        return null;
    }
}

// Show user information
function displayUserInfo(idToken) {
    const decoded = decodeJWT(idToken);
    if (!decoded) {
        showError('Failed to decode token');
        return;
    }

    // Display user information
    document.getElementById('user-name').textContent = decoded.name || decoded.preferred_username || 'N/A';
    document.getElementById('user-email').textContent = decoded.email || 'N/A';
    document.getElementById('user-given-name').textContent = decoded.given_name || 'N/A';
    document.getElementById('user-family-name').textContent = decoded.family_name || 'N/A';

    // Display token expiration
    if (decoded.exp) {
        const expires = new Date(decoded.exp * 1000);
        document.getElementById('token-expires').textContent = expires.toLocaleString();
    }

    // Show user info section and hide login button
    document.getElementById('user-info-section').style.display = 'block';
    document.getElementById('login-btn').style.display = 'none';
    document.getElementById('logout-btn').style.display = 'inline-block';
    document.getElementById('status').textContent = 'Authenticated';
    document.getElementById('status').className = 'status-message status-success';

    // Store token in sessionStorage for persistence
    sessionStorage.setItem('id_token', idToken);
    sessionStorage.setItem('access_token', decoded);
}

// Handle login
async function handleLogin() {
    if (!CONFIG.cognitoDomain || !CONFIG.clientId) {
        alert('Cognito configuration not found. Please ensure the demo is configured with proper Cognito domain and client ID.');
        return;
    }

    const scopes = 'openid email profile';
    const redirectUri = encodeURIComponent(CONFIG.callbackUrl);

    // Generate PKCE parameters
    const { codeVerifier, codeChallenge } = await generatePKCE();

    // Store code verifier for token exchange
    sessionStorage.setItem('pkce_code_verifier', codeVerifier);

    // Use authorization code flow with PKCE - works with identity providers
    const loginUrl = `https://$${CONFIG.cognitoDomain}.auth.$${CONFIG.region}.amazoncognito.com/oauth2/authorize?` +
        `client_id=$${CONFIG.clientId}&` +
        `response_type=code&` +
        `scope=$${encodeURIComponent(scopes)}&` +
        `redirect_uri=$${redirectUri}&` +
        `code_challenge=$${codeChallenge}&` +
        `code_challenge_method=S256&` +
        `identity_provider=AzureAD`;

    window.location.href = loginUrl;
}

// Handle logout
function handleLogout() {
    if (!CONFIG.cognitoDomain || !CONFIG.clientId) {
        sessionStorage.clear();
        location.reload();
        return;
    }

    const logoutUrl = `https://$${CONFIG.cognitoDomain}.auth.$${CONFIG.region}.amazoncognito.com/logout?` +
        `client_id=$${CONFIG.clientId}&` +
        `logout_uri=$${encodeURIComponent(CONFIG.callbackUrl)}`;

    sessionStorage.clear();
    window.location.href = logoutUrl;
}

// Show error message
function showError(error, description) {
    const statusEl = document.getElementById('status');
    statusEl.textContent = `Error: $${error}$${description ? ' - ' + description : ''}`;
    statusEl.className = 'status-message status-error';
}

// Initialize app
async function init() {
    initConfig();

    // Check for OAuth callback (authorization code)
    const code = parseCallback();
    if (code) {
        const codeVerifier = sessionStorage.getItem('pkce_code_verifier');
        if (!codeVerifier) {
            showError('PKCE Error', 'Code verifier not found. Please try logging in again.');
            return;
        }

        const tokens = await exchangeCodeForTokens(code, codeVerifier);
        if (tokens && tokens.idToken) {
            displayUserInfo(tokens.idToken);
            sessionStorage.removeItem('pkce_code_verifier'); // Clean up
        }
        // Clean up URL
        window.history.replaceState({}, document.title, window.location.pathname);
    } else {
        // Check if user is already logged in (sessionStorage)
        const storedToken = sessionStorage.getItem('id_token');
        if (storedToken) {
            displayUserInfo(storedToken);
        }
    }

    // Setup event listeners
    document.getElementById('login-btn').addEventListener('click', handleLogin);
    document.getElementById('logout-btn').addEventListener('click', handleLogout);

    // Allow manual configuration via prompt (for testing/fallback)
    if (!CONFIG.cognitoDomain || !CONFIG.clientId) {
        const configureBtn = document.createElement('button');
        configureBtn.textContent = 'Configure Cognito';
        configureBtn.className = 'btn btn-secondary';
        configureBtn.style.marginTop = '10px';
        configureBtn.onclick = function() {
            const domain = prompt('Enter Cognito domain (e.g., cognito-demo-abc123):');
            const clientId = prompt('Enter Client ID:');
            const region = prompt('Enter AWS region (e.g., ap-southeast-2):', 'ap-southeast-2');

            if (domain && clientId) {
                CONFIG.cognitoDomain = domain;
                CONFIG.clientId = clientId;
                CONFIG.region = region || 'ap-southeast-2';
                localStorage.setItem('cognito_config', JSON.stringify(CONFIG));
                location.reload();
            }
        };
        document.getElementById('login-section').appendChild(configureBtn);
    }
}

// Run when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
