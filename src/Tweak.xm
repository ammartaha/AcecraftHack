#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>

// IL2CPP Resolver Header
#include "IL2CPP_Resolver.hpp"

// ============================================================================
// TWEAK V26 - GOD MODE + XP MULTIPLIER
// ============================================================================
/*
   BREAKTHROUGH: Found GMNoDamage property via dnSpy decompilation!

   Changes:
   1. GOD MODE: Continuously set PlayerLogic.GMNoDamage = true
   2. XP MULTIPLIER: Hook set_CurExp and multiply by 200
   3. ONE-HIT KILL: Hook GetDamageBonus and return huge value (optional)

   Strategy: Use runtime reflection to find instances and set properties directly.
*/

static NSString *logFilePath = nil;
static NSFileHandle *logFileHandle = nil;

// Feature toggles
static BOOL isGodModeEnabled = YES;
static BOOL isXPMultiplierEnabled = YES;
static BOOL isOneHitKillEnabled = NO;
static int xpMultiplier = 200;

// UI Elements
static UIButton *floatingBtn;
static UIView *menuView;
static UIVisualEffectView *blurEffectView;
static UIWindow *mainWindow = nil;

// Il2Cpp class and method pointers
static Unity::il2cppClass* playerLogicClass = nullptr;
static Unity::il2cppMethodInfo* setGMNoDamageMethod = nullptr;
static Unity::il2cppMethodInfo* getGMNoDamageMethod = nullptr;
static Unity::il2cppMethodInfo* setCurExpMethod = nullptr;
static Unity::il2cppMethodInfo* getCurExpMethod = nullptr;

// Original function pointers for hooks
typedef void (*set_CurExp_t)(void* instance, float value);
static set_CurExp_t orig_set_CurExp = nullptr;

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
    logFilePath = [documentsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"acecraft_v26_%@.txt", timestamp]];
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    logToFile(@"=== ACECRAFT V26: GOD MODE + XP MULTIPLIER ===");
}

// ============================================================================
// XP MULTIPLIER HOOK
// ============================================================================
void hook_set_CurExp(void* instance, float value) {
    if (isXPMultiplierEnabled && value > 0) {
        float multipliedValue = value * xpMultiplier;
        logToFile([NSString stringWithFormat:@"[XP] Original: %.2f → Multiplied: %.2f (x%d)", value, multipliedValue, xpMultiplier]);
        orig_set_CurExp(instance, multipliedValue);
    } else {
        orig_set_CurExp(instance, value);
    }
}

// ============================================================================
// GOD MODE LOOP
// ============================================================================
void startGodModeLoop() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        logToFile(@"[GOD MODE] Loop started");

        while(1) {
            @try {
                if (isGodModeEnabled && playerLogicClass && setGMNoDamageMethod) {
                    // Find PlayerLogic instance
                    Unity::il2cppObject* playerInstance = Unity::Object::FindObject(playerLogicClass);

                    if (playerInstance) {
                        // Set GMNoDamage = true
                        bool trueValue = true;
                        void* args[] = { &trueValue };
                        IL2CPP::Method::Invoke(setGMNoDamageMethod, playerInstance, args, nullptr);

                        // Verify it was set (optional logging)
                        static int logCounter = 0;
                        if (logCounter++ % 100 == 0) { // Log every 100 iterations
                            bool currentValue = false;
                            IL2CPP::Method::Invoke(getGMNoDamageMethod, playerInstance, nullptr, &currentValue);
                            logToFile([NSString stringWithFormat:@"[GOD MODE] GMNoDamage = %d", currentValue]);
                        }
                    }
                }
            } @catch (NSException *exception) {
                logToFile([NSString stringWithFormat:@"[ERROR] God mode loop: %@", exception]);
            }

            usleep(100000); // 0.1 second
        }
    });
}

