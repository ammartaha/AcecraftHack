#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>
#import "Utils.h"

// ============================================================================
// TWEAK V19 - REFLECTION INTERCEPTOR (HYBRIDCLR KILLER)
// ============================================================================
// Problem: The Damage Logic is in a Hotfix Assembly (HybridCLR).
// Direct hooks fail because the address isn't native.
// Solution: Hook the LOOKUP system.
// When the game asks "Where is DoDamage?", we give it a pointer to NOTHING.

static NSString *logFilePath = nil;
static NSFileHandle *logFileHandle = nil;
static BOOL isDamagePatched = NO;

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
                   [NSString stringWithFormat:@"acecraft_v19_%@.txt", timestamp]];
    
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    
    logToFile(@"=== ACECRAFT TRACER V19: REFLECTION INTERCEPTOR ===");
}

// ============================================================================
// IL2CPP TYPES
// ============================================================================
typedef struct MethodInfo {
    void* methodPointer;
    void* invoker_method;
    const char* name;
    void* klass;
    void* return_type;
    void* parameters;
    void* some_other_stuff;
} MethodInfo;

typedef void* (*il2cpp_class_get_method_from_name_t)(void* klass, const char* name, int argsCount);
typedef const char* (*il2cpp_class_get_name_t)(void* klass);
typedef const char* (*il2cpp_class_get_namespace_t)(void* klass);

static il2cpp_class_get_method_from_name_t il2cpp_class_get_method_from_name = NULL;
static il2cpp_class_get_name_t il2cpp_class_get_name = NULL;
static il2cpp_class_get_namespace_t il2cpp_class_get_namespace = NULL;

void loadIl2Cpp() {
    void* h = dlopen(NULL, RTLD_NOW);
    if (!h) return;
    il2cpp_class_get_method_from_name = (il2cpp_class_get_method_from_name_t)dlsym(h, "il2cpp_class_get_method_from_name");
    il2cpp_class_get_name = (il2cpp_class_get_name_t)dlsym(h, "il2cpp_class_get_name");
    il2cpp_class_get_namespace = (il2cpp_class_get_namespace_t)dlsym(h, "il2cpp_class_get_namespace");
}

// ============================================================================
// THE FAKE METHOD
// ============================================================================
void Fake_DoDamage(void* self, void* damageInfo) {
    if (!isDamagePatched) {
         logToFile(@"[BLOCK] Damage intercepted and BLOCKED!");
         isDamagePatched = YES; // Log once to avoid spam
    }
}

// ============================================================================
// THE HOOK
// ============================================================================

static void* (*orig_il2cpp_class_get_method_from_name)(void* klass, const char* name, int argsCount);

void* hook_il2cpp_class_get_method_from_name(void* klass, const char* name, int argsCount) {
    // 1. Get the original result (The real method)
    void* result = orig_il2cpp_class_get_method_from_name(klass, name, argsCount);
    
    if (!result || !klass || !name) return result;
    
    // 2. Check if this is the target method
    // We are looking for "DoDamage" or "OnAttacked" inside "PlayerLogic"
    if (strcmp(name, "DoDamage") == 0 || strcmp(name, "OnAttacked") == 0 || strcmp(name, "DoingDamage") == 0) {
        
        const char* className = il2cpp_class_get_name(klass);
        
        if (className && strstr(className, "PlayerLogic")) {
            logToFile([NSString stringWithFormat:@"[INTERCEPT] Game asked for: %s.%s", className, name]);
            
            // 3. THE SWAP (DNS Spoofing)
            // We overwrite the function pointer in the MethodInfo struct!
            MethodInfo* method = (MethodInfo*)result;
            method->methodPointer = (void*)Fake_DoDamage;
            // method->invoker_method = (void*)Fake_DoDamage; // Optional, might crash if signature mismatch
            
            logToFile(@"[PATCH] Replaced with Fake_DoDamage!");
        }
    }
    
    return result;
}

// ============================================================================
// SETUP
// ============================================================================
void setupHooks() {
    loadIl2Cpp();
    
    if (il2cpp_class_get_method_from_name) {
        logToFile(@"[INFO] Hooking il2cpp_class_get_method_from_name...");
        MSHookFunction((void*)il2cpp_class_get_method_from_name, (void*)hook_il2cpp_class_get_method_from_name, (void**)&orig_il2cpp_class_get_method_from_name);
    } else {
        logToFile(@"[ERR] Could not find il2cpp_class_get_method_from_name!");
    }
}

%ctor {
    NSLog(@"[Acecraft] V19 Loading...");
    initLogFile();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupHooks();
    });
}
