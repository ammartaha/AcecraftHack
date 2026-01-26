# 🔧 Unity Explorer Troubleshooting - Can't Find Instances

## Problem: Only Seeing Classes, No Instances or Fields

This is a common issue. Let's fix it step by step.

---

## ✅ Solution 1: Use C# Console to Find Instance

Unity Explorer has a **C# Console** that lets you run code directly!

### Step 1: Find the C# Console Tab

Look for a tab called:
- **"C# Console"**
- **"REPL"** (Read-Eval-Print Loop)
- **"Console"**
- **"Evaluate"**

It might be at the top or bottom of Unity Explorer.

### Step 2: Type This Command

In the console input box, type:

```csharp
UnityEngine.Object.FindObjectOfType(typeof(WE.Battle.Logic.PlayerLogic))
```

OR shorter version:

```csharp
FindObjectOfType<WE.Battle.Logic.PlayerLogic>()
```

### Step 3: Press Enter/Execute

You should see output like:

```
=> PlayerLogic (WE.Battle.Logic.PlayerLogic)
   Instance ID: #12345
   [Inspect] button
```

### Step 4: Click [Inspect] Button

This will open the instance inspector with all the fields!

### Step 5: Find GMNoDamage and Edit It

Now you should see:
```
GMNoDamage: false  ← Click and change to true
```

---

## ✅ Solution 2: Direct Property Setter via Console

If you can't find the inspector, you can SET the property directly via console!

### Step 1: Get the Instance

In C# Console, type:

```csharp
var player = UnityEngine.Object.FindObjectOfType(typeof(WE.Battle.Logic.PlayerLogic)) as WE.Battle.Logic.PlayerLogic;
```

Press Enter. You should see:
```
=> PlayerLogic instance assigned
```

### Step 2: Set GMNoDamage = true

Now type:

```csharp
player.GMNoDamage = true;
```

Press Enter.

### Step 3: Verify

Check if it was set:

```csharp
player.GMNoDamage
```

Should return:
```
=> true
```

### Step 4: Test God Mode!

Now go take damage from enemies and see if your HP stays full!

---

## ✅ Solution 3: Keep Setting It in a Loop

If the value resets, you need to keep setting it every frame.

### In C# Console, type:

```csharp
var player = UnityEngine.Object.FindObjectOfType(typeof(WE.Battle.Logic.PlayerLogic)) as WE.Battle.Logic.PlayerLogic;
if (player != null) {
    UnityEngine.Debug.Log("Found PlayerLogic! Setting GMNoDamage = true");
    player.GMNoDamage = true;
    player.IsInvincible = true;
}
```

Press Enter and test!

---

## ✅ Solution 4: Object Search (Different Method)

### Step 1: Look for "Search" Feature

In Unity Explorer menu, look for:
- **"Search"** button
- **"Find Objects"** option
- A **search icon** 🔍

### Step 2: Search by Type

When the search dialog opens:

**Search Type:** Object Type / Component Type

**Value:** `PlayerLogic` or `WE.Battle.Logic.PlayerLogic`

**Where:** Active Scene / All Scenes

### Step 3: Click Search/Find

It should list all PlayerLogic instances.

---

## ✅ Solution 5: Scene Hierarchy Navigation

### Step 1: Open Scene View

Look for:
- **"Scene Explorer"** tab
- **"Hierarchy"** tab
- **"GameObject Browser"**

### Step 2: Expand Scene Objects

Look for game objects with names like:
```
▼ Root
  ▼ BattleSystem
    ▼ Logic
      ▼ PlayerLogic  ← Look for this!
```

OR

```
▼ Managers
  ▼ GameLogic
    ▼ PlayerManager
      ▶ Player_0  ← Your player might be here
```

### Step 3: Click on Objects

Click on different objects until you find one with a `PlayerLogic` component.

---

## 🎯 Alternative: Use Debug Commands in Console

Try these console commands one by one:

### Command 1: Find All Objects of Type
```csharp
UnityEngine.Object.FindObjectsOfType(typeof(WE.Battle.Logic.PlayerLogic))
```

Should return an array of instances.

### Command 2: Try Shorter Class Name
```csharp
UnityEngine.Object.FindObjectOfType(typeof(PlayerLogic))
```

### Command 3: Search via Reflection
```csharp
var type = System.Type.GetType("WE.Battle.Logic.PlayerLogic, WeGame.Battle.Logic");
UnityEngine.Object.FindObjectOfType(type)
```

### Command 4: List All Components
```csharp
UnityEngine.Object.FindObjectsOfType<UnityEngine.MonoBehaviour>()
```

This will list ALL MonoBehaviours. Look for PlayerLogic in the results.

---

## 🚨 Critical: ARE YOU IN A BATTLE?

**PlayerLogic ONLY exists during gameplay!**

### ❌ WRONG - You're in:
- Main menu
- Character select screen
- Loading screen
- Settings menu

### ✅ CORRECT - You're in:
- Active battle/level
- Enemies are on screen
- Your character is moving/shooting
- HP bar is visible

