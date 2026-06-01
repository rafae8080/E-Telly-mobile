# 🔐 Firebase Authentication — Implementation Guide

> A beginner-friendly walkthrough of how login, sign-up, Google Sign-In, email
> verification, and password reset were built in **E-Telly**.
>
> **Read this if you want to understand:** where each piece lives, what each file
> does, and *why* we chose this approach.

---

## 1. The Big Picture (read this first)

E-Telly has **two parts**:

| Part | Folder | Role |
|------|--------|------|
| 📱 **Mobile app** (Flutter) | `etelly-mobile` | What the user taps on their phone |
| 🖥️ **Server** (Node + MongoDB) | `etelly-mern/server` | Stores the user data, gives out "passes" (JWT tokens) |

The key idea behind this whole feature is one sentence:

> **Firebase handles the passwords. Our server only checks Firebase's word for it,
> then issues its own pass (JWT).**

We did **not** add any new tools/libraries. Firebase was *already* in the project
(it was being used for Google Sign-In and push notifications). We just used more of
what was already there. This matters because the project was already approved with
this tech stack — no new dependency means no new approval needed.

---

## 2. How Authentication Flows (the mental model)

Think of it like getting into an event:

1. **Firebase** is the *ID checker at the door*. It confirms "yes, this is really
   this person, and their email is real."
2. Firebase hands the user a **temporary signed ticket** — this is called an
   **ID token**. It expires after 1 hour and cannot be faked.
3. The app gives that ticket to **our server**.
4. Our server double-checks the ticket with Firebase (using the Firebase Admin SDK),
   and if it's valid, hands back **our own wristband** — a **JWT** that the rest of
   the app uses.

```
 [User] → Firebase (checks identity) → gives ID token
        → App sends ID token → Our Server
        → Server verifies token with Firebase → gives back our JWT
        → User is logged in ✅
```

**Why this design?**
- Our server **never sees or stores the user's real password.** Firebase does. That's
  more secure, not less.
- It's the **same pattern Google Sign-In already used** in this project — so
  email/password now works exactly the same way, keeping the code consistent.

---

## 3. Every File We Touched (and why)

### 📱 Mobile App — `etelly-mobile/lib/`

| File | Status | What it does | Why |
|------|--------|--------------|-----|
| `screens/login_screen.dart` | ✏️ Edited | Email/password login, Google Sign-In, "Forgot Password" | The main entry door |
| `screens/sign_up_screen.dart` | ✏️ Edited | Create account, pick barangay, strong-password check | Where new users register |
| `screens/email_verification_screen.dart` | 🆕 New | "Waiting room" that watches for email verification | So users can't log in with a fake/unverified email |
| `screens/profile_completion_screen.dart` | 🆕 New | After first Google sign-in, asks for barangay + address | Google doesn't give us a home address — we need it |
| `widgets/sign_up.dart` | ✏️ Edited | Holds the list of **16 barangays** + form widgets | Shared by sign-up *and* profile-completion screens |

### 🖥️ Server — `etelly-mern/server/`

| File | Status | What it does | Why |
|------|--------|--------------|-----|
| `models/user.js` | ✏️ Edited | Made the `password` field **optional** | Firebase users have no password stored on our side |
| `routes/auth.js` | ✏️ Edited | The endpoints: `/register`, `/login`, `/google`, `/profile`, `/change-password` | Verifies Firebase tokens, issues our JWT |

### ⚙️ Configuration (Android)

| File | What it does |
|------|--------------|
| `android/app/google-services.json` | Connects the Android app to the Firebase project `etelly-app` |
| `android/app/src/main/AndroidManifest.xml` | Has the `INTERNET` permission (needed for auth calls) |

---

## 4. Feature-by-Feature Breakdown

### 🔵 A. "Continue with Google"

**File:** `lib/screens/login_screen.dart` → `_handleGoogleSignIn()`