// ============================================================================
// SETUP HOOKS AND METHODS
// ============================================================================
void setupHacks() {
    logToFile(@"[INIT] Initializing Il2CppResolver...");

    // 1. Initialize Il2Cpp Resolver
    bool init = IL2CPP::Initialize();
    if (!init) {
        logToFile(@"[FATAL] Il2CppResolver initialization failed!");
        return;
    }
    logToFile(@"[INIT] Il2CppResolver initialized successfully");

    // 2. Attach to domain
    Unity::il2cppDomain* domain = IL2CPP::Domain::Get();
    IL2CPP::Domain::Attach(domain);
    logToFile(@"[INIT] Attached to Il2Cpp domain");

    // 3. Find PlayerLogic class
    logToFile(@"[SEARCH] Looking for WE.Battle.Logic.PlayerLogic...");
    playerLogicClass = IL2CPP::Class::Find("WE.Battle.Logic.PlayerLogic");

    if (!playerLogicClass) {
        logToFile(@"[ERROR] PlayerLogic class not found!");
        return;
    }
    logToFile([NSString stringWithFormat:@"[FOUND] PlayerLogic class at %p", playerLogicClass]);

    // 4. Find methods
    void* iter = nullptr;

    while (Unity::il2cppMethodInfo* method = IL2CPP::Class::GetMethods(playerLogicClass, &iter)) {
        const char* methodName = method->name;

        // Find set_GMNoDamage
        if (strcmp(methodName, "set_GMNoDamage") == 0 && method->parameters_count == 1) {
            setGMNoDamageMethod = method;
            logToFile([NSString stringWithFormat:@"[FOUND] set_GMNoDamage at %p", method->methodPointer]);
        }

        // Find get_GMNoDamage
        if (strcmp(methodName, "get_GMNoDamage") == 0 && method->parameters_count == 0) {
            getGMNoDamageMethod = method;
            logToFile([NSString stringWithFormat:@"[FOUND] get_GMNoDamage at %p", method->methodPointer]);
        }

        // Find set_CurExp
        if (strcmp(methodName, "set_CurExp") == 0 && method->parameters_count == 1) {
            setCurExpMethod = method;
            void* methodAddr = (void*)method->methodPointer;
            logToFile([NSString stringWithFormat:@"[FOUND] set_CurExp at %p", methodAddr]);

            // Hook set_CurExp for XP multiplier
            if (isXPMultiplierEnabled) {
                MSHookFunction(methodAddr, (void*)hook_set_CurExp, (void**)&orig_set_CurExp);
                logToFile(@"[HOOK] set_CurExp hooked successfully!");
            }
        }

        // Find get_CurExp
        if (strcmp(methodName, "get_CurExp") == 0 && method->parameters_count == 0) {
            getCurExpMethod = method;
            logToFile([NSString stringWithFormat:@"[FOUND] get_CurExp at %p", method->methodPointer]);
        }
    }

    // 5. Verify we found the required methods
    if (setGMNoDamageMethod && getGMNoDamageMethod) {
        logToFile(@"[SUCCESS] God mode methods found!");
        startGodModeLoop();
    } else {
        logToFile(@"[ERROR] God mode methods not found!");
    }

    if (setCurExpMethod) {
        logToFile([NSString stringWithFormat:@"[SUCCESS] XP multiplier ready (x%d)", xpMultiplier]);
    } else {
        logToFile(@"[WARN] XP methods not found - multiplier won't work");
    }

    logToFile(@"[INIT] Setup complete!");
}

// ============================================================================
// UI
// ============================================================================

