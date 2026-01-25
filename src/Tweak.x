#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>

// ============================================================================
// ADVANCED TRACER V2 - Actually hooks found methods!
// ============================================================================

static NSString *logFilePath = nil;
static NSFileHandle *logFileHandle = nil;
static int callCount = 0;
static int hookCount = 0;

// ============================================================================
// LOGGING
// ============================================================================
void logToFile(NSString *message) {
    if (!logFileHandle) return;
    
    NSString *timestamp = [[NSDateFormatter localizedStringFromDate:[NSDate date]
                                                          dateStyle:NSDateFormatterNoStyle
                                                          timeStyle:NSDateFormatterMediumStyle] stringByAppendingString:@" "];
    NSString *logLine = [NSString stringWithFormat:@"[%d] %@%@\n", callCount++, timestamp, message];
    
    [logFileHandle writeData:[logLine dataUsingEncoding:NSUTF8StringEncoding]];
    [logFileHandle synchronizeFile];
    NSLog(@"[ACE] %@", message);
}

void initLogFile() {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = [paths firstObject];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    logFilePath = [documentsDir stringByAppendingPathComponent:
                   [NSString stringWithFormat:@"acecraft_v2_%@.txt", timestamp]];
    
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    
    logToFile(@"=== ACECRAFT TRACER V2 - HOOKS ENABLED ===");
}

// ============================================================================
// IL2CPP API TYPES
// ============================================================================
typedef void* (*il2cpp_domain_get_t)(void);
typedef void* (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* size);
typedef void* (*il2cpp_assembly_get_image_t)(void* assembly);
typedef void* (*il2cpp_class_from_name_t)(void* image, const char* namespaze, const char* name);
typedef void* (*il2cpp_class_get_methods_t)(void* klass, void** iter);
typedef void* (*il2cpp_class_get_method_from_name_t)(void* klass, const char* name, int argsCount);
typedef const char* (*il2cpp_method_get_name_t)(void* method);
typedef void* (*il2cpp_method_get_pointer_t)(void* method);  // THIS IS KEY!

static il2cpp_domain_get_t il2cpp_domain_get = NULL;
static il2cpp_domain_get_assemblies_t il2cpp_domain_get_assemblies = NULL;
static il2cpp_assembly_get_image_t il2cpp_assembly_get_image = NULL;
static il2cpp_class_from_name_t il2cpp_class_from_name = NULL;
static il2cpp_class_get_methods_t il2cpp_class_get_methods = NULL;
static il2cpp_class_get_method_from_name_t il2cpp_class_get_method_from_name = NULL;
static il2cpp_method_get_name_t il2cpp_method_get_name = NULL;
static il2cpp_method_get_pointer_t il2cpp_method_get_pointer = NULL;

// ============================================================================
// ORIGINAL FUNCTION POINTERS
// ============================================================================
static void (*orig_BulletManager_SpawnBullet)(void* self, void* bulletData) = NULL;
static void (*orig_Bullet_SetHp)(void* self, void* hp) = NULL;
static void (*orig_Player_Hit)(void* self) = NULL;
static void (*orig_Player_TakeDamage)(void* self, void* damage) = NULL;
static void* (*orig_BulletManager_Spawn)(void* self, void* data) = NULL;

// ============================================================================
// HOOK FUNCTIONS - These will log when called!
// ============================================================================
void hook_BulletManager_SpawnBullet(void* self, void* bulletData) {
    logToFile([NSString stringWithFormat:@">>> SpawnBullet! self=%p bulletData=%p", self, bulletData]);
    hookCount++;
    if (orig_BulletManager_SpawnBullet) {
        orig_BulletManager_SpawnBullet(self, bulletData);
    }
}

void hook_Bullet_SetHp(void* self, void* hp) {
    logToFile([NSString stringWithFormat:@">>> SetHp! self=%p hp=%p", self, hp]);
    hookCount++;
    if (orig_Bullet_SetHp) {
        orig_Bullet_SetHp(self, hp);
    }
}

