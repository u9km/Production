#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <netdb.h>
#include <errno.h>
#include <stdarg.h>
#include <atomic>
#include <thread>

// أعلام التوقيع الرقمي (Code Signature) لإخفاء البصمة
#define CS_OPS_STATUS 0
#define CS_VALID 0x00000001
#define CS_GET_TASK_ALLOW 0x00000004 // صلاحية التطبيقات المكركة (ESign/TrollStore)
#define CS_DEBUGGED 0x10000000       // علامة الحقن

struct rebinding { const char *name; void *replacement; void **replaced; };
extern "C" int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

static std::atomic<bool> isSafeEngineActive(false);

// =================================================================
// ===============  الفلتر الآمن (بدون كراش) =======================
// =================================================================

inline bool isStrictLethalPath(const char *path) {
    if (!path) return false;
    
    if (strstr(path, "/Logs") || 
        strstr(path, "Saved/Logs") ||
        strstr(path, "RoleInfo.ini") ||
        strstr(path, "Saved/Pandora") ||
        strstr(path, "Saved/CrashSight") ||
        strstr(path, "MMKV") ||
        strstr(path, "tombstone") ||
        strstr(path, "embedded.mobileprovision")) { // إخفاء ملف الشهادة الخارجي
        return true;
    }
    return false;
}

// =================================================================
// ===============  الطبقة 1: إخفاء بصمة الذاكرة (Signature Spoof) =
// =================================================================

// هذا هو الدرع النووي الذي يمسح بصمة ESign والشهادات الخارجية من الذاكرة
static int (*orig_csops)(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
int my_csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize) {
    int ret = orig_csops(pid, ops, useraddr, usersize);
    if (isSafeEngineActive.load(std::memory_order_relaxed) && ops == CS_OPS_STATUS && useraddr) {
        uint32_t *status = (uint32_t *)useraddr;
        
        *status |= CS_VALID;              // إجبار النواة على اعتبار اللعبة أصلية
        *status &= ~CS_GET_TASK_ALLOW;    // مسح بصمة التطبيقات المكركة
        *status &= ~CS_DEBUGGED;          // مسح بصمة الحقن والديباجر
    }
    return ret;
}

// =================================================================
// ===============  الطبقة 2: اعتراض مسارات النظام =================
// =================================================================

static int (*orig_stat)(const char *path, struct stat *buf);
int my_stat(const char *path, struct stat *buf) {
    if (isSafeEngineActive.load(std::memory_order_relaxed) && isStrictLethalPath(path)) {
        errno = ENOENT; return -1;
    }
    return orig_stat(path, buf);
}

static int (*orig_open)(const char *path, int oflag, ...);
int my_open(const char *path, int oflag, ...) {
    mode_t mode = 0;
    if (oflag & O_CREAT) {
        va_list args; va_start(args, oflag); mode = va_arg(args, int); va_end(args);
    }
    
    if (isSafeEngineActive.load(std::memory_order_relaxed) && isStrictLethalPath(path)) {
        errno = EACCES; return -1;
    }
    
    if (oflag & O_CREAT) return orig_open(path, oflag, mode);
    return orig_open(path, oflag);
}

// =================================================================
// ===============  الطبقة 3: الثقب الأسود للشبكة ==================
// =================================================================

static int (*orig_getaddrinfo)(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res);
int my_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res) {
    if (isSafeEngineActive.load(std::memory_order_relaxed) && node) {
        const char* blackhole[] = {
            "ocsp.apple.com", "ppq.apple.com", "world-gen.g.aaplimg.com", // منع أبل من إسقاط الشهادة
            "app-measurement.com", "crashsight.com", "crashsight.qq.com", "bugly.qq.com",
            "tdatamaster.com", "firebaseio.com", "apm.tencent.com", "adjust.com"
        };
        for (int i = 0; i < 11; i++) { 
            if (strstr(node, blackhole[i])) return EAI_NONAME; 
        }
    }
    return orig_getaddrinfo(node, service, hints, res);
}

// =================================================================
// ===============  الطبقة 4: استنساخ المتجر (إخفاء الكراك بالكامل) =
// =================================================================

static IMP orig_appStoreReceiptURL;
NSURL* my_appStoreReceiptURL(id self, SEL _cmd) {
    if (isSafeEngineActive.load(std::memory_order_relaxed)) {
        NSString *fakeReceipt = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"_MASReceipt/receipt"];
        return [NSURL fileURLWithPath:fakeReceipt]; // إيهام اللعبة بوجود فاتورة شراء أصلية
    }
    return ((NSURL*(*)(id, SEL))orig_appStoreReceiptURL)(self, _cmd);
}

