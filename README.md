# 🗺️ Map Distance Calculator - Flutter App

**ਪੰਜਾਬੀ ਵਿੱਚ ਪੂਰੀ Guide ਹੇਠਾਂ ਹੈ** ✅

A Flutter app to measure map distances, calculate travel time, and measure area — converted from the original Next.js web app.

---

## 📱 Features
- 📍 GPS auto-detection
- 📏 Distance measurement (Haversine formula)
- 🏔️ Elevation profile chart
- 📐 Area measurement (polygon mode)
- 🚗🚶🚴 Travel time estimates (Car/Walk/Bike)
- 💾 Save & load routes
- 🔗 Share routes via link
- 🗂️ Route history (last 5)
- FAQ section

---

## 🛠️ Setup karo (ਸ਼ੁਰੂ ਕਿਵੇਂ ਕਰੋ)

### Step 1: Flutter Install karo
```bash
# Flutter SDK download karo: https://flutter.dev/docs/get-started/install
flutter --version  # Check karo k install hoya ki nahi
```

### Step 2: Project clone karo
```bash
git clone https://github.com/YOUR_USERNAME/map-distance-calculator.git
cd map-distance-calculator
```

### Step 3: Dependencies install karo
```bash
flutter pub get
```

### Step 4: Run karo (test lyi)
```bash
flutter run
```

---

## 🐙 GITHUB TE KIVE DAAVO (Step by Step)

### Part A: GitHub Account banana
1. **github.com** te jao
2. "Sign up" karo (free hai)
3. Username, email, password rakho

### Part B: New Repository banana
1. GitHub login karo
2. **"+" button** (top right) → **"New repository"** click karo
3. Repository name: `map-distance-calculator`
4. Description: `Free Map Distance Calculator Flutter App`
5. **Public** rakho (free hai)
6. **"Create repository"** click karo

### Part C: Code GitHub te daavo
Terminal (ya Command Prompt) kholo apne project folder vich:

```bash
# Step 1: Git initialize karo
git init

# Step 2: Saara code add karo
git add .

# Step 3: First commit karo
git commit -m "Initial Flutter app - Map Distance Calculator"

# Step 4: GitHub naal connect karo
# (apna username replace karo)
git remote add origin https://github.com/YOUR_USERNAME/map-distance-calculator.git

# Step 5: Upload karo
git branch -M main
git push -u origin main
```

### Part D: GitHub Actions (Automatic APK Build)
Jado bhi tusi `git push` karo, GitHub automatically APK build karega!

1. GitHub repository kholo
2. **Actions** tab te click karo
3. Build status dekho
4. Build complete hone te → **Artifacts** section vich APK download karo

---

## 🏪 PLAY STORE TE PUBLISH KARNA

### Step 1: Google Play Console Account banana
1. **play.google.com/console** te jao
2. Google account naal login karo
3. **One-time fee: $25 USD** devo (ek baar hi)
4. Developer account verify hoga (1-2 din lagde ne)

### Step 2: App Sign karna (Zaruri hai!)
APK sign karne lyi keystore banana padega:

```bash
# Keystore generate karo (EK baar hi karo, file sambhal ke rakho!)
keytool -genkey -v -keystore ~/map-calculator-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias map-calculator

# Poocheya jaega: name, city, country etc. - sab bhar do
```

**key.properties file** banao project vich `android/` folder vich:
```
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=map-calculator
storeFile=/path/to/map-calculator-key.jks
```

**android/app/build.gradle** vich signing config add karo:
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### Step 3: AAB (App Bundle) build karo
```bash
flutter build appbundle --release
# File milegi: build/app/outputs/bundle/release/app-release.aab
```

### Step 4: Play Console vich Upload karna
1. **play.google.com/console** login karo
2. **"Create app"** click karo
3. App details bhar do:
   - App name: `Map Distance Calculator`
   - Default language: `English (India)`
   - App type: `App`
   - Free ya Paid: `Free`
4. **"Create app"** karo

### Step 5: Store Listing bharni (Zaruri!)
Dashboard vich **"Store presence" → "Main store listing"** te jao:

| Field | Kya bhar'no |
|-------|-------------|
| App name | Map Distance Calculator |
| Short description | Free GPS map distance & area calculator |
| Full description | Measure distances on real maps, calculate travel time for car/walk/bike, measure area, save & share routes. No signup needed! |

**Screenshots zaruri ne:**
- Phone screenshots: minimum 2, maximum 8
- Tablet screenshots (optional)
- Feature graphic: 1024 × 500 px image

### Step 6: App Release karna
1. **"Production" → "Create new release"**
2. AAB file upload karo (`app-release.aab`)
3. Release notes likhgo (e.g., "Initial release")
4. **"Review release"** → **"Start rollout to production"**

### Review Process
- Google 1-7 din review karda hai
- Email auga approve hone te
- App live ho jauga Play Store te!

---

## ⚠️ Zaruri Notes

### .gitignore vich rakhna (secrets GitHub te mat daavo!)
```
# Keystore - KABHI GitHub te mat daavo!
*.jks
*.keystore
android/key.properties
```

### Keystore file sambhal ke rakho
- **Keystore file gum ho gayi = app kabhi update nahi ho sakda**
- Google Drive ya kisi safe jagah backup rakho
- Password yaad rakho ya secure jagah likhke rakho

---

## 📞 Problem aave to
- Flutter issues: **flutter.dev/docs**
- Play Store issues: **support.google.com/googleplay/android-developer**

---

*Built with Flutter 💙 | Map data © OpenStreetMap contributors*
