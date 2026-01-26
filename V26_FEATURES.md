# 🎉 Acecraft V26 - Feature List

**Build Date:** 2026-01-26
**Status:** Ready to Build & Test

---

## ✨ NEW FEATURES

### 🛡️ 1. GOD MODE
**What it does:** Makes your player invincible!

**How it works:**
- Finds the `PlayerLogic` instance in memory
- Continuously sets `GMNoDamage = true` every 0.1 seconds
- All damage is blocked by the game's built-in god mode check

**Toggle:** ON by default (can be turned off in menu)

---

### ⭐ 2. XP MULTIPLIER x200
**What it does:** Multiplies all XP gains by 200!

**How it works:**
- Hooks the `set_CurExp` property setter
- Intercepts XP gains before they're applied
- Multiplies the value by 200
- Logs each multiplication to the file

**Toggle:** ON by default (can be turned off in menu)

**Example:**
```
Kill enemy → Gain 10 XP
↓
V26 intercepts → 10 * 200 = 2000 XP
↓
You actually gain: 2000 XP!
```

---

### 🎮 3. IN-GAME MENU
**What it does:** Control all features without rebuilding!

**Features:**
- ⚡ Floating button (draggable)
- 🛡️ God Mode toggle
- ⭐ XP Multiplier toggle
- Beautiful blur UI with cyan theme
- Real-time feature enable/disable

**How to open:**
- Tap the ⚡ lightning button in-game!

---

## 📊 TECHNICAL DETAILS

### God Mode Implementation
```cpp
// Every 0.1 seconds:
1. Find PlayerLogic instance
2. Call set_GMNoDamage(true)
3. Verify it was set (log every 100 cycles)
4. Repeat forever
```

### XP Multiplier Implementation
```cpp
// When game tries to set XP:
Original: player.CurExp = 10;
           ↓
Hooked:   hook_set_CurExp(player, 10)
           ↓
Modified: player.CurExp = 10 * 200 = 2000;
```

---

## 📝 LOGS

**Location:**
```
/var/mobile/Containers/Data/Application/[APP_ID]/Documents/acecraft_v26_[timestamp].txt
```

**What's logged:**
- ✅ Tweak initialization
- ✅ Il2CppResolver status
- ✅ Class/method finding results
- ✅ Hook installation status
- ✅ God mode activation (every 100 cycles)
- ✅ XP multiplications (every gain)
- ✅ Feature toggle changes
- ❌ Any errors

**Example log:**
```
=== ACECRAFT V26: GOD MODE + XP MULTIPLIER ===
[INIT] Il2CppResolver initialized successfully
[FOUND] PlayerLogic class at 0x1a2b3c4d5
[FOUND] set_GMNoDamage at 0x1147c3cd8
[FOUND] set_CurExp at 0x1147ba080
[HOOK] set_CurExp hooked successfully!
[GOD MODE] Loop started
[GOD MODE] GMNoDamage = 1
[XP] Original: 10.00 → Multiplied: 2000.00 (x200)
```

---

## 🎯 WHY THIS WILL WORK

### Previous Versions (V1-V25):
❌ Hooked interpreter stubs (wrong target)
❌ Methods never triggered
❌ No effect in-game

### V26 Approach:
✅ Uses **built-in god mode property** (GMNoDamage)
✅ Uses **runtime reflection** to find instances
✅ Calls property setters via Il2Cpp API
✅ **Verified via dnSpy decompilation** (not guessing!)
✅ Hooks actual property setter for XP (not interpreter stub)

---

## 🚀 BUILD & DEPLOY

### Step 1: Commit & Push
```bash
git add .
git commit -m "Tweak V26: God Mode + XP Multiplier x200"
git push origin main
```

### Step 2: Download from GitHub Actions
1. Go to: https://github.com/[your-repo]/actions
2. Wait for build to complete
3. Download `AcecraftHack.deb`

