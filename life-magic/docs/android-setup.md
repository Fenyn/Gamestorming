# Life Magic — Phone + Pixel Watch Setup

## Prerequisites

1. **Android Studio** — Install from developer.android.com/studio
2. **Godot Android export templates** — In Godot: Editor > Manage Export Templates > Download for 4.6
3. **Your Pixel phone** with Developer Mode enabled
   - Settings > About Phone > tap Build Number 7 times
   - Settings > Developer Options > USB Debugging ON
4. **Health Connect** app installed on phone (pre-installed on Pixel, or get from Play Store)

---

## Step 1: Configure Android Export in Godot

1. Open project in Godot Editor
2. Project > Export > Add > Android
3. Set:
   - **Min SDK**: 28 (required for Health Connect)
   - **Target SDK**: 34
   - **Package Unique Name**: `com.lifemagic.game`
   - **Custom Build**: ON (required for plugins)
   - **Plugins**: enable `HealthConnect`
4. Under **Keystore**:
   - Generate a debug keystore: `keytool -genkey -v -keystore debug.keystore -alias androiddebugkey -keyalg RSA -validity 10000`
   - Set keystore path, alias: `androiddebugkey`, password: `android`
5. Under **Permissions**: ensure these are checked:
   - `android.permission.health.READ_HEART_RATE`
   - `android.permission.health.READ_STEPS`

---

## Step 2: Build the Plugin

The Health Connect plugin lives at `android/plugins/health-connect/`. Godot's custom build system compiles it automatically when you export with Custom Build ON.

If you hit Godot version mismatch errors (plugin targets 4.3, project is 4.6), edit:

```
android/plugins/health-connect/build.gradle.kts
```

Change the Godot dependency version to match your templates:

```kotlin
compileOnly("org.godotengine:godot:4.6.0.stable")
```

---

## Step 3: Export and Install

**Option A — Direct USB:**

1. Plug phone into PC via USB
2. In Godot: Project > Export > Android > Export Project (or one-click deploy button in toolbar)
3. Accept USB debugging prompt on phone

**Option B — APK file:**

1. Export to .apk file
2. Transfer to phone and install (enable "Install unknown apps" for your file manager)

---

## Step 4: Connect Pixel Watch to Health Connect

Your Pixel Watch already syncs HR to Health Connect via the Fitbit or Wear OS app:

1. On phone, open **Health Connect** app
2. Verify **Fitbit** (or **Wear OS**) shows as a connected source
3. Check that Heart Rate data is flowing: Health Connect > Browse > Heart Rate > should show recent readings

---

## Step 5: In-Game Setup

1. Launch Life Magic
2. Go to **Profile** tab
3. Set **Heart Rate Source** to **Health** (the "Health" button only appears on Android with Health Connect available)
4. Grant permissions when prompted
5. Your real BPM should appear within 2-3 seconds

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Health" button doesn't appear | Health Connect not installed, or plugin didn't load (check Godot output log) |
| BPM stays at 0 | Open Health Connect app, verify HR data exists from last 30 seconds |
| Permission denied | Uninstall and reinstall app, or go to Settings > Apps > Life Magic > Permissions |
| Plugin build fails | Check Android Studio + JDK 17 are on PATH, and Gradle can resolve dependencies |
| Watch HR not syncing | Open Fitbit/Wear OS app, ensure background sync is on |

---

## Data Flow

```
Pixel Watch > Fitbit/Wear OS app > Health Connect > Life Magic plugin (polls every 2s) > GDScript
```

No health data is stored. The plugin reads the latest value, passes it to GDScript, and discards it.
