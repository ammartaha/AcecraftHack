#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>

// ============================================================================
// ADVANCED LOGGER - Traces Unity il2cpp method calls
// ============================================================================

static NSString *logFilePath = nil;
static NSFileHandle *logFileHandle = nil;
static int callCount = 0;

// ============================================================================
// LOGGING FUNCTION
// ============================================================================
void logToFile(NSString *message) {
    if (!logFileHandle) return;
    
    NSString *timestamp = [[NSDateFormatter localizedStringFromDate:[NSDate date]
                                                          dateStyle:NSDateFormatterNoStyle
                                                          timeStyle:NSDateFormatterMediumStyle] stringByAppendingString:@" "];
    NSString *logLine = [NSString stringWithFormat:@"[%d] %@%@\n", callCount++, timestamp, message];
    
    [logFileHandle writeData:[logLine dataUsingEncoding:NSUTF8StringEncoding]];
    [logFileHandle synchronizeFile];
    
    NSLog(@"[AcecraftLog] %@", message);
}

void initLogFile() {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = [paths firstObject];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    logFilePath = [documentsDir stringByAppendingPathComponent:
                   [NSString stringWithFormat:@"acecraft_trace_%@.txt", timestamp]];
    
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    
    NSLog(@"[AcecraftLog] Trace file: %@", logFilePath);
    logToFile(@"=== ACECRAFT ADVANCED TRACER ===");
}

// ============================================================================
// FIXED POINT STRUCT
// ============================================================================
struct FP {
    int64_t _serializedValue;
};

// ============================================================================
// GET UNITYFRAMEWORK BASE
// ============================================================================
static uintptr_t unityBase = 0;

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
// IL2CPP EXPORTS - These should work on any version!
// ============================================================================
typedef void* (*il2cpp_domain_get_t)(void);
typedef void* (*il2cpp_class_from_name_t)(void* image, const char* namespaze, const char* name);
typedef void* (*il2cpp_class_get_method_from_name_t)(void* klass, const char* name, int argsCount);
typedef void* (*il2cpp_method_get_pointer_t)(void* method);
typedef void* (*il2cpp_assembly_get_image_t)(void* assembly);
typedef void** (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* size);
typedef const char* (*il2cpp_class_get_name_t)(void* klass);
typedef void* (*il2cpp_string_new_t)(const char* str);

static il2cpp_domain_get_t il2cpp_domain_get = NULL;
static il2cpp_class_from_name_t il2cpp_class_from_name = NULL;
static il2cpp_class_get_method_from_name_t il2cpp_class_get_method_from_name = NULL;
static il2cpp_assembly_get_image_t il2cpp_assembly_get_image = NULL;
static il2cpp_domain_get_assemblies_t il2cpp_domain_get_assemblies = NULL;
static il2cpp_class_get_name_t il2cpp_class_get_name = NULL;
static il2cpp_string_new_t il2cpp_string_new = NULL;

// ============================================================================
// HOOKED FUNCTIONS - Using dynamic addresses this time
// ============================================================================

// We'll hook Unity's SendMessage to see all game communications
typedef void (*Unity_SendMessage_t)(const char* objName, const char* methodName, const char* message);
static Unity_SendMessage_t orig_SendMessage = NULL;

void hook_SendMessage(const char* objName, const char* methodName, const char* message) {
    logToFile([NSString stringWithFormat:@"SendMessage: %s.%s(%s)", 
               objName ? objName : "null", 
               methodName ? methodName : "null", 
               message ? message : "null"]);
    if (orig_SendMessage) orig_SendMessage(objName, methodName, message);
}

// Hook Application.Quit to detect game exit
typedef void (*App_Quit_t)(void);
static App_Quit_t orig_AppQuit = NULL;

void hook_AppQuit(void) {
    logToFile(@"Application.Quit called!");
    if (orig_AppQuit) orig_AppQuit();
}

// ============================================================================
// IMPORT TABLE HOOKS - Hook common functions by name
// ============================================================================
void setupImportHooks() {
    // Try to find and hook UnitySendMessage from symbols
    void *unityHandle = dlopen(NULL, RTLD_NOW);
    
    // Look for UnitySendMessage - this is exported by Unity
    void *sendMsgPtr = dlsym(unityHandle, "UnitySendMessage");
    if (sendMsgPtr) {
        MSHookFunction(sendMsgPtr, (void*)hook_SendMessage, (void**)&orig_SendMessage);
        logToFile([NSString stringWithFormat:@"Hooked UnitySendMessage at %p", sendMsgPtr]);
    } else {
        logToFile(@"UnitySendMessage not found in exports");
    }
    
    // Try to find il2cpp exports
    il2cpp_domain_get = (il2cpp_domain_get_t)dlsym(unityHandle, "il2cpp_domain_get");
    il2cpp_class_from_name = (il2cpp_class_from_name_t)dlsym(unityHandle, "il2cpp_class_from_name");
    il2cpp_class_get_method_from_name = (il2cpp_class_get_method_from_name_t)dlsym(unityHandle, "il2cpp_class_get_method_from_name");
    il2cpp_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(unityHandle, "il2cpp_assembly_get_image");
    il2cpp_domain_get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(unityHandle, "il2cpp_domain_get_assemblies");
    il2cpp_class_get_name = (il2cpp_class_get_name_t)dlsym(unityHandle, "il2cpp_class_get_name");
    il2cpp_string_new = (il2cpp_string_new_t)dlsym(unityHandle, "il2cpp_string_new");
    
    if (il2cpp_domain_get) {
        logToFile(@"Found il2cpp_domain_get");
    }
    if (il2cpp_class_from_name) {
        logToFile(@"Found il2cpp_class_from_name");
    }
    if (il2cpp_class_get_method_from_name) {
        logToFile(@"Found il2cpp_class_get_method_from_name");
    }
}