void hook_Player_Hit(void* self) {
    logToFile([NSString stringWithFormat:@">>> Player.Hit! self=%p", self]);
    hookCount++;
    if (orig_Player_Hit) {
        orig_Player_Hit(self);
    }
}

void hook_Player_TakeDamage(void* self, void* damage) {
    logToFile([NSString stringWithFormat:@">>> Player.TakeDamage! self=%p damage=%p", self, damage]);
    hookCount++;
    if (orig_Player_TakeDamage) {
        orig_Player_TakeDamage(self, damage);
    }
}

void* hook_BulletManager_Spawn(void* self, void* data) {
    logToFile([NSString stringWithFormat:@">>> BulletManager.Spawn! self=%p", self]);
    hookCount++;
    if (orig_BulletManager_Spawn) {
        return orig_BulletManager_Spawn(self, data);
    }
    return NULL;
}

// ============================================================================
// FIND AND HOOK A METHOD
// ============================================================================
bool findAndHookMethod(const char* namespaze, const char* className, const char* methodName, 
                       int argCount, void* hookFunc, void** origFunc) {
    if (!il2cpp_domain_get || !il2cpp_class_from_name || !il2cpp_method_get_pointer) {
        return false;
    }
    
    void* domain = il2cpp_domain_get();
    if (!domain) return false;
    
    size_t size = 0;
    void** assemblies = il2cpp_domain_get_assemblies(domain, &size);
    
    for (size_t i = 0; i < size; i++) {
        void* image = il2cpp_assembly_get_image(assemblies[i]);
        if (!image) continue;
        
        void* klass = il2cpp_class_from_name(image, namespaze, className);
        if (klass) {
            void* method = il2cpp_class_get_method_from_name(klass, methodName, argCount);
            if (method) {
                // GET THE ACTUAL FUNCTION POINTER!
                void* funcPtr = il2cpp_method_get_pointer(method);
                if (funcPtr) {
                    MSHookFunction(funcPtr, hookFunc, origFunc);
                    logToFile([NSString stringWithFormat:@"HOOKED %s.%s.%s at %p", 
                               namespaze, className, methodName, funcPtr]);
                    return true;
                } else {
                    logToFile([NSString stringWithFormat:@"Found %s.%s.%s but couldn't get pointer", 
                               namespaze, className, methodName]);
                }
            }
        }
    }
    
    return false;
}

// ============================================================================
// LIST ALL METHODS IN A CLASS (for discovery)
// ============================================================================
void listClassMethods(const char* namespaze, const char* className) {
    if (!il2cpp_domain_get || !il2cpp_class_from_name || !il2cpp_class_get_methods) {
        return;
    }
    
    void* domain = il2cpp_domain_get();
    if (!domain) return;
    
    size_t size = 0;
    void** assemblies = il2cpp_domain_get_assemblies(domain, &size);
    
    for (size_t i = 0; i < size; i++) {
        void* image = il2cpp_assembly_get_image(assemblies[i]);
        if (!image) continue;
        
        void* klass = il2cpp_class_from_name(image, namespaze, className);
        if (klass) {
            logToFile([NSString stringWithFormat:@"=== Methods in %s.%s ===", namespaze, className]);
            
            void* iter = NULL;
            void* method;
            int count = 0;
            while ((method = il2cpp_class_get_methods(klass, &iter)) != NULL && count < 50) {
                const char* name = il2cpp_method_get_name(method);
                if (name) {
                    logToFile([NSString stringWithFormat:@"  - %s", name]);
                }
                count++;
            }
            return;
        }
    }
    
    logToFile([NSString stringWithFormat:@"Class %s.%s not found", namespaze, className]);
}

