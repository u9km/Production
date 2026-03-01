#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <fcntl.h>
#include <unistd.h>
#include <netdb.h>
#include <errno.h>
#include <stdarg.h>
#include <atomic>
#include <thread>
#include <mach-o/dyld.h>
#include <mach/mach.h>

struct rebinding { const char *name; void *replacement; void **replaced; };
extern "C" int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

static std::atomic<bool> isGodEngineActive(false);

// =================================================================
// ===============  فلتر الإعدام الشامل (The Universal Filter) =====
// =================================================================

inline bool isLethalPath(const char *path) {
    if (!path) return false;
    // أي مسار يحاول الإبلاغ عنك أو قراءة ملفات الكراك
    if (strstr(path, "Saved/Logs") || 
        strstr(path, "Saved/RoleInfo") ||
        strstr(path, "Saved/Pandora") ||
        strstr(path, "Saved/CrashSight") ||
        strstr(path, "MMKV") ||
        strstr(path, "tombstone") ||
        strstr(path, "embedded.mobileprovision") ||
        strstr(path, "ShadowTracker")) { 
        return true;
    }
    // منع اللعبة من فحص الذاكرة التنفيذية الخاصة بها (Anti-Dump)
    const char* exec_path = _dyld_get_image_name(0);
    if (exec_path && strcmp(path, exec_path) == 0) return true;
    
    return false;
}

// =================================================================
// ===============  الطبقة 1: التخفي وإعماء الحماية (Anti-Cheat Blindness)
// =================================================================

static const char* (*orig_dyld_get_image_name)(uint32_t image_index);
const char* my_dyld_get_image_name(uint32_t image_index) {
    const char* name = orig_dyld_get_image_name(image_index);
    if (isGodEngineActive.load(std::memory_order_relaxed) && name) {
        if (strstr(name, "AmarShield") || strstr(name, "Cydia") || strstr(name, "MobileSubstrate")) {
            return "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"; // تمويه كامل
        }
    }
    return name;
}

static int (*orig_isatty)(int fd);
int my_isatty(int fd) {
    if (isGodEngineActive.load(std::memory_order_relaxed)) return 0; // إخفاء بيئة التطوير
    return orig_isatty(fd);
}

static int (*orig_sysctl)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
int my_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int ret = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    if (isGodEngineActive.load(std::memory_order_relaxed) && ret == 0 && name && namelen >= 3) {
        if (name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID) {
            if (oldp && oldlenp && *oldlenp >= sizeof(struct kinfo_proc)) {
                struct kinfo_proc *info = (struct kinfo_proc *)oldp;
                info->kp_proc.p_flag &= ~P_TRACED; // مسح علامة الحقن
            }
        }
    }
    return ret;
}

// =================================================================
// ===============  الطبقة 2: خنق الملفات الفولاذي (File Choke) ====
// =================================================================

static int (*orig_stat)(const char *path, struct stat *buf);
int my_stat(const char *path, struct stat *buf) {
    if (isGodEngineActive.load(std::memory_order_relaxed) && isLethalPath(path)) { errno = ENOENT; return -1; }
    return orig_stat(path, buf);
}

static int (*orig_access)(const char *path, int amode);
int my_access(const char *path, int amode) {
    if (isGodEngineActive.load(std::memory_order_relaxed) && isLethalPath(path)) { errno = ENOENT; return -1; }
    return orig_access(path, amode);
}

static int (*orig_open)(const char *path, int oflag, ...);
int my_open(const char *path, int oflag, ...) {
    mode_t mode = 0;
    if (oflag & O_CREAT) {
        va_list args; va_start(args, oflag); mode = va_arg(args, int); va_end(args);
    }
    if (isGodEngineActive.load(std::memory_order_relaxed) && isLethalPath(path)) { errno = EACCES; return -1; }
    if (oflag & O_CREAT) return orig_open(path, oflag, mode);
    return orig_open(path, oflag);
}

// =================================================================
// ===============  الطبقة 3: ثقب الشبكة الأسود (Network Nullification)
// =================================================================

static int (*orig_getaddrinfo)(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res);
int my_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res) {
    if (isGodEngineActive.load(std::memory_order_relaxed) && node) {
        const char* blackhole[] = {
            "ocsp.apple.com", "ppq.apple.com", "world-gen.g.aaplimg.com", // الشهادة
            "app-measurement.com", "crashsight.com", "crashsight.qq.com", "bugly.qq.com", // الغيابي
            "tdatamaster.com", "firebaseio.com", "apm.tencent.com", "adjust.com", "appsflyer.com"
        };
        for (int i = 0; i < 12; i++) { 
            if (strstr(node, blackhole[i])) return EAI_NONAME; 
        }
    }
    return orig_getaddrinfo(node, service, hints, res);
}

// =================================================================
// ===============  الطبقة 4: تزييف الاستنساخ (AppStore Spoofer) ===
// =================================================================

