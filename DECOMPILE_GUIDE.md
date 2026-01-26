# dnSpy Decompilation Guide for Acecraft

## Quick Start

Run the script:
```bash
open_dnspy.bat
```

Or manually:
```bash
cd E:\tweak
tools\dnSpy\dnSpy.exe "acecraft files\Documents\dragon2019\assets\Hybrid\WeGame.Battle.Logic.bytes"
```

---

## Step-by-Step: Finding the Damage Logic

### 1. Open the Assembly
- dnSpy will load `WeGame.Battle.Logic.bytes`
- You'll see an assembly tree in the left panel

### 2. Navigate to the Namespace
Expand the tree:
```
WeGame.Battle.Logic.bytes
  └─ {} WeGame.Battle.Logic.bytes
      └─ {} WE
          └─ {} Battle
              └─ {} Logic
                  ├─ PlayerLogic (← THIS IS WHAT WE NEED!)
                  ├─ PlayerController
                  └─ ... other classes
```

### 3. Find PlayerLogic Class
Click on **`PlayerLogic`** to view its code.

### 4. Look for These Methods (Search with Ctrl+F)

#### **Primary Targets (Damage Pipeline):**
- `DoDamage` - Applies damage to player
- `ApplyDamage` - Alternative damage method
- `set_CurHP` - Sets current HP (property setter)
- `OnAttacked` - Called when player is hit
- `OnHPChange` - HP change event handler
- `UpdateHPAttribute` - Updates HP attributes

#### **Secondary Targets (God Mode Logic):**
- `get_GMNoDamage` - Gets god mode flag (property getter)
- `set_GMNoDamage` - Sets god mode flag (property setter)
- `DoInvincible` - Invincibility logic
- `get_IsDead` - Death check

### 5. Analyze Each Method

For each method, note:
- **What it does**: Does it subtract HP? Does it check invincibility?
- **When it's called**: Is it called every frame? Only on hit?
- **Field offsets**: What fields does it access? (e.g., `this.curHP`, `this.GMNoDamage`)

### 6. Export the Code (Optional)

Right-click on **`PlayerLogic`** → **Export to Project** → Save as C# files for later reference.

---

## What to Look For

### Example 1: Simple Damage Method
```csharp
public void DoDamage(float damage) {
    if (this.GMNoDamage) return;  // ← GOD MODE CHECK!
    this.curHP -= damage;  // ← HP REDUCTION
    if (this.curHP <= 0f) {
        this.OnDie();
    }
}
```
**Strategy:** Hook this method and force an early return, OR set `GMNoDamage = true`.

### Example 2: Property Setter
```csharp
public void set_CurHP(float value) {
    this._curHP = value;  // ← Field offset we can patch!
    this.OnHPChange();
}
```
**Strategy:** Hook the setter and clamp the value to max HP.

### Example 3: Invincibility Check
```csharp
public bool CanTakeDamage() {
    return !this.GMNoDamage && !this.isInvincible;
}
```
**Strategy:** Hook this to always return `false`.

---

## Next Steps After Analysis

Once you find the damage method, **document these details** in `CURRENT_STAGE.md`:

1. **Method name**: e.g., `WE.Battle.Logic.PlayerLogic::DoDamage`
2. **Method signature**: e.g., `void DoDamage(float damage)`
3. **IL2CPP method pointer**: (You already have this from your logs)
4. **Key fields used**:
   - `GMNoDamage` at offset `???`
   - `curHP` at offset `???`
5. **Invincibility check logic**: Does it check `GMNoDamage`? Where?

Then we'll decide on the best patching strategy:
- **Option A**: Patch the .bytes file directly (modify IL code)
- **Option B**: Hook the HybridCLR interpreter
- **Option C**: Memory-lock the HP value

---

## Troubleshooting

### "The file is not a valid .NET assembly"
- The .bytes file might be encrypted or compressed
- Try other assemblies first (e.g., `Assembly-CSharp.bytes`)

### "Can't find WE.Battle.Logic namespace"
- Search for `PlayerLogic` directly (Edit → Search Assemblies → Ctrl+Shift+K)
- The namespace might be different or obfuscated

### dnSpy crashes on startup
- Run as Administrator
- Or use ILSpy instead: https://github.com/icsharpcode/ILSpy/releases

---

## Alternative: Use ILSpy (If dnSpy Doesn't Work)

Download ILSpy: https://github.com/icsharpcode/ILSpy/releases/latest

Then:
```bash
ILSpy.exe "acecraft files\Documents\dragon2019\assets\Hybrid\WeGame.Battle.Logic.bytes"
```

Same navigation steps apply.
