#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>

// IL2CPP Resolver Header
// We use the relative path or include path set in Makefile
#include "IL2CPP_Resolver.hpp"

// ============================================================================
// TWEAK V24 - DYNAMIC RESOLVER (IOS-Il2CppResolver)
// ============================================================================
/*
   Changes:
   1. TECH: Integrated IOS-Il2cppResolver Library.
   2. FIX: Replaces failed `dlsym` lookup with robust Runtime Method Resolution.
   3. GOAL: Find `UnityEngine.Debug.Log` reliably and Sniff it.
*/

static NSString *logFilePath = nil;
static NSFileHandle *logFileHandle = nil;
static BOOL isGodModeRef = YES;

// UI Elements
static UIButton *floatingBtn;
static UIView *menuView;
static UIVisualEffectView *blurEffectView;
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
    logFilePath = [documentsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"acecraft_v24_%@.txt", timestamp]];
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    logToFile(@"=== ACECRAFT V24: DYNAMIC RESOLVER SNIFFER ===");
}

// ============================================================================
// HOOKS: DYNAMIC DEBUG SNIFFER
// ============================================================================

// Original function pointer type (Generic)
static void (*orig_DebugLog)(void* message);

void hook_DebugLog(void* message) {
    // We treat message as Il2CppObject*.
    // We can try to use standard C# ToString here via Resolver if we wanted,
    // but for now let's just log that we hit it and maybe primitive type check.
    
    // NOTE: Casting Il2CppObject to string manually is risky if we don't know it's a string.
    // But Debug.Log accepts Object.
    
    logToFile(@"[UNITY] Debug.Log Called!"); 
    // If we wanted to read the string:
    // Unity::System_String* str = (Unity::System_String*)message;
    // if (str) logToFile([NSString stringWithFormat:@"[STR] Length: %d", str->Length]);
    
    if (orig_DebugLog) orig_DebugLog(message);
}


// ============================================================================
// SETUP HOOKS VIA RESOLVER
// ============================================================================
void setupDynamicHooks() {
    // 1. Initialize Resolver
    // This scans the binary for Il2Cpp exports using "UnityFramework" (set in Config.h)
    logToFile(@"[INIT] Initializing Il2CppResolver...");
    bool init = IL2CPP::Initialize();
    
    if (!init) {
        logToFile(@"[FATAL] Il2CppResolver Initialization Failed!");
        return;
    }
    logToFile(@"[INIT] Resolver Initialized!");
    
    // 2. Attach Thread
    IL2CPP::Domain::Get(); // Ensure domain loaded
    Unity::il2cppDomain* domain = IL2CPP::Domain::Get();
    IL2CPP::Domain::Attach(domain);
    
    // 3. Find Class: UnityEngine.Debug
    logToFile(@"[FIND] Looking for UnityEngine.Debug...");
    Unity::il2cppClass* debugClass = IL2CPP::Class::Find("UnityEngine.Debug");
    if (!debugClass) {
        logToFile(@"[ERR] Class UnityEngine.Debug not found!");
        return;
    }
    
    // 4. Find Method: Log(object)
    // We need to be specific about arguments to overload resolution?
    // IOS-Il2cppResolver GetMethod usually takes name. If overloaded, might pick first or need args.
    // Debug.Log has many overloads. We want the simple one taking 1 arg (Object).
    // Or just hook ALL of them?
    
    // Let's try finding "Log" with 1 argument.
    // API: Class::GetMethod(name, argsCount)
    // We will iterate methods if needed, but let's try standard GetMethod.
    
    std::vector<Unity::il2cppMethodInfo*> methods = IL2CPP::Class::GetMethods(debugClass);
    void* targetAddr = NULL;
    
    for (auto method : methods) {
        // filter by name "Log" and param count 1
        if (strcmp(method->name, "Log") == 0 && method->parameters_count == 1) {
             targetAddr = (void*)method->methodPointer;
             logToFile([NSString stringWithFormat:@"[FOUND] Debug.Log(obj) at %p", targetAddr]);
             break;
        }
    }
    
    if (targetAddr) {
        MSHookFunction(targetAddr, (void*)hook_DebugLog, (void**)&orig_DebugLog);
        logToFile(@"[HOOK] Hooked Debug.Log Successfully!");
    } else {
        logToFile(@"[ERR] Debug.Log method not found in class!");
    }
}


