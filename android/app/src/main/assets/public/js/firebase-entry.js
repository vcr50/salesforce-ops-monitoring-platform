const isNativeApp =
  typeof window !== 'undefined' &&
  typeof window.Capacitor?.isNativePlatform === 'function' &&
  window.Capacitor.isNativePlatform();

const FIREBASE_AUTH_ASSET_VERSION = '20260409-3';
const firebaseModulePath = isNativeApp
  ? `./firebase-config.native.js?v=${FIREBASE_AUTH_ASSET_VERSION}`
  : `./firebase-config.js?v=${FIREBASE_AUTH_ASSET_VERSION}`;

// ─── file:// bypass: show dashboard immediately without Firebase ───
function showDashboardFallback() {
  const loader = document.getElementById('initialLoader');
  const login = document.getElementById('loginOverlay');
  const dash = document.getElementById('mainDashboard');
  if (loader) loader.style.display = 'none';
  if (login) login.style.display = 'none';
  if (dash) dash.style.display = 'block';
  console.warn('[Firebase Entry] Showing dashboard in offline/file mode.');
}

let firebaseModulePromise;

if (window.location.protocol === 'file:') {
  // On file:// protocol, ES module imports fail due to CORS.
  // Skip Firebase entirely and show the dashboard directly.
  console.warn('[Firebase Entry] file:// protocol detected — skipping Firebase, showing dashboard.');
  showDashboardFallback();
  firebaseModulePromise = Promise.resolve();
} else {
  firebaseModulePromise = import(firebaseModulePath).catch((error) => {
    console.error(`Failed to load ${firebaseModulePath}`, error);
    // Fallback: show dashboard even if Firebase fails to load
    showDashboardFallback();
  });
}

// ─── Safety net: never leave a blank screen for more than 3 seconds ───
setTimeout(() => {
  const dash = document.getElementById('mainDashboard');
  const login = document.getElementById('loginOverlay');
  const loader = document.getElementById('initialLoader');
  if (dash && dash.style.display === 'none' &&
      (!login || login.style.display === 'none') &&
      (!loader || loader.style.display === 'none')) {
    showDashboardFallback();
  }
}, 3000);

window.triggerFirebaseSignIn = async function() {
  const existingSignInTrigger = window.__vertexSignInTriggerPromise;
  if (existingSignInTrigger) {
    return existingSignInTrigger;
  }

  const signInTriggerPromise = (async () => {
  if (window.location.protocol === 'file:') {
    alert('Google sign-in requires a hosted URL (localhost or https). It cannot work from file:// protocol.');
    return;
  }

  if (typeof window.fbSignIn === 'function') {
    return window.fbSignIn();
  }

  await firebaseModulePromise;

  if (typeof window.fbSignIn === 'function') {
    return window.fbSignIn();
  }

  console.error('window.fbSignIn is not ready yet');
  alert('Sign-in is not ready yet. Please refresh once and try again.');
  })();

  window.__vertexSignInTriggerPromise = signInTriggerPromise;
  try {
    return await signInTriggerPromise;
  } finally {
    if (window.__vertexSignInTriggerPromise === signInTriggerPromise) {
      window.__vertexSignInTriggerPromise = null;
    }
  }
};

const loginBtnMain = document.getElementById('loginBtnMain');
if (loginBtnMain) {
  loginBtnMain.onclick = () => window.triggerFirebaseSignIn();
}
