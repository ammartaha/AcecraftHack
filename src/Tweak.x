#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <CydiaSubstrate/CydiaSubstrate.h>
#import "Utils.h"

// ============================================================================
// TWEAK V10 - METHOD DUMPER
// ============================================================================
// Goal: Find the "Execute" or "Handler" methods inside the Logic classes

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
                   [NSString stringWithFormat:@"acecraft_v10_%@.txt", timestamp]];
    
    [[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil];
    logFileHandle = [NSFileHandle fileHandleForWritingAtPath:logFilePath];
    
    logToFile(@"=== ACECRAFT TRACER V10: METHOD DUMPER ===");
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

void loadIl2Cpp() {
    void* h = dlopen(NULL, RTLD_NOW);
    if (!h) return;
    il2cpp_domain_get = (il2cpp_domain_get_t)dlsym(h, "il2cpp_domain_get");
    il2cpp_domain_get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(h, "il2cpp_domain_get_assemblies");
    il2cpp_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(h, "il2cpp_assembly_get_image");
    il2cpp_class_from_name = (il2cpp_class_from_name_t)dlsym(h, "il2cpp_class_from_name");
    il2cpp_class_get_methods = (il2cpp_class_get_methods_t)dlsym(h, "il2cpp_class_get_methods");
    il2cpp_method_get_name = (il2cpp_method_get_name_t)dlsym(h, "il2cpp_method_get_name");
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
// INSPECTOR
// ============================================================================
void dumpMethodsForClass(const char* namespaze, const char* className) {
    void* klass = findClass(namespaze, className);
    if (!klass) {
        logToFile([NSString stringWithFormat:@"[ERR] Class %s.%s NOT FOUND", namespaze, className]);
        return;
    }
    
    logToFile([NSString stringWithFormat:@"=== Methods for %s.%s ===", namespaze, className]);
    
    void* iter = NULL;
    void* method;
    int count = 0;
    while ((method = il2cpp_class_get_methods(klass, &iter)) != NULL) {
        const char* mName = il2cpp_method_get_name ? il2cpp_method_get_name(method) : "?";
        void* ptr = *(void**)method;
        logToFile([NSString stringWithFormat:@"  %s () -> %p", mName, ptr]);
        count++;
    }
    if (count == 0) logToFile(@"  (No methods found or dump failed)");
}

void inspectLogicClasses() {
    logToFile(@"Starting Method Dump...");
    
    // 1. The main Player Logic System
    dumpMethodsForClass("WE.Battle.Logic", "PlayerLogic");
    
    // 2. The God Mode switch
    dumpMethodsForClass("WE.Game", "SetNoDamage");
    
    // 3. The Hurt Event (Does it have an Execute?)
    dumpMethodsForClass("WE.Battle.Logic", "PlayerHurtEvent");
    
    // 4. Force HP Lock
    dumpMethodsForClass("WE.Game", "PlayerLockHp");
    
    // 5. The Player Controller View (Frontend)
    dumpMethodsForClass("WE.Battle.View", "PlayerController");
    
    logToFile(@"Method Dump Complete.");
}

// ============================================================================
// UI
// ============================================================================
@interface ModMenuController : NSObject
+ (void)showMenu;
@end

@implementation ModMenuController
+ (void)showMenu {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Acecraft Hack V10"
                                                                   message:@"Method Dumper Running..."
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
        menuButton.frame = CGRectMake(50, 200, 50, 50);
        menuButton.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.8];
        menuButton.layer.cornerRadius = 25;
        [menuButton setTitle:@"V10" forState:UIControlStateNormal];
        
        [menuButton addTarget:[ModMenuController class] action:@selector(showMenu) forControlEvents:UIControlEventTouchUpInside];
        
        [mainWindow addSubview:menuButton];
        [mainWindow bringSubviewToFront:menuButton];
    });
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
%ctor {
    NSLog(@"[Acecraft] V10 Loading...");
    initLogFile();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        loadIl2Cpp();
        inspectLogicClasses(); // Dump on load
        setupMenuButton();
    });
}
