# ByeMacDPI v3.0.9 Release Notes

**Stable Release: Gatekeeper & Connectivity Fixes**

This is the definitive stable release that resolves all installation and connectivity issues on macOS.

### 🛡️ Critical Fixes (v3.0.9)
*   **Gatekeeper Approval:** Fixed an issue where the embedded `ciadpi` binary was blocked by macOS Gatekeeper even after the app was approved. Both the app and the binary are now correctly signed.
*   **"App is Damaged" Fix:** Automated quarantine removal ensures the app runs immediately after unzipping.

### 📦 Distribution
*   **ZIP Package:** Now distributed as a simple ZIP file. Just unzip, move to Applications, and run!

### 🎨 UI & UX Improvements
*   **Full Localization:** Complete Turkish 🇹🇷 and English 🇺🇸 support.
*   **Visual Feedback:** Pulsating animations and loading spinners for Start/Stop actions.
*   **Clear Status:** "Starting..." / "Stopping..." indicators instead of generic checking text.

### 🚀 Core Functionality
*   **Vesktop Support:** Native support for launching Vesktop.
*   **Bundled Engine:** Embedded `ciadpi` binary (ARM64 Optimized).
*   **Smart Sync:** Real-time service status polling.
*   **Crash Loop Fixed:** Resolved "Gaming Mode" crash issues.
*   **Orphan Cleaner:** Auto-cleans old processes to prevent port conflicts.

---
*Recommended for all users.*
