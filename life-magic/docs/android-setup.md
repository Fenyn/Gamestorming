# Life Magic — Phone + Pixel Watch Setup

## Prerequisites

1. **JDK 17** — Required for the Gradle build. Install from adoptium.net or via Android Studio.
2. **Android Studio** — Install from developer.android.com/studio (provides SDK Manager, adb, and build tools)
3. **Godot 4.6 Android export templates** — In Godot: Editor > Manage Export Templates > Download for 4.6
4. **Your Pixel phone** with Developer Mode enabled
   - Settings > About Phone > tap Build Number 7 times
   - Settings > Developer Options > USB Debugging ON
5. **Health Connect** app installed on phone (pre-installed on Pixel 6+, or get from Play Store)

---

## Step 1: Install Android Build Template

The Health Connect plugin compiles from source as part of Godot's Gradle build. You need the Android build template installed first.

1. In Godot: **Project > Install Android Build Template**
2. This creates `android/build/` with the Gradle project structure (build.gradle, settings.gradle, etc.)
3. The plugin at `android/plugins/health-connect/` is automatically included as a module

> If the "Install Android Build Template" option is greyed out, make sure you've downloaded the Android export templates for Godot 4.6 first (Editor > Manage Export Templates).

---

## Step 2: Configure Android Export

1. Open project in Godot Editor
2. Project > Export > Add **Android** (or edit the existing Android preset)
3. Under **Gradle Build**:
   - **Use Gradle Build**: ON (required — the Health Connect plugin compiles from source)
   - **Min SDK**: `28` (required for Health Connect API)
   - **Target SDK**: `34`
4. Under **Package**:
   - **Unique Name**: `com.lifemagic.game`
5. Under **Keystore**:
   - Generate a debug keystore if you don't have one:
     ```
     keytool -genkey -v -keystore debug.keystore -alias androiddebugkey -keyalg RSA -validity 10000
     ```
   - Set keystore path, alias: `androiddebugkey`, password: `android`

**Permissions note:** Health Connect permissions (`READ_HEART_RATE`, `READ_STEPS`) are declared in the plugin's own `AndroidManifest.xml`, not in Godot's export permission checkboxes. They get merged into the final APK automatically during the Gradle build. You don't need to check anything in the Godot permissions list.

---

## Step 3: Verify Plugin Gradle Config

The plugin's build config lives at:

```
android/plugins/health-connect/build.gradle.kts
```

Make sure the Godot dependency version matches your export templates:

```kotlin
compileOnly("org.godotengine:godot:4.6.0.stable")
```

If you see build errors about unresolved Godot classes, this version mismatch is almost always the cause.

The plugin is a **v2 Android plugin** — Godot discovers it automatically via the `org.godotengine.plugin.v2.HealthConnect` metadata in its `AndroidManifest.xml`. There's no checkbox to enable it; if the Gradle build succeeds, the plugin is available.

---

## Step 4: Export and Install

**Option A — Direct USB (recommended for dev):**

1. Plug phone into PC via USB
2. Accept USB debugging prompt on phone
3. In Godot: click the **Android one-click deploy** button in the toolbar (phone icon)
4. First build takes a few minutes (Gradle downloads dependencies); subsequent builds are faster

**Option B — APK file:**

1. Project > Export > Android > Export Project
2. Transfer the .apk to phone and install (enable "Install unknown apps" for your file manager)

---

## Step 5: Connect Pixel Watch to Health Connect

Your Pixel Watch already syncs HR to Health Connect via the Fitbit or Wear OS app:

1. On phone, open **Health Connect** app
2. Verify **Fitbit** (or **Wear OS**) shows as a connected source
3. Check that Heart Rate data is flowing: Health Connect > Browse > Heart Rate > should show recent readings

---

## Step 6: In-Game Setup

1. Launch Life Magic
2. Go to **Profile** tab
3. Set **Heart Rate Source** to **Health** (the "Health" button only appears on Android when the plugin loaded successfully)
4. Grant permissions when prompted
5. Your real BPM should appear within 2-3 seconds

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Health" button doesn't appear | Plugin didn't load — check Godot output log for Gradle errors. Make sure "Use Gradle Build" is ON. |
| Gradle build fails: "unresolved reference" | Godot dependency version mismatch — check `build.gradle.kts` uses `4.6.0.stable` |
| Gradle build fails: can't resolve dependencies | Check JDK 17 is on PATH and Android Studio's SDK Manager has API 34 installed |
| BPM stays at 0 | Open Health Connect app, verify HR data exists from the last 30 seconds |
| Permission denied | Uninstall and reinstall app, or Settings > Apps > Life Magic > Permissions |
| Watch HR not syncing to Health Connect | Open Fitbit/Wear OS app, ensure background sync is on |
| "Install Android Build Template" greyed out | Download export templates first: Editor > Manage Export Templates > Download for 4.6 |

---

## Data Flow

```
Pixel Watch → Fitbit/Wear OS app → Health Connect → Plugin (polls every 2s) → GDScript
```

No health data is stored. The plugin reads the latest value, passes it to GDScript, and discards it.

---

## Architecture Reference

- **Plugin source**: `android/plugins/health-connect/` (Kotlin, compiles during Gradle build)
- **Plugin class**: `HealthConnectPlugin.kt` — exposes methods to GDScript via `@UsedByGodot`
- **GDScript integration**: `scripts/autoload/heart_rate_manager.gd` — accesses plugin via `Engine.get_singleton("HealthConnect")`
- **HR sources**: demo (built-in simulation), simulated (manual BPM), websocket (external HR monitor), health_connect (Android Health Connect)