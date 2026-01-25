#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>
#import "Utils.h"

// ============================================================================
// TWEAK V7 - COMBINED MOD MENU + OMNI TRACER
// ============================================================================

static NSString *logFilePath = nil;
static NSFileHandle *logFileHandle = nil;
static BOOL isGodMode = NO;
static UIButton *menuButton = nil;
static UIWindow *mainWindow = nil;

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
                   [NSString stringWithFormat:@"acecraft_v7_%@.txt", timestamp]];
    
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    
    logToFile(@"=== ACECRAFT TRACER V7: OMNI LOGGER ===");
    logToFile(@"Monitoring: Player.Hit, Bullet.SetHp, Lua.Broadcast, Physics.Collision");
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

// 1. Player.Hit (Original Candidate)
static void (*orig_Player_Hit)(void* self);
void hook_Player_Hit(void* self) {
    logToFile([NSString stringWithFormat:@"[PLAYER] Hit called! GodMode: %d", isGodMode]);
    if (isGodMode) return;
    if (orig_Player_Hit) orig_Player_Hit(self);
}

// 2. Lua Event Broadcast (Likely Candidate)
static void (*orig_Broadcast)(void* self, int eventId);
void hook_Broadcast(void* self, int eventId) {
    // Filter out common spam events if needed, but for now log all
    logToFile([NSString stringWithFormat:@"[LUA] Broadcast ID: %d", eventId]);
    if (orig_Broadcast) orig_Broadcast(self, eventId);
}

// 3. Bullet SetHp (Enemy Damage)
static void (*orig_Bullet_SetHp)(void* self, struct FP hp);
void hook_Bullet_SetHp(void* self, struct FP hp) {
    float val = FPToFloat(hp);
    logToFile([NSString stringWithFormat:@"[BULLET] SetHp: %.2f", val]);
    if (orig_Bullet_SetHp) orig_Bullet_SetHp(self, hp);
}

// 4. Physics Collision (FSBodyComponent)
static void (*orig_OnCollisionEnter)(void* self, void* collision);
void hook_OnCollisionEnter(void* self, void* collision) {
    logToFile(@"[PHYSICS] OnCollisionEnter");
    if (orig_OnCollisionEnter) orig_OnCollisionEnter(self, collision);
}


// Helper to install hook by name
void hookMethodByName(void* klass, const char* methodName, void* hookFn, void** origPtr) {
    if (!klass || !il2cpp_class_get_methods) return;
    
    void* iter = NULL;
    void* method;
    while ((method = il2cpp_class_get_methods(klass, &iter)) != NULL) {
        const char* mName = il2cpp_method_get_name ? il2cpp_method_get_name(method) : "";
        
        // Exact match
        if (strcmp(mName, methodName) == 0) {
            void* ptr = *(void**)method;
            if (ptr) {
                MSHookFunction(ptr, hookFn, origPtr);
                logToFile([NSString stringWithFormat:@"[HOOK] Installed %s at %p", methodName, ptr]);
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Acecraft Hack V7"
                                                                   message:@"Mod Menu + Omni Tracer"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    // Toggle God Mode
    NSString *godModeTitle = isGodMode ? @"God Mode: ON ✅" : @"God Mode: OFF ❌";
    UIAlertAction *godModeAction = [UIAlertAction actionWithTitle:godModeTitle
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
        isGodMode = !isGodMode;
        logToFile([NSString stringWithFormat:@"[UI] God Mode toggled: %d", isGodMode]);
        [self showMenu]; 
    }];
    [alert addAction:godModeAction];
    
    // Close
    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    
    // Show
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (rootVC) {
        [rootVC presentViewController:alert animated:YES completion:nil];
    }
}

@end

void setupMenuButton() {
    dispatch_async(dispatch_get_main_queue(), ^{
        mainWindow = [UIApplication sharedApplication].keyWindow;
        if (!mainWindow) return;
        
        menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
        menuButton.frame = CGRectMake(50, 50, 50, 50);
        menuButton.backgroundColor = [[UIColor orangeColor] colorWithAlphaComponent:0.8]; // Orange for V7
        menuButton.layer.cornerRadius = 25;
        menuButton.clipsToBounds = YES;
        [menuButton setTitle:@"V7" forState:UIControlStateNormal];
        menuButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [menuButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:menuButton action:@selector(handlePan:)];
        [menuButton addGestureRecognizer:pan];
        
        [menuButton addTarget:[ModMenuController class] action:@selector(showMenu) forControlEvents:UIControlEventTouchUpInside];
        
        [mainWindow addSubview:menuButton];
        [mainWindow bringSubviewToFront:menuButton];
        
        logToFile(@"[UI] Menu button created");
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
// MAIN SETUP
// ============================================================================
void setupHooks() {
    loadIl2Cpp();
    
    // Find Classes
    void* playerClass = findClass("BB", "Player");
    void* luaClass = findClass("", "LuaEventCenterBridge");
    void* bulletClass = findClass("BB", "Bullet");
    void* bodyClass = findClass("", "FSBodyComponent");
    
    // Install Hooks
    if (playerClass) hookMethodByName(playerClass, "Hit", (void*)hook_Player_Hit, (void**)&orig_Player_Hit);
    if (luaClass) hookMethodByName(luaClass, "Broadcast", (void*)hook_Broadcast, (void**)&orig_Broadcast);
    if (bulletClass) hookMethodByName(bulletClass, "SetHp", (void*)hook_Bullet_SetHp, (void**)&orig_Bullet_SetHp);
    
    // Note: FSBodyComponent might be in a different namespace or global
    if (bodyClass) hookMethodByName(bodyClass, "OnCollisionEnter", (void*)hook_OnCollisionEnter, (void**)&orig_OnCollisionEnter);
    else logToFile(@"[WARN] FSBodyComponent class not found via empty namespace");
}

%ctor {
    NSLog(@"[Acecraft] V7 Loading...");
    initLogFile();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupHooks();
        setupMenuButton();
    });
}