// ============================================================================
// DYNAMIC IL2CPP HOOKS - Find methods at runtime
// ============================================================================
void* findIl2CppMethod(const char* namespaze, const char* className, const char* methodName, int argCount) {
    if (!il2cpp_domain_get || !il2cpp_class_from_name || !il2cpp_class_get_method_from_name) {
        return NULL;
    }
    
    void* domain = il2cpp_domain_get();
    if (!domain) return NULL;
    
    size_t size = 0;
    void** assemblies = il2cpp_domain_get_assemblies(domain, &size);
    
    for (size_t i = 0; i < size; i++) {
        void* image = il2cpp_assembly_get_image(assemblies[i]);
        if (!image) continue;
        
        void* klass = il2cpp_class_from_name(image, namespaze, className);
        if (klass) {
            void* method = il2cpp_class_get_method_from_name(klass, methodName, argCount);
            if (method) {
                logToFile([NSString stringWithFormat:@"Found %s.%s.%s", namespaze, className, methodName]);
                // Note: Need il2cpp_method_get_pointer to get actual address
                return method;
            }
        }
    }
    
    return NULL;
}

// ============================================================================
// OBJC METHOD SWIZZLE - Hook NSObject methods
// ============================================================================
static IMP orig_performSelector = NULL;

id hook_performSelector(id self, SEL _cmd, SEL aSelector) {
    const char* selName = sel_getName(aSelector);
    const char* className = object_getClassName(self);
    
    // Log interesting selectors
    if (strstr(selName, "damage") || strstr(selName, "health") || 
        strstr(selName, "exp") || strstr(selName, "gold") ||
        strstr(selName, "gem") || strstr(selName, "hit") ||
        strstr(selName, "Damage") || strstr(selName, "Health")) {
        logToFile([NSString stringWithFormat:@"ObjC: [%s %s]", className, selName]);
    }
    
    return ((id(*)(id, SEL, SEL))orig_performSelector)(self, _cmd, aSelector);
}

// ============================================================================
// SETUP ALL HOOKS
// ============================================================================
void setupAdvancedHooks() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        unityBase = getUnityFrameworkBase();
        logToFile([NSString stringWithFormat:@"UnityFramework base: 0x%lx", unityBase]);
        
        // Setup import-based hooks
        setupImportHooks();
        
        // Try to find methods dynamically
        logToFile(@"Searching for game methods...");
        
        // These will log if found
        findIl2CppMethod("BB", "BulletManager", "SpawnBullet", 1);
        findIl2CppMethod("BB", "Bullet", "SetHp", 1);
        findIl2CppMethod("", "Player", "Hit", 0);
        
        // Swizzle NSObject performSelector to catch ObjC calls
        Method method = class_getInstanceMethod([NSObject class], @selector(performSelector:));
        if (method) {
            orig_performSelector = method_setImplementation(method, (IMP)hook_performSelector);
            logToFile(@"Swizzled NSObject performSelector:");
        }
        
        logToFile(@"=== ADVANCED TRACER READY ===");
        logToFile(@"Play the game - all interesting calls will be logged!");
        logToFile([NSString stringWithFormat:@"Log file: %@", logFilePath]);
    });
}

// ============================================================================
// UI STATUS
// ============================================================================
static UILabel *statusLabel = nil;

void setupStatusUI() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIApplication sharedApplication] keyWindow];
        
        statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 50, 220, 70)];
        statusLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        statusLabel.textColor = [UIColor cyanColor];
        statusLabel.font = [UIFont fontWithName:@"Menlo" size:9];
        statusLabel.numberOfLines = 4;
        statusLabel.text = @"🔍 ADVANCED TRACER\nSearching for methods...\nPlay the game!";
        statusLabel.layer.cornerRadius = 8;
        statusLabel.clipsToBounds = YES;
        statusLabel.textAlignment = NSTextAlignmentCenter;
        
        [window addSubview:statusLabel];
        
        // Update status periodically
        [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer *timer) {
            statusLabel.text = [NSString stringWithFormat:@"🔍 ADVANCED TRACER\nCalls logged: %d\nCheck Documents/", callCount];
        }];
    });
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
%ctor {
    NSLog(@"[AcecraftLog] ==========================================");
    NSLog(@"[AcecraftLog] ADVANCED TRACER - Using dynamic method lookup");
    NSLog(@"[AcecraftLog] ==========================================");
    
    initLogFile();
    setupStatusUI();
    setupAdvancedHooks();
}
