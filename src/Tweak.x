#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>
#import "Utils.h"

// ============================================================================
// TWEAK V9 - TARGETED LUA LOGIC HOOKS
// ============================================================================
// Based on V8 Dump:
// WE.Game.SetNoDamage (Ideal God Mode?)
// WE.Battle.Logic.PlayerHurtEvent
// WE.Game.PlayerLockHp

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
                   [NSString stringWithFormat:@"acecraft_v9_%@.txt", timestamp]];
    
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    
    logToFile(@"=== ACECRAFT TRACER V9: LOGIC HOOKS ===");
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

// Hook 1: WE.Game.SetNoDamage  <- This sounds like the winner!
static void (*orig_SetNoDamage)(void* self, bool enable);
void hook_SetNoDamage(void* self, bool enable) {
    logToFile([NSString stringWithFormat:@"[GOD] SetNoDamage called! Arg: %d", enable]);
    // Force enable if God Mode is on
    if (isGodMode) {
        logToFile(@"[GOD] Forcing SetNoDamage(true)");
        if (orig_SetNoDamage) orig_SetNoDamage(self, true);
        return;
    }
    if (orig_SetNoDamage) orig_SetNoDamage(self, enable);
}

// Hook 2: WE.Game.PlayerLockHp <- Another strong candidate
static void (*orig_PlayerLockHp)(void* self, void* data);
void hook_PlayerLockHp(void* self, void* data) {
    logToFile(@"[GOD] PlayerLockHp called!");
    if (orig_PlayerLockHp) orig_PlayerLockHp(self, data);
}

// Hook 3: WE.Battle.Logic.PlayerHurtEvent <- The likely damage trigger
static void (*orig_PlayerHurtEvent)(void* self, void* data);
void hook_PlayerHurtEvent(void* self, void* data) {
    logToFile(@"[DAMAGE] PlayerHurtEvent Fired!");
    if (isGodMode) {
        logToFile(@"[DAMAGE] Blocked PlayerHurtEvent!");
        return; // BLOCK IT
    }
    if (orig_PlayerHurtEvent) orig_PlayerHurtEvent(self, data);
}


// Helper to install hook by name (Partial match for safety)
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Acecraft Hack V9"
                                                                   message:@"Targeted Logic Hooks"
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
        menuButton.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.8]; // Green for Success!
        menuButton.layer.cornerRadius = 25;
        [menuButton setTitle:@"V9" forState:UIControlStateNormal];
        
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
    
    // Class names from V8 Log
    void* gameSetNoDamage = findClass("WE.Game", "SetNoDamage");
    void* playerHurtEvent = findClass("WE.Battle.Logic", "PlayerHurtEvent");
    void* playerLockHp = findClass("WE.Game", "PlayerLockHp");
    
    if (gameSetNoDamage) hookMethodByName(gameSetNoDamage, "ctor", (void*)hook_SetNoDamage, (void**)&orig_SetNoDamage); // Usually constructors or 'Invoke' call these events
    // NOTE: These are likely Event classes. We need to hook their CONSTRUCTOR or INVOKE method.
    // The V8 log showed these as classes. Let's try hooking .ctor to see if they get instantiated on damage.
    
    if (playerHurtEvent) hookMethodByName(playerHurtEvent, "ctor", (void*)hook_PlayerHurtEvent, (void**)&orig_PlayerHurtEvent);
    if (playerLockHp) hookMethodByName(playerLockHp, "ctor", (void*)hook_PlayerLockHp, (void**)&orig_PlayerLockHp);
}

%ctor {
    NSLog(@"[Acecraft] V9 Loading...");
    initLogFile();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupHooks();
        setupMenuButton();
    });
}
