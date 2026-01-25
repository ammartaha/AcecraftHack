#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>

// ============================================================================
// TRACER V3 - Works with any Unity version!
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
                   [NSString stringWithFormat:@"acecraft_v3_%@.txt", timestamp]];
    
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    
    logToFile(@"=== ACECRAFT TRACER V3 ===");
}

// ============================================================================
// IL2CPP API - Multiple methods to get function pointers
// ============================================================================
typedef void* (*il2cpp_domain_get_t)(void);
typedef void* (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* size);
typedef void* (*il2cpp_assembly_get_image_t)(void* assembly);
typedef void* (*il2cpp_class_from_name_t)(void* image, const char* namespaze, const char* name);
typedef void* (*il2cpp_class_get_methods_t)(void* klass, void** iter);
typedef void* (*il2cpp_class_get_method_from_name_t)(void* klass, const char* name, int argsCount);
typedef const char* (*il2cpp_method_get_name_t)(void* method);
typedef void* (*il2cpp_runtime_invoke_t)(void* method, void* obj, void** params, void** exc);

// Multiple names for the same function in different Unity versions
typedef void* (*get_method_pointer_t)(void* method);

static il2cpp_domain_get_t il2cpp_domain_get = NULL;
static il2cpp_domain_get_assemblies_t il2cpp_domain_get_assemblies = NULL;
static il2cpp_assembly_get_image_t il2cpp_assembly_get_image = NULL;
static il2cpp_class_from_name_t il2cpp_class_from_name = NULL;
static il2cpp_class_get_methods_t il2cpp_class_get_methods = NULL;
static il2cpp_class_get_method_from_name_t il2cpp_class_get_method_from_name = NULL;
static il2cpp_method_get_name_t il2cpp_method_get_name = NULL;
static get_method_pointer_t get_method_pointer = NULL;

// ============================================================================
// METHOD INFO STRUCT - Read pointer directly from struct!
// In il2cpp, MethodInfo has the pointer at the very first field
// ============================================================================
typedef struct Il2CppMethodInfo {
    void* methodPointer;  // First field is always the function pointer!
    void* invoker_method;
    const char* name;
    // ... more fields
} Il2CppMethodInfo;

void* getMethodPointer(void* methodInfo) {
    if (!methodInfo) return NULL;
    
    // Method 1: Try the exported function
    if (get_method_pointer) {
        return get_method_pointer(methodInfo);
    }
    
    // Method 2: Read directly from struct (first field is usually the pointer)
    Il2CppMethodInfo* info = (Il2CppMethodInfo*)methodInfo;
    return info->methodPointer;
}

// ============================================================================
// HOOK FUNCTIONS
// ============================================================================
static void (*orig_BulletManager_SpawnBullet)(void* self, void* bulletData) = NULL;
static void (*orig_Bullet_SetHp)(void* self, void* hp) = NULL;
static void* (*orig_BulletManager_Spawn)(void* self, void* data) = NULL;

void hook_BulletManager_SpawnBullet(void* self, void* bulletData) {
    logToFile([NSString stringWithFormat:@">>> SpawnBullet! data=%p", bulletData]);
    hookCount++;
    if (orig_BulletManager_SpawnBullet) orig_BulletManager_SpawnBullet(self, bulletData);
}

void hook_Bullet_SetHp(void* self, void* hp) {
    logToFile([NSString stringWithFormat:@">>> Bullet.SetHp! hp=%p", hp]);
    hookCount++;
    if (orig_Bullet_SetHp) orig_Bullet_SetHp(self, hp);
}

void* hook_BulletManager_Spawn(void* self, void* data) {
    logToFile(@">>> BulletManager.Spawn!");
    hookCount++;
    if (orig_BulletManager_Spawn) return orig_BulletManager_Spawn(self, data);
    return NULL;
}

// ============================================================================
// FIND AND HOOK
// ============================================================================
bool findAndHook(const char* namespaze, const char* className, const char* methodName, 
                 int argCount, void* hookFunc, void** origFunc) {
    if (!il2cpp_domain_get || !il2cpp_class_from_name) return false;
    
    void* domain = il2cpp_domain_get();
    if (!domain) { logToFile(@"No domain"); return false; }
    
    size_t size = 0;
    void** assemblies = il2cpp_domain_get_assemblies(domain, &size);
    logToFile([NSString stringWithFormat:@"Found %zu assemblies", size]);
    
    for (size_t i = 0; i < size; i++) {
        void* image = il2cpp_assembly_get_image(assemblies[i]);
        if (!image) continue;
        
        void* klass = il2cpp_class_from_name(image, namespaze, className);
        if (klass) {
            void* method = il2cpp_class_get_method_from_name(klass, methodName, argCount);
            if (method) {
                void* funcPtr = getMethodPointer(method);
                
                logToFile([NSString stringWithFormat:@"Found %s.%s.%s method=%p ptr=%p", 
                           namespaze, className, methodName, method, funcPtr]);
                
                if (funcPtr && funcPtr != method) {
                    MSHookFunction(funcPtr, hookFunc, origFunc);
                    logToFile([NSString stringWithFormat:@"✓ HOOKED at %p", funcPtr]);
                    return true;
                }
            }
        }
    }
    return false;
}

