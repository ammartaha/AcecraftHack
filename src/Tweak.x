#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>
#import "Utils.h"

// ============================================================================
// TRACER V5 - COMPREHENSIVE METHOD LOGGER
// ============================================================================
// Goal: Find which method ACTUALLY handles player damage by logging ALL calls

static NSString *logFilePath = nil;
static NSFileHandle *logFileHandle = nil;
static BOOL isGodMode = NO;
static UIButton *menuButton = nil;

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
                   [NSString stringWithFormat:@"acecraft_v5_%@.txt", timestamp]];
    
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    
    logToFile(@"=== ACECRAFT TRACER V5: COMPREHENSIVE LOGGER ===");
    logToFile([NSString stringWithFormat:@"Log: %@", logFilePath]);
}

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

// Note: Using specific hooks below instead of generic hook

// ============================================================================
// SPECIFIC HOOKS - One for each method we want to monitor
// ============================================================================

// Player methods
static void (*orig_Player_Hit)(void* self);
void hook_Player_Hit(void* self) {
    logToFile([NSString stringWithFormat:@">>> Player.Hit called! self=%p godMode=%d", self, isGodMode]);
    if (isGodMode) {
        logToFile(@"    BLOCKED by God Mode!");
        return;
    }
    if (orig_Player_Hit) orig_Player_Hit(self);
}

// Bullet methods  
static void (*orig_Bullet_SetHp)(void* self, struct FP hp);
void hook_Bullet_SetHp(void* self, struct FP hp) {
    float hpFloat = FPToFloat(hp);
    logToFile([NSString stringWithFormat:@">>> Bullet.SetHp called! self=%p hp=%.2f", self, hpFloat]);
    if (orig_Bullet_SetHp) orig_Bullet_SetHp(self, hp);
}

static void (*orig_Bullet_InitInfo)(void* self, void* bulletData);
void hook_Bullet_InitInfo(void* self, void* bulletData) {
    logToFile([NSString stringWithFormat:@">>> Bullet.InitInfo called! self=%p data=%p", self, bulletData]);
    if (orig_Bullet_InitInfo) orig_Bullet_InitInfo(self, bulletData);
}

static void (*orig_Bullet_Destroy)(void* self);
void hook_Bullet_Destroy(void* self) {
    logToFile([NSString stringWithFormat:@">>> Bullet.Destroy called! self=%p", self]);
    if (orig_Bullet_Destroy) orig_Bullet_Destroy(self);
}

// BulletManager methods
static void* (*orig_BulletManager_SpawnBullet)(void* self, void* data);
void* hook_BulletManager_SpawnBullet(void* self, void* data) {
    logToFile([NSString stringWithFormat:@">>> BulletManager.SpawnBullet called! self=%p data=%p", self, data]);
    return orig_BulletManager_SpawnBullet ? orig_BulletManager_SpawnBullet(self, data) : NULL;
}

// ============================================================================
// HOOK INSTALLER
// ============================================================================
void hookMethodByName(void* klass, const char* methodName, void* hookFn, void** origPtr) {
    if (!klass || !il2cpp_class_get_methods) return;
    
    void* iter = NULL;
    void* method;
    while ((method = il2cpp_class_get_methods(klass, &iter)) != NULL) {
        const char* mName = il2cpp_method_get_name ? il2cpp_method_get_name(method) : "";
        if (strcmp(mName, methodName) == 0) {
            // Get pointer at offset 0
            void* ptr = *(void**)method;
            if (ptr) {
                MSHookFunction(ptr, hookFn, origPtr);
                logToFile([NSString stringWithFormat:@"[HOOK] %s at %p", methodName, ptr]);
            } else {
                logToFile([NSString stringWithFormat:@"[WARN] %s pointer is NULL!", methodName]);
            }
            return;
        }
    }
    logToFile([NSString stringWithFormat:@"[WARN] Method %s NOT FOUND!", methodName]);
}

// ============================================================================
// UI - Simple Mod Menu
// ============================================================================
@interface ModMenuController : NSObject
+ (void)showMenu;
@end

@implementation ModMenuController
+ (void)showMenu {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Acecraft Hack V5"
                                                                   message:@"Tracer Mode Active"
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
        menuButton.frame = CGRectMake(20, 100, 60, 60);
        menuButton.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.7];
        menuButton.layer.cornerRadius = 30;
        [menuButton setTitle:@"V5" forState:UIControlStateNormal];
        menuButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        
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
    logToFile(@"Setting up hooks...");
    loadIl2Cpp();
    
    if (!il2cpp_domain_get) {
        logToFile(@"[ERROR] Failed to load il2cpp functions!");
        return;
    }
    
    // Find classes
    void* playerClass = findClass("BB", "Player");
    void* bulletClass = findClass("BB", "Bullet");  
    void* bulletMgrClass = findClass("BB", "BulletManager");
    
    logToFile([NSString stringWithFormat:@"Classes: Player=%p Bullet=%p BulletMgr=%p", 
               playerClass, bulletClass, bulletMgrClass]);
    
    // List ALL methods in Player class
    if (playerClass) {
        logToFile(@"=== BB.Player Methods ===");
        void* iter = NULL;
        void* method;
        while ((method = il2cpp_class_get_methods(playerClass, &iter)) != NULL) {
            const char* mName = il2cpp_method_get_name ? il2cpp_method_get_name(method) : "?";
            void* ptr = *(void**)method;
            logToFile([NSString stringWithFormat:@"  %s -> %p", mName, ptr]);
        }
    }
    
    // Hook Player.Hit
    hookMethodByName(playerClass, "Hit", (void*)hook_Player_Hit, (void**)&orig_Player_Hit);
    
    // Hook Bullet methods
    hookMethodByName(bulletClass, "SetHp", (void*)hook_Bullet_SetHp, (void**)&orig_Bullet_SetHp);
    hookMethodByName(bulletClass, "InitInfo", (void*)hook_Bullet_InitInfo, (void**)&orig_Bullet_InitInfo);
    hookMethodByName(bulletClass, "Destroy", (void*)hook_Bullet_Destroy, (void**)&orig_Bullet_Destroy);
    
    // Hook BulletManager
    hookMethodByName(bulletMgrClass, "SpawnBullet", (void*)hook_BulletManager_SpawnBullet, (void**)&orig_BulletManager_SpawnBullet);
    
    logToFile(@"=== HOOKS INSTALLED ===");
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
%ctor {
    NSLog(@"[Acecraft] V5 Tracer Loading...");
    initLogFile();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupHooks();
        setupMenuButton();
    });
}
