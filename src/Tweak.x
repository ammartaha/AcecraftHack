#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>
#import "Utils.h"

// ============================================================================
// TWEAK V8 - CLASS DUMPER & DEBUGGER
// ============================================================================

static NSString *logFilePath = nil;
static NSFileHandle *logFileHandle = nil;
static UIButton *menuButton = nil;

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
                   [NSString stringWithFormat:@"acecraft_v8_%@.txt", timestamp]];
    
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    
    logToFile(@"=== ACECRAFT TRACER V8: CLASS DUMPER ===");
}

// ============================================================================
// IL2CPP TYPES
// ============================================================================
typedef void* (*il2cpp_domain_get_t)(void);
typedef void* (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* size);
typedef void* (*il2cpp_assembly_get_image_t)(void* assembly);
typedef void* (*il2cpp_image_get_name_t)(void* image);
typedef size_t (*il2cpp_image_get_class_count_t)(void* image);
typedef void* (*il2cpp_image_get_class_t)(void* image, size_t index);
typedef const char* (*il2cpp_class_get_name_t)(void* klass);
typedef const char* (*il2cpp_class_get_namespace_t)(void* klass);
typedef void* (*il2cpp_class_get_methods_t)(void* klass, void** iter);
typedef const char* (*il2cpp_method_get_name_t)(void* method);

static il2cpp_domain_get_t il2cpp_domain_get = NULL;
static il2cpp_domain_get_assemblies_t il2cpp_domain_get_assemblies = NULL;
static il2cpp_assembly_get_image_t il2cpp_assembly_get_image = NULL;
static il2cpp_image_get_name_t il2cpp_image_get_name = NULL;
static il2cpp_image_get_class_count_t il2cpp_image_get_class_count = NULL;
static il2cpp_image_get_class_t il2cpp_image_get_class = NULL;
static il2cpp_class_get_name_t il2cpp_class_get_name = NULL;
static il2cpp_class_get_namespace_t il2cpp_class_get_namespace = NULL;
static il2cpp_class_get_methods_t il2cpp_class_get_methods = NULL;
static il2cpp_method_get_name_t il2cpp_method_get_name = NULL;

void loadIl2Cpp() {
    void* h = dlopen(NULL, RTLD_NOW);
    if (!h) return;
    il2cpp_domain_get = (il2cpp_domain_get_t)dlsym(h, "il2cpp_domain_get");
    il2cpp_domain_get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(h, "il2cpp_domain_get_assemblies");
    il2cpp_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(h, "il2cpp_assembly_get_image");
    il2cpp_image_get_name = (il2cpp_image_get_name_t)dlsym(h, "il2cpp_image_get_name");
    il2cpp_image_get_class_count = (il2cpp_image_get_class_count_t)dlsym(h, "il2cpp_image_get_class_count");
    il2cpp_image_get_class = (il2cpp_image_get_class_t)dlsym(h, "il2cpp_image_get_class");
    il2cpp_class_get_name = (il2cpp_class_get_name_t)dlsym(h, "il2cpp_class_get_name");
    il2cpp_class_get_namespace = (il2cpp_class_get_namespace_t)dlsym(h, "il2cpp_class_get_namespace");
    il2cpp_class_get_methods = (il2cpp_class_get_methods_t)dlsym(h, "il2cpp_class_get_methods");
    il2cpp_method_get_name = (il2cpp_method_get_name_t)dlsym(h, "il2cpp_method_get_name");
}

// ============================================================================
// INSPECTOR
// ============================================================================
void inspectClasses() {
    if (!il2cpp_domain_get) return;
    
    logToFile(@"Starting Class Dump...");
    void* domain = il2cpp_domain_get();
    size_t size = 0;
    void** assemblies = il2cpp_domain_get_assemblies(domain, &size);
    
    for (size_t i = 0; i < size; i++) {
        void* image = il2cpp_assembly_get_image(assemblies[i]);
        const char* imgName = il2cpp_image_get_name(image);
        logToFile([NSString stringWithFormat:@"Assembly: %s", imgName]);
        
        // Search specific assemblies to save time
        if (strstr(imgName, "Assembly-CSharp") || strstr(imgName, "Logic") || strstr(imgName, "Model")) {
            size_t classCount = il2cpp_image_get_class_count(image);
            for (size_t j = 0; j < classCount; j++) {
                void* klass = il2cpp_image_get_class(image, j);
                const char* name = il2cpp_class_get_name(klass);
                const char* ns = il2cpp_class_get_namespace(klass);
                
                // Filter for interesting classes
                if (strstr(name, "Lua") || strstr(name, "Bridge") || strstr(name, "Player") || 
                    strstr(name, "Event") || strstr(name, "Damage") || strstr(name, "Hit")) {
                    logToFile([NSString stringWithFormat:@"  FOUND: %s.%s", ns, name]);
                }
            }
        }
    }
    logToFile(@"Class Dump Complete.");
}

// ============================================================================
// UI
// ============================================================================
@interface ModMenuController : NSObject
+ (void)showMenu;
@end

@implementation ModMenuController
+ (void)showMenu {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Acecraft Hack V8"
                                                                   message:@"Class Dumper Running..."
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:nil]];
    
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (rootVC) {
        [rootVC presentViewController:alert animated:YES completion:nil];
    }
}
@end

void setupMenuButton() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
        if (!mainWindow) return;
        
        menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
        menuButton.frame = CGRectMake(50, 150, 50, 50);
        menuButton.backgroundColor = [[UIColor blueColor] colorWithAlphaComponent:0.8];
        menuButton.layer.cornerRadius = 25;
        [menuButton setTitle:@"V8" forState:UIControlStateNormal];
        
        [menuButton addTarget:[ModMenuController class] action:@selector(showMenu) forControlEvents:UIControlEventTouchUpInside];
        
        [mainWindow addSubview:menuButton];
        [mainWindow bringSubviewToFront:menuButton];
    });
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
%ctor {
    NSLog(@"[Acecraft] V8 Loading...");
    initLogFile();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        loadIl2Cpp();
        inspectClasses(); // Run the dump immediately on load
        setupMenuButton();
    });
}
