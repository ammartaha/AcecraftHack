#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <CydiaSubstrate/CydiaSubstrate.h>

// ============================================================================
// GLOBAL TOGGLES
// ============================================================================
static BOOL isGodMode = NO;
static BOOL isOneHit = NO;
static int xpMultiplier = 1;

// ============================================================================
// FIXED POINT STRUCT (from dump.cs)
// ============================================================================
struct FP {
    int64_t _serializedValue;
};

// ============================================================================
// ORIGINAL FUNCTION POINTERS
// ============================================================================
static void (*orig_Player_Hit)(void *self);
static void (*orig_Bullet_SetHp)(void *self, struct FP hp);

// ============================================================================
// HOOK: Player.Hit() - RVA: 0x453E3C
// Called when player takes damage
// ============================================================================
void hook_Player_Hit(void *self) {
    NSLog(@"[AcecraftHack] Player.Hit() called! GodMode=%d", isGodMode);
    if (isGodMode) {
        NSLog(@"[AcecraftHack] BLOCKED damage (God Mode ON)");
        return; // Don't call original = no damage
    }
    orig_Player_Hit(self);
}

// ============================================================================
// HOOK: Bullet.SetHp() - RVA: 0x4530C8
// Called when any bullet/entity HP changes
// ============================================================================
void hook_Bullet_SetHp(void *self, struct FP hp) {
    NSLog(@"[AcecraftHack] Bullet.SetHp() called! HP=%lld OneHit=%d", hp._serializedValue, isOneHit);
    if (isOneHit) {
        // Set HP to 0 = instant kill
        struct FP zeroHp = {0};
        orig_Bullet_SetHp(self, zeroHp);
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

// ============================================================================
// SETUP NATIVE HOOKS
// ============================================================================
void setupNativeHooks() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        uintptr_t base = getUnityFrameworkBase();
        if (!base) {
            NSLog(@"[AcecraftHack] ERROR: UnityFramework not found!");
            return;
        }
        NSLog(@"[AcecraftHack] UnityFramework base: 0x%lx", base);
        
        // Hook Player.Hit
        void *hitAddr = (void *)(base + 0x453E3C);
        MSHookFunction(hitAddr, (void *)hook_Player_Hit, (void **)&orig_Player_Hit);
        NSLog(@"[AcecraftHack] Hooked Player.Hit at %p", hitAddr);
        
        // Hook Bullet.SetHp
        void *setHpAddr = (void *)(base + 0x4530C8);
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
- (void)handleButtonTap:(UITapGestureRecognizer *)gesture;
- (void)handleButtonDrag:(UIPanGestureRecognizer *)gesture;
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
    overlayView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideMenu)];
    [overlayView addGestureRecognizer:dismissTap];
    [window addSubview:overlayView];
    
    // Menu container - centered
    CGFloat menuWidth = 280;
    CGFloat menuHeight = 320;
    menuView = [[UIView alloc] initWithFrame:CGRectMake((screenBounds.size.width - menuWidth)/2,
                                                         (screenBounds.size.height - menuHeight)/2,
                                                         menuWidth, menuHeight)];
    menuView.backgroundColor = [[UIColor darkGrayColor] colorWithAlphaComponent:0.95];
    menuView.layer.cornerRadius = 15;
    menuView.clipsToBounds = YES;
    
    // Title
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, menuWidth, 30)];
    title.text = @"Acecraft Mod Menu";
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont boldSystemFontOfSize:18];
    [menuView addSubview:title];
    
    CGFloat yOffset = 50;
    
    // God Mode Toggle
    UILabel *godLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, yOffset, 150, 30)];
    godLabel.text = @"God Mode";
    godLabel.textColor = [UIColor whiteColor];
    [menuView addSubview:godLabel];
    
    UISwitch *godSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(menuWidth - 70, yOffset, 50, 30)];
    godSwitch.on = isGodMode;
    godSwitch.tag = 1;
    [godSwitch addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    [menuView addSubview:godSwitch];
    yOffset += 50;
    
    // One Hit Kill Toggle
    UILabel *ohkLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, yOffset, 150, 30)];
    ohkLabel.text = @"One Hit Kill";
    ohkLabel.textColor = [UIColor whiteColor];
    [menuView addSubview:ohkLabel];
    
    UISwitch *ohkSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(menuWidth - 70, yOffset, 50, 30)];
    ohkSwitch.on = isOneHit;
    ohkSwitch.tag = 2;
    [ohkSwitch addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    [menuView addSubview:ohkSwitch];
    yOffset += 50;
    
    // XP Multiplier Input
    UILabel *xpLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, yOffset, 150, 30)];
    xpLabel.text = @"XP Multiplier";
    xpLabel.textColor = [UIColor whiteColor];
    [menuView addSubview:xpLabel];
    
    UITextField *xpField = [[UITextField alloc] initWithFrame:CGRectMake(menuWidth - 80, yOffset, 60, 30)];
    xpField.backgroundColor = [UIColor whiteColor];
    xpField.textColor = [UIColor blackColor];
    xpField.textAlignment = NSTextAlignmentCenter;
    xpField.keyboardType = UIKeyboardTypeNumberPad;
    xpField.text = [NSString stringWithFormat:@"%d", xpMultiplier];
    xpField.layer.cornerRadius = 5;
    xpField.tag = 100;
    [xpField addTarget:self action:@selector(xpFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [menuView addSubview:xpField];
    yOffset += 60;
    
    // Debug Info
    UILabel *debugLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, yOffset, menuWidth - 20, 60)];
    debugLabel.text = [NSString stringWithFormat:@"Debug: Base=0x%lx\nCheck Console for logs", getUnityFrameworkBase()];
    debugLabel.textColor = [UIColor greenColor];
    debugLabel.font = [UIFont systemFontOfSize:10];
    debugLabel.numberOfLines = 0;
    [menuView addSubview:debugLabel];
    yOffset += 70;
    
    // Close Button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, menuHeight - 50, menuWidth - 40, 40);
    closeBtn.backgroundColor = [UIColor redColor];
    [closeBtn setTitle:@"CLOSE" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.layer.cornerRadius = 8;
    [closeBtn addTarget:self action:@selector(hideMenu) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:closeBtn];
    
    [window addSubview:menuView];
}

