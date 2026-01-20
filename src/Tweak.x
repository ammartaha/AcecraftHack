#import <UIKit/UIKit.h>
#import "Utils.h"
#import "substrate.h"

// --- Global Toggles ---
static BOOL isGodMode = NO;
static BOOL isOneHit = NO;
static int xpMultiplier = 1;

// --- Interfaces for Il2Cpp Classes ---
// Defined based on dump.cs

struct BulletData_BB {
    // We need to match the struct layout exactly or access by offset if fields are private
    // For now, casting strict pointers.
    // offsets based on dump.cs
    // 0x18 string PrefabName
    // 0x58 SpawnGroup Parent
    // 0x88 FP MaxHP
};

@interface Bullet : NSObject
- (void)SetHp:(struct FP)hp;
- (void)InitInfo:(void *)bulletData; // bulletData is BulletData_BB*
@end

@interface MonoBehaviour : NSObject
@end

// --- UI Helper ---
@interface UIWindow (Tweak)
- (UIViewController *)rootViewController;
@end

UIButton *menuButton;

void showMenu() {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Acecraft Mod Menu"
                                                                   message:@"By Antigravity"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    // God Mode Toggle
    NSString *godTitle = isGodMode ? @"[ON] God Mode" : @"[OFF] God Mode";
    [alert addAction:[UIAlertAction actionWithTitle:godTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        isGodMode = !isGodMode;
        showMenu(); // Reopen to show state change
    }]];

    // One Hit Kill Toggle
    NSString *ohkTitle = isOneHit ? @"[ON] One Hit Kill" : @"[OFF] One Hit Kill";
    [alert addAction:[UIAlertAction actionWithTitle:ohkTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        isOneHit = !isOneHit;
        showMenu();
    }]];

    // XP Multiplier
    NSString *xpTitle = [NSString stringWithFormat:@"XP Multiplier: %dx", xpMultiplier];
    [alert addAction:[UIAlertAction actionWithTitle:xpTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (xpMultiplier == 1) xpMultiplier = 10;
        else if (xpMultiplier == 10) xpMultiplier = 100;
        else xpMultiplier = 1;
        showMenu();
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];

    [[[UIApplication sharedApplication] keyWindow].rootViewController presentViewController:alert animated:YES completion:nil];
}

void setupMenu() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIApplication sharedApplication] keyWindow];
        menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
        menuButton.frame = CGRectMake(50, 50, 80, 40);
        menuButton.backgroundColor = [UIColor redColor];
        [menuButton setTitle:@"MOD" forState:UIControlStateNormal];
        [menuButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [menuButton addTarget:window action:@selector(menuButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        
        // Add action to window to handle tap? No, adding target self won't work easily in C func.
        // Let's use a simpler drag handler or just add to window.
        [window addSubview:menuButton];
        
        // Simple tap handler
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:window action:@selector(handleMenuTap)];
        [menuButton addGestureRecognizer:tap];
    });
}

// --- Hooks ---

// Hook: BB.Bullet.SetHp
// RVA: 0x4530C8 (from dump.cs line 441133)
// void SetHp(FP currHp)
%hook Bullet

- (void)SetHp:(struct FP)currHp {
    if (isGodMode) {
        // Naive check: If current HP is dropping, and it's HUGE (Player), prevent it?
        // Better: Check if this Bullet is a Player.
        // How? PrefabName?
        // For now, if GodMode is on, we prevent HP reduction for EVERYONE (Bad idea) OR
        // we print the PrefabName to identifying the Player first.
        
        // If we can identify the player:
        // if ([self.PrefabName containsString:@"Hero"]) { return; }
        
        // Placeholder safe logic:
        // Only prevent death (HP <= 0)
        if (currHp._serializedValue <= 0) {
             // For God Mode we usually want to avoid taking damage at all.
             // Let's try to verify if this is the Player.
             // Assuming Player bullet/ship has 'Player' in name or strict MaxHP.
        }
    }
    %orig(currHp);
}

// Hook: BB.Bullet.InitInfo
// RVA: 0x452E10
// void InitInfo(BulletData_BB bulletData)
- (void)InitInfo:(void *)bulletDataPtr {
    if (isOneHit) {
        // We need to access bulletData fields.
        // struct BulletData_BB *data = (struct BulletData_BB *)bulletDataPtr;
        // data->MoveSpeed = FloatToFP(50.0f); // Example modification
        // We still need to find the Damage field offset!
    }
    %orig;
}

%end

// --- Constructor ---
%ctor {
    setupMenu();
    %init;
}