// FORWARD DECLARATIONS (Required for class_addMethod)
void handlePanImpl(id self, SEL _cmd, UIPanGestureRecognizer *sender);
void sw1ChangedImpl(id self, SEL _cmd, UISwitch *sender);
void toggleMenu(id self, SEL _cmd);

// ============================================================================
// UI
// ============================================================================

void toggleMenu(id self, SEL _cmd) {
    if (menuView.hidden) {
        menuView.hidden = NO;
        menuView.transform = CGAffineTransformMakeScale(0.8, 0.8);
        menuView.alpha = 0;
        
        [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.8 options:0 animations:^{
            menuView.transform = CGAffineTransformIdentity;
            menuView.alpha = 1;
        } completion:nil];
    } else {
        [UIView animateWithDuration:0.3 animations:^{
            menuView.transform = CGAffineTransformMakeScale(0.8, 0.8);
            menuView.alpha = 0;
        } completion:^(BOOL finished){
            menuView.hidden = YES;
        }];
    }
}

void setupUI() {
    dispatch_async(dispatch_get_main_queue(), ^{
        mainWindow = [UIApplication sharedApplication].keyWindow;
        if (!mainWindow) return;

        floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        floatingBtn.frame = CGRectMake(50, 50, 50, 50);
        floatingBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        floatingBtn.layer.cornerRadius = 25;
        floatingBtn.layer.borderWidth = 1;
        floatingBtn.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
        [floatingBtn setTitle:@"A" forState:UIControlStateNormal];
        [floatingBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
        floatingBtn.titleLabel.font = [UIFont boldSystemFontOfSize:24];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:floatingBtn action:@selector(handlePan:)];
        [floatingBtn addGestureRecognizer:pan];
        [floatingBtn addTarget:floatingBtn action:@selector(menuBtnTapped) forControlEvents:UIControlEventTouchUpInside];
        
        class_addMethod([UIButton class], @selector(handlePan:), (IMP)handlePanImpl, "v@:@:@");
        class_addMethod([UIButton class], @selector(menuBtnTapped), (IMP)toggleMenu, "v@:");

        [mainWindow addSubview:floatingBtn];

        menuView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 280, 250)];
        menuView.center = mainWindow.center;
        
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurEffectView.frame = menuView.bounds;
        blurEffectView.layer.cornerRadius = 20;
        blurEffectView.layer.masksToBounds = YES;
        blurEffectView.layer.borderWidth = 1;
        blurEffectView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.2].CGColor;
        [menuView addSubview:blurEffectView];
        
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 280, 30)];
        title.text = @"ACECRAFT V24";
        title.textColor = [UIColor whiteColor];
        title.textAlignment = NSTextAlignmentCenter;
        title.font = [UIFont boldSystemFontOfSize:20];
        [menuView addSubview:title];
        
        UISwitch *sw1 = [[UISwitch alloc] initWithFrame:CGRectMake(200, 70, 50, 30)];
        sw1.on = isGodModeRef;
        [sw1 addTarget:sw1 action:@selector(sw1Changed:) forControlEvents:UIControlEventValueChanged];
        class_addMethod([UISwitch class], @selector(sw1Changed:), (IMP)sw1ChangedImpl, "v@:@:@");
        [menuView addSubview:sw1];
        
        UILabel *lbl1 = [[UILabel alloc] initWithFrame:CGRectMake(20, 70, 150, 30)];
        lbl1.text = @"Debug Scan";
        lbl1.textColor = [UIColor cyanColor];
        [menuView addSubview:lbl1];
        
        menuView.hidden = YES;
        [mainWindow addSubview:menuView];
    });
}

void handlePanImpl(id self, SEL _cmd, UIPanGestureRecognizer *sender) {
    if (sender.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [sender translationInView:mainWindow];
        sender.view.center = CGPointMake(sender.view.center.x + translation.x, sender.view.center.y + translation.y);
        [sender setTranslation:CGPointZero inView:mainWindow];
    }
}

void sw1ChangedImpl(id self, SEL _cmd, UISwitch *sender) {
    isGodModeRef = sender.on;
    logToFile([NSString stringWithFormat:@"[UI] Debug Scan Toggled: %d", isGodModeRef]);
}


%ctor {
    NSLog(@"[Acecraft] V24 Loading...");
    initLogFile();
    
    // Safety delay to ensure UnityFramework is loaded
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupUI();
        setupDynamicHooks();
    });
}
