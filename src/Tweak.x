#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CydiaSubstrate/CydiaSubstrate.h>
#import "Utils.h"

// ============================================================================
// TWEAK V16 - LOGIC UPDATE HOOK (HYBRIDCLR SAFE RETRY)
// ============================================================================
// Previous bug: PlayerController.get_PlayerModel() returns PlayerModel, NOT PlayerLogic.
// Fix: Hook PlayerLogic.OnBattleUpdate and set GMNoDamage on the real logic instance.
// HybridCLR hotfix assemblies load late, so we retry until classes/methods resolve.

static NSString *logFilePath = nil;
static NSFileHandle *logFileHandle = nil;
static NSString *toggleFilePath = nil;
static BOOL isGodModeApplied = NO;
static BOOL hooksInstalled = NO;
static BOOL gGodModeEnabled = YES;
static int setupAttempts = 0;
static CFAbsoluteTime lastToggleCheck = 0;
static CFAbsoluteTime lastHookLog = 0;
static CFAbsoluteTime lastHpBoost = 0;

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
                   [NSString stringWithFormat:@"acecraft_v16_%@.txt", timestamp]];
    toggleFilePath = [documentsDir stringByAppendingPathComponent:@"acecraft_toggle.txt"];
    
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    
    // Create toggle file if missing (default enabled)
    if (![[NSFileManager defaultManager] fileExistsAtPath:toggleFilePath]) {
        [@"1" writeToFile:toggleFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    
    logToFile(@"=== ACECRAFT TRACER V16: LOGIC UPDATE HOOK ===");
    logToFile([NSString stringWithFormat:@"[INFO] Toggle file: %@", toggleFilePath]);
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
typedef void* (*il2cpp_class_get_method_from_name_t)(void* klass, const char* name, int argsCount);
typedef void* (*il2cpp_method_get_pointer_t)(void* method);

static il2cpp_domain_get_t il2cpp_domain_get = NULL;
static il2cpp_domain_get_assemblies_t il2cpp_domain_get_assemblies = NULL;
static il2cpp_assembly_get_image_t il2cpp_assembly_get_image = NULL;
static il2cpp_class_from_name_t il2cpp_class_from_name = NULL;
static il2cpp_class_get_methods_t il2cpp_class_get_methods = NULL;
static il2cpp_method_get_name_t il2cpp_method_get_name = NULL;
static il2cpp_class_get_method_from_name_t il2cpp_class_get_method_from_name = NULL;
static il2cpp_method_get_pointer_t il2cpp_method_get_pointer = NULL;

// Minimal MethodInfo definition for methodPointer access
typedef struct MethodInfo {
    void* methodPointer;
    void* virtualMethodPointer;
    void* invoker_method;
    const char* name;
    void* klass;
    const void* return_type;
    const void* parameters;
    void* rgctx_data;
    void* genericMethod;
    uint32_t token;
    uint16_t flags;
    uint16_t iflags;
    uint16_t slot;
    uint8_t parameters_count;
    uint8_t bitflags;
} MethodInfo;

void loadIl2Cpp() {
    void* h = dlopen(NULL, RTLD_NOW);
    if (!h) return;
    il2cpp_domain_get = (il2cpp_domain_get_t)dlsym(h, "il2cpp_domain_get");
    il2cpp_domain_get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(h, "il2cpp_domain_get_assemblies");
    il2cpp_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(h, "il2cpp_assembly_get_image");
    il2cpp_class_from_name = (il2cpp_class_from_name_t)dlsym(h, "il2cpp_class_from_name");
    il2cpp_class_get_methods = (il2cpp_class_get_methods_t)dlsym(h, "il2cpp_class_get_methods");
    il2cpp_method_get_name = (il2cpp_method_get_name_t)dlsym(h, "il2cpp_method_get_name");
    il2cpp_class_get_method_from_name = (il2cpp_class_get_method_from_name_t)dlsym(h, "il2cpp_class_get_method_from_name");
    il2cpp_method_get_pointer = (il2cpp_method_get_pointer_t)dlsym(h, "il2cpp_method_get_pointer");
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

MethodInfo* findMethodInfo(void* klass, const char* methodName) {
    if (!klass) return NULL;
    if (il2cpp_class_get_method_from_name) {
        return (MethodInfo*)il2cpp_class_get_method_from_name(klass, methodName, -1);
    }
    if (!il2cpp_class_get_methods) return NULL;
    void* iter = NULL;
    void* method;
    while ((method = il2cpp_class_get_methods(klass, &iter)) != NULL) {
        const char* mName = il2cpp_method_get_name ? il2cpp_method_get_name(method) : "";
        if (strcmp(mName, methodName) == 0) {
            return (MethodInfo*)method;
        }
    }
    return NULL;
}

void* getMethodPointer(MethodInfo* method) {
    if (!method) return NULL;
    if (method->methodPointer) return method->methodPointer;
    if (il2cpp_method_get_pointer) return il2cpp_method_get_pointer(method);
    if (method->virtualMethodPointer) return method->virtualMethodPointer;
    return NULL;
}

// ============================================================================
// METHOD POINTERS (WE WILL CALL THESE)
// ============================================================================

// PlayerLogic.set_GMNoDamage(bool)
static void (*SetGMNoDamage)(void* logic, bool enable);

// PlayerLogic.DoInvincible(float)
static void (*DoInvincible)(void* logic, float duration);

// PlayerLogic.SetPlayerHpToMax()
static void (*SetPlayerHpToMax)(void* logic);

// ============================================================================
// HOOKS
// ============================================================================

static BOOL readToggleValue() {
    if (!toggleFilePath) return YES;
    NSError *err = nil;
    NSString *contents = [NSString stringWithContentsOfFile:toggleFilePath encoding:NSUTF8StringEncoding error:&err];
    if (!contents || err) return YES; // default to enabled if unreadable
    NSString *trim = [[contents stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if ([trim isEqualToString:@"0"] || [trim isEqualToString:@"off"] || [trim isEqualToString:@"false"]) return NO;
    return YES;
}

static void refreshToggle() {
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (now - lastToggleCheck < 2.0) return;
    lastToggleCheck = now;
    BOOL newVal = readToggleValue();
    if (newVal != gGodModeEnabled) {
        gGodModeEnabled = newVal;
        logToFile([NSString stringWithFormat:@"[TOGGLE] GodMode %s", gGodModeEnabled ? "ENABLED" : "DISABLED"]);
        if (!gGodModeEnabled) isGodModeApplied = NO;
    }
}

// Hook PlayerLogic.OnBattleUpdate (no params)
static void (*orig_PlayerLogic_OnBattleUpdate)(void* self);
void hook_PlayerLogic_OnBattleUpdate(void* self) {
    refreshToggle();
    
    if (self && gGodModeEnabled) {
        if (SetGMNoDamage) {
            SetGMNoDamage(self, true);
            if (!isGodModeApplied) {
                logToFile(@"[GOD] Applied GMNoDamage=TRUE via PlayerLogic!");
                isGodModeApplied = YES;
            }
        }
        
        // Optional safety: top off HP periodically
        if (SetPlayerHpToMax) {
            CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
            if (now - lastHpBoost > 1.0) {
                SetPlayerHpToMax(self);
                lastHpBoost = now;
            }
        }
    }
    
    // Throttled heartbeat to confirm hook is running
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (now - lastHookLog > 10.0) {
        logToFile(@"[HOOK] PlayerLogic.OnBattleUpdate tick");
        lastHookLog = now;
    }
    
    if (orig_PlayerLogic_OnBattleUpdate) orig_PlayerLogic_OnBattleUpdate(self);
}

// ============================================================================
// SETUP
// ============================================================================
bool setupHooksOnce() {
    loadIl2Cpp();
    
    void* logicClass = findClass("WE.Battle.Logic", "PlayerLogic");
    
    if (!logicClass) {
        logToFile(@"[WAIT] PlayerLogic class not found (HybridCLR not ready yet)");
        return false;
    }

    // Get Method Pointers (So we can call them)
    MethodInfo* miSetGM = findMethodInfo(logicClass, "set_GMNoDamage");
    MethodInfo* miInv = findMethodInfo(logicClass, "DoInvincible");
    MethodInfo* miHpMax = findMethodInfo(logicClass, "SetPlayerHpToMax");
    MethodInfo* miUpdate = findMethodInfo(logicClass, "OnBattleUpdate");

    SetGMNoDamage = (void (*)(void*, bool))getMethodPointer(miSetGM);
    DoInvincible = (void (*)(void*, float))getMethodPointer(miInv);
    SetPlayerHpToMax = (void (*)(void*))getMethodPointer(miHpMax);
    void* updateMethod = getMethodPointer(miUpdate);

    logToFile([NSString stringWithFormat:@"[INIT] set_GMNoDamage: %p", SetGMNoDamage]);
    logToFile([NSString stringWithFormat:@"[INIT] SetPlayerHpToMax: %p", SetPlayerHpToMax]);
    logToFile([NSString stringWithFormat:@"[INIT] OnBattleUpdate: %p", updateMethod]);

    if (!SetGMNoDamage || !updateMethod) {
        logToFile(@"[WAIT] Method pointers not ready (may be interpreted); retrying...");
        return false;
    }

    MSHookFunction(updateMethod, (void*)hook_PlayerLogic_OnBattleUpdate, (void**)&orig_PlayerLogic_OnBattleUpdate);
    logToFile(@"[HOOK] Installed PlayerLogic.OnBattleUpdate");
    return true;
}

void scheduleSetupRetry() {
    if (hooksInstalled) return;
    setupAttempts++;
    if (setupAttempts > 60) {
        logToFile(@"[ERR] Setup retries exceeded. Hooks not installed.");
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!hooksInstalled) {
            if (setupHooksOnce()) {
                hooksInstalled = YES;
            } else {
                scheduleSetupRetry();
            }
        }
    });
}

%ctor {
    NSLog(@"[Acecraft] V16 Loading...");
    initLogFile();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        scheduleSetupRetry();
    });
}
