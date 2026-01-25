#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>
#import "Utils.h"

// ============================================================================
// TWEAK V11 - PLAYER LOGIC GOD MODE
// ============================================================================
// Target: WE.Battle.Logic.PlayerLogic
// Hooks: 
// - OnAttacked() -> Block it
// - get_GMNoDamage() -> Force True
// - DoInvincible() -> Log it

static NSString *logFilePath = nil;
static NSFileHandle *logFileHandle = nil;
static BOOL isGodMode = NO;
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
                   [NSString stringWithFormat:@"acecraft_v11_%@.txt", timestamp]];
    
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    
    logToFile(@"=== ACECRAFT TRACER V11: PLAYER LOGIC HOOKS ===");
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

// Hook 1: WE.Battle.Logic.PlayerLogic.OnAttacked
// This is likely the main entry point for damage
static void (*orig_OnAttacked)(void* self, void* damageInfo);
void hook_OnAttacked(void* self, void* damageInfo) {
    if (isGodMode) {
        logToFile(@"[GOD] OnAttacked BLOCKED!");
        return; // Complete immunity
    }
    logToFile(@"[DMG] OnAttacked called (GodMode OFF)");
    if (orig_OnAttacked) orig_OnAttacked(self, damageInfo);
}

// Hook 2: WE.Battle.Logic.PlayerLogic.get_GMNoDamage
// Built-in Developer God Mode switch?
static bool (*orig_get_GMNoDamage)(void* self);
bool hook_get_GMNoDamage(void* self) {
    if (isGodMode) {
        // logToFile(@"[GOD] get_GMNoDamage -> Returning TRUE"); // Comment out spam
        return true;
    }
    return orig_get_GMNoDamage ? orig_get_GMNoDamage(self) : false;
}

// Hook 3: WE.Battle.Logic.PlayerLogic.DoInvincible
// Trigger invincibility state
static void (*orig_DoInvincible)(void* self, float duration);
void hook_DoInvincible(void* self, float duration) {
    logToFile([NSString stringWithFormat:@"[LOGIC] DoInvincible(%.2f)", duration]);
    if (orig_DoInvincible) orig_DoInvincible(self, duration);
}

// Helper to install hook by name (Exact match)
void hookMethodByName(void* klass, const char* methodName, void* hookFn, void** origPtr) {
    if (!klass || !il2cpp_class_get_methods) return;
    
    void* iter = NULL;
    void* method;
    while ((method = il2cpp_class_get_methods(klass, &iter)) != NULL) {
        const char* mName = il2cpp_method_get_name ? il2cpp_method_get_name(method) : "";
        
        if (strcmp(mName, methodName) == 0) {
            void* ptr = *(void**)method;
            if (ptr) {
                MSHookFunction(ptr, hookFn, origPtr);
                logToFile([NSString stringWithFormat:@"[HOOK] Installed %s at %p", mName, ptr]);
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Acecraft Hack V11"
                                                                   message:@"PlayerLogic Hooks"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSString *godModeTitle = isGodMode ? @"God Mode: ON ✅" : @"God Mode: OFF ❌";
    [alert addAction:[UIAlertAction actionWithTitle:godModeTitle
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * action) {
        isGodMode = !isGodMode;
        logToFile([NSString stringWithFormat:@"[UI] God Mode toggled: %d", isGodMode]);
        [self showMenu];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    
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
        menuButton.frame = CGRectMake(50, 100, 50, 50);
        menuButton.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.8]; // Red for Final!
        menuButton.layer.cornerRadius = 25;
        [menuButton setTitle:@"V11" forState:UIControlStateNormal];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:menuButton action:@selector(handlePan:)];
        [menuButton addGestureRecognizer:pan];
        [menuButton addTarget:[ModMenuController class] action:@selector(showMenu) forControlEvents:UIControlEventTouchUpInside];
        
        [mainWindow addSubview:menuButton];
        [mainWindow bringSubviewToFront:menuButton];
    });
}
@interface UIButton (Draggable)
@end
@implementation UIButton (Draggable)
- (void)handlePan:(UIPanGestureRecognizer *)sender {
    CGPoint translation = [sender translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [sender setTranslation:CGPointZero inView:self.superview];
}
@end

// ============================================================================
// SETUP
// ============================================================================
void setupHooks() {
    loadIl2Cpp();
    
    // Validated Class Name from V10 Log
    void* playerLogic = findClass("WE.Battle.Logic", "PlayerLogic");
    
    if (playerLogic) {
        logToFile(@"[INFO] Found PlayerLogic class!");
        hookMethodByName(playerLogic, "OnAttacked", (void*)hook_OnAttacked, (void**)&orig_OnAttacked);
        hookMethodByName(playerLogic, "get_GMNoDamage", (void*)hook_get_GMNoDamage, (void**)&orig_get_GMNoDamage);
        hookMethodByName(playerLogic, "DoInvincible", (void*)hook_DoInvincible, (void**)&orig_DoInvincible);
    } else {
        logToFile(@"[ERR] PlayerLogic class NOT FOUND!");
    }
}

%ctor {
    NSLog(@"[Acecraft] V11 Loading...");
    initLogFile();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupHooks();
        setupMenuButton();
    });
}