static IMP orig_fileExistsAtPath;
BOOL my_fileExistsAtPath(id self, SEL _cmd, NSString *path) {
    if (isSafeEngineActive.load(std::memory_order_relaxed) && path) {
        if ([path containsString:@"embedded.mobileprovision"]) {
            return NO; // إنكار وجود ملف الشهادة الخارجية تماماً
        }
    }
    return ((BOOL(*)(id, SEL, NSString*))orig_fileExistsAtPath)(self, _cmd, path);
}

// =================================================================
// ===============  الطبقة 5: التنظيف والتشميع الصامت ==============
// =================================================================

void ExecuteSafeCleanup() {
    NSArray *targetPaths = @[
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Logs", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/MMKV", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Pandora", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/RoleInfo.ini", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/CrashSight", NSHomeDirectory()]
    ];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in targetPaths) {
        chflags([path UTF8String], 0); 
        if ([fm fileExistsAtPath:path]) {
            [fm removeItemAtPath:path error:nil]; 
        }
        [@"SAFE_ZONE" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [fm setAttributes:@{NSFilePosixPermissions: @0000} ofItemAtPath:path error:nil];
        chflags([path UTF8String], UF_IMMUTABLE); 
    }
}

void BackgroundSafeLoop() {
    while (true) {
        if (isSafeEngineActive.load(std::memory_order_relaxed)) {
            ExecuteSafeCleanup();
        }
        std::this_thread::sleep_for(std::chrono::seconds(15)); 
    }
}

void SetupLifecycleHooks() {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        if (isSafeEngineActive.load(std::memory_order_relaxed)) ExecuteSafeCleanup();
    }];
}

// =================================================================
// ===============  الإقلاع الآمن ==================================
// =================================================================

@interface AmarSafeUI : NSObject
+ (void)igniteSafeEngine;
@end

@implementation AmarSafeUI
+ (void)igniteSafeEngine {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        bool expected = false;
        if (!isSafeEngineActive.compare_exchange_strong(expected, true)) return;
        
        // ربط هوكات الـ C (بما فيها هوك بصمة التوقيع csops)
        struct rebinding r[] = { 
            {"stat", (void*)my_stat, (void**)&orig_stat},
            {"open", (void*)my_open, (void**)&orig_open},
            {"csops", (void*)my_csops, (void**)&orig_csops}, // الدرع السري للبصمة
            {"getaddrinfo", (void*)my_getaddrinfo, (void**)&orig_getaddrinfo}
        };
        rebind_symbols(r, 4);
        
        // ربط هوكات الـ Objective-C (فاتورة المتجر وإخفاء الملف)
        Method receiptMethod = class_getInstanceMethod([NSBundle class], @selector(appStoreReceiptURL));
        orig_appStoreReceiptURL = method_getImplementation(receiptMethod);
        method_setImplementation(receiptMethod, (IMP)my_appStoreReceiptURL);
        
        Method fileMethod = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
        orig_fileExistsAtPath = method_getImplementation(fileMethod);
        method_setImplementation(fileMethod, (IMP)my_fileExistsAtPath);
        
        // التنظيف والمراقبة
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            ExecuteSafeCleanup();
        });
        std::thread(BackgroundSafeLoop).detach();
        SetupLifecycleHooks();
        
        // إشعار النجاح
        UIWindow *win = nil;
        for (UIWindowScene* s in [UIApplication sharedApplication].connectedScenes) {
            if (s.activationState == UISceneActivationStateForegroundActive) { win = s.windows.firstObject; break; }
        }
        if (!win) return;
        
        UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 260, 45)];
        toast.center = CGPointMake(win.center.x, 60);
        toast.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
        toast.textColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.4 alpha:1.0];
        toast.textAlignment = NSTextAlignmentCenter;
        toast.font = [UIFont boldSystemFontOfSize:14];
        toast.text = @"✅ تم إخفاء بصمة التوقيع والغيابي";
        toast.layer.cornerRadius = 22.5;
        toast.clipsToBounds = YES;
        toast.layer.borderWidth = 1.0;
        toast.layer.borderColor = [UIColor greenColor].CGColor;
        toast.alpha = 0.0;
        
        [win addSubview:toast];
        
        [UIView animateWithDuration:0.5 animations:^{
            toast.alpha = 1.0;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.5 delay:3.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
                toast.alpha = 0.0;
            } completion:^(BOOL finished) {
                [toast removeFromSuperview];
            }];
        }];
    });
}
@end

__attribute__((constructor)) static void inject_safe() { 
    [AmarSafeUI igniteSafeEngine]; 
}
