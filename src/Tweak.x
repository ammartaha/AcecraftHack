#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>
#import "Utils.h"

// ============================================================================
// TWEAK V12 - BRUTE FORCE TRACER
// ============================================================================
// Strategy: Hook ANY method that looks kinda like it might be related to HP/Damage.
// If it logs, we got it.

static NSString *logFilePath = nil;
static NSFileHandle *logFileHandle = nil;
static UIButton *menuButton = nil;

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
                   [NSString stringWithFormat:@"acecraft_v12_%@.txt", timestamp]];
    
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    
    logToFile(@"=== ACECRAFT TRACER V12: BRUTE FORCE ===");
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
// BRUTE FORCE HOOKS
// ============================================================================
// We define individual hooks for each target to ensure we capture checking.
// Most Unity Update/Event logic uses (void* self) or (void* self, void* arg).

// --- PlayerLogic Hooks ---

static void (*orig_OnHPChange)(void* self);
void hook_OnHPChange(void* self) {
    logToFile(@"[TRACE] PlayerLogic.OnHPChange");
    if (orig_OnHPChange) orig_OnHPChange(self);
}

static void (*orig_UpdateHPAttribute)(void* self);
void hook_UpdateHPAttribute(void* self) {
    logToFile(@"[TRACE] PlayerLogic.UpdateHPAttribute");
    if (orig_UpdateHPAttribute) orig_UpdateHPAttribute(self);
}

static void (*orig_OnCollision)(void* self, void* collision);
void hook_OnCollision(void* self, void* collision) {
    logToFile(@"[TRACE] PlayerLogic.OnCollision");
    if (orig_OnCollision) orig_OnCollision(self, collision);
}

static void (*orig_OnAttacked)(void* self, void* info);
void hook_OnAttacked(void* self, void* info) {
    logToFile(@"[TRACE] PlayerLogic.OnAttacked");
    if (orig_OnAttacked) orig_OnAttacked(self, info);
}

static void (*orig_DoInvincible)(void* self, float time);
void hook_DoInvincible(void* self, float time) {
    logToFile([NSString stringWithFormat:@"[TRACE] PlayerLogic.DoInvincible(%.2f)", time]);
    if (orig_DoInvincible) orig_DoInvincible(self, time);
}

static void (*orig_OnDie)(void* self);
void hook_OnDie(void* self) {
    logToFile(@"[TRACE] PlayerLogic.OnDie");
    if (orig_OnDie) orig_OnDie(self);
}

static void (*orig_Dead)(void* self);
void hook_Dead(void* self) {
    logToFile(@"[TRACE] PlayerLogic.Dead");
    if (orig_Dead) orig_Dead(self);
}

static void (*orig_Heal)(void* self, void* amt);
void hook_Heal(void* self, void* amt) {
    logToFile(@"[TRACE] PlayerLogic.Heal");
    if (orig_Heal) orig_Heal(self, amt);
}

static void (*orig_AddHPShield)(void* self, void* amt);
void hook_AddHPShield(void* self, void* amt) {
    logToFile(@"[TRACE] PlayerLogic.AddHPShield");
    if (orig_AddHPShield) orig_AddHPShield(self, amt);
}

// --- PlayerController (View) Hooks ---

static void (*orig_OnCurHpChange)(void* self);
void hook_OnCurHpChange(void* self) {
    logToFile(@"[TRACE] PlayerController.OnCurHpChange (View Updated)");
    if (orig_OnCurHpChange) orig_OnCurHpChange(self);
}

// --- SetNoDamage Hooks ---

static void (*orig_ReceiveTriggerIn)(void* self, void* a, void* b);
void hook_ReceiveTriggerIn(void* self, void* a, void* b) {
    logToFile(@"[TRACE] SetNoDamage.ReceiveTriggerIn");
    if (orig_ReceiveTriggerIn) orig_ReceiveTriggerIn(self, a, b);
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
                logToFile([NSString stringWithFormat:@"[HOOK] Installed %s", mName]);
                return;
            }
        }
    }
    logToFile([NSString stringWithFormat:@"[WARN] Method %s NOT FOUND", methodName]);
}

// ============================================================================
// UI
// ============================================================================
@interface ModMenuController : NSObject
+ (void)showMenu;
@end

@implementation ModMenuController
+ (void)showMenu {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Acecraft Hack V12"
                                                                   message:@"Brute Force Tracer"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (rootVC) {
        [rootVC presentViewController:alert animated:YES completion:nil];
    }
}
@end

void setupMenuButton() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
        if (!mainWindow) return;
        
        menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
        menuButton.frame = CGRectMake(50, 50, 60, 60);
        menuButton.backgroundColor = [[UIColor purpleColor] colorWithAlphaComponent:0.8];
        menuButton.layer.cornerRadius = 30;
        [menuButton setTitle:@"V12" forState:UIControlStateNormal];
        
        [menuButton addTarget:[ModMenuController class] action:@selector(showMenu) forControlEvents:UIControlEventTouchUpInside];
        
        [mainWindow addSubview:menuButton];
        [mainWindow bringSubviewToFront:menuButton];
    });
}

// ============================================================================
// SETUP
// ============================================================================
void setupHooks() {
    loadIl2Cpp();
    
    void* logicClass = findClass("WE.Battle.Logic", "PlayerLogic");
    void* viewClass = findClass("WE.Battle.View", "PlayerController");
    void* godClass = findClass("WE.Game", "SetNoDamage");
    
    if (logicClass) {
        logToFile(@"[INFO] Hooking PlayerLogic...");
        hookMethodByName(logicClass, "OnHPChange", (void*)hook_OnHPChange, (void**)&orig_OnHPChange);
        hookMethodByName(logicClass, "UpdateHPAttribute", (void*)hook_UpdateHPAttribute, (void**)&orig_UpdateHPAttribute);
        hookMethodByName(logicClass, "OnCollision", (void*)hook_OnCollision, (void**)&orig_OnCollision);
        hookMethodByName(logicClass, "OnAttacked", (void*)hook_OnAttacked, (void**)&orig_OnAttacked);
        hookMethodByName(logicClass, "DoInvincible", (void*)hook_DoInvincible, (void**)&orig_DoInvincible);
        hookMethodByName(logicClass, "OnDie", (void*)hook_OnDie, (void**)&orig_OnDie);
        hookMethodByName(logicClass, "Dead", (void*)hook_Dead, (void**)&orig_Dead);
        hookMethodByName(logicClass, "Heal", (void*)hook_Heal, (void**)&orig_Heal);
        hookMethodByName(logicClass, "AddHPShield", (void*)hook_AddHPShield, (void**)&orig_AddHPShield);
    }
    
    if (viewClass) {
        logToFile(@"[INFO] Hooking PlayerController...");
        hookMethodByName(viewClass, "OnCurHpChange", (void*)hook_OnCurHpChange, (void**)&orig_OnCurHpChange);
    }
    
    if (godClass) {
        logToFile(@"[INFO] Hooking SetNoDamage...");
        hookMethodByName(godClass, "ReceiveTriggerIn", (void*)hook_ReceiveTriggerIn, (void**)&orig_ReceiveTriggerIn);
    }
}

%ctor {
    NSLog(@"[Acecraft] V12 Loading...");
    initLogFile();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupHooks();
        setupMenuButton();
    });
}
