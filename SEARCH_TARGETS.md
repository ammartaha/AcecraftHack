# Damage Pipeline Search Targets

Use this checklist when analyzing `PlayerLogic` in dnSpy.

---

## Priority 1: HP Manipulation Methods

Search for these method names (Ctrl+F in dnSpy):

- [ ] `DoDamage`
- [ ] `ApplyDamage`
- [ ] `TakeDamage`
- [ ] `ReduceHP`
- [ ] `set_CurHP` (property setter)
- [ ] `set_HP`
- [ ] `UpdateHP`
- [ ] `ChangeHP`

**What to note:**
- Does it check `GMNoDamage` or `isInvincible` before applying damage?
- What is the exact line that subtracts HP? (e.g., `this.curHP -= damage;`)

---

## Priority 2: Invincibility/God Mode Methods

- [ ] `get_GMNoDamage` (property getter)
- [ ] `set_GMNoDamage` (property setter)
- [ ] `DoInvincible`
- [ ] `SetInvincible`
- [ ] `CanTakeDamage`
- [ ] `IsInvincible`

**What to note:**
- Is `GMNoDamage` a bool field?
- Where is it checked in the damage pipeline?

---

## Priority 3: Event Handlers

- [ ] `OnAttacked`
- [ ] `OnHit`
- [ ] `OnHPChange`
- [ ] `OnDamaged`
- [ ] `OnCollision`
- [ ] `OnTriggerEnter`

**What to note:**
- Which of these actually applies damage vs. just notifies?
- Are they called every hit?

---

## Priority 4: Update Methods

- [ ] `Update`
- [ ] `FixedUpdate`
- [ ] `OnBattleUpdate`
- [ ] `UpdateHPAttribute`

**What to note:**
- Does `Update()` check god mode status?
- Is there a frame-by-frame god mode check?

---

## What Success Looks Like

You should find something like this:

```csharp
// Example 1: Simple damage method
public void DoDamage(float damage)
{
    if (this.GMNoDamage) // ← BINGO! This is the god mode check
    {
        return; // Skip damage if god mode is on
    }
    this.curHP -= damage; // ← This is where HP is actually reduced
    if (this.curHP <= 0f)
    {
        this.OnDie();
    }
}

// Example 2: Property that controls god mode
public bool GMNoDamage
{
    get { return this._GMNoDamage; }
    set { this._GMNoDamage = value; } // ← We need to set this to TRUE
}
```

---

## After Finding the Code

Document in `CURRENT_STAGE.md`:

1. **Method signature**: `public void DoDamage(float damage)`
2. **God mode field**: `private bool _GMNoDamage;` or similar
3. **Key finding**: "Damage is skipped if `GMNoDamage == true`"
4. **Line numbers**: Where the checks occur

Then we can choose the best attack:
- **If god mode check exists**: Force `GMNoDamage = true` via memory write or hook
- **If no god mode check**: Hook `DoDamage` and force early return
- **If HP is a property**: Hook `set_CurHP` and clamp it to max

---

## Bonus: Search for String Literals

In dnSpy, use **Edit → Search Assemblies** (Ctrl+Shift+K) and search for:

- `"god mode"`
- `"invincible"`
- `"no damage"`
- `"cheat"`
- `"debug"`

These might reveal hidden debug commands or developer menus.
