#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>
#import "Utils.h"

// ============================================================================
// MOD STATE
// ============================================================================
static BOOL isGodMode = NO;
static UIButton *menuButton = nil;
static UIWindow *mainWindow = nil;

// ============================================================================
// IL2CPP TYPES & HELPERS
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

void* findMethod(const char* namespaze, const char* className, const char* methodName) {
    if (!il2cpp_domain_get) return NULL;
    void* domain = il2cpp_domain_get();
    size_t size = 0;
    void** assemblies = il2cpp_domain_get_assemblies(domain, &size);
    
    for (size_t i = 0; i < size; i++) {
        void* image = il2cpp_assembly_get_image(assemblies[i]);
        if (!image) continue;
        void* klass = il2cpp_class_from_name(image, namespaze, className);
        if (klass) {
            void* iter = NULL;
            void* method;
            while ((method = il2cpp_class_get_methods(klass, &iter)) != NULL) {
                const char* mName = il2cpp_method_get_name ? il2cpp_method_get_name(method) : "";
                if (strcmp(mName, methodName) == 0) {
                    return method;
                }
            }
        }
    }
    return NULL;
}

// ============================================================================
// HOOKS
// ============================================================================

// Original function pointers
void (*orig_Player_Hit)(void* self, void* damageInfo); // Assuming unknown args
void (*orig_Bullet_InitInfo)(void* self, void* info); // Assuming unknown args

// Hook Implementations
void hook_Player_Hit(void* self, void* damageInfo) {
    if (isGodMode) {
        NSLog(@"[Acecraft] Blocked Player.Hit (God Mode Active)");
        return; // Skip damage
    }
    NSLog(@"[Acecraft] Player.Hit called (Normal)");
    if (orig_Player_Hit) orig_Player_Hit(self, damageInfo);
}

// ============================================================================
// UI
// ============================================================================

@interface ModMenuController : NSObject
+ (void)showMenu;
@end

@implementation ModMenuController

+ (void)showMenu {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Acecraft Hack"
                                                                   message:@"Coded by Ammar"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    // Toggle God Mode
    NSString *godModeTitle = isGodMode ? @"God Mode: ON ✅" : @"God Mode: OFF ❌";
    UIAlertAction *godModeAction = [UIAlertAction actionWithTitle:godModeTitle
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
        isGodMode = !isGodMode;
        [self showMenu]; // Re-open menu to update state
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
        menuButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        menuButton.layer.cornerRadius = 25;
        menuButton.clipsToBounds = YES;
        [menuButton setTitle:@"Hack" forState:UIControlStateNormal];
        menuButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        [menuButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        
        // Dragging support
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:menuButton action:@selector(handlePan:)];
        [menuButton addGestureRecognizer:pan];
        
        // Tap action
        [menuButton addTarget:[ModMenuController class] action:@selector(showMenu) forControlEvents:UIControlEventTouchUpInside];
        
        [mainWindow addSubview:menuButton];
        [mainWindow bringSubviewToFront:menuButton];
    });
}

// Add Pan Gesture Handler Category to UIButton for simplicity
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
    
    // Hook Player.Hit
    void* hitMethod = findMethod("BB", "Player", "Hit");
    if (hitMethod) {
        // Pointer is at offset 0 based on V4 analysis
        void* hitPtr = *(void**)hitMethod;
        
        if (hitPtr) {
            MSHookFunction(hitPtr, (void*)hook_Player_Hit, (void**)&orig_Player_Hit);
            NSLog(@"[Acecraft] Hooked BB.Player.Hit at %p", hitPtr);
        } else {
            NSLog(@"[Acecraft] BB.Player.Hit pointer is NULL!");
        }
    } else {
        NSLog(@"[Acecraft] BB.Player.Hit method NOT FOUND!");
    }
}

%ctor {
    NSLog(@"[Acecraft] Loading Mod...");
    
    // Delay setup to ensure Il2Cpp is initialized
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupHooks();
        setupMenuButton();
    });
}
