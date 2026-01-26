# Acecraft Mod – Current Stage (2026-01-26 UPDATED)

## ✅ STATUS: BREAKTHROUGH ACHIEVED!

**Previous Issue:** Hooks didn't work because we were hooking HybridCLR interpreter stubs.

**NEW DISCOVERY:** The game has **BUILT-IN god mode** - we just need to enable it!

---

## 🎯 KEY FINDINGS (via dnSpy Analysis)

### 1. God Mode Property Found!

**Location:** `PlayerLogic.cs` Line 4165
```csharp
public bool GMNoDamage { get; set; }
```

**How It Works:** Line 3105 in `OnAttacked()` method
```csharp
if (this.GMNoDamage)
{
    damageInfo.Damage = 0;  // ← ALL DAMAGE BLOCKED!
}
```

### 2. Damage Pipeline Mapped

**Method:** `OnAttacked(DamageInfo damageInfo)` (Line 3090-3170)

**Flow:**
1. Check `IsInvincible` → Return if true
2. Trigger buffs
3. **Check `GMNoDamage`** → Set damage to 0 if true ✅
4. Check immunity
5. Call `base.TakeDamage()` → Apply damage
6. Send events

### 3. One-Hit Kill Targets

**Method:** `GetDamageBonus(EntityLogic entityLogic)` (Line 377)
- Returns damage multiplier
- Hook and return 999999 for one-hit kills

**Properties:**
- `BossDamageBonus` (Line 617)
- `MinionDamageBonus` (Line 597)
- `CriticalHitDamageBonus` (Line 424)

---

## 🚀 RECOMMENDED IMPLEMENTATION (V26)

### Strategy: Runtime Property Invoke

**Approach:**
1. Use Il2CppResolver to find `set_GMNoDamage` method
2. Find `PlayerLogic` instance via `FindObjectOfType`
3. Call the setter every frame: `set_GMNoDamage(instance, true)`

**Why This Works:**
- ✅ Uses built-in game API
- ✅ No need to hook interpreter
- ✅ Works with HybridCLR
- ✅ Simple boolean property (no complex logic)

---

## 📋 NEXT STEPS (In Order)

### Phase 1: Verification (BEFORE building V26)
- [ ] Load Unity Explorer on device
- [ ] Find `PlayerLogic` instance in Explorer
- [ ] Manually set `GMNoDamage = true`
- [ ] Test if player becomes invincible
- [ ] Document results

### Phase 2: Implementation (IF Phase 1 succeeds)
- [ ] Write V26 tweak code (runtime property invoke)
- [ ] Use Il2CppResolver to find methods
- [ ] Implement god mode toggle
- [ ] Implement one-hit kill (optional)
- [ ] Test locally

### Phase 3: Build & Deploy
- [ ] Commit to git
- [ ] Push to GitHub (triggers build)
- [ ] Download .deb from Actions
- [ ] Sideload with Sideloadly
- [ ] Test on device

---

## 🛠️ CODE TEMPLATE (V26)

```cpp
// Find PlayerLogic class
Unity::il2cppClass* playerLogicClass = IL2CPP::Class::Find("WE.Battle.Logic.PlayerLogic");

// Find set_GMNoDamage method (property setter)
Unity::il2cppMethodInfo* setGMMethod = IL2CPP::Class::GetMethodFromName(
    playerLogicClass,
    "set_GMNoDamage",
    1  // 1 parameter (bool value)
);

// In update loop or timer:
void* playerInstance = Unity::Object::FindObjectOfType("WE.Battle.Logic.PlayerLogic");
if (playerInstance && setGMMethod && isGodModeEnabled) {
    bool trueValue = true;
    void* args[] = { &trueValue };
    IL2CPP::Method::Invoke(setGMMethod, playerInstance, args);
}
```

---

## 🎯 WHY THIS WILL WORK

### Previous Attempts (V1-V24):
❌ Hooked native methods that were actually interpreter stubs
❌ Methods resolved to same address (shared trampolines)
❌ Hooks installed but never triggered

### New Approach (V26):
✅ Use **existing game feature** (`GMNoDamage` property)
✅ Call via **runtime reflection** (bypasses interpreter issue)
✅ Direct property setter (simple boolean, no complex logic)
✅ Verified in source code (not guessing!)

---

## 📊 SUCCESS PROBABILITY

**God Mode:** 95% (built-in feature, just needs enabling)
**One-Hit Kill:** 85% (depends on FP type structure)

---

## 📁 FILES CREATED

- `ANALYSIS_RESULTS.md` - Full technical analysis
- `DECOMPILE_GUIDE.md` - dnSpy usage guide
- `SEARCH_TARGETS.md` - Search checklist
- `HOW_IT_WORKS.md` - Explanation of .bytes files
- `decompiled_output/PlayerLogic.cs` - Full decompiled source

---

## 🔍 VERIFICATION BEFORE BUILDING

**DO NOT BUILD V26 YET!**

First, verify god mode works by:
1. Inject Unity Explorer (you have `Explorer.dylib` in tools/)
2. Find `PlayerLogic` instance
3. Set `GMNoDamage = true` manually
4. Test in-game

If it works → Implement in tweak
If it doesn't → Investigate why

---

## 🎉 CONCLUSION

**The solution was hiding in plain sight!**

The developers left a **debug god mode property** in the code. We just need to flip it to `true`.

No complex hooking, no memory scanning, no assembly patching needed - just call a simple property setter!

**This is the cleanest, most reliable solution possible.** 🚀
