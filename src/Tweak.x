#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>
#import "Utils.h"

// ============================================================================
// TWEAK V15 - DEEP HOOKING (CONTROLLER -> LOGIC)
// ============================================================================
// The PlayerController has an instance.
// The PlayerLogic does NOT (static/singleton issue or pure object).
// Solution: Use PlayerController to GET PlayerLogic, then abuse it.

static NSString *logFilePath = nil;
static NSFileHandle *logFileHandle = nil;
static BOOL isGodModeApplied = NO;

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
                   [NSString stringWithFormat:@"acecraft_v15_%@.txt", timestamp]];
    
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    
    logToFile(@"=== ACECRAFT TRACER V15: CONTROLLER PROXY ===");
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

void* findMethod(void* klass, const char* methodName) {
    if (!klass || !il2cpp_class_get_methods) return NULL;
    void* iter = NULL;
    void* method;
    while ((method = il2cpp_class_get_methods(klass, &iter)) != NULL) {
        const char* mName = il2cpp_method_get_name ? il2cpp_method_get_name(method) : "";
        if (strcmp(mName, methodName) == 0) {
            return *(void**)method;
        }
    }
    return NULL;
}

// ============================================================================
// METHOD POINTERS (WE WILL CALL THESE)
// ============================================================================

// PlayerController.get_PlayerModel() -> Returns PlayerLogic*
static void* (*GetPlayerModel)(void* controller);

// PlayerLogic.set_GMNoDamage(bool)
static void (*SetGMNoDamage)(void* logic, bool enable);

// PlayerLogic.DoInvincible(float)
static void (*DoInvincible)(void* logic, float duration);

// ============================================================================
// HOOKS
// ============================================================================

// Hook PlayerController.Update
// We use this to repeatedly apply God Mode to the underlying logic object
static void (*orig_Controller_Update)(void* self);
void hook_Controller_Update(void* self) {
    
    if (self && GetPlayerModel) {
        void* logicObj = GetPlayerModel(self);
        
        if (logicObj) {
            // Found the hidden logic object!
            
            // 1. Force GMNoDamage
            if (SetGMNoDamage) {
                SetGMNoDamage(logicObj, true);
                if (!isGodModeApplied) {
                    logToFile(@"[GOD] Applied GMNoDamage=TRUE via Controller!");
                    isGodModeApplied = YES;
                }
            }
            
            // 2. Force Invincibility (Backup)
            if (DoInvincible) {
                // Apply 60 seconds of invincibility every frame (overkill but safe)
                // DoInvincible(logicObj, 60.0f);
            }
            
        } else {
             if (isGodModeApplied) logToFile(@"[WARN] Controller.get_PlayerModel() returned NULL!");
        }
    }
    
    // Call original update
    if (orig_Controller_Update) orig_Controller_Update(self);
}

// ============================================================================
// SETUP
// ============================================================================
void setupHooks() {
    loadIl2Cpp();
    
    void* controllerClass = findClass("WE.Battle.View", "PlayerController");
    void* logicClass = findClass("WE.Battle.Logic", "PlayerLogic");
    
    if (controllerClass && logicClass) {
        
        // 1. Get Method Pointers (So we can call them)
        GetPlayerModel = (void* (*)(void*))findMethod(controllerClass, "get_PlayerModel");
        SetGMNoDamage = (void (*)(void*, bool))findMethod(logicClass, "set_GMNoDamage");
        DoInvincible = (void (*)(void*, float))findMethod(logicClass, "DoInvincible");
        
        logToFile([NSString stringWithFormat:@"[INIT] GetPlayerModel: %p", GetPlayerModel]);
        logToFile([NSString stringWithFormat:@"[INIT] SetGMNoDamage: %p", SetGMNoDamage]);
        
        // 2. Install Hook on Update
        void* updateMethod = findMethod(controllerClass, "Update");
        if (updateMethod) {
             MSHookFunction(updateMethod, (void*)hook_Controller_Update, (void**)&orig_Controller_Update);
             logToFile(@"[HOOK] Installed PlayerController.Update");
        }
        
    } else {
        logToFile(@"[ERR] Classes NOT FOUND!");
    }
}

%ctor {
    NSLog(@"[Acecraft] V15 Loading...");
    initLogFile();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupHooks();
    });
}
