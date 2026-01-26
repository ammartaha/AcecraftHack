# 🔍 God Mode Verification Guide (BEFORE Coding)

**Goal:** Manually test if setting `GMNoDamage = true` actually makes the player invincible.

**Tool:** Unity Explorer (runtime Unity object inspector)

---

## 📋 Overview

Instead of writing code and hoping it works, we'll:

1. ✅ Inject **Unity Explorer** into the game
2. ✅ Use it to **find** the `PlayerLogic` instance while playing
3. ✅ Manually **set** `GMNoDamage = true` using the UI
4. ✅ Test if player becomes invincible
5. ✅ If YES → Write the tweak code confidently
6. ✅ If NO → Investigate why and find another approach

---

## 🛠️ Step-by-Step Verification Process

### Step 1: Prepare Unity Explorer Files

You already have Unity Explorer! Check your tools folder:

```bash
E:\tweak\tools\Explorer.dylib     ← Unity Explorer library
E:\tweak\tools\Explorer.plist     ← Configuration file
```

**Verify they exist:**

```bash
ls -lh tools/Explorer.*
```

You should see:
- `Explorer.dylib` (~491 KB)
- `Explorer.plist` (~376 bytes)

---

### Step 2: Inject Unity Explorer into Game IPA

**You'll use Sideloadly to inject Unity Explorer alongside the game.**

#### Option A: Use Your Original Game IPA (No Tweak)

This is the **cleanest** approach for testing:

1. **Open Sideloadly**
2. **Load your decrypted Acecraft IPA**
3. **Click "Advanced Options"**
4. **Check "Inject dylibs/frameworks"**
5. **Click the `+` button**
6. **Select:** `E:\tweak\tools\Explorer.dylib`
7. **Start sideloading**

#### Option B: Use Latest .deb + Unity Explorer

If you want to test your existing tweak + Unity Explorer together:

1. Get your latest `.deb` from GitHub Actions (e.g., V24)
2. In Sideloadly Advanced Options:
   - Add `com.acecrafthack...deb` (your tweak)
   - Add `Explorer.dylib` (Unity Explorer)
3. Sideload both together

---

### Step 3: Install and Launch the Game

After Sideloadly finishes:

1. ✅ Game will install on your iPhone
2. ✅ Launch the game
3. ✅ Unity Explorer will load automatically with the game

---

### Step 4: Open Unity Explorer Menu

Once in-game, Unity Explorer adds a **floating menu button**.

**Look for:**
- A small **semi-transparent button** on the screen (usually top-left or can be dragged)
- It might say "UE" or have a Unity icon

**If you don't see it:**
- Try **swiping from the left edge** of the screen
- Or check if there's a **gesture** to open it (varies by UnityExplorer version)
- Some versions use a **three-finger tap**

**If still not visible:**
- The injection might have failed
- Check Sideloadly logs for errors

---

### Step 5: Navigate to PlayerLogic Instance

Once Unity Explorer is open:

#### 5.1: Go to "Object Explorer" Tab

Click on the **Object Explorer** tab (usually the first tab).

#### 5.2: Search for PlayerLogic

In the search bar at the top, type:

```
PlayerLogic
```

Or the full class name:

```
WE.Battle.Logic.PlayerLogic
```

#### 5.3: Find the Active Instance

You should see results like:

```
[PlayerLogic] (WE.Battle.Logic.PlayerLogic)
  Instance ID: 12345
  Status: Active
```

**Click on it** to view its properties.

**If you don't see it:**
- You need to be **in a battle** (not in menu)
- Start a game level first, THEN search
- PlayerLogic only exists during gameplay

---

### Step 6: Find the GMNoDamage Property

After clicking the PlayerLogic instance:

#### 6.1: View Inspector Panel

Unity Explorer will show an **Inspector** panel with all fields/properties.

#### 6.2: Scroll to Find GMNoDamage

Look through the list for:

```
GMNoDamage (Boolean)
  Value: false  ← Currently disabled
```

Or use the **search/filter** in the inspector if available.

#### 6.3: Alternative - Use Property Search

Some Unity Explorer versions have a property search. Type:

```
GMNoDamage
```

---

### Step 7: Set GMNoDamage = true

Once you find the `GMNoDamage` property:

#### 7.1: Click on the Value

Click on the `false` value next to `GMNoDamage`.

#### 7.2: Change to true

A text input or toggle should appear. Change it to:

```
true
```

Or toggle the checkbox to **ON**.

#### 7.3: Apply/Save

Some versions require clicking **"Apply"** or **"Set"** button.

Others apply changes immediately.

---

### Step 8: Test God Mode!

**Now test if the player is invincible:**

1. ✅ Let enemies shoot you
2. ✅ Intentionally crash into bullets
3. ✅ Take damage from bosses

**Expected Results:**

- ✅ **SUCCESS:** HP doesn't decrease, player can't die
- ❌ **FAILURE:** Player still takes damage

---

## 📊 Interpreting Results

### ✅ If God Mode Works:

**What you'll see:**
- Player HP stays at max
- Damage numbers might appear but HP doesn't change
- Player can't die

**What this means:**
- The `GMNoDamage` property **WORKS!**
- Your analysis was **CORRECT!**
- You can confidently write the V26 tweak code