- (void)hideMenu {
    [menuView removeFromSuperview];
    [overlayView removeFromSuperview];
    menuView = nil;
    overlayView = nil;
}

- (void)toggleChanged:(UISwitch *)sender {
    if (sender.tag == 1) {
        isGodMode = sender.on;
        NSLog(@"[AcecraftHack] God Mode: %@", isGodMode ? @"ON" : @"OFF");
    } else if (sender.tag == 2) {
        isOneHit = sender.on;
        NSLog(@"[AcecraftHack] One Hit Kill: %@", isOneHit ? @"ON" : @"OFF");
    }
}

- (void)xpFieldChanged:(UITextField *)field {
    xpMultiplier = [field.text intValue];
    if (xpMultiplier < 1) xpMultiplier = 1;
    NSLog(@"[AcecraftHack] XP Multiplier: %d", xpMultiplier);
}

@end

// ============================================================================
// SETUP FLOATING BUTTON
// ============================================================================
void setupFloatingButton() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIApplication sharedApplication] keyWindow];
        
        // Circular floating button
        floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
        floatingButton.frame = CGRectMake(30, 100, 50, 50);
        floatingButton.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.6];
        floatingButton.layer.cornerRadius = 25;
        floatingButton.clipsToBounds = YES;
        [floatingButton setTitle:@"MOD" forState:UIControlStateNormal];
        [floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        
        // Tap to open menu
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:[ModMenuController shared] action:@selector(handleButtonTap:)];
        [floatingButton addGestureRecognizer:tap];
        
        // Drag to move
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:[ModMenuController shared] action:@selector(handleButtonDrag:)];
        [floatingButton addGestureRecognizer:pan];
        
        [window addSubview:floatingButton];
        NSLog(@"[AcecraftHack] Floating button added to window");
    });
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
%ctor {
    NSLog(@"[AcecraftHack] Tweak loaded!");
    setupFloatingButton();
    setupNativeHooks();
}
