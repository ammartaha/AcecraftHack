#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>
#import "Utils.h"

// ============================================================================
// TWEAK V23 - DEBUG LOG SNIFFER & IGAMEGOD READY
// ============================================================================
/*
   Changes:
   1. STRATEGY: Hook `UnityEngine.Debug.Log` instead of SendMessage.
   2. GOAL: Capture game's internal logs to find logic flow.
   3. UI: Updated title to reflect "Logger".
*/

static NSString *logFilePath = nil;
static NSFileHandle *logFileHandle = nil;

// Toggles
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
    logFilePath = [documentsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"acecraft_v23_%@.txt", timestamp]];
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    logToFile(@"=== ACECRAFT V23: DEBUG LOG SNIFFER ===");
}

// ============================================================================
// IL2CPP TYPES & HELPERS
// ============================================================================
typedef void* (*il2cpp_string_chars_t)(void* str);
typedef int (*il2cpp_string_length_t)(void* str);

static il2cpp_string_chars_t il2cpp_string_chars = NULL;
static il2cpp_string_length_t il2cpp_string_length = NULL;

void loadIl2Cpp() {
    void* h = dlopen(NULL, RTLD_NOW);
    if (!h) return;
    il2cpp_string_chars = (il2cpp_string_chars_t)dlsym(h, "il2cpp_string_chars");
    il2cpp_string_length = (il2cpp_string_length_t)dlsym(h, "il2cpp_string_length");
}

char* GetStringFromIl2CppString(void* strObj) {
    if (!strObj || !il2cpp_string_chars || !il2cpp_string_length) return NULL;
    
    // Safety 1: Check Length
    int len = il2cpp_string_length(strObj);
    if (len <= 0 || len > 2048) return NULL; 
    
    // Safety 2: Get Chars
    uint16_t* chars = (uint16_t*)il2cpp_string_chars(strObj);
    if (!chars) return NULL;
    
    // Safety 3: Conversion
    static char buffer[2049];
    int i = 0;
    for (i = 0; i < len && i < 2048; i++) {
        uint16_t c = chars[i];
        if (c < 32 || c > 126) buffer[i] = '?';
        else buffer[i] = (char)c;
    }
    buffer[i] = 0;
    return buffer;
}


// ============================================================================
// HOOKS: DEBUG LOGGER
// ============================================================================

// UnityEngine.Debug.Log(object message)
static void (*orig_DebugLog)(void* message);

void hook_DebugLog(void* message) {
    if (message) {
        // In Unity, Debug.Log takes an Object. It calls ToString().
        // If it passes a String directly, it's an Il2CppString.
        // We will assume it's a string for now or try to cast.
        // Risk: value types boxed?
        // Let's try GetString.
        
        char* msgC = GetStringFromIl2CppString(message);
        if (msgC) {
             logToFile([NSString stringWithFormat:@"[UNITY] %s", msgC]);
        }
    }
    
    if (orig_DebugLog) orig_DebugLog(message);
}

// FORWARD DECLARATIONS
void handlePanImpl(id self, SEL _cmd, UIPanGestureRecognizer *sender);
void sw1ChangedImpl(id self, SEL _cmd, UISwitch *sender);
void toggleMenu(id self, SEL _cmd);

// ============================================================================
// UI: MODERN GLASSMORPHISM
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

        // 1. Floating Button
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
        
        class_addMethod([UIButton class], @selector(handlePan:), (IMP)handlePanImpl, "v@:@:@"); // Fix types? No, v@:@ is standard for id, SEL, id
        class_addMethod([UIButton class], @selector(menuBtnTapped), (IMP)toggleMenu, "v@:");

        [mainWindow addSubview:floatingBtn];

        // 2. Menu View
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
        title.text = @"DEBUG LOGGER";
        title.textColor = [UIColor whiteColor];
        title.textAlignment = NSTextAlignmentCenter;
        title.font = [UIFont boldSystemFontOfSize:20];
        [menuView addSubview:title];
        
        // Switch 1: Log Toggle
        UISwitch *sw1 = [[UISwitch alloc] initWithFrame:CGRectMake(200, 70, 50, 30)];
        sw1.on = isGodModeRef;
        [sw1 addTarget:sw1 action:@selector(sw1Changed:) forControlEvents:UIControlEventValueChanged];
        class_addMethod([UISwitch class], @selector(sw1Changed:), (IMP)sw1ChangedImpl, "v@:@:@");
        [menuView addSubview:sw1];
        
        UILabel *lbl1 = [[UILabel alloc] initWithFrame:CGRectMake(20, 70, 150, 30)];
        lbl1.text = @"Log Unity Debug";
        lbl1.textColor = [UIColor cyanColor];
        [menuView addSubview:lbl1];
        
        menuView.hidden = YES;
        [mainWindow addSubview:menuView];
    });
}

// ObjC Implementation Helpers
void handlePanImpl(id self, SEL _cmd, UIPanGestureRecognizer *sender) {
    if (sender.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [sender translationInView:mainWindow];
        sender.view.center = CGPointMake(sender.view.center.x + translation.x, sender.view.center.y + translation.y);
        [sender setTranslation:CGPointZero inView:mainWindow];
    }
}

void sw1ChangedImpl(id self, SEL _cmd, UISwitch *sender) {
    isGodModeRef = sender.on;
    logToFile([NSString stringWithFormat:@"[UI] Logging Toggled: %d", isGodModeRef]);
}


// ============================================================================
// SETUP HOOKS
// ============================================================================
void findAndHookDebugLog() {
    loadIl2Cpp();
    
    void* handle = dlopen(NULL, RTLD_NOW);
    void* (*il2cpp_resolve_icall)(const char*) = dlsym(handle, "il2cpp_resolve_icall");
    
    if (il2cpp_resolve_icall) {
        void* addr = il2cpp_resolve_icall("UnityEngine.Debug::Log(System.Object)");
        if (addr) {
             MSHookFunction(addr, (void*)hook_DebugLog, (void**)&orig_DebugLog);
             logToFile(@"[HOOK] Hooked UnityEngine.Debug::Log");
        } else {
             logToFile(@"[ERR] Failed to resolve Debug.Log icall");
        }
    }
}

%ctor {
    NSLog(@"[Acecraft] V23 Loading...");
    initLogFile();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupUI();
        findAndHookDebugLog();
    });
}
