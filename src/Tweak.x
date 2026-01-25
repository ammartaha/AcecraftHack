#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>
#import "Utils.h"

// ============================================================================
// TWEAK V14 - OBJECT SNIFFER
// ============================================================================
// Goal: Who is moving?
// We hook Transform.set_position.
// We check the class name of the object moving.
// Only log unique names to avoid spam.

static NSString *logFilePath = nil;
static NSFileHandle *logFileHandle = nil;
static NSMutableSet *loggedClasses = nil;

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
    
    logFilePath = [documentsDir stringByAppendingPathComponent:
                   [NSString stringWithFormat:@"acecraft_v14_%@.txt", timestamp]];
    
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    loggedClasses = [[NSMutableSet alloc] init];
    
    logToFile(@"=== ACECRAFT TRACER V14: OBJECT SNIFFER ===");
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

// Object Info
typedef void* (*il2cpp_object_get_class_t)(void* obj);
typedef const char* (*il2cpp_class_get_name_t)(void* klass);
typedef const char* (*il2cpp_class_get_namespace_t)(void* klass);

static il2cpp_domain_get_t il2cpp_domain_get = NULL;
static il2cpp_domain_get_assemblies_t il2cpp_domain_get_assemblies = NULL;
static il2cpp_assembly_get_image_t il2cpp_assembly_get_image = NULL;
static il2cpp_class_from_name_t il2cpp_class_from_name = NULL;
static il2cpp_class_get_methods_t il2cpp_class_get_methods = NULL;
static il2cpp_method_get_name_t il2cpp_method_get_name = NULL;

static il2cpp_object_get_class_t il2cpp_object_get_class = NULL;
static il2cpp_class_get_name_t il2cpp_class_get_name = NULL;
static il2cpp_class_get_namespace_t il2cpp_class_get_namespace = NULL;

void loadIl2Cpp() {
    void* h = dlopen(NULL, RTLD_NOW);
    if (!h) return;
    il2cpp_domain_get = (il2cpp_domain_get_t)dlsym(h, "il2cpp_domain_get");
    il2cpp_domain_get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(h, "il2cpp_domain_get_assemblies");
    il2cpp_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(h, "il2cpp_assembly_get_image");
    il2cpp_class_from_name = (il2cpp_class_from_name_t)dlsym(h, "il2cpp_class_from_name");
    il2cpp_class_get_methods = (il2cpp_class_get_methods_t)dlsym(h, "il2cpp_class_get_methods");
    il2cpp_method_get_name = (il2cpp_method_get_name_t)dlsym(h, "il2cpp_method_get_name");
    
    il2cpp_object_get_class = (il2cpp_object_get_class_t)dlsym(h, "il2cpp_object_get_class");
    il2cpp_class_get_name = (il2cpp_class_get_name_t)dlsym(h, "il2cpp_class_get_name");
    il2cpp_class_get_namespace = (il2cpp_class_get_namespace_t)dlsym(h, "il2cpp_class_get_namespace");
}

void* findClass(const char* namespaze, const char* className) {
    if (!il2cpp_domain_get) return NULL;
    void* domain = il2cpp_domain_get();
    size_t size = 0;
    void** assemblies = il2cpp_domain_get_assemblies(domain, &size);
    
    for (size_t i = 0; i < size; i++) {
        void* image = il2cpp_assembly_get_image(assemblies[i]);
        if (!image) continue;
        void* klass = il2cpp_class_from_name(image, namespaze, className);
        if (klass) return klass;
    }
    return NULL;
}

// ============================================================================
// HOOKS
// ============================================================================

struct Vector3 { float x, y, z; };

// UnityEngine.Transform.set_position(Vector3)
static void (*orig_set_position)(void* self, struct Vector3 pos);
void hook_set_position(void* self, struct Vector3 pos) {
    
    // Inspect who is moving!
    if (il2cpp_object_get_class && il2cpp_class_get_name && self) {
        void* klass = il2cpp_object_get_class(self);
        if (klass) {
            const char* name = il2cpp_class_get_name(klass);
            const char* ns = il2cpp_class_get_namespace(klass);
            NSString *className = [NSString stringWithFormat:@"%s.%s", ns ? ns : "", name];
            
            // Filter common spam
            if (![className containsString:@"UnityEngine"] && 
                ![className containsString:@"UI"] &&
                ![className containsString:@"Canvas"]) {
                
                @synchronized(loggedClasses) {
                    if (![loggedClasses containsObject:className]) {
                        logToFile([NSString stringWithFormat:@"[MOVE] Active Object: %@", className]);
                        [loggedClasses addObject:className];
                    }
                }
            }
        }
    }
    
    if (orig_set_position) orig_set_position(self, pos);
}

// Helper query method by name
void hookMethodByName(void* klass, const char* methodName, void* hookFn, void** origPtr) {
    if (!klass || !il2cpp_class_get_methods) return;
    
    void* iter = NULL;
    void* method;
    while ((method = il2cpp_class_get_methods(klass, &iter)) != NULL) {
        const char* mName = il2cpp_method_get_name ? il2cpp_method_get_name(method) : "";
        if (strcmp(mName, methodName) == 0) {
            void* ptr = *(void**)method;
            if (ptr) {
                MSHookFunction(ptr, hookFn, origPtr);
                logToFile([NSString stringWithFormat:@"[HOOK] Installed %s @ %p", mName, ptr]);
                return;
            }
        }
    }
    logToFile([NSString stringWithFormat:@"[WARN] Method %s NOT FOUND", methodName]);
}

// ============================================================================
// SETUP
// ============================================================================
void setupHooks() {
    loadIl2Cpp();
    
    // Hook Transform.set_position
    // Note: Transform is in UnityEngine.CoreModule.dll, usually "UnityEngine.Transform"
    void* transformClass = findClass("UnityEngine", "Transform");
    
    if (transformClass) {
        logToFile(@"[INFO] Hooking UnityEngine.Transform...");
        hookMethodByName(transformClass, "set_position", (void*)hook_set_position, (void**)&orig_set_position);
    } else {
        logToFile(@"[ERR] UnityEngine.Transform NOT FOUND!");
    }
}

%ctor {
    NSLog(@"[Acecraft] V14 Loading...");
    initLogFile();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupHooks();
    });
}
