# How dnSpy Can Read .bytes Files

## What Are These .bytes Files?

The files in `acecraft files/Documents/dragon2019/assets/Hybrid/` are **disguised .NET assemblies**.

### The Trick:
```
WeGame.Battle.Logic.bytes  ← Looks like a data file
      ↓
Actually a renamed WeGame.Battle.Logic.dll  ← Real .NET assembly
```

### Why Rename to .bytes?

Game developers do this to:
1. **Bypass iOS restrictions** - Apple doesn't allow downloading executable code (.dll, .exe) at runtime
2. **Enable hot-updates** - By renaming to .bytes, they can download updates without resubmitting to App Store
3. **Use HybridCLR** - The interpreter loads these .bytes files and executes them as C# code

### Proof It's a .NET DLL:

Remember when I checked the file header? I found:
```
00000000: 4d5a 9000  ← "MZ" signature (DOS/PE executable header)
00000080: 5045 0000  ← "PE" signature (Portable Executable)
```

These are the same headers as a Windows .exe or .dll file!

---

## How dnSpy Detected It

dnSpy doesn't care about the file extension. It reads the **file content**:

1. You opened: `WeGame.Battle.Logic.bytes`
2. dnSpy reads first bytes: `MZ` + `PE` headers
3. dnSpy says: "This is a .NET assembly!"
4. dnSpy loads it as a DLL and decompiles the IL (Intermediate Language) code back to C#

---

## What You're Seeing in dnSpy

```
WeGame.Battle.Logic (0.0.0.0)  ← Assembly name + version
  └─ WeGame.Battle.Logic.dll   ← dnSpy shows it as .dll (its true identity)
      ├─ PE                    ← Portable Executable metadata
      ├─ Type References       ← References to other types
      ├─ References            ← References to other assemblies
      ├─ WE.Battle.Logic       ← NAMESPACE (this contains PlayerLogic!)
      └─ WE.Game               ← NAMESPACE (this contains SetNoDamage!)
```

### What's a Namespace?

Think of it like folders:
```
Your Hard Drive
  └─ E:\tweak\
      ├─ src\         ← Folder
      └─ tools\       ← Folder

Game Assembly
  └─ WE.Battle.Logic  ← Namespace (like a folder for code)
      ├─ PlayerLogic        ← Class (like a file)
      ├─ EnemyLogic         ← Class
      └─ BattleManager      ← Class
```

---

## So These ARE the Game Files!

**YES!** You're looking at the **actual game logic code** that runs on your iPhone.

### What You're Seeing:
- ✅ **Source code** - The actual C# code the developers wrote
- ✅ **Real logic** - This is what controls player HP, damage, god mode, etc.
- ✅ **Modifiable** - You can patch this file or hook these methods

### The Flow:
```
1. Game starts on iPhone
   ↓
2. UnityFramework loads
   ↓
3. HybridCLR interpreter starts
   ↓
4. Loads WeGame.Battle.Logic.bytes from Documents/dragon2019/assets/Hybrid/
   ↓
5. Executes the C# code inside (PlayerLogic, damage, etc.)
   ↓
6. Your character takes damage based on this code!
```

---

## Why Your Hooks Didn't Work Before

Now you understand the problem:

### Old Approach (V17, V24):
```
Your tweak hooks → Native method pointer (0x1147ba080)
                    ↓
                    Interpreter stub (shared trampoline)
                    ↓
                    ??? (never reaches actual code)
```

### What's Actually Happening:
```
Game runs → HybridCLR interpreter → Reads WeGame.Battle.Logic.bytes
            ↓                        ↓
            Calls interpreter        Executes PlayerLogic.DoDamage()
            stub                     ↓
                                     Reduces HP!
```

Your hooks are targeting the **interpreter stub**, not the **actual DoDamage() code**.

---

## Now With dnSpy, You Can See:

The **actual C# code** that runs, for example:
```csharp
public void DoDamage(float damage)
{
    if (this.GMNoDamage)  // ← This check happens in INTERPRETED code
    {
        return;  // Skip damage
    }
    this.curHP -= damage;  // ← This is where HP is reduced
}
```

This code is **inside the .bytes file**, not compiled into the native binary!

---

## Next Step: Find This Code

Now expand `WE.Battle.Logic` in dnSpy to see the actual `PlayerLogic` class and its methods.

You're looking at the **real game source code** now!
