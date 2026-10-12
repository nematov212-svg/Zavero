// ZAVERO POS - Native Mac Touch ID / WebAuthn Platform Authenticator
window.zaveroBiometrics = {
  // Check if real hardware biometric (Mac Touch ID / Windows Hello / Platform Authenticator) is available
  isAvailable: async function () {
    try {
      if (window.PublicKeyCredential &&
          PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable) {
        return await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
      }
      return false;
    } catch (e) {
      console.warn("Biometric check failed:", e);
      return false;
    }
  },

  // Register real Mac Touch ID
  registerTouchID: async function (username) {
    try {
      if (!window.PublicKeyCredential) {
        return JSON.stringify({ success: false, message: "Brauzeringizda Touch ID (WebAuthn) qo'llab-quvvatlanmaydi." });
      }

      const challenge = new Uint8Array(32);
      window.crypto.getRandomValues(challenge);

      const userId = new Uint8Array(16);
      window.crypto.getRandomValues(userId);

      const createOptions = {
        publicKey: {
          challenge: challenge,
          rp: {
            name: "ZAVERO POS",
            id: window.location.hostname
          },
          user: {
            id: userId,
            name: username || "director@zavero.uz",
            displayName: "ZAVERO Director"
          },
          pubKeyCredParams: [
            { alg: -7, type: "public-key" },   // ES256
            { alg: -257, type: "public-key" }  // RS256
          ],
          authenticatorSelection: {
            authenticatorAttachment: "platform", // Real hardware Touch ID on Mac / Windows Hello
            userVerification: "required",
            residentKey: "preferred"
          },
          timeout: 60000,
          attestation: "none"
        }
      };

      const credential = await navigator.credentials.create(createOptions);
      if (credential) {
        const rawIdBase64 = btoa(String.fromCharCode(...new Uint8Array(credential.rawId)));
        localStorage.setItem("zavero_touch_id_cred", rawIdBase64);
        localStorage.setItem("zavero_touch_id_enabled", "true");
        localStorage.setItem("zavero_touch_id_registered_at", new Date().toISOString());
        return JSON.stringify({ success: true, id: rawIdBase64 });
      }
      return JSON.stringify({ success: false, message: "Barmoq izi tasdiqlanmadi." });
    } catch (err) {
      console.error("Touch ID registration error:", err);
      return JSON.stringify({ success: false, message: err.message || "Barmoq izi ro'yxatdan o'tmadi." });
    }
  },

  // Authenticate with real Mac Touch ID
  verifyTouchID: async function () {
    try {
      if (!window.PublicKeyCredential) {
        return JSON.stringify({ success: false, message: "Brauzeringizda Touch ID qo'llab-quvvatlanmaydi." });
      }

      const challenge = new Uint8Array(32);
      window.crypto.getRandomValues(challenge);

      const savedCredId = localStorage.getItem("zavero_touch_id_cred");
      const allowCredentials = [];

      if (savedCredId) {
        try {
          const binaryString = atob(savedCredId);
          const bytes = new Uint8Array(binaryString.length);
          for (let i = 0; i < binaryString.length; i++) {
            bytes[i] = binaryString.charCodeAt(i);
          }
          allowCredentials.push({
            id: bytes,
            type: "public-key"
          });
        } catch (e) {}
      }

      const getOptions = {
        publicKey: {
          challenge: challenge,
          rpId: window.location.hostname,
          userVerification: "required",
          timeout: 60000,
          allowCredentials: allowCredentials.length > 0 ? allowCredentials : undefined
        }
      };

      const assertion = await navigator.credentials.get(getOptions);
      if (assertion) {
        return JSON.stringify({ success: true });
      }
      return JSON.stringify({ success: false, message: "Barmoq izi tasdiqlanmadi." });
    } catch (err) {
      console.error("Touch ID verification error:", err);
      return JSON.stringify({ success: false, message: err.message || "Barmoq izi xatoligi." });
    }
  }
};