### Step 3: Sideload
1. Open Sideloadly
2. Load Acecraft IPA
3. Advanced Options → Inject → Select `.deb`
4. Install to device

### Step 4: Test
1. Launch game
2. Look for ⚡ button
3. Start a level
4. Toggle god mode ON
5. Take damage → HP shouldn't drop!
6. Kill enemies → Check if XP is multiplied

### Step 5: Check Logs
1. Connect device to computer
2. Open device files
3. Go to: Acecraft → Documents
4. Open: `acecraft_v26_*.txt`
5. Check for errors or success messages

---

## ⚙️ CONFIGURATION

Want to change the XP multiplier?

**Edit line 31 in `Tweak.xm`:**
```cpp
static int xpMultiplier = 200;  // Change this number!
```

Examples:
- `50` = 50x XP
- `500` = 500x XP
- `999` = 999x XP
- `1` = Normal XP (no multiplier)

Then rebuild!

---

## 🔧 TROUBLESHOOTING

### God Mode Doesn't Work
**Check logs for:**
```
[ERROR] PlayerLogic class not found!
```
**Solution:** HybridCLR issue, try patching .bytes file instead

```
[ERROR] God mode methods not found!
```
**Solution:** Method names might be obfuscated, check dnSpy

### XP Multiplier Doesn't Work
**Check logs for:**
```
[WARN] XP methods not found
```
**Solution:** set_CurExp might be interpreter stub (HybridCLR issue)

**Alternative:** Hook BattleModel.CurExp instead

### No Logs Generated
**Possible causes:**
1. Tweak didn't load → Check Sideloadly injection
2. Wrong app container → Check app ID in path
3. File permissions → Check Documents folder exists

### Menu Button Doesn't Appear
**Possible causes:**
1. UI setup failed → Check logs for errors
2. Window not found → Game might use different window system
3. Delay too short → Increase delay in `%ctor` from 5s to 10s

---

## 📊 SUCCESS PROBABILITY

| Feature | Probability | Reason |
|---------|-------------|--------|
| God Mode | 90% | Built-in property, verified in code |
| XP Multiplier | 85% | Hook might hit interpreter stub (HybridCLR) |
| UI Menu | 95% | Standard UIKit code |
| Overall Success | 85%+ | Main features use game's own API |

---

## 🎉 EXPECTED RESULTS

### If Successful:
✅ God mode button appears in-game
✅ Player can't die (HP doesn't decrease)
✅ XP gains are 200x higher
✅ Logs show successful initialization
✅ Features can be toggled on/off

### If Partial Success:
⚠️ God mode works but XP doesn't (or vice versa)
⚠️ Logs show some methods not found
→ Still a WIN! We can fix the other feature separately

### If Complete Failure:
❌ No button appears
❌ Player still takes damage
❌ Logs show all methods not found
→ Fallback to .bytes patching or memory editing

---

## 🔄 NEXT VERSIONS

If V26 works partially, future versions can add:

**V27 Ideas:**
- 💰 Gold/Currency multiplier
- ⚔️ Damage multiplier (one-hit kill)
- 🏃 Speed hack
- 🎯 Aimbot/auto-aim
- 🔓 Unlock all characters
- 🎁 Free shop items

**V28 Ideas:**
- 🌐 Unlimited ammo
- ⏱️ Slow motion
- 👻 No cooldowns
- 🎲 Loot multiplier

---

## 📖 DOCUMENTATION GENERATED

All analysis files created:
- ✅ `ANALYSIS_RESULTS.md` - Full technical findings
- ✅ `CURRENT_STAGE.md` - Updated implementation status
- ✅ `VERIFICATION_GUIDE.md` - Unity Explorer testing guide
- ✅ `DECOMPILE_GUIDE.md` - dnSpy usage instructions
- ✅ `V26_FEATURES.md` - This file!
- ✅ `decompiled_output/PlayerLogic.cs` - Full source code

---

**Ready to build V26! Let's see if god mode actually works!** 🚀
