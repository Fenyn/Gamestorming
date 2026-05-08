# Life Magic — Phone + Pixel Watch Setup

## Prerequisites Overview

You need four things installed before you can export to Android:

1. JDK 17 (Java Development Kit)
2. Android Studio + Android SDK
3. Godot 4.6 Android export templates
4. A debug keystore for signing builds

Plus your Pixel phone set up for USB debugging and a Pixel Watch for live heart rate streaming.

---

## Step 0: Install the Dev Environment

### 0a. Install JDK 17

The Gradle build system requires Java 17.

1. Go to https://adoptium.net/
2. Download **Temurin JDK 17** (LTS) — Windows x64 `.msi` installer
3. During installation, check both:
   - **Set JAVA_HOME variable**
   - **Add to PATH**
4. After install, open a new terminal and verify:
   ```
   java -version
   ```
   You should see `openjdk version "17.x.x"`.

### 0b. Install Android Studio + SDK

Android Studio provides the SDK Manager, platform tools (adb), and build tools that Godot needs.

1. Go to https://developer.android.com/studio
2. Download and run the installer — default settings are fine
3. On first launch, Android Studio will run the **Setup Wizard**:
   - Choose **Standard** install type
   - It will download the Android SDK, SDK Platform API 34, and Build Tools automatically
   - Note the **Android SDK Location** it shows (usually `C:\Users\<you>\AppData\Local\Android\Sdk`) — you'll need this path for Godot
4. After the wizard completes, open **SDK Manager** (Settings > Languages & Frameworks > Android SDK) and confirm these are installed:
   - **SDK Platforms** tab: Android 14.0 (API 34)
   - **SDK Tools** tab: Android SDK Build-Tools, Android SDK Command-line Tools, Android SDK Platform-Tools

### 0c. Point Godot at the SDK and JDK

1. In Godot: **Editor > Editor Settings**
2. Search for **Android** in the left sidebar under **Export**
3. Set these paths:
   - **Android SDK Path**: your SDK location from step 0b (e.g., `C:\Users\<you>\AppData\Local\Android\Sdk`)
   - **Java SDK Path**: your JDK 17 install directory (e.g., `C:\Program Files\Eclipse Adoptium\jdk-17.x.x-hotspot`)
4. You should see green checkmarks next to both paths if they're valid

### 0d. Download Godot Export Templates

1. In Godot: **Editor > Manage Export Templates**
2. Click **Download and Install** for version 4.6
3. Wait for the download to complete — this is ~600 MB

### 0e. Generate a Debug Keystore

A keystore is required to sign APKs, even for debug builds.

1. Open a terminal and `cd` to your project directory (or anywhere you want to keep the keystore)
2. Run:
   ```
   keytool -genkey -v -keystore debug.keystore -alias androiddebugkey -keyalg RSA -validity 10000
   ```