// ============================================================================
// LIST ALL METHODS
// ============================================================================
void listMethods(const char* namespaze, const char* className) {
    if (!il2cpp_domain_get || !il2cpp_class_from_name) return;
    
    void* domain = il2cpp_domain_get();
    if (!domain) return;
    
    size_t size = 0;
    void** assemblies = il2cpp_domain_get_assemblies(domain, &size);
    
    for (size_t i = 0; i < size; i++) {
        void* image = il2cpp_assembly_get_image(assemblies[i]);
        if (!image) continue;
        
        void* klass = il2cpp_class_from_name(image, namespaze, className);
        if (klass) {
            logToFile([NSString stringWithFormat:@"=== %s.%s methods ===", namespaze, className]);
            
            void* iter = NULL;
            void* method;
            int n = 0;
            while ((method = il2cpp_class_get_methods(klass, &iter)) != NULL && n < 30) {
                const char* name = il2cpp_method_get_name ? il2cpp_method_get_name(method) : "?";
                void* ptr = getMethodPointer(method);
                logToFile([NSString stringWithFormat:@"  %s -> %p", name, ptr]);
                n++;
            }
            return;
        }
    }
    logToFile([NSString stringWithFormat:@"Class %s.%s NOT FOUND", namespaze, className]);
}

// ============================================================================
// LOAD IL2CPP
// ============================================================================
void loadIl2Cpp() {
    void* h = dlopen(NULL, RTLD_NOW);
    
    il2cpp_domain_get = (il2cpp_domain_get_t)dlsym(h, "il2cpp_domain_get");
    il2cpp_domain_get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(h, "il2cpp_domain_get_assemblies");
    il2cpp_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(h, "il2cpp_assembly_get_image");
    il2cpp_class_from_name = (il2cpp_class_from_name_t)dlsym(h, "il2cpp_class_from_name");
    il2cpp_class_get_methods = (il2cpp_class_get_methods_t)dlsym(h, "il2cpp_class_get_methods");
    il2cpp_class_get_method_from_name = (il2cpp_class_get_method_from_name_t)dlsym(h, "il2cpp_class_get_method_from_name");
    il2cpp_method_get_name = (il2cpp_method_get_name_t)dlsym(h, "il2cpp_method_get_name");
    
    // Try multiple names for getting method pointer
    get_method_pointer = (get_method_pointer_t)dlsym(h, "il2cpp_method_get_pointer");
    if (!get_method_pointer) get_method_pointer = (get_method_pointer_t)dlsym(h, "il2cpp_method_get_function_pointer");
    if (!get_method_pointer) get_method_pointer = (get_method_pointer_t)dlsym(h, "il2cpp_resolve_icall");
    
    logToFile([NSString stringWithFormat:@"il2cpp_domain_get: %p", il2cpp_domain_get]);
    logToFile([NSString stringWithFormat:@"il2cpp_class_from_name: %p", il2cpp_class_from_name]);
    logToFile([NSString stringWithFormat:@"il2cpp_class_get_methods: %p", il2cpp_class_get_methods]);
    logToFile([NSString stringWithFormat:@"get_method_pointer: %p (will use struct if NULL)", get_method_pointer]);
}

// ============================================================================
// SETUP
// ============================================================================
void setup() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        logToFile(@"Loading il2cpp...");
        loadIl2Cpp();
        
        if (!il2cpp_domain_get) {
            logToFile(@"FATAL: il2cpp_domain_get not found!");
            return;
        }
        
        logToFile(@"Discovering classes...");
        
        // List methods to see what's available
        listMethods("BB", "Player");
        listMethods("BB", "BulletManager");  
        listMethods("BB", "Bullet");
        listMethods("BB", "BulletData");
        listMethods("", "Player");  // Try without namespace too
        
        logToFile(@"Attempting hooks...");
        
        // Try to hook
        findAndHook("BB", "BulletManager", "SpawnBullet", 1, 
                    (void*)hook_BulletManager_SpawnBullet, (void**)&orig_BulletManager_SpawnBullet);
        findAndHook("BB", "BulletManager", "Spawn", 1, 
                    (void*)hook_BulletManager_Spawn, (void**)&orig_BulletManager_Spawn);
        findAndHook("BB", "Bullet", "SetHp", 1, 
                    (void*)hook_Bullet_SetHp, (void**)&orig_Bullet_SetHp);
        
        logToFile(@"=== SETUP COMPLETE ===");
        logToFile([NSString stringWithFormat:@"Log: %@", logFilePath]);
    });
}

// ============================================================================
// UI
// ============================================================================
static UILabel *label = nil;

void setupUI() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *w = [[UIApplication sharedApplication] keyWindow];
        label = [[UILabel alloc] initWithFrame:CGRectMake(10, 50, 180, 50)];
        label.backgroundColor = [[UIColor orangeColor] colorWithAlphaComponent:0.9];
        label.textColor = [UIColor blackColor];
        label.font = [UIFont boldSystemFontOfSize:10];
        label.numberOfLines = 2;
        label.text = @"V3 Loading...";
        label.textAlignment = NSTextAlignmentCenter;
        label.layer.cornerRadius = 6;
        label.clipsToBounds = YES;
        [w addSubview:label];
        
        [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
            label.text = [NSString stringWithFormat:@"V3 Hooks:%d Calls:%d", hookCount, callCount];
            if (hookCount > 0) label.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.9];
        }];
    });
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
%ctor {
    NSLog(@"[ACE] V3 Loading");
    initLogFile();
    setupUI();
    setup();
}
