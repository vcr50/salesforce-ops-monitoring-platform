// ─── Firebase Config & Auth/Firestore Integration ──────────────────────────
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-app.js';
import { getAuth, GoogleAuthProvider, signInWithPopup, signOut, onAuthStateChanged }
  from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-auth.js';
import { getFirestore, doc, setDoc, getDoc }
  from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js';

const firebaseConfig = {
  apiKey:            "AIzaSyA8DHO1aGSe-8-L9x77-rtAeFgw5xYyzqc",
  authDomain:        "tomcodex-academy.firebaseapp.com",
  projectId:         "tomcodex-academy",
  storageBucket:     "tomcodex-academy.firebasestorage.app",
  messagingSenderId: "12422540827",
  appId:             "1:12422540827:web:2aa8a57abce3e7779412be"
};

const app      = initializeApp(firebaseConfig);
const auth     = getAuth(app);
const db       = getFirestore(app);
const GOOGLE_SIGN_IN_MODE_KEY = 'google_sign_in_mode';
const GOOGLE_SERVICE_SCOPES = [
  'https://www.googleapis.com/auth/calendar',
  'https://www.googleapis.com/auth/tasks',
  'https://www.googleapis.com/auth/fitness.activity.read',
  'https://www.googleapis.com/auth/fitness.location.read'
];

// ─── Expose to global scope so app.js can call these ───
window.fbAuth = auth;
window.fbDb   = db;

let authUiBusy = false;

function setAuthUiBusy(isBusy) {
  authUiBusy = isBusy;
  const loginOverlay = document.getElementById('loginOverlay');
  const mainDashboard = document.getElementById('mainDashboard');
  const initialLoader = document.getElementById('initialLoader');
  const buttons = [
    document.getElementById('loginBtnMain'),
    document.getElementById('fbLoginBtn'),
    document.getElementById('gcalConnectBtn'),
    document.getElementById('tasksConnectBtn')
  ];

  buttons.forEach((btn) => {
    if (btn) {
      btn.disabled = isBusy;
      btn.setAttribute('aria-busy', isBusy ? 'true' : 'false');
    }
  });

  if (isBusy) {
    if (loginOverlay) loginOverlay.style.display = 'none';
    if (mainDashboard) mainDashboard.style.display = 'none';
    if (initialLoader) initialLoader.style.display = 'flex';
  } else if (initialLoader) {
    initialLoader.style.display = 'none';
  }
}

function buildGoogleProvider(scopes = [], prompt = 'select_account') {
  const googleProvider = new GoogleAuthProvider();
  scopes.forEach((scope) => googleProvider.addScope(scope));
  googleProvider.setCustomParameters({ prompt });
  return googleProvider;
}

function rememberGoogleSignInMode(mode) {
  sessionStorage.setItem(GOOGLE_SIGN_IN_MODE_KEY, mode);
}

function consumeGoogleSignInMode() {
  const mode = sessionStorage.getItem(GOOGLE_SIGN_IN_MODE_KEY) || 'login';
  sessionStorage.removeItem(GOOGLE_SIGN_IN_MODE_KEY);
  return mode;
}

function storeGoogleAccessTokenFromResult(result) {
  const credential = GoogleAuthProvider.credentialFromResult(result);
  if (credential && credential.accessToken) {
    localStorage.setItem('gcalToken', credential.accessToken);
    if (window.syncCalendarUI) window.syncCalendarUI();
  }
}

async function runGoogleSignIn({ scopes = [], prompt = 'select_account', mode = 'login' } = {}) {
  const existingSignInPromise = window.__vertexGoogleSignInPromise;
  if (existingSignInPromise) {
    return existingSignInPromise;
  }

  const signInPromise = (async () => {
    const provider = buildGoogleProvider(scopes, prompt);
    rememberGoogleSignInMode(mode);
    setAuthUiBusy(true);

    try {
      const result = await signInWithPopup(auth, provider);
      const signedInMode = consumeGoogleSignInMode();
      if (signedInMode !== 'login') {
        storeGoogleAccessTokenFromResult(result);
      }
    } catch (e) {
      if (e?.code === 'auth/cancelled-popup-request') {
        console.warn('Ignoring duplicate popup request while sign-in is already in progress.');
        return;
      }

      if (e?.code === 'auth/popup-closed-by-user') {
        console.info('Google popup was closed by the user.');
        return;
      }

      console.error('Login failed', e);
      const message = e?.message || 'Google sign-in failed.';
      alert('Login failed: ' + message);
    } finally {
      setAuthUiBusy(false);
      if (!auth.currentUser) {
        showFbUser(null);
      }
    }
  })();

  window.__vertexGoogleSignInPromise = signInPromise;
  try {
    return await signInPromise;
  } finally {
    if (window.__vertexGoogleSignInPromise === signInPromise) {
      window.__vertexGoogleSignInPromise = null;
    }
  }
}