**What happens, step by step:**
1. The Google account picker pops up (`_googleSignIn.signIn()`).
2. We take what Google gives us and **link it to Firebase**
   (`FirebaseAuth.instance.signInWithCredential(...)`). ← *This was the missing step
   that made it broken before.*
3. Firebase gives us an ID token.
4. We send it to the server (`POST /api/auth/google`).
5. The server replies with `isNewUser: true` or `false`.
   - **New user** → go to **Profile Completion** screen (ask for address).
   - **Existing user** → go straight to **Home**.

**The one tricky config detail:**
```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['email', 'profile'],
  serverClientId: '927012189317-...apps.googleusercontent.com', // ← web client ID
);
```
On Android you **must** use `serverClientId` (the *web* OAuth client), **not**
`clientId`. If you use `clientId`, the `idToken` comes back empty and nothing works.

> ⚠️ **The #1 thing that breaks Google Sign-In on Android:** the phone's SHA-1
> fingerprint must be registered in the Firebase Console. If it isn't, you get
> `ApiException: 10` which the app now shows as *"Google sign-in is not configured
> for this build (error 10)."* See **Section 6**.

---

### 🟢 B. Sign Up (create account)

**File:** `lib/screens/sign_up_screen.dart` → `_handleSignUp()`

**What happens:**
1. The form is validated (name, email, barangay, address, strong password).
2. Firebase creates the account: `createUserWithEmailAndPassword(...)`.
3. Firebase **sends a verification email for free**: `sendEmailVerification()`.
4. We send the name + address to our server (`POST /api/auth/register`), which saves
   the MongoDB record (no password stored).
5. The user is taken to the **Email Verification waiting screen**.

**Strong password rule** (`_isStrongPassword()`):
- 8+ characters
- 1 uppercase, 1 lowercase, 1 number, 1 special character

**Why a strong password?** Standard security practice; weak passwords are the easiest
way for accounts to get hacked.

**The 16 barangays** live in `lib/widgets/sign_up.dart` as `antipoloBarangays`:
> Bagong Nayon, Beverly Hills, Calawis, Cupang, Dalig, Dela Paz, Inarawan, Mambugan,
> Mayamot, Munting Dilaw, San Isidro, San Jose, San Juan, San Luis, San Roque, Santa Cruz

---

### 🟡 C. Email Verification (the "waiting room")

**File:** `lib/screens/email_verification_screen.dart`

This is styled like an OTP screen, but for an email link instead of a code.

**What it does:**
- Shows *"Check your inbox — we sent a link to your-email@gmail.com."*
- **Auto-checks every 5 seconds** (`Timer.periodic`) — when the user clicks the link
  in their email, the app notices and logs them in automatically.
- **"I've Verified My Email"** button — lets the user check immediately.
- **"Resend"** button — with a 60-second cooldown so users can't spam it.

**Why a waiting screen instead of just a dialog?** The user complained that the old
flow said *"verify your email"* but felt stuck with no way to resend if the email
never arrived. This screen fixes that — it's the standard "OTP-style" pattern users
already understand.

**Important:** the server enforces verification too. At login,
`POST /api/auth/login` checks `decoded.email_verified` and returns **403** if the
email isn't verified. So even if someone bypassed the app screen, the server still
blocks them.

---

### 🟣 D. Forgot / Reset Password

**File:** `lib/screens/login_screen.dart` → `_handleForgotPassword()`

**What happens:**
1. User types their email and taps "Forgot Password?".
2. `FirebaseAuth.instance.sendPasswordResetEmail(...)` — **Firebase sends the reset
   email and hosts the reset page entirely.**
3. User clicks the link, sets a new password on Firebase's page, done.

**Why this is great:** zero server code, zero custom email setup. Firebase does
everything — the standard, secure way.

---

### 🟠 E. Profile Completion (new Google users only)

**File:** `lib/screens/profile_completion_screen.dart`

When someone signs in with Google for the **first time**, Google gives us their name
and email — but **not their home address or barangay**, which E-Telly needs (it's a
disaster/evacuation app — location matters).

