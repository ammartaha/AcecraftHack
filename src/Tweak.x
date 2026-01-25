#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>

// ============================================================================
// TRACER V4 - MEMORY INSPECTOR
// ============================================================================

static NSString *logFilePath = nil;
static NSFileHandle *logFileHandle = nil;

static uintptr_t unityBase = 0;

// ============================================================================
// LOGGING
// ============================================================================
void logToFile(NSString *message) {
    if (!logFileHandle) return;
    
    // Add simple queuing to prevent partial writes
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
    
    logFilePath = [documentsDir stringByAppendingPathComponent:
                   [NSString stringWithFormat:@"acecraft_v4_%@.txt", timestamp]];
    
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    
    logToFile(@"=== ACECRAFT TRACER V4: MEMORY INSPECTOR ===");
}

// ============================================================================
// IL2CPP TYPES
// ============================================================================
typedef void* (*il2cpp_domain_get_t)(void);
typedef void* (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* size);
typedef void* (*il2cpp_assembly_get_image_t)(void* assembly);
typedef void* (*il2cpp_class_from_name_t)(void* image, const char* namespaze, const char* name);
typedef void* (*il2cpp_class_get_methods_t)(void* klass, void** iter);
typedef const char* (*il2cpp_method_get_name_t)(void* method);

static il2cpp_domain_get_t il2cpp_domain_get = NULL;
static il2cpp_domain_get_assemblies_t il2cpp_domain_get_assemblies = NULL;
static il2cpp_assembly_get_image_t il2cpp_assembly_get_image = NULL;
static il2cpp_class_from_name_t il2cpp_class_from_name = NULL;
static il2cpp_class_get_methods_t il2cpp_class_get_methods = NULL;
static il2cpp_method_get_name_t il2cpp_method_get_name = NULL;

// ============================================================================
// MEMORY UTILS
// ============================================================================
uintptr_t getUnityBase() {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "UnityFramework")) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

// Check if a pointer is likely a code address in UnityFramework
bool isLikelyCodePointer(void* ptr) {
    uintptr_t addr = (uintptr_t)ptr;
    // Allow range of 100MB from base, just heuristic
    return (addr > unityBase && addr < unityBase + 0x10000000); 
}

// Dump struct memory to find pointers
void dumpMemory(void* ptr, int size) {
    if (!ptr) return;
    
    NSMutableString *hex = [NSMutableString string];
    uint64_t *p = (uint64_t*)ptr;
    
    for (int i = 0; i < size/8; i++) {
        uint64_t val = p[i];
        [hex appendFormat:@"%02X: 0x%016llx ", i*8, val];
        
        if (isLikelyCodePointer((void*)val)) {
            [hex appendString:@" [POSSIBLE CODE]"];
        }
        [hex appendString:@"\n"];
    }
    logToFile(hex);
}

// ============================================================================
// INSPECT METHOD
// ============================================================================
void inspectMethod(void* method) {
    if (!method) return;
    
    const char* name = il2cpp_method_get_name ? il2cpp_method_get_name(method) : "?";
    logToFile([NSString stringWithFormat:@"--- Inspecting Method: %s (%p) ---", name, method]);
    
    // Dump first 64 bytes of MethodInfo struct
    dumpMemory(method, 64);
}

// ============================================================================
// INSPECT CLASS
// ============================================================================
void inspectClass(const char* namespaze, const char* className) {
    if (!il2cpp_domain_get) return;
    
    void* domain = il2cpp_domain_get();
    size_t size = 0;
    void** assemblies = il2cpp_domain_get_assemblies(domain, &size);
    
    for (size_t i = 0; i < size; i++) {
        void* image = il2cpp_assembly_get_image(assemblies[i]);
        if (!image) continue;
        
        void* klass = il2cpp_class_from_name(image, namespaze, className);
        if (klass) {
            logToFile([NSString stringWithFormat:@"=== FOUND CLASS %s.%s ===", namespaze, className]);
            
            void* iter = NULL;
            void* method;
            while ((method = il2cpp_class_get_methods(klass, &iter)) != NULL) {
                const char* mName = il2cpp_method_get_name ? il2cpp_method_get_name(method) : "?";
                
                // Only inspect interesting methods
                if (strstr(mName, "SetHp") || strstr(mName, "SpawnBullet") || 
                    strstr(mName, "Hit") || strstr(mName, "TakeDamage")) {
                    inspectMethod(method);
                }
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
    il2cpp_method_get_name = (il2cpp_method_get_name_t)dlsym(h, "il2cpp_method_get_name");
}

// ============================================================================
// SETUP
// ============================================================================
void setup() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        unityBase = getUnityBase();
        logToFile([NSString stringWithFormat:@"Unity Base: 0x%lx", unityBase]);
        
        loadIl2Cpp();
        
        if (!il2cpp_domain_get) {
            logToFile(@"Failed to load il2cpp functions");
            return;
        }
        
        // Inspect structs to find where the pointer is living
        inspectClass("BB", "Player");
        inspectClass("BB", "Bullet");
        inspectClass("BB", "BulletManager");
        
        logToFile(@"=== INSPECTION COMPLETE ===");
    });
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
%ctor {
    NSLog(@"[ACE] V4 Loading");
    initLogFile();
    setup();
}
