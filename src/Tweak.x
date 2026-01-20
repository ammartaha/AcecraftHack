#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <CydiaSubstrate/CydiaSubstrate.h>

// ============================================================================
// GLOBAL TOGGLES & MULTIPLIERS
// ============================================================================
static BOOL isNeverDie = NO;
static BOOL isOneHitKill = NO;
static BOOL isHighEnergy = NO;
static float expMultiplier = 1.0f;
static float attackMultiplier = 1.0f;

// ============================================================================
// FIXED POINT STRUCT (from dump.cs)
// FP uses 32 fractional bits, so ONE = 4294967296 (2^32)
// ============================================================================
struct FP {
    int64_t _serializedValue;
};

static inline struct FP FloatToFP(float value) __attribute__((unused));
static inline struct FP FloatToFP(float value) {
    struct FP fp;
    fp._serializedValue = (int64_t)(value * 4294967296.0);
    return fp;
}

static inline float FPToFloat(struct FP value) __attribute__((unused));
static inline float FPToFloat(struct FP value) {
    return (float)value._serializedValue / 4294967296.0f;
}

// ============================================================================
// ORIGINAL FUNCTION POINTERS
// ============================================================================
static void (*orig_Player_Hit)(void *self);
static void (*orig_Bullet_SetHp)(void *self, struct FP hp);

// ============================================================================
// HOOK: Player.Hit() - RVA: 0x453E3C
// Called when player takes damage - NEVER DIE feature
// ============================================================================
void hook_Player_Hit(void *self) {
    NSLog(@"[AcecraftHack] Player.Hit() called! NeverDie=%d", isNeverDie);
    if (isNeverDie) {
        NSLog(@"[AcecraftHack] BLOCKED damage (Never Die ON)");
        return; // Don't execute = no damage taken
    }
    orig_Player_Hit(self);
}

// ============================================================================
// HOOK: Bullet.SetHp() - RVA: 0x4530C8
// Called when bullet/entity HP changes - ONE HIT KILL feature
// ============================================================================
void hook_Bullet_SetHp(void *self, struct FP hp) {
    NSLog(@"[AcecraftHack] Bullet.SetHp() HP=%lld OneHitKill=%d", hp._serializedValue, isOneHitKill);
    
    if (isOneHitKill) {
        // Set enemy HP to 0 for instant kill
        // Note: This affects all entities - enemies will die instantly
        struct FP zeroHp = {0};
        orig_Bullet_SetHp(self, zeroHp);
        NSLog(@"[AcecraftHack] SET HP TO ZERO (One Hit Kill)");
        return;
    }
    orig_Bullet_SetHp(self, hp);
}

// ============================================================================
// GET UNITYFRAMEWORK BASE ADDRESS
// ============================================================================
static uintptr_t getUnityFrameworkBase() {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "UnityFramework")) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

static uintptr_t unityBase = 0;

// ============================================================================
// SETUP NATIVE HOOKS
// ============================================================================
void setupNativeHooks() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        unityBase = getUnityFrameworkBase();
        if (!unityBase) {
            NSLog(@"[AcecraftHack] ERROR: UnityFramework not found!");
            return;
        }
        NSLog(@"[AcecraftHack] UnityFramework base: 0x%lx", unityBase);
        
        // Hook Player.Hit - Never Die
        void *hitAddr = (void *)(unityBase + 0x453E3C);
        MSHookFunction(hitAddr, (void *)hook_Player_Hit, (void **)&orig_Player_Hit);
        NSLog(@"[AcecraftHack] Hooked Player.Hit at %p", hitAddr);
        
        // Hook Bullet.SetHp - One Hit Kill
        void *setHpAddr = (void *)(unityBase + 0x4530C8);
        MSHookFunction(setHpAddr, (void *)hook_Bullet_SetHp, (void **)&orig_Bullet_SetHp);
        NSLog(@"[AcecraftHack] Hooked Bullet.SetHp at %p", setHpAddr);
    });
}

// ============================================================================
// UI: FLOATING BUTTON & MENU
// ============================================================================
static UIButton *floatingButton = nil;
static UIView *menuView = nil;
static UIView *overlayView = nil;

@interface ModMenuController : NSObject
+ (instancetype)shared;
- (void)showMenu;
- (void)hideMenu;
@end

@implementation ModMenuController