So new Google users see this screen once, fill in barangay + street, and it's saved
via `PATCH /api/auth/profile`. Returning Google users skip it.

> This is the same pattern Grab, Lazada, etc. use — "Sign up with Google, then finish
> a couple of details."

---

## 5. Server Endpoints (cheat sheet)

All in `etelly-mern/server/routes/auth.js`:

| Endpoint | Who uses it | What it expects | What it returns |
|----------|-------------|-----------------|-----------------|
| `POST /register` | Mobile sign-up | `{ idToken, name, address }` | `202` "verify your email" |
| `POST /login` | Mobile login | `{ idToken }` | `200` + JWT, or `403` if unverified, or `404` if no account |
| `POST /google` | Google Sign-In | `{ idToken }` | `200` + JWT + `isNewUser` |
| `PATCH /profile` | Profile completion | `{ address }` + JWT header | Updated user |
| `POST /change-password` | Admins (web) | `{ newPassword }` + JWT | Uses **bcrypt** |
| `POST /login` (legacy) | Admins (web) | `{ email, password }` | Uses **bcrypt** |

### 🛡️ Why is `bcrypt` still in the code?

`bcrypt` (password hashing) is **kept on purpose** for **admin / web-portal accounts**
that still log in with email + password directly on the server. Firebase only owns the
passwords of *mobile citizen users*. So:
- **Mobile users** → Firebase owns the password (we never store it). ✅
- **Admins** → still use bcrypt on our server. ✅

Removing bcrypt would break admin login, so we left it. This is **not** a security
downgrade — it's two correct systems for two different user types.

---

## 6. ⚠️ The Android Setup Step You Cannot Skip (SHA-1 Fingerprint)

Google Sign-In on Android refuses to work unless your app's **SHA-1 fingerprint** is
registered in Firebase. This is **not a code problem** — it's a console setting.

**Symptom:** Google sign-in fails with *"check your connection"* / `ApiException: 10`
even though the internet is fine.

**Fix (one time):**
1. Go to <https://console.firebase.google.com> → open project **etelly-app**.
2. Click ⚙️ → **Project settings** → scroll to **Your apps**.
3. Select the Android app `com.example.e_telly_app`.
4. Under **SHA certificate fingerprints**, click **Add fingerprint**.
5. Paste your debug SHA-1, e.g.:
   ```
   A5:EC:58:A1:E8:6C:DB:1F:0C:92:83:31:8B:F3:43:5B:21:9E:63:C4
   ```
6. **Save**, then **download the new `google-services.json`** and replace
   `android/app/google-services.json`.
7. Run `flutter clean`, then rebuild.

**Also check:** Firebase Console → **Authentication** → **Sign-in method** →
**Google** and **Email/Password** are both **Enabled**.

> 🔑 To get your machine's debug SHA-1 (PowerShell on Windows):
> ```powershell
> & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v `
>   -keystore "$env:USERPROFILE\.android\debug.keystore" `
>   -alias androiddebugkey -storepass android -keypass android
> ```
> Each developer's machine has a *different* debug SHA-1, so each one must be added.

---

## 7. Quick Test Checklist

| # | Test | Expected result |
|---|------|-----------------|
| 1 | Sign up → check Gmail | "Verify your email" link arrives |
| 2 | Click the link → return to app | Auto-detected, logged in to Home |
| 3 | Try to log in **before** verifying | Sent to waiting screen, blocked |
| 4 | Forgot password → enter email | Reset link arrives in Gmail |
| 5 | Google Sign-In (new account) | Account picker → Profile Completion → Home |
| 6 | Google Sign-In (existing) | Account picker → straight to Home |
| 7 | Wrong password | "Incorrect email or password." (no crash) |
| 8 | Barangay picker | All **16** barangays listed |
| 9 | Weak password on sign-up | Inline error before it submits |

---

## 8. Glossary (plain English)

