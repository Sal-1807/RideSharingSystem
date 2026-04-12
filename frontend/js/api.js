// api.js - Shared API helper functions used by all pages
// All requests go to the same Express server (same origin = no CORS issues)

const API = {
    BASE: '/api',   // base URL; change if backend is on a different port

    // ── Generic fetch wrapper ─────────────────────────────────
    async request(method, url, body = null) {
        const options = {
            method,
            credentials: 'include',   // include session cookie
            headers: { 'Content-Type': 'application/json' }
        };
        if (body) options.body = JSON.stringify(body);

        const res = await fetch(API.BASE + url, options);
        const data = await res.json();

        if (!res.ok) throw new Error(data.error || 'Request failed');
        return data;
    },

    get:    (url)        => API.request('GET',    url),
    post:   (url, body)  => API.request('POST',   url, body),
    patch:  (url, body)  => API.request('PATCH',  url, body),
    delete: (url)        => API.request('DELETE', url),

    // ── Auth helpers ──────────────────────────────────────────
    auth: {
        login:              (body)  => API.post('/auth/login', body),
        logout:             ()      => API.post('/auth/logout'),
        registerPassenger:  (body)  => API.post('/auth/register/passenger', body),
        registerDriver:     (body)  => API.post('/auth/register/driver', body),
        me:                 ()      => API.get('/auth/me'),
    },

    // ── Passenger helpers ─────────────────────────────────────
    passenger: {
        profile:      (id) => API.get(`/passenger/profile/${id}`),
        wallet:       (id) => API.get(`/passenger/wallet/${id}`),
        rides:        (id) => API.get(`/passenger/ride-requests/${id}`),
        trips:        (id) => API.get(`/passenger/trips/${id}`),
        tickets:      (id) => API.get(`/passenger/tickets/${id}`),
        promos:       ()   => API.get('/passenger/promos'),
        requestRide:  (b)  => API.post('/passenger/ride-request', b),
    },

    // ── Driver helpers ────────────────────────────────────────
    driver: {
        profile:      (id) => API.get(`/driver/profile/${id}`),
        pendingRides: ()   => API.get('/driver/pending-rides'),
        trips:        (id) => API.get(`/driver/trips/${id}`),
        ratings:      (id) => API.get(`/driver/ratings/${id}`),
        earnings:     (id) => API.get(`/driver/earnings/${id}`),
        acceptRide:   (b)  => API.post('/driver/accept-ride', b),
        startTrip:    (id) => API.post(`/driver/start-trip/${id}`),
        endTrip:      (id, dist) => API.post(`/driver/end-trip/${id}`, { distance: dist }),
    },

    // ── Admin helpers ─────────────────────────────────────────
    admin: {
        passengers:    () => API.get('/admin/passengers'),
        drivers:       () => API.get('/admin/drivers'),
        trips:         () => API.get('/admin/trips'),
        payments:      () => API.get('/admin/payments'),
        tickets:       () => API.get('/admin/support-tickets'),
        stats:         () => API.get('/admin/stats'),
        promos:        () => API.get('/admin/promos'),
        highPayments:  () => API.get('/admin/high-payments'),
        addPromo:      (b)  => API.post('/admin/promos', b),
        createPromo:   (b)  => API.post('/admin/promos', b),
        updateTicket:  (id, status) => API.patch(`/admin/support-tickets/${id}`, { status }),
        resolveTicket: (id) => API.patch(`/admin/support-tickets/${id}`, { status: 'Resolved' }),
    },

    // ── Trip helpers ──────────────────────────────────────────
    trips: {
        get:          (id) => API.get(`/trips/${id}`),
        driverTrips:  ()   => API.get('/trips/analytics/driver-trips'),
        avgFare:      ()   => API.get('/trips/analytics/avg-fare'),
        distance:     ()   => API.get('/trips/analytics/distance'),
        earnings:     ()   => API.get('/trips/analytics/driver-earnings'),
        aboveAvg:     ()   => API.get('/trips/analytics/above-avg'),
        longTrips:    ()   => API.get('/trips/analytics/long-trips'),
    },

    // ── Payment helpers ───────────────────────────────────────
    payments: {
        pay:  (b)  => API.post('/payments', b),
        trip: (id) => API.get(`/payments/trip/${id}`),
    },

    // ── Rating helpers ────────────────────────────────────────
    ratings: {
        submit: (b)  => API.post('/ratings', b),
        trip:   (id) => API.get(`/ratings/trip/${id}`),
        driver: (id) => API.get(`/ratings/driver/${id}`),
    },

    // ── Support helpers ───────────────────────────────────────
    support: {
        raise: (b) => API.post('/support', b),
        my:    (userId, userType) => API.get(`/support/user/${userId}/${userType}`),
    },

    // ── Location helpers ──────────────────────────────────────
    locations: {
        all:          () => API.get('/locations'),
        vehicleTypes: () => API.get('/locations/vehicle-types'),
    }
};

// ── Session / Auth utilities ──────────────────────────────────

// Save user info to localStorage after login
function saveUser(userData) {
    localStorage.setItem('rss_user', JSON.stringify(userData));
}

// Get user info from localStorage
function getUser() {
    const u = localStorage.getItem('rss_user');
    return u ? JSON.parse(u) : null;
}

// Clear user info on logout
function clearUser() {
    localStorage.removeItem('rss_user');
}

// Redirect if not logged in (call on protected pages)
function requireAuth(allowedTypes = ['passenger', 'driver', 'admin']) {
    const user = getUser();
    if (!user) {
        window.location.href = '/login.html';
        return null;
    }
    if (!allowedTypes.includes(user.user_type)) {
        window.location.href = '/login.html';
        return null;
    }
    return user;
}

// Redirect if already logged in (call on login/register pages)
function redirectIfLoggedIn() {
    const user = getUser();
    if (!user) return;
    if (user.user_type === 'passenger') window.location.href = '/passenger_dashboard.html';
    else if (user.user_type === 'driver') window.location.href = '/driver_dashboard.html';
    else if (user.user_type === 'admin')  window.location.href = '/admin_dashboard.html';
}

// ── UI helpers ────────────────────────────────────────────────

// Show a toast/alert message
function showAlert(message, type = 'success', containerId = 'alert-box') {
    const box = document.getElementById(containerId);
    if (!box) return;
    box.className = `alert alert-${type} show`;
    box.textContent = message;
    setTimeout(() => {
        box.className = 'alert';
        box.textContent = '';
    }, 4000);
}

// Format date for display
function formatDate(dateStr) {
    if (!dateStr) return '—';
    return new Date(dateStr).toLocaleString('en-IN', {
        day: '2-digit', month: 'short', year: 'numeric',
        hour: '2-digit', minute: '2-digit'
    });
}

// Map status string → badge class
function statusBadge(status) {
    if (!status) return '';
    const map = {
        'Completed': 'badge-success',
        'Ongoing':   'badge-info',
        'Accepted':  'badge-info',
        'Pending':   'badge-warning',
        'Cancelled': 'badge-danger',
        'Open':      'badge-warning',
        'Resolved':  'badge-success',
        'Paid':      'badge-success',
        'Failed':    'badge-danger',
    };
    const cls = map[status] || 'badge-muted';
    return `<span class="badge ${cls}">${status}</span>`;
}

// Populate nav bar with logged-in user name
function populateNav(user) {
    const nameEl = document.getElementById('nav-user-name');
    if (nameEl && user) nameEl.textContent = `👤 ${user.name}`;
}

// Logout function
async function logout() {
    try { await API.auth.logout(); } catch (_) {}
    clearUser();
    window.location.href = '/login.html';
}
