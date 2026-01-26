# Acecraft Hacking: The Master Guide 📘

**Target:** Acecraft: Sky Hero
**Platform:** iOS (Non-Jailbroken/Jailed)
**Technique:** Il2Cpp Native Hooking & DLL Injection

---

## 1. Game Architecture & Findings 🕵️‍♂️

### The Engine

* **Unity + Il2Cpp:** The game is built with Unity. The C# code is compiled into C++ native code (`GameAssembly.dylib` or `UnityFramework`).
* **Implication:** We cannot use simple C# reflection. We must use **Memory Offsets** or **Runtime Symbol Resolution** (dlsym) to find functions.

### Key Discoveries

Through our 15 versions of investigation, we mapped the game's internal structure:

1. **`WE.Battle.Logic.PlayerLogic`**:
    * This class contains the *math* for Health, Damage, and God Mode (`GMNoDamage`).
    * **Problem:** It has "No Instance" at runtime. It is likely a pure data object held by another class.
2. **`WE.Battle.View.PlayerController`**:
    * This class handles the *visuals* and input.
    * **Status:** **ALIVE**. It has an active instance in memory.
    * **The Trick:** It holds a reference to `PlayerLogic` via the method `get_PlayerModel()`.
3. **`WE.Game.SetNoDamage`**:
    * A built-in developer debug class intended for God Mode.

---

## 2. Tools & Workflow 🛠️

### 1. The Environment (VS Code)

We perform all editing in `e:/tweak`.

* **`src/Tweak.x`**: The main source code. Uses **Logos** syntax (`%hook`, `%ctor`) mixed with C++ (`MSHookFunction`).
* **`MakeFile`**: Instructions for the compiler.
* **`Utils.h`**: A helper file we wrote to interact with Unity's Il2Cpp engine (finding classes/methods by name).

### 2. Version Control (Git)

We use Git to save changes and send them to the cloud.

**How to Push Changes (The Command List):**
Every time you want to save your work or trigger a new build:

```powershell
# 1. Stage all changed files
git add .

# 2. Save the snapshot (Replace "..." with your message)
git commit -m "Updated Tweak to V16"

# 3. Send to GitHub
git push origin main
```

### 3. The Build System (GitHub Actions)

* **What it is:** A cloud server that compiles our code.
* **Why:** You are on Windows, but compiling iOS tweaks requires macOS (Xcode). GitHub provides a free macOS runner.
* **Trigger:** Happens automatically when you run `git push`.
* **Output:** A `.deb` file (Debian Package) containing the hack.

---

## 3. Deployment (Sideloading) 📲

Since you are on a **Non-Jailbroken** device, you cannot simply install the `.deb`. You must **Inject** it into the game IPA.

### The Tool: Sideloadly

Sideloadly is a PC tool that signs apps with your Apple ID so they run on non-jailbroken phones.

### The Injection Process

1. **Download Artifact:** Get the latest `.deb` file from the GitHub Actions run.
2. **Open Sideloadly.**
3. **IPA Slot:** Drag the *Decrypted* Acecraft `.ipa` file into Sideloadly.
4. **Advanced Options:**
    * Click "Advanced Options".
    * Check **"Inject dylibs/frameworks"**.
    * Click `+dylib/deb` and select our `com.acecrafthack...deb` file.
    * (Optional) Check "Cydia Substrate" if available/needed.
5. **Start:** Click Start. Sideloadly unpacks the game, puts our hack inside the `Frameworks` folder, re-signs it, and installs it to your phone.

---

## 4. Current Strategy (Deep Hooking) 🧠

Our current best approach (V15) is **Deep Hooking**:

1. We hook `PlayerController` (because we know it exists).
2. Inside its `Update()` loop, we call `get_PlayerModel()` to steal the pointer to the hidden `PlayerLogic`.
3. We use that pointer to manually force `GMNoDamage = true` directly in memory.

This bypasses the need to find the `PlayerLogic` instance ourselves—we let the game find it for us.