**If you're not in a battle, PlayerLogic doesn't exist yet!**

---

## 🔍 Diagnostic: Check What Unity Explorer Shows

### Tell me what you see:

#### Question 1: What tabs are visible?
List all tabs you see at the top of Unity Explorer:
- [ ] Object Explorer
- [ ] Class Browser
- [ ] C# Console
- [ ] Scene Explorer
- [ ] Search
- [ ] Other: ___________

#### Question 2: Are you in gameplay?
- [ ] Yes, I'm in an active battle with enemies
- [ ] No, I'm in the menu
- [ ] Not sure

#### Question 3: Can you find C# Console?
- [ ] Yes, I found it
- [ ] No, can't find it
- [ ] Don't know what to look for

---

## 🛠️ Unity Explorer Version Check

Different versions have different features.

### Check the Version:

Look for:
- **"About"** button
- **"Info"** or **"Version"** in settings
- Version number somewhere in the UI

**Common versions:**
- **UnityExplorer 4.x** - Has C# Console
- **UnityExplorer 3.x** - Limited features
- **Custom builds** - May vary

---

## ⚡ Quick Test Script (Copy-Paste This)

### In C# Console, copy and paste this ENTIRE block:

```csharp
// Find PlayerLogic and enable god mode
var playerType = System.Type.GetType("WE.Battle.Logic.PlayerLogic, WeGame.Battle.Logic");
if (playerType != null) {
    UnityEngine.Debug.Log("Found PlayerLogic type!");
    var instance = UnityEngine.Object.FindObjectOfType(playerType);
    if (instance != null) {
        UnityEngine.Debug.Log("Found PlayerLogic instance!");
        var gmnodamageProperty = playerType.GetProperty("GMNoDamage");
        if (gmnodamageProperty != null) {
            gmnodamageProperty.SetValue(instance, true);
            UnityEngine.Debug.Log("Set GMNoDamage = true!");
            var currentValue = gmnodamageProperty.GetValue(instance);
            UnityEngine.Debug.Log("Current value: " + currentValue);
        }
        var invincibleProperty = playerType.GetProperty("IsInvincible");
        if (invincibleProperty != null) {
            invincibleProperty.SetValue(instance, true);
            UnityEngine.Debug.Log("Set IsInvincible = true!");
        }
    } else {
        UnityEngine.Debug.Log("ERROR: PlayerLogic instance not found. Are you in a battle?");
    }
} else {
    UnityEngine.Debug.Log("ERROR: PlayerLogic type not found. Wrong assembly name?");
}
```

**Press Enter and check the output logs!**

---

## 📊 Expected Output

### ✅ SUCCESS:
```
Found PlayerLogic type!
Found PlayerLogic instance!
Set GMNoDamage = true!
Current value: True
Set IsInvincible = true!
```

**Now test if you're invincible!**

### ❌ ERROR 1:
```
ERROR: PlayerLogic instance not found. Are you in a battle?
```

**Solution:** Start a battle level and run the script again!

### ❌ ERROR 2:
```
ERROR: PlayerLogic type not found. Wrong assembly name?
```

**Solution:** Try this alternative script:

```csharp
// Alternative: Search all types
var allTypes = System.AppDomain.CurrentDomain.GetAssemblies()
    .SelectMany(a => a.GetTypes())
    .Where(t => t.Name == "PlayerLogic");
foreach(var type in allTypes) {
    UnityEngine.Debug.Log("Found type: " + type.FullName);
}
```

This will show the correct full type name.

---

## 🎯 Simplified Test (If Console Works)

Once C# Console is working, just run:

```csharp
FindObjectOfType<WE.Battle.Logic.PlayerLogic>().GMNoDamage = true;
```

That's it! Then test god mode immediately!

---

## 🔄 Alternative Verification Methods

If Unity Explorer isn't cooperating:

### Option A: Inject Our Tweak to Test

We can write a simple V26 tweak that:
1. Finds PlayerLogic
2. Sets GMNoDamage = true
3. Logs results

Then you just check the logs to see if it worked.

### Option B: Patch the .bytes File

We can modify `WeGame.Battle.Logic.bytes` directly in dnSpy to force god mode on.

### Option C: Memory Editor

Use a memory editor like iGameGod to:
1. Search for boolean values
2. Find GMNoDamage in memory
3. Lock it to true

---

## 📝 What to Report Back

Tell me:

1. **Are you in an active battle?** (Yes/No)
2. **What tabs do you see in Unity Explorer?** (List them)
3. **Can you find "C# Console" tab?** (Yes/No)
4. **What happened when you ran the test script?** (Copy any output)

Based on your answers, I'll provide the next specific steps!

---

## 🚀 Don't Give Up!

If Unity Explorer isn't cooperating, we have backup plans:
- Write a test tweak
- Patch the assembly directly
- Use alternative tools

**The god mode property EXISTS - we just need to flip it to true!** 🎯