| Term | Meaning |
|------|---------|
| **Firebase Auth** | Google's free service that checks identities and stores passwords for us |
| **ID token** | A temporary, signed "ticket" Firebase gives proving who you are (expires in 1 hr) |
| **JWT** | Our server's own "wristband" the app carries around after login |
| **Firebase Admin SDK** | The server-side tool that verifies Firebase ID tokens |
| **SHA-1 fingerprint** | A unique signature of your app's build; Google uses it to trust your app (Android only) |
| **bcrypt** | A password-hashing tool — still used for admin accounts only |
| **`serverClientId`** | The "web" OAuth client ID Android needs to get a usable Google token |

---

---

# 📱➡️🍏 PLAN: iOS Implementation (do ONLY if the panel asks)

> **Status: NOT done. Android is enough for the demo.**
>
> The Flutter **code** already works on iOS as-is — no Dart changes are needed.
> What's missing is **iOS-side Firebase/Google configuration**. iOS does **not** use
> SHA-1 fingerprints at all; it uses a different config file and a URL scheme.

### What already works on iOS (no changes needed)
- ✅ All Dart screens (login, sign-up, verification, profile completion)
- ✅ Email/password login, registration, email verification, password reset
- ✅ All server endpoints (the server doesn't care which phone called it)

### What is missing on iOS
- ❌ `GoogleService-Info.plist` (the iOS version of `google-services.json`) — confirmed
  **not present** in `ios/Runner/`.
- ❌ The Google Sign-In **URL scheme** in `Info.plist`.
- ❌ The iOS app may not be registered in the Firebase project yet.

### Step-by-step iOS setup (when needed)

> ⚠️ Steps 1–7 require a **Mac with Xcode**. iOS cannot be built on Windows.

1. **Register the iOS app in Firebase:**
   Firebase Console → project **etelly-app** → ⚙️ Project settings → **Add app** →
   choose **iOS**. Use the iOS bundle ID (find it in Xcode under *Runner → General →
   Bundle Identifier*, e.g. `com.example.eTellyApp`).

2. **Download `GoogleService-Info.plist`** and add it to the project:
   - Place it at `ios/Runner/GoogleService-Info.plist`.
   - In Xcode, drag it into the **Runner** target (check "Copy items if needed").

3. **Add the reversed client ID URL scheme** to `ios/Runner/Info.plist`.
   Open `GoogleService-Info.plist`, copy the `REVERSED_CLIENT_ID` value, then add:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <!-- paste the REVERSED_CLIENT_ID here -->
         <string>com.googleusercontent.apps.927012189317-xxxxxxxx</string>
       </array>
     </dict>
   </array>
   ```

4. **Set the iOS deployment target** to 13.0+ in Xcode (Firebase requires it) and run
   `cd ios && pod install`.

5. **Update the Google Sign-In code** (only if needed):
   On iOS, `google_sign_in` reads the client ID from `GoogleService-Info.plist`
   automatically, so the existing `serverClientId` is fine. If you hit a "missing
   client ID" error, pass `clientId:` (the **iOS** OAuth client ID) for iOS using a
   platform check (`Platform.isIOS`).

6. **Enable iOS in Firebase Authentication** — the Google and Email/Password providers
   are project-wide, so they're already on from the Android setup. No change needed.

7. **Apple-specific (only if you submit to the App Store):**
   Apple **requires** "Sign in with Apple" if you offer any third-party login like
   Google. For a class demo this is **not** required — only for a real App Store
   release. This would be extra work (new provider + `sign_in_with_apple` package).

### iOS effort estimate
| Task | Effort |
|------|--------|
| Register iOS app + download plist | 15 min |
| Info.plist URL scheme + pod install | 20 min |
| Test on a real iPhone / simulator | 30 min |
| (Optional) Sign in with Apple for App Store | Half a day+ |

> **Recommendation for the demo:** stay on **Android only**. The whole feature works
> there, and iOS adds Mac/Xcode requirements and Apple's "Sign in with Apple" rule
> with no benefit for a demo. Do the iOS steps above **only if a panelist specifically
> asks to see it on an iPhone.**
