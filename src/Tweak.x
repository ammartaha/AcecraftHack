#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <CydiaSubstrate/CydiaSubstrate.h>

// ============================================================================
// LOGGER MOD - Records function calls to a file
// ============================================================================

static NSString *logFilePath = nil;
static NSFileHandle *logFileHandle = nil;
static int callCount = 0;

// ============================================================================
// LOGGING FUNCTION - Writes to file in Documents folder
// ============================================================================
void logToFile(NSString *message) {
    if (!logFileHandle) return;
    
    NSString *timestamp = [[NSDateFormatter localizedStringFromDate:[NSDate date]
                                                          dateStyle:NSDateFormatterNoStyle
                                                          timeStyle:NSDateFormatterMediumStyle] stringByAppendingString:@" "];
    NSString *logLine = [NSString stringWithFormat:@"[%d] %@%@\n", callCount++, timestamp, message];
    
    [logFileHandle writeData:[logLine dataUsingEncoding:NSUTF8StringEncoding]];
    [logFileHandle synchronizeFile]; // Flush immediately
    
    NSLog(@"[AcecraftLogger] %@", message);
}

void initLogFile() {
    // Get Documents directory
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = [paths firstObject];
    
    // Create log file with timestamp
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    logFilePath = [documentsDir stringByAppendingPathComponent:
                   [NSString stringWithFormat:@"acecraft_log_%@.txt", timestamp]];
    
    // Create file
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    
    NSLog(@"[AcecraftLogger] Log file created at: %@", logFilePath);
    logToFile(@"=== ACECRAFT FUNCTION LOGGER STARTED ===");
    logToFile([NSString stringWithFormat:@"Log file: %@", logFilePath]);
}

// ============================================================================
// FIXED POINT STRUCT
// ============================================================================
struct FP {
    int64_t _serializedValue;
};

static inline float FPToFloat(struct FP value) {
    return (float)value._serializedValue / 4294967296.0f;
}

// ============================================================================
// ORIGINAL FUNCTION POINTERS - We'll hook MANY functions to see which are called
// ============================================================================

// Player class
static void (*orig_Player_Hit)(void *self);

// Bullet class
static void (*orig_Bullet_SetHp)(void *self, struct FP hp);
static void (*orig_Bullet_InitInfo)(void *self, void *bulletData);
static void (*orig_Bullet_Destroy)(void *self);
static void (*orig_Bullet_UpdateLife)(void *self, struct FP lifeTime);

// BulletManager class
static void (*orig_BulletManager_SpawnBullet)(void *self, void *bulletData);
static void *(*orig_BulletManager_Spawn)(void *self, void *prefabName);
static void (*orig_BulletManager_Destroy)(void *self, void *bullet);

// BulletData_BB class
static void (*orig_BulletData_SetPosition)(void *self, void *position);
static void (*orig_BulletData_SetSpeed)(void *self, struct FP speed);
static void (*orig_BulletData_Dispose)(void *self);

// ============================================================================
// HOOKS - Log everything!
// ============================================================================

void hook_Player_Hit(void *self) {
    logToFile([NSString stringWithFormat:@"Player.Hit() called! self=%p", self]);
    orig_Player_Hit(self);
}

void hook_Bullet_SetHp(void *self, struct FP hp) {
    logToFile([NSString stringWithFormat:@"Bullet.SetHp() self=%p HP=%lld (%.2f)", 
               self, hp._serializedValue, FPToFloat(hp)]);
    orig_Bullet_SetHp(self, hp);
}

void hook_Bullet_InitInfo(void *self, void *bulletData) {
    logToFile([NSString stringWithFormat:@"Bullet.InitInfo() self=%p bulletData=%p", self, bulletData]);
    orig_Bullet_InitInfo(self, bulletData);
}

void hook_Bullet_Destroy(void *self) {
    logToFile([NSString stringWithFormat:@"Bullet.Destroy() self=%p", self]);
    orig_Bullet_Destroy(self);
}