window.fbSignIn = async function() {
  return runGoogleSignIn({ mode: 'login' });
};

window.fbConnectGoogleServices = async function() {
  return runGoogleSignIn({
    scopes: GOOGLE_SERVICE_SCOPES,
    prompt: 'consent select_account',
    mode: 'services'
  });
};

window.fbSignOut = async function() {
  sessionStorage.removeItem('journeyReload');
  localStorage.removeItem('gcalToken');
  try {
    await signOut(auth);
  } finally {
    showFbUser(null);
  }
};

// Save globalState to Firestore under users/{uid}/data
window.fbSave = async function(globalState) {
  const user = auth.currentUser;
  if (!user) return false;
  try {
    await setDoc(doc(db, 'users', user.uid, 'data', 'state'), {
      payload: JSON.stringify(globalState),
      updated: Date.now()
    });
    return true;
  } catch (e) { console.error('Firestore save failed', e); return false; }
};

// Load globalState from Firestore
window.fbLoad = async function() {
  const user = auth.currentUser;
  if (!user) return null;
  try {
    const snap = await getDoc(doc(db, 'users', user.uid, 'data', 'state'));
    if (snap.exists()) {
      return JSON.parse(snap.data().payload);
    }
  } catch (e) { console.error('Firestore load failed', e); }
  return null;
};

// ─── Auth state change handler ─────────────────────────
onAuthStateChanged(auth, async (user) => {
  showFbUser(user);
  if (user) {
    if (window.syncCalendarUI) window.syncCalendarUI(); // Auto-link calendar on refresh
    // Load cloud data on login or page refresh
    const cloudState = await window.fbLoad();
    if (cloudState) {
      // Wait for app.js to define applyCloudState (handles module load race condition)
      let retries = 0;
      const tryApply = () => {
        if (window.applyCloudState) {
          window.applyCloudState(cloudState);
        } else if (retries < 30) {
          retries++;
          setTimeout(tryApply, 100);
        } else {
          console.warn('applyCloudState never became available');
        }
      };
      tryApply();
    }
  }
});

function showFbUser(user) {
  const btn    = document.getElementById('fbLoginBtn');
  const avatar = document.getElementById('fbAvatar');
  const name   = document.getElementById('fbUserName');
  const loginOverlay = document.getElementById('loginOverlay');
  const mainDashboard = document.getElementById('mainDashboard');
  const initialLoader = document.getElementById('initialLoader');

  if (user) {
    // Hide the initial mask once auth resolves
    if (initialLoader) initialLoader.style.display = 'none';
    // Clear any journey-reload flag
    sessionStorage.removeItem('journeyReload');
    if (btn) btn.style.display = 'none';
    if (avatar) { avatar.src = user.photoURL || ''; avatar.style.display = 'block'; }
    if (name)   { name.textContent = user.displayName?.split(' ')[0] || 'Me'; name.style.display = 'inline'; }
    
    // Switch to Dashboard
    if (loginOverlay) loginOverlay.style.display = 'none';
    if (mainDashboard) mainDashboard.style.display = 'block';
  } else {
    // If this is a journey-switch reload, don't flash the login screen
    if (sessionStorage.getItem('journeyReload') === '1') return;
    if (authUiBusy) return;

    if (initialLoader) initialLoader.style.display = 'none';

    if (btn) btn.style.display = 'inline-flex';
    if (avatar) avatar.style.display = 'none';
    if (name)   name.style.display   = 'none';

    const loginBtnMain = document.getElementById('loginBtnMain');
    if (loginBtnMain) {
      // Assigning the handler directly prevents duplicate popup attempts
      // when auth state changes re-render the signed-out UI.
      loginBtnMain.onclick = window.fbSignIn;
    }

    // Switch to Login
    if (loginOverlay) loginOverlay.style.display = 'flex';
    if (mainDashboard) mainDashboard.style.display = 'none';
  }
}
