#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>
#import "Utils.h"

// ============================================================================
// TWEAK V13 - SANITY CHECK
// ============================================================================
// Goal: Verify hooks work by hooking Update loops.
// If this generates logs, the system works, and we just missed the damage method.
// If this DOES NOT generate logs, our entire hooking mechanism (Il2Cpp) is broken/offset.

static NSString *logFilePath = nil;
static NSFileHandle *logFileHandle = nil;
static int updateLogCount = 0; // Prevent spamming 100GB log

// ============================================================================
// LOGGING
// ============================================================================
void logToFile(NSString *message) {
    if (!logFileHandle) return;
    @synchronized(logFileHandle) {
        NSString *logLine = [NSString stringWithFormat:@"%@\n", message];
        [logFileHandle writeData:[logLine dataUsingEncoding:NSUTF8StringEncoding]];
        [logFileHandle synchronizeFile];
    }
}

void initLogFile() {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = [paths firstObject];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    logFilePath = [documentsDir stringByAppendingPathComponent:
                   [NSString stringWithFormat:@"acecraft_v13_%@.txt", timestamp]];
    
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    
    logToFile(@"=== ACECRAFT TRACER V13: SANITY CHECK ===");
}

// ============================================================================
// IL2CPP TYPES
// ============================================================================
typedef void* (*il2cpp_domain_get_t)(void);
typedef void* (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* size);
typedef void* (*il2cpp_assembly_get_image_t)(void* assembly);
typedef void* (*il2cpp_class_from_name_t)(void* image, const char* namespaze, const char* name);
typedef void* (*il2cpp_class_get_methods_t)(void* klass, void** iter);
typedef const char* (*il2cpp_method_get_name_t)(void* method);

static il2cpp_domain_get_t il2cpp_domain_get = NULL;
static il2cpp_domain_get_assemblies_t il2cpp_domain_get_assemblies = NULL;
static il2cpp_assembly_get_image_t il2cpp_assembly_get_image = NULL;
static il2cpp_class_from_name_t il2cpp_class_from_name = NULL;
static il2cpp_class_get_methods_t il2cpp_class_get_methods = NULL;
static il2cpp_method_get_name_t il2cpp_method_get_name = NULL;

void loadIl2Cpp() {
    void* h = dlopen(NULL, RTLD_NOW);
    if (!h) return;
    il2cpp_domain_get = (il2cpp_domain_get_t)dlsym(h, "il2cpp_domain_get");
    il2cpp_domain_get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(h, "il2cpp_domain_get_assemblies");
    il2cpp_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(h, "il2cpp_assembly_get_image");
    il2cpp_class_from_name = (il2cpp_class_from_name_t)dlsym(h, "il2cpp_class_from_name");
    il2cpp_class_get_methods = (il2cpp_class_get_methods_t)dlsym(h, "il2cpp_class_get_methods");
    il2cpp_method_get_name = (il2cpp_method_get_name_t)dlsym(h, "il2cpp_method_get_name");
}

void* findClass(const char* namespaze, const char* className) {
    if (!il2cpp_domain_get) return NULL;
    void* domain = il2cpp_domain_get();
    size_t size = 0;
    void** assemblies = il2cpp_domain_get_assemblies(domain, &size);
    
    for (size_t i = 0; i < size; i++) {
        void* image = il2cpp_assembly_get_image(assemblies[i]);
        if (!image) continue;
        void* klass = il2cpp_class_from_name(image, namespaze, className);
        if (klass) return klass;
    }
    return NULL;
}

// ============================================================================
// HOOKS
// ============================================================================

// 1. Controller Update (View) - Should fire every frame
static void (*orig_Controller_Update)(void* self);
void hook_Controller_Update(void* self) {
    if (updateLogCount < 50) {
        logToFile(@"[ALIVE] PlayerController.Update() is RUNNING");
        updateLogCount++;
    }
    if (orig_Controller_Update) orig_Controller_Update(self);
}

// 2. Logic Battle Update - Should fire every tick
static void (*orig_Logic_OnBattleUpdate)(void* self);
void hook_Logic_OnBattleUpdate(void* self) {
    if (updateLogCount < 100) { // Allow more for this one
        logToFile(@"[ALIVE] PlayerLogic.OnBattleUpdate() is RUNNING");
        updateLogCount++;
    }
    if (orig_Logic_OnBattleUpdate) orig_Logic_OnBattleUpdate(self);
}

// 3. Global Damage (WE.Game)
static void (*orig_DoingDamage)(void* self, void* data);
void hook_DoingDamage(void* self, void* data) {
    logToFile(@"[DMG] WE.Game.DoingDamage Called!");
    if (orig_DoingDamage) orig_DoingDamage(self, data);
}

// 4. BB.Player (Alternative Class)
static void (*orig_BB_SetHp)(void* self, int hp);
void hook_BB_SetHp(void* self, int hp) {
    logToFile([NSString stringWithFormat:@"[BB] Player.SetHp(%d)", hp]);
    if (orig_BB_SetHp) orig_BB_SetHp(self, hp);
}


// Helper to install hook by name (Partial match)
void hookMethodByName(void* klass, const char* methodName, void* hookFn, void** origPtr) {
    if (!klass || !il2cpp_class_get_methods) return;
    
    void* iter = NULL;
    void* method;
    while ((method = il2cpp_class_get_methods(klass, &iter)) != NULL) {
        const char* mName = il2cpp_method_get_name ? il2cpp_method_get_name(method) : "";
        
        if (strstr(mName, methodName)) {
            void* ptr = *(void**)method;
            if (ptr) {
                MSHookFunction(ptr, hookFn, origPtr);
                logToFile([NSString stringWithFormat:@"[HOOK] Installed %s @ %p", mName, ptr]);
                return;
            }
        }
    }
    logToFile([NSString stringWithFormat:@"[WARN] Method %s NOT FOUND", methodName]);
}

// ============================================================================
// SETUP
// ============================================================================
void setupHooks() {
    loadIl2Cpp();
    
    void* logicClass = findClass("WE.Battle.Logic", "PlayerLogic");
    void* viewClass = findClass("WE.Battle.View", "PlayerController");
    void* gameClass = findClass("WE.Game", "DoingDamage");
    void* bbClass = findClass("BB", "Player");
    
    if (viewClass) {
        hookMethodByName(viewClass, "Update", (void*)hook_Controller_Update, (void**)&orig_Controller_Update);
    }
    if (logicClass) {
        hookMethodByName(logicClass, "OnBattleUpdate", (void*)hook_Logic_OnBattleUpdate, (void**)&orig_Logic_OnBattleUpdate);
    }
    
    // Attempt global damage
    // Note: DoingDamage might be a class (Event) or a method in a class. V8 Log line 220 says "WE.Game.DoingDamage".
    // If it's a class (Event), we hook constructor.
    if (gameClass) {
         hookMethodByName(gameClass, "ctor", (void*)hook_DoingDamage, (void**)&orig_DoingDamage);
         // Also try ReceiveTriggerIn if it's a Logic node
         hookMethodByName(gameClass, "ReceiveTriggerIn", (void*)hook_DoingDamage, (void**)&orig_DoingDamage);
    }
    
    if (bbClass) {
        hookMethodByName(bbClass, "set_Hp", (void*)hook_BB_SetHp, (void**)&orig_BB_SetHp);
    }
}

%ctor {
    NSLog(@"[Acecraft] V13 Loading...");
    initLogFile();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupHooks();
    });
}