+ (instancetype)shared {
    static ModMenuController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ModMenuController alloc] init];
    });
    return instance;
}

- (void)handleButtonTap:(UITapGestureRecognizer *)gesture {
    [self showMenu];
}

- (void)handleButtonDrag:(UIPanGestureRecognizer *)gesture {
    UIView *button = gesture.view;
    CGPoint translation = [gesture translationInView:button.superview];
    button.center = CGPointMake(button.center.x + translation.x, button.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:button.superview];
}

- (void)showMenu {
    if (menuView) return;
    
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    
    // Dark overlay
    overlayView = [[UIView alloc] initWithFrame:screenBounds];
    overlayView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideMenu)];
    [overlayView addGestureRecognizer:dismissTap];
    [window addSubview:overlayView];
    
    // Menu container - centered
    CGFloat menuWidth = 300;
    CGFloat menuHeight = 420;
    menuView = [[UIView alloc] initWithFrame:CGRectMake((screenBounds.size.width - menuWidth)/2,
                                                         (screenBounds.size.height - menuHeight)/2,
                                                         menuWidth, menuHeight)];
    menuView.backgroundColor = [[UIColor colorWithRed:0.1 green:0.1 blue:0.15 alpha:0.95] colorWithAlphaComponent:0.95];
    menuView.layer.cornerRadius = 20;
    menuView.layer.borderWidth = 2;
    menuView.layer.borderColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0].CGColor;
    menuView.clipsToBounds = YES;
    
    // Title
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, menuWidth, 30)];
    title.text = @"⚡ ACECRAFT HACK ⚡";
    title.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont boldSystemFontOfSize:18];
    [menuView addSubview:title];
    
    CGFloat yOffset = 55;
    CGFloat rowHeight = 50;
    
    // ========== NEVER DIE ==========
    [self addToggleRow:@"🛡️ Never Die" y:yOffset tag:1 isOn:isNeverDie];
    yOffset += rowHeight;
    
    // ========== ONE HIT KILL ==========
    [self addToggleRow:@"⚔️ One Hit Kill" y:yOffset tag:2 isOn:isOneHitKill];
    yOffset += rowHeight;
    
    // ========== HIGH ENERGY ==========
    [self addToggleRow:@"⚡ High Energy (Ultimate)" y:yOffset tag:3 isOn:isHighEnergy];
    yOffset += rowHeight;
    
    // ========== EXP MULTIPLIER ==========
    UILabel *expLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, yOffset, 140, 30)];
    expLabel.text = @"📈 EXP Multiplier";
    expLabel.textColor = [UIColor whiteColor];
    expLabel.font = [UIFont systemFontOfSize:14];
    [menuView addSubview:expLabel];
    
    UITextField *expField = [[UITextField alloc] initWithFrame:CGRectMake(menuWidth - 100, yOffset, 70, 30)];
    expField.backgroundColor = [UIColor whiteColor];
    expField.textColor = [UIColor blackColor];
    expField.textAlignment = NSTextAlignmentCenter;
    expField.keyboardType = UIKeyboardTypeDecimalPad;
    expField.text = [NSString stringWithFormat:@"%.1f", expMultiplier];
    expField.layer.cornerRadius = 5;
    expField.tag = 100;
    [expField addTarget:self action:@selector(expFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [menuView addSubview:expField];
    yOffset += rowHeight;
    
    // ========== ATTACK MULTIPLIER ==========
    UILabel *atkLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, yOffset, 140, 30)];
    atkLabel.text = @"💥 Attack Multiplier";
    atkLabel.textColor = [UIColor whiteColor];
    atkLabel.font = [UIFont systemFontOfSize:14];
    [menuView addSubview:atkLabel];
    
    UITextField *atkField = [[UITextField alloc] initWithFrame:CGRectMake(menuWidth - 100, yOffset, 70, 30)];
    atkField.backgroundColor = [UIColor whiteColor];
    atkField.textColor = [UIColor blackColor];
    atkField.textAlignment = NSTextAlignmentCenter;
    atkField.keyboardType = UIKeyboardTypeDecimalPad;
    atkField.text = [NSString stringWithFormat:@"%.1f", attackMultiplier];
    atkField.layer.cornerRadius = 5;
    atkField.tag = 101;
    [atkField addTarget:self action:@selector(atkFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [menuView addSubview:atkField];
    yOffset += rowHeight + 10;
    
    // Debug Info
    UILabel *debugLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, yOffset, menuWidth - 20, 40)];
    debugLabel.text = [NSString stringWithFormat:@"📍 Base: 0x%lX", unityBase];
    debugLabel.textColor = [UIColor colorWithRed:0.3 green:0.8 blue:0.3 alpha:1.0];
    debugLabel.font = [UIFont fontWithName:@"Menlo" size:10];
    debugLabel.textAlignment = NSTextAlignmentCenter;
    [menuView addSubview:debugLabel];
    yOffset += 45;
    
    // Close Button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(30, menuHeight - 55, menuWidth - 60, 40);
    closeBtn.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
    [closeBtn setTitle:@"CLOSE" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    closeBtn.layer.cornerRadius = 10;
    [closeBtn addTarget:self action:@selector(hideMenu) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:closeBtn];
    
    [window addSubview:menuView];
}