void hook_Bullet_UpdateLife(void *self, struct FP lifeTime) {
    // This might be called frequently, so we'll log less detail
    static int updateCount = 0;
    if (updateCount++ % 100 == 0) { // Log every 100th call
        logToFile([NSString stringWithFormat:@"Bullet.UpdateLife() [x100] self=%p life=%.2f", 
                   self, FPToFloat(lifeTime)]);
    }
    orig_Bullet_UpdateLife(self, lifeTime);
}

void hook_BulletManager_SpawnBullet(void *self, void *bulletData) {
    logToFile([NSString stringWithFormat:@"BulletManager.SpawnBullet() self=%p bulletData=%p", self, bulletData]);
    
    // Try to read some fields from bulletData
    if (bulletData) {
        // MaxHP is at offset 0x88
        struct FP *maxHP = (struct FP *)((uintptr_t)bulletData + 0x88);
        // CanBeHit is at offset 0x84
        bool *canBeHit = (bool *)((uintptr_t)bulletData + 0x84);
        
        logToFile([NSString stringWithFormat:@"  -> MaxHP=%lld (%.2f), CanBeHit=%d", 
                   maxHP->_serializedValue, FPToFloat(*maxHP), *canBeHit]);
    }
    
    orig_BulletManager_SpawnBullet(self, bulletData);
}

void *hook_BulletManager_Spawn(void *self, void *prefabName) {
    logToFile([NSString stringWithFormat:@"BulletManager.Spawn() self=%p prefabName=%p", self, prefabName]);
    return orig_BulletManager_Spawn(self, prefabName);
}

void hook_BulletManager_Destroy_Bullet(void *self, void *bullet) {
    logToFile([NSString stringWithFormat:@"BulletManager.Destroy() self=%p bullet=%p", self, bullet]);
    orig_BulletManager_Destroy(self, bullet);
}

void hook_BulletData_SetPosition(void *self, void *position) {
    static int posCount = 0;
    if (posCount++ % 50 == 0) { // Log every 50th call
        logToFile([NSString stringWithFormat:@"BulletData.SetPosition() [x50] self=%p", self]);
    }
    orig_BulletData_SetPosition(self, position);
}

void hook_BulletData_SetSpeed(void *self, struct FP speed) {
    logToFile([NSString stringWithFormat:@"BulletData.SetSpeed() self=%p speed=%.2f", self, FPToFloat(speed)]);
    orig_BulletData_SetSpeed(self, speed);
}

