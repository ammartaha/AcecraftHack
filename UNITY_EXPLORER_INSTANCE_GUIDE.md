# 🔍 Finding PlayerLogic INSTANCE in Unity Explorer

## ❌ The Problem You Just Hit

**Error:** "No instance found in this class"

**What happened:** You found the `GMNoDamage` property in the **CLASS DEFINITION**, but you need a **LIVE INSTANCE** (the actual player object running in the game).

**Analogy:**
- **Class Definition** = Blueprint of a car (can't drive it!)
- **Instance** = Actual car you're driving (this is what we need!)

---

## ✅ Solution: Find the Live Instance

### Method 1: Object Explorer → Search Instances (Recommended)

#### Step 1: Switch to Object Explorer Tab

At the top of Unity Explorer, click:
```
[Object Explorer]  ← Click this tab
```

NOT:
```
[Class/Type Explorer]  ← This shows definitions only
```

#### Step 2: Make Sure You're IN A BATTLE

**CRITICAL:** PlayerLogic only exists during gameplay!

- ❌ Don't search in main menu
- ❌ Don't search in character select
- ✅ Start a level/battle
- ✅ Wait for gameplay to start
- ✅ THEN search

#### Step 3: Search for Instances

In the **Object Explorer** tab, look for a search box at the top.

**Type one of these:**

```
PlayerLogic
```

OR

```
WE.Battle.Logic.PlayerLogic
```

#### Step 4: Find the Result

You should see something like:

```
🔹 PlayerLogic (WE.Battle.Logic.PlayerLogic)
   Scene: [Battle_Scene]
   Instance ID: #12345
   ▶ [View Details]
```

**Click on it!**

---

### Method 2: Scene Hierarchy (Alternative)

If search doesn't work:

#### Step 1: Go to Scene Explorer

Click the **Scene Explorer** tab in Unity Explorer.

#### Step 2: Browse the Hierarchy

Look for game objects with names like:

```
▼ BattleManager
  ▼ PlayerManager
    ▼ Player
      ▶ PlayerLogic  ← This might be it!
```

OR

```
▼ GameRoot
  ▼ LogicSystem
    ▼ Players
      ▶ PlayerLogic  ← Or here!
```

#### Step 3: Click on It

Click the GameObject that contains PlayerLogic component.

---

### Method 3: Search by Component

In Unity Explorer:

#### Step 1: Go to Search Tab

Look for a tab called **"Search"** or **"Find Instances"**.

#### Step 2: Search by Type

Enter:
```
Type: WE.Battle.Logic.PlayerLogic
```

#### Step 3: Click "Find All Instances"

Unity Explorer will list ALL active PlayerLogic instances.

---

## 🎯 Once You Find the Instance

After clicking on the live instance, you should see:

```
=== PlayerLogic Instance #12345 ===

Fields & Properties:
  ├─ GMNoDamage: false      ← Click here to edit!
  ├─ IsInvincible: false    ← Or this!
  ├─ CurHP: 100.0
  ├─ MaxHP: 100.0
  └─ ... (more properties)
```

---

## ✅ How to Set GMNoDamage = true

### Step 1: Click on the Value

Click on the `false` next to `GMNoDamage`.

### Step 2: Edit the Value

A text box or toggle should appear:

**Option A: Toggle**
```
GMNoDamage: [OFF] ← Click to toggle ON
```

**Option B: Text Input**
```
GMNoDamage: [false]  ← Change to "true"
```

### Step 3: Apply

Look for an **"Apply"** or **"Set"** button and click it.

OR

Some versions apply automatically when you change the value.

---

## 🚨 Troubleshooting

### Issue 1: "No Instances Found"

**Cause:** You're not in a battle yet!

**Solution:**
1. ❌ Close Unity Explorer
2. ✅ Start a level/battle
3. ✅ Wait for enemies to spawn
4. ✅ Re-open Unity Explorer
5. ✅ Search again

---

### Issue 2: Multiple PlayerLogic Instances

**Cause:** Multiplayer mode or co-op?

**Solution:**
- You'll see multiple results like:
  ```
  PlayerLogic #12345 (Player 1)
  PlayerLogic #67890 (Player 2)
  ```
- Click on **Player 1** (your player)
- If unsure, try both and see which one affects YOUR character

---

### Issue 3: Can't Find Object Explorer Tab

**Different Unity Explorer versions have different layouts.**

Look for these tab names:
- **"Object Explorer"**
- **"Object Search"**
- **"Instance Browser"**
- **"Live Objects"**

OR

Look for a dropdown that says:
```
[View: Classes] ← Change this to [View: Instances]
```

---

### Issue 4: Property is Read-Only / Can't Edit

**If GMNoDamage shows as read-only:**

**Solution 1: Use the Setter Method**

Look for a button or option that says:
```
set_GMNoDamage(bool value)  [Invoke]
```

Click **[Invoke]** and enter:
```
Parameters:
  value: true
```

**Solution 2: Try IsInvincible Instead**

If GMNoDamage is read-only, try:
```
IsInvincible: false  ← Set this to true instead
```

---

### Issue 5: Value Changes But Nothing Happens

**Possible causes:**

1. **Game resets it every frame**
   - Watch the value in Unity Explorer
   - Does it flip back to `false` immediately?
   - If yes: Your tweak will need to set it EVERY frame

2. **Wrong player instance**
   - You edited Player 2, but you're playing as Player 1
   - Search again and try a different instance

3. **Not in combat yet**
   - Set `GMNoDamage = true`
   - THEN take damage from enemies
   - Not before

---

## 📸 Visual Guide

### What You're Looking For:

**❌ WRONG (Class Definition):**
```
Class Browser
  └─ WE.Battle.Logic.PlayerLogic
      ├─ Type: Class
      ├─ Namespace: WE.Battle.Logic
      └─ Members:
          ├─ GMNoDamage (property)  ← Can't invoke without instance!
          └─ ...
```

**✅ CORRECT (Live Instance):**
```
Object Explorer
  └─ PlayerLogic #12345
      ├─ Type: WE.Battle.Logic.PlayerLogic
      ├─ Scene: Battle_Scene
      ├─ Active: true
      └─ Properties:
          ├─ GMNoDamage: false  ← Click to edit!
          ├─ IsInvincible: false
          ├─ CurHP: 100.0
          └─ MaxHP: 100.0
```

---

## 🎯 Step-by-Step (Simplified)

1. ✅ **Start a battle** (leave menu, enter gameplay)
2. ✅ **Open Unity Explorer**
3. ✅ **Go to "Object Explorer" tab** (NOT Class Explorer!)
4. ✅ **Search: `PlayerLogic`**
5. ✅ **Click on the instance** (should show Scene, Instance ID)
6. ✅ **Find `GMNoDamage` property**
7. ✅ **Click on `false` → Change to `true`**
8. ✅ **Take damage from enemies**
9. ✅ **Report if HP stays full!**

---

## 🎉 Success Indicators

### You found the INSTANCE when you see:

- ✅ `Instance ID: #xxxxx`
- ✅ `Scene: [SomeBattleScene]`
- ✅ Properties have ACTUAL VALUES (not just type definitions)
- ✅ You can EDIT the values directly

### You're still in CLASS view if you see:

- ❌ `Type: Class`
- ❌ `Namespace: WE.Battle.Logic`
- ❌ Only method signatures (no values)
- ❌ "No instance found" errors

---

## 🚀 Quick Test

**After setting GMNoDamage = true:**

1. ✅ Immediately run into enemy bullets
2. ✅ Watch your HP bar
3. ✅ If HP doesn't move → **SUCCESS!** 🎉
4. ❌ If HP decreases → Report back for troubleshooting

---

## 📝 Alternative Properties to Try

If `GMNoDamage` doesn't work, also try setting these to `true`:

```
IsInvincible: true
```

Or look for:
```
DebugModel.Invincible: true
```

Or try this:
```
MaxHP: 999999
CurHP: 999999
```

---

## 🔄 If Instance Disappears

**PlayerLogic might be destroyed/recreated when:**
- You die and respawn
- Level changes
- Game restarts

**Solution:** Search for the instance again after respawn.

---

**Now try finding the INSTANCE (not the class) and report what happens!** 🚀