- (void)addToggleRow:(NSString *)labelText y:(CGFloat)y tag:(NSInteger)tag isOn:(BOOL)isOn {
    CGFloat menuWidth = 300;
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 180, 30)];
    label.text = labelText;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:14];
    [menuView addSubview:label];
    
    UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectMake(menuWidth - 70, y, 50, 30)];
    toggle.on = isOn;
    toggle.tag = tag;
    toggle.onTintColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0];
    [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    [menuView addSubview:toggle];
}

- (void)hideMenu {
    [menuView removeFromSuperview];
    [overlayView removeFromSuperview];
    menuView = nil;
    overlayView = nil;
}

- (void)toggleChanged:(UISwitch *)sender {
    switch (sender.tag) {
        case 1:
            isNeverDie = sender.on;
            NSLog(@"[AcecraftHack] Never Die: %@", isNeverDie ? @"ON" : @"OFF");
            break;
        case 2:
            isOneHitKill = sender.on;
            NSLog(@"[AcecraftHack] One Hit Kill: %@", isOneHitKill ? @"ON" : @"OFF");
            break;
        case 3:
            isHighEnergy = sender.on;
            NSLog(@"[AcecraftHack] High Energy: %@", isHighEnergy ? @"ON" : @"OFF");
            break;
    }
}

- (void)expFieldChanged:(UITextField *)field {
    expMultiplier = [field.text floatValue];
    if (expMultiplier < 1.0f) expMultiplier = 1.0f;
    NSLog(@"[AcecraftHack] EXP Multiplier: %.1f", expMultiplier);
}

- (void)atkFieldChanged:(UITextField *)field {
    attackMultiplier = [field.text floatValue];
    if (attackMultiplier < 1.0f) attackMultiplier = 1.0f;
    NSLog(@"[AcecraftHack] Attack Multiplier: %.1f", attackMultiplier);
}

@end

// ============================================================================
// SETUP FLOATING BUTTON
// ============================================================================
void setupFloatingButton() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIApplication sharedApplication] keyWindow];
        
        // Circular floating button - semi-transparent
        floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
        floatingButton.frame = CGRectMake(20, 120, 55, 55);
        floatingButton.backgroundColor = [[UIColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:1.0] colorWithAlphaComponent:0.7];
        floatingButton.layer.cornerRadius = 27.5;
        floatingButton.layer.borderWidth = 2;
        floatingButton.layer.borderColor = [UIColor whiteColor].CGColor;
        floatingButton.clipsToBounds = YES;
        [floatingButton setTitle:@"MOD" forState:UIControlStateNormal];
        [floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        
        // Tap to open menu
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:[ModMenuController shared] action:@selector(handleButtonTap:)];
        [floatingButton addGestureRecognizer:tap];
        
        // Drag to move
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:[ModMenuController shared] action:@selector(handleButtonDrag:)];
        [floatingButton addGestureRecognizer:pan];
        
        [window addSubview:floatingButton];
        NSLog(@"[AcecraftHack] Floating button added!");
    });
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
%ctor {
    NSLog(@"[AcecraftHack] ==========================================");
    NSLog(@"[AcecraftHack] Tweak loaded! Version 2.0");
    NSLog(@"[AcecraftHack] Features: Never Die, One Hit Kill, High Energy");
    NSLog(@"[AcecraftHack] ==========================================");
    setupFloatingButton();
    setupNativeHooks();
}