// FORWARD DECLARATIONS
void handlePanImpl(id self, SEL _cmd, UIPanGestureRecognizer *sender);
void sw1ChangedImpl(id self, SEL _cmd, UISwitch *sender);
void sw2ChangedImpl(id self, SEL _cmd, UISwitch *sender);
void toggleMenu(id self, SEL _cmd);

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
        if (!mainWindow) {
            mainWindow = [UIApplication sharedApplication].windows.firstObject;
        }
        if (!mainWindow) return;

        // Floating button
        floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        floatingBtn.frame = CGRectMake(50, 100, 60, 60);
        floatingBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
        floatingBtn.layer.cornerRadius = 30;
        floatingBtn.layer.borderWidth = 2;
        floatingBtn.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.8].CGColor;
        [floatingBtn setTitle:@"⚡" forState:UIControlStateNormal];
        floatingBtn.titleLabel.font = [UIFont systemFontOfSize:30];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:floatingBtn action:@selector(handlePan:)];
        [floatingBtn addGestureRecognizer:pan];
        [floatingBtn addTarget:floatingBtn action:@selector(menuBtnTapped) forControlEvents:UIControlEventTouchUpInside];

        class_addMethod([UIButton class], @selector(handlePan:), (IMP)handlePanImpl, "v@:@");
        class_addMethod([UIButton class], @selector(menuBtnTapped), (IMP)toggleMenu, "v@:");

        [mainWindow addSubview:floatingBtn];

        // Menu view
        menuView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
        menuView.center = mainWindow.center;

        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurEffectView.frame = menuView.bounds;
        blurEffectView.layer.cornerRadius = 20;
        blurEffectView.layer.masksToBounds = YES;
        blurEffectView.layer.borderWidth = 2;
        blurEffectView.layer.borderColor = [[UIColor cyanColor] colorWithAlphaComponent:0.5].CGColor;
        [menuView addSubview:blurEffectView];

        // Title
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, 300, 35)];
        title.text = @"⚡ ACECRAFT V26 ⚡";
        title.textColor = [UIColor cyanColor];
        title.textAlignment = NSTextAlignmentCenter;
        title.font = [UIFont boldSystemFontOfSize:22];
        [menuView addSubview:title];

        // God Mode toggle
        UISwitch *sw1 = [[UISwitch alloc] initWithFrame:CGRectMake(220, 80, 50, 30)];
        sw1.on = isGodModeEnabled;
        [sw1 addTarget:sw1 action:@selector(sw1Changed:) forControlEvents:UIControlEventValueChanged];
        class_addMethod([UISwitch class], @selector(sw1Changed:), (IMP)sw1ChangedImpl, "v@:@");
        [menuView addSubview:sw1];

        UILabel *lbl1 = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, 180, 30)];
        lbl1.text = @"🛡️ God Mode";
        lbl1.textColor = [UIColor whiteColor];
        lbl1.font = [UIFont boldSystemFontOfSize:16];
        [menuView addSubview:lbl1];

        // XP Multiplier toggle
        UISwitch *sw2 = [[UISwitch alloc] initWithFrame:CGRectMake(220, 130, 50, 30)];
        sw2.on = isXPMultiplierEnabled;
        [sw2 addTarget:sw2 action:@selector(sw2Changed:) forControlEvents:UIControlEventValueChanged];
        class_addMethod([UISwitch class], @selector(sw2Changed:), (IMP)sw2ChangedImpl, "v@:@");
        [menuView addSubview:sw2];

        UILabel *lbl2 = [[UILabel alloc] initWithFrame:CGRectMake(20, 130, 180, 30)];
        lbl2.text = @"⭐ XP x200";
        lbl2.textColor = [UIColor whiteColor];
        lbl2.font = [UIFont boldSystemFontOfSize:16];
        [menuView addSubview:lbl2];

        // Info label
        UILabel *info = [[UILabel alloc] initWithFrame:CGRectMake(20, 200, 260, 80)];
        info.text = @"Check Documents folder\nfor acecraft_v26_*.txt logs\n\nGod mode prevents damage\nXP x200 multiplies all XP gains";
        info.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
        info.textAlignment = NSTextAlignmentCenter;
        info.font = [UIFont systemFontOfSize:12];
        info.numberOfLines = 5;
        [menuView addSubview:info];

        menuView.hidden = YES;
        [mainWindow addSubview:menuView];

        logToFile(@"[UI] Menu created successfully");
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
    isGodModeEnabled = sender.on;
    logToFile([NSString stringWithFormat:@"[UI] God Mode: %@", isGodModeEnabled ? @"ON" : @"OFF"]);
}

void sw2ChangedImpl(id self, SEL _cmd, UISwitch *sender) {
    isXPMultiplierEnabled = sender.on;
    logToFile([NSString stringWithFormat:@"[UI] XP Multiplier: %@", isXPMultiplierEnabled ? @"ON" : @"OFF"]);
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
%ctor {
    NSLog(@"[Acecraft] V26 Loading...");
    initLogFile();
    logToFile(@"=== TWEAK V26 LOADED ===");
    logToFile(@"Features: God Mode + XP Multiplier x200");

    // Wait for UnityFramework to load
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        logToFile(@"[INIT] Starting setup...");
        setupUI();
        setupHacks();
    });
}