void hook_BulletData_Dispose(void *self) {
    logToFile([NSString stringWithFormat:@"BulletData.Dispose() self=%p", self]);
    orig_BulletData_Dispose(self);
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
// SETUP ALL HOOKS
// ============================================================================
void setupLoggerHooks() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        unityBase = getUnityFrameworkBase();
        if (!unityBase) {
            logToFile(@"ERROR: UnityFramework not found!");
            return;
        }
        logToFile([NSString stringWithFormat:@"UnityFramework base: 0x%lx", unityBase]);
        
        // Hook Player.Hit - RVA: 0x453E3C
        MSHookFunction((void *)(unityBase + 0x453E3C), (void *)hook_Player_Hit, (void **)&orig_Player_Hit);
        logToFile(@"Hooked Player.Hit at 0x453E3C");
        
        // Hook Bullet.SetHp - RVA: 0x4530C8
        MSHookFunction((void *)(unityBase + 0x4530C8), (void *)hook_Bullet_SetHp, (void **)&orig_Bullet_SetHp);
        logToFile(@"Hooked Bullet.SetHp at 0x4530C8");
        
        // Hook Bullet.InitInfo - RVA: 0x452E10
        MSHookFunction((void *)(unityBase + 0x452E10), (void *)hook_Bullet_InitInfo, (void **)&orig_Bullet_InitInfo);
        logToFile(@"Hooked Bullet.InitInfo at 0x452E10");
        
        // Hook Bullet.Destroy - RVA: 0x453018
        MSHookFunction((void *)(unityBase + 0x453018), (void *)hook_Bullet_Destroy, (void **)&orig_Bullet_Destroy);
        logToFile(@"Hooked Bullet.Destroy at 0x453018");
        
        // Hook Bullet.UpdateLife - RVA: 0x452F84
        MSHookFunction((void *)(unityBase + 0x452F84), (void *)hook_Bullet_UpdateLife, (void **)&orig_Bullet_UpdateLife);
        logToFile(@"Hooked Bullet.UpdateLife at 0x452F84");
        
        // Hook BulletManager.SpawnBullet - RVA: 0x453ABC
        MSHookFunction((void *)(unityBase + 0x453ABC), (void *)hook_BulletManager_SpawnBullet, (void **)&orig_BulletManager_SpawnBullet);
        logToFile(@"Hooked BulletManager.SpawnBullet at 0x453ABC");
        
        // Hook BulletManager.Spawn - RVA: 0x4537A0
        MSHookFunction((void *)(unityBase + 0x4537A0), (void *)hook_BulletManager_Spawn, (void **)&orig_BulletManager_Spawn);
        logToFile(@"Hooked BulletManager.Spawn at 0x4537A0");
        
        // Hook BulletManager.Destroy - RVA: 0x4532B8
        MSHookFunction((void *)(unityBase + 0x4532B8), (void *)hook_BulletManager_Destroy_Bullet, (void **)&orig_BulletManager_Destroy);
        logToFile(@"Hooked BulletManager.Destroy at 0x4532B8");
        
        // Hook BulletData_BB.SetPosition - RVA: 0x34CEB8
        MSHookFunction((void *)(unityBase + 0x34CEB8), (void *)hook_BulletData_SetPosition, (void **)&orig_BulletData_SetPosition);
        logToFile(@"Hooked BulletData.SetPosition at 0x34CEB8");
        
        // Hook BulletData_BB.SetSpeed - RVA: 0x34D134
        MSHookFunction((void *)(unityBase + 0x34D134), (void *)hook_BulletData_SetSpeed, (void **)&orig_BulletData_SetSpeed);
        logToFile(@"Hooked BulletData.SetSpeed at 0x34D134");
        
        // Hook BulletData_BB.Dispose - RVA: 0x34EEC4
        MSHookFunction((void *)(unityBase + 0x34EEC4), (void *)hook_BulletData_Dispose, (void **)&orig_BulletData_Dispose);
        logToFile(@"Hooked BulletData.Dispose at 0x34EEC4");
        
        logToFile(@"=== ALL HOOKS INSTALLED ===");
        logToFile(@"Play the game now! Log will record function calls.");
        logToFile([NSString stringWithFormat:@"Log file location: %@", logFilePath]);
    });
}

// ============================================================================
// UI: Simple status indicator
// ============================================================================
static UILabel *statusLabel = nil;

void setupStatusIndicator() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIApplication sharedApplication] keyWindow];
        
        statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 50, 200, 60)];
        statusLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
        statusLabel.textColor = [UIColor greenColor];
        statusLabel.font = [UIFont fontWithName:@"Menlo" size:10];
        statusLabel.numberOfLines = 3;
        statusLabel.text = [NSString stringWithFormat:@"🔴 LOGGER ACTIVE\nCalls: %d\nCheck Documents/", callCount];
        statusLabel.layer.cornerRadius = 5;
        statusLabel.clipsToBounds = YES;
        statusLabel.textAlignment = NSTextAlignmentCenter;
        
        [window addSubview:statusLabel];
        
        // Update counter periodically
        [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
            statusLabel.text = [NSString stringWithFormat:@"🔴 LOGGER ACTIVE\nCalls: %d\nLog: Documents/", callCount];
        }];
    });
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
%ctor {
    NSLog(@"[AcecraftLogger] ==========================================");
    NSLog(@"[AcecraftLogger] LOGGER MODE - Recording all function calls");
    NSLog(@"[AcecraftLogger] ==========================================");
    
    initLogFile();
    setupStatusIndicator();
    setupLoggerHooks();
}