**Next step:** Implement the tweak to automatically set `GMNoDamage = true`

---

### ❌ If God Mode Doesn't Work:

**Possible reasons:**

#### Reason 1: Property Didn't Actually Change

**Check:**
- Look at the property value again in Unity Explorer
- Make sure it says `true`, not `false`
- Try setting it again

#### Reason 2: Value Resets Every Frame

**Check:**
- Watch the property while in-game
- Does it flip back to `false` automatically?
- If yes, the game is resetting it → Your tweak needs to set it **every frame**

#### Reason 3: There's Another Check

**Check in dnSpy:**
- Look at line 3092 in `OnAttacked()` method:
  ```csharp
  if (this.IsInvincible) return;
  ```
- Maybe `IsInvincible` is checked first?
- Try setting BOTH `GMNoDamage = true` AND `IsInvincible = true`

#### Reason 4: Wrong Instance

**Check:**
- Are you in **multiplayer mode**?
- There might be multiple `PlayerLogic` instances
- Make sure you're editing the **correct player's** instance

---

## 🎯 Alternative Tests

If you can't find `GMNoDamage` in Unity Explorer:

### Test 1: Set IsInvincible = true

Look for:
```
IsInvincible (Boolean)
  Value: false
```

Set it to `true` and test.

### Test 2: Set CurHP to a huge value

Look for:
```
CurHP (FixD2 or float)
  Value: 100
```

Set it to `999999` and see if it stays high.

### Test 3: Check MaxHP

Look for:
```
MaxHP (FixD2 or float)
  Value: 100
```

Set it to `999999` and test.

---

## 📝 Documentation Template

After testing, fill this out:

```
=== GOD MODE VERIFICATION RESULTS ===

Date: 2026-01-26
Game Version: [Check in app]
Unity Explorer Version: [Check which version you injected]

STEPS TAKEN:
- [ ] Injected Unity Explorer via Sideloadly
- [ ] Opened Unity Explorer in-game
- [ ] Found PlayerLogic instance
- [ ] Located GMNoDamage property
- [ ] Set GMNoDamage = true
- [ ] Tested taking damage

RESULTS:
[ ] ✅ SUCCESS - Player is invincible!
[ ] ❌ FAILURE - Player still takes damage

OBSERVATIONS:
- GMNoDamage initial value: [true/false]
- GMNoDamage after setting: [true/false]
- Does value reset? [yes/no]
- HP behavior: [describe what happened]

NEXT STEPS:
[If success: Implement V26 tweak]
[If failure: Try alternative properties or investigate further]
```

---

## 🛠️ Troubleshooting

### Unity Explorer Doesn't Show Up

**Solution 1: Check Injection**
- Open Sideloadly logs
- Look for "Injected Explorer.dylib successfully"

**Solution 2: Try Different Gesture**
- Three-finger tap
- Swipe from screen edge
- Long-press on screen

**Solution 3: Reinstall**
- Delete game from device
- Re-inject with Sideloadly
- Make sure Explorer.dylib is in the file list

### Can't Find PlayerLogic Instance

**Solution 1: Start a Battle**
- PlayerLogic only exists during gameplay
- Go to main menu → Start level → Then search

**Solution 2: Search Parent Class**
- Try searching for `EntityLogic` (parent class)
- Or search for `PlayerController` (related class)

**Solution 3: Browse All Objects**
- In Unity Explorer, browse **Scene Hierarchy**
- Look for game manager objects
- PlayerLogic might be under a manager

### GMNoDamage Property Not Visible

**Solution 1: Expand Properties Section**
- Unity Explorer groups fields vs properties
- Make sure "Properties" section is expanded

**Solution 2: Search All Members**
- Some versions hide properties by default
- Enable "Show Properties" in settings

**Solution 3: Try Field Name**
- The property might be backed by a field: `_GMNoDamage`
- Or: `<GMNoDamage>k__BackingField`

---

## ⚡ Quick Verification (No Unity Explorer)

If Unity Explorer doesn't work, you can still verify by:

### Method 1: Patch the .bytes File Directly

1. Open `WeGame.Battle.Logic.bytes` in dnSpy
2. Edit `OnAttacked` method
3. Add `return;` at line 3092 (skip all damage)
4. Save modified .bytes
5. Replace in IPA
6. Sideload and test

### Method 2: Check Debug Mode

Look in Unity Explorer for:
```
DebugModel.Invincible (Boolean)
```

The code checks this too (line 3101):
```csharp
if (this.battleLogicSystem.DebugModel.Invincible)
{
    damageInfo.Damage = 0;
}
```

Try setting `DebugModel.Invincible = true` instead!

---

## ✅ Success Checklist

- [ ] Explorer.dylib injected successfully
- [ ] Unity Explorer menu appears in-game
- [ ] PlayerLogic instance found
- [ ] GMNoDamage property visible
- [ ] Value changed to true
- [ ] Player tested taking damage
- [ ] Results documented

---

## 🎉 After Successful Verification

If god mode works, document:

1. **Exact property name:** `GMNoDamage` or `_GMNoDamage` or other
2. **Property type:** `Boolean` or `bool`
3. **Behavior:** Does it stay true or reset every frame?
4. **Side effects:** Any visual glitches, crashes, etc.?

Then proceed to **write V26 tweak code** with confidence! 🚀