// ============================================================================
// LOAD IL2CPP FUNCTIONS
// ============================================================================
bool loadIl2CppFunctions() {
    void* handle = dlopen(NULL, RTLD_NOW);
    
    il2cpp_domain_get = (il2cpp_domain_get_t)dlsym(handle, "il2cpp_domain_get");
    il2cpp_domain_get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(handle, "il2cpp_domain_get_assemblies");
    il2cpp_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(handle, "il2cpp_assembly_get_image");
    il2cpp_class_from_name = (il2cpp_class_from_name_t)dlsym(handle, "il2cpp_class_from_name");
    il2cpp_class_get_methods = (il2cpp_class_get_methods_t)dlsym(handle, "il2cpp_class_get_methods");
    il2cpp_class_get_method_from_name = (il2cpp_class_get_method_from_name_t)dlsym(handle, "il2cpp_class_get_method_from_name");
    il2cpp_method_get_name = (il2cpp_method_get_name_t)dlsym(handle, "il2cpp_method_get_name");
    il2cpp_method_get_pointer = (il2cpp_method_get_pointer_t)dlsym(handle, "il2cpp_method_get_pointer");
    
    if (il2cpp_domain_get) logToFile(@"Found il2cpp_domain_get");
    if (il2cpp_method_get_pointer) logToFile(@"Found il2cpp_method_get_pointer (CRITICAL!)");
    
    return il2cpp_domain_get && il2cpp_method_get_pointer;
}

// ============================================================================
// SETUP HOOKS
// ============================================================================
void setupHooks() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        logToFile(@"Loading il2cpp functions...");
        
        if (!loadIl2CppFunctions()) {
            logToFile(@"ERROR: Failed to load il2cpp functions!");
            return;
        }
        
        logToFile(@"Hooking game methods...");
        
        // Hook BulletManager methods (namespace "BB")
        findAndHookMethod("BB", "BulletManager", "SpawnBullet", 1, 
                          (void*)hook_BulletManager_SpawnBullet, (void**)&orig_BulletManager_SpawnBullet);
        
        findAndHookMethod("BB", "BulletManager", "Spawn", 1, 
                          (void*)hook_BulletManager_Spawn, (void**)&orig_BulletManager_Spawn);
        
        // Hook Bullet methods
        findAndHookMethod("BB", "Bullet", "SetHp", 1, 
                          (void*)hook_Bullet_SetHp, (void**)&orig_Bullet_SetHp);
        
        // Hook Player methods (try different namespaces)
        findAndHookMethod("BB", "Player", "Hit", 0, 
                          (void*)hook_Player_Hit, (void**)&orig_Player_Hit);
        
        findAndHookMethod("", "Player", "Hit", 0, 
                          (void*)hook_Player_Hit, (void**)&orig_Player_Hit);
        
        findAndHookMethod("BB", "Player", "TakeDamage", 1, 
                          (void*)hook_Player_TakeDamage, (void**)&orig_Player_TakeDamage);
        
        // List methods in key classes to discover what's available
        logToFile(@"Discovering class methods...");
        listClassMethods("BB", "Player");
        listClassMethods("BB", "BulletManager");
        listClassMethods("BB", "Bullet");
        
        logToFile(@"=== HOOKS INSTALLED - PLAY THE GAME! ===");
        logToFile([NSString stringWithFormat:@"Log file: %@", logFilePath]);
    });
}

// ============================================================================
// UI
// ============================================================================
static UILabel *statusLabel = nil;

void setupUI() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIApplication sharedApplication] keyWindow];
        
        statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 50, 200, 60)];
        statusLabel.backgroundColor = [[UIColor purpleColor] colorWithAlphaComponent:0.8];
        statusLabel.textColor = [UIColor whiteColor];
        statusLabel.font = [UIFont boldSystemFontOfSize:11];
        statusLabel.numberOfLines = 3;
        statusLabel.text = @"🎮 TRACER V2\nWaiting...";
        statusLabel.layer.cornerRadius = 8;
        statusLabel.clipsToBounds = YES;
        statusLabel.textAlignment = NSTextAlignmentCenter;
        
        [window addSubview:statusLabel];
        
        [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
            statusLabel.text = [NSString stringWithFormat:@"🎮 TRACER V2\nHooks: %d\nCalls: %d", 
                               hookCount, callCount];
            if (hookCount > 0) {
                statusLabel.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.8];
            }
        }];
    });
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
%ctor {
    NSLog(@"[ACE] === TRACER V2 LOADING ===");
    initLogFile();
    setupUI();
    setupHooks();
}