static IMP orig_appStoreReceiptURL;
NSURL* my_appStoreReceiptURL(id self, SEL _cmd) {
    if (isGodEngineActive.load(std::memory_order_relaxed)) {
        NSString *fakeReceipt = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"_MASReceipt/receipt"];
        return [NSURL fileURLWithPath:fakeReceipt];
    }
    return ((NSURL*(*)(id, SEL))orig_appStoreReceiptURL)(self, _cmd);
}

static IMP orig_fileExistsAtPath;
BOOL my_fileExistsAtPath(id self, SEL _cmd, NSString *path) {
    if (isGodEngineActive.load(std::memory_order_relaxed) && path) {
        if ([path containsString:@"embedded.mobileprovision"] || [path containsString:@"ShadowTrackerExtra/Saved"]) {
            return NO; 
        }
    }
    return ((BOOL(*)(id, SEL, NSString*))orig_fileExistsAtPath)(self, _cmd, path);
}

// =================================================================
// ===============  الطبقة 5: التشميع والمراقبة (Concrete Lock) ====
// =================================================================

void ExecuteAbsoluteLockdown() {
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
        if ([fm fileExistsAtPath:path]) [fm removeItemAtPath:path error:nil];
        [@"GOD_MODE_ACTIVE" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [fm setAttributes:@{NSFilePosixPermissions: @0000} ofItemAtPath:path error:nil];
        chflags([path UTF8String], UF_IMMUTABLE); // الختم النووي
    }
}

void UniversalBackgroundLoop() {
    while (true) {
        if (isGodEngineActive.load(std::memory_order_relaxed)) {
            ExecuteAbsoluteLockdown();
        }
        std::this_thread::sleep_for(std::chrono::seconds(10));
    }
}

void SetupLifecycleRadar() {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        if (isGodEngineActive.load(std::memory_order_relaxed)) ExecuteAbsoluteLockdown();
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        if (isGodEngineActive.load(std::memory_order_relaxed)) ExecuteAbsoluteLockdown();
    }];
}

// =================================================================
// ===============  التشغيل الشبح الشامل (Ghost Boot) ==============
// =================================================================

@interface AmarGodEngineUI : NSObject
+ (void)igniteGodEngine;
@end

@implementation AmarGodEngineUI
+ (void)igniteGodEngine {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        bool expected = false;
        if (!isGodEngineActive.compare_exchange_strong(expected, true)) return;
        
        // 1. تفعيل 8 هوكات فتاكة لنظام الـ C
        struct rebinding r[] = { 
            {"stat", (void*)my_stat, (void**)&orig_stat},
            {"access", (void*)my_access, (void**)&orig_access},
            {"open", (void*)my_open, (void**)&orig_open},
            {"getaddrinfo", (void*)my_getaddrinfo, (void**)&orig_getaddrinfo},
            {"_dyld_get_image_name", (void*)my_dyld_get_image_name, (void**)&orig_dyld_get_image_name},
            {"isatty", (void*)my_isatty, (void**)&orig_isatty},
            {"sysctl", (void*)my_sysctl, (void**)&orig_sysctl}
        };
        rebind_symbols(r, 7);
        
        // 2. تفعيل هوكات الـ Objective-C (تزييف أبل)
        Method receiptMethod = class_getInstanceMethod([NSBundle class], @selector(appStoreReceiptURL));
        orig_appStoreReceiptURL = method_getImplementation(receiptMethod);
        method_setImplementation(receiptMethod, (IMP)my_appStoreReceiptURL);
        
        Method fileMethod = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
        orig_fileExistsAtPath = method_getImplementation(fileMethod);
        method_setImplementation(fileMethod, (IMP)my_fileExistsAtPath);
        
        // 3. التشميع والمراقبة
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            ExecuteAbsoluteLockdown();
        });
        SetupLifecycleRadar();
        std::thread(UniversalBackgroundLoop).detach();
        
        // 4. إشعار النهاية
        UIWindow *win = nil;
        for (UIWindowScene* s in [UIApplication sharedApplication].connectedScenes) {
            if (s.activationState == UISceneActivationStateForegroundActive) { win = s.windows.firstObject; break; }
        }
        if (!win) return;
        
        UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 240, 45)];
        toast.center = CGPointMake(win.center.x, 60);
        toast.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.95];
        toast.textColor = [UIColor colorWithRed:0.8 green:0.0 blue:1.0 alpha:1.0]; // أرجواني (God Tier)
        toast.textAlignment = NSTextAlignmentCenter;
        toast.font = [UIFont boldSystemFontOfSize:14];
        toast.text = @"🌌 المحرك الشامل قيد العمل";
        toast.layer.cornerRadius = 22.5;
        toast.clipsToBounds = YES;
        toast.layer.borderWidth = 1.0;
        toast.layer.borderColor = [UIColor purpleColor].CGColor;
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

__attribute__((constructor)) static void inject_god_engine() { 
    [AmarGodEngineUI igniteGodEngine]; 
}