3. When prompted:
   - **Keystore password**: `android` (this is the standard debug convention)
   - **Name, org, city, etc.**: press Enter through all of them (or type anything — it doesn't matter for debug)
   - **Key password**: press Enter to use the same as the keystore password
4. You'll have a `debug.keystore` file
5. In Godot: **Editor > Editor Settings > Export > Android**:
   - **Debug Keystore**: path to your `debug.keystore`
   - **Debug Keystore User**: `androiddebugkey`
   - **Debug Keystore Pass**: `android`

### 0f. Set Up Your Pixel Phone

1. On your phone: **Settings > About Phone** > tap **Build Number** 7 times to enable Developer Mode
2. **Settings > System > Developer Options**:
   - **USB Debugging**: ON
3. Connect your phone via USB cable
4. Accept the **Allow USB debugging** prompt on your phone
5. Verify the connection — open a terminal and run:
   ```
   adb devices
   ```
   You should see your device listed. (If `adb` isn't on your PATH, it's at `<SDK path>\platform-tools\adb.exe`)

---

## Step 1: Install Android Build Template

The HeartLink plugin compiles from source as part of Godot's Gradle build. You need the Android build template installed first.

1. In Godot: **Project > Install Android Build Template**
2. This creates `android/build/` with the Gradle project structure (build.gradle, settings.gradle, etc.)
3. **Important:** After installing the template, verify that `android/build/settings.gradle` includes the HeartLink plugin:
   ```gradle
   include ':heart-link'
   project(':heart-link').projectDir = new File('../plugins/heart-link')
   ```
   And that `android/build/build.gradle` includes:
   ```gradle
   implementation project(':heart-link')
   ```
   Reinstalling the build template overwrites these files, so you must re-add the lines above if you reinstall.

> If the "Install Android Build Template" option is greyed out, make sure you've downloaded the Android export templates for Godot 4.6 first (Editor > Manage Export Templates).

---

## Step 2: Configure Android Export

1. Open project in Godot Editor
2. Project > Export > Add **Android** (or edit the existing Android preset)
3. Under **Gradle Build**:
   - **Use Gradle Build**: ON (required — the HeartLink plugin compiles from source)
   - **Min SDK**: `28`
   - **Target SDK**: `34`
4. Under **Package**:
   - **Unique Name**: `com.lifemagic.game`
5. Under **Keystore**:
   - Use the debug keystore you created in Step 0e
   - Set keystore path, alias: `androiddebugkey`, password: `android`

---

## Step 3: Verify Plugin Gradle Config

The plugin's build config lives at:

```
android/plugins/heart-link/build.gradle.kts
```

Make sure the Godot dependency version matches your export templates:

```kotlin
compileOnly("org.godotengine:godot:4.6.0.stable")
```

If you see build errors about unresolved Godot classes, this version mismatch is almost always the cause.

The plugin is a **v2 Android plugin** — Godot discovers it automatically via the `org.godotengine.plugin.v2.HeartLink` metadata in its `AndroidManifest.xml`. There's no checkbox to enable it; if the Gradle build succeeds, the plugin is available.

---

## Step 4: Export and Install the Phone App

**Option A — Direct USB (recommended for dev):**

1. Plug phone into PC via USB
2. Accept USB debugging prompt on phone
3. In Godot: click the **Android one-click deploy** button in the toolbar (phone icon near play/stop buttons)
4. First build takes a few minutes (Gradle downloads dependencies); subsequent builds are faster

**Option B — APK file:**

1. Project > Export > Android > Export Project
2. Install via terminal:
   ```
   adb install path\to\your\exported.apk
   ```

---

## Step 5: Set Up Pixel Watch for Live HR Streaming

The watch runs a small companion app ("Life Magic HR") that reads your heart rate sensor directly and streams it to the phone in real time (~1 update per second).

### 5a. Enable Developer Options on Pixel Watch

1. On your watch: **Settings > System > About** > tap **Build Number** 7 times
2. Go back to **Settings > Developer Options**:
   - **ADB Debugging**: ON
   - **Debug over Wi-Fi**: ON (or use USB if you have a watch debug cable)
3. Note the IP address shown under "Debug over Wi-Fi" (e.g., `192.168.1.42`)

### 5b. Connect to Watch via ADB

Over Wi-Fi:
```
adb connect 192.168.1.42:5555
```

Verify both devices are connected:
```
adb devices
```
You should see two entries — your phone and your watch.

### 5c. Build and Install the Watch App

The watch app is a separate Gradle project at `life-magic/wear/`:

```
cd life-magic\wear
..\android\build\gradlew assembleDebug
```

> **Note:** The watch project uses the Gradle wrapper from the phone's build directory. If you don't have `gradlew` there, you can use any Gradle 8.11+ installation, or copy the wrapper files into `wear/`.

Then install to the watch (use the watch's device serial or IP):
```
adb -s 192.168.4.47:39155 install build\outputs\apk\debug\life-magic-wear-debug.apk
```

### 5d. Grant Permissions on Watch

1. Open **Life Magic HR** on your watch (it appears in the app list)
2. Grant **Body Sensors** permission when prompted
3. Optionally grant **Notifications** permission (for the streaming notification)
4. Tap **Start** to begin streaming

You should see your current BPM on the watch screen. The notification bar will show "Life Magic HR" while streaming is active.

---

## Step 6: In-Game Setup

1. Make sure the watch app is running and showing your BPM
2. Launch Life Magic on your phone
3. Go to **Settings** tab
4. Set **Heart Rate Source** to **Watch**
5. You should see "Watch connected!" and your live BPM within 1-2 seconds

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Watch" button doesn't appear | HeartLink plugin didn't load — check Godot output log for Gradle errors. Make sure "Use Gradle Build" is ON and `settings.gradle` includes `:heart-link`. |
| Gradle build fails: "unresolved reference" | Godot dependency version mismatch — check `build.gradle.kts` uses `4.6.0.stable` |
| Gradle build fails: can't resolve dependencies | Check JDK 17 is on PATH and Android Studio's SDK Manager has API 34 installed |
| BPM stays at 0 / "Waiting for watch..." | Watch app isn't streaming. Open Life Magic HR on watch and tap Start. Make sure both devices are on the same Google account. |
| Watch app says "Phone not found" | Phone app must be running. Check both devices are paired and connected via Bluetooth. |
| "Watch disconnected" appears | Watch may have gone to sleep or lost Bluetooth connection. Reopen the watch app and tap Start. |
| Can't connect to watch via ADB | Make sure ADB debugging and Wi-Fi debugging are ON in watch Developer Options. Try `adb connect <ip>:5555` again. |
| Watch build fails | Run from `life-magic\wear\` directory. Make sure JAVA_HOME points to JDK 17. |
| "Install Android Build Template" greyed out | Download export templates first: Editor > Manage Export Templates > Download for 4.6 |

---

## Data Flow

```
Pixel Watch HR Sensor → Health Services MeasureClient → MessageClient (Wearable Data Layer) → Phone WearableListenerService → HeartLinkPlugin → GDScript
```

No health data is stored anywhere. The watch reads the sensor value, sends it to the phone, and the phone plugin holds only the most recent value in a volatile field. When the app closes, all data is gone.

---

## Architecture Reference

- **Phone plugin source**: `android/plugins/heart-link/` (Kotlin, compiles during Gradle build)
- **Phone plugin class**: `HeartLinkPlugin.kt` — exposes methods to GDScript via `@UsedByGodot`
- **Phone listener**: `WearHRListenerService.kt` — receives Wearable Data Layer messages
- **Watch app source**: `wear/` (standalone Gradle project)
- **Watch service**: `HRStreamingService.kt` — reads HR sensor and sends to phone
- **GDScript integration**: `scripts/autoload/heart_rate_manager.gd` — accesses plugin via `Engine.get_singleton("HeartLink")`
- **HR sources**: demo (built-in simulation), simulated (manual BPM), websocket (external HR monitor), wear (live Wear OS watch)
