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
#include <sys/types.h>
#include <sys/sysctl.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <dlfcn.h>
// تم حذف ptrace.h بنجاح!


struct rebinding { const char *name; void *replacement; void **replaced; };
extern "C" int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

#define CS_OPS_STATUS 0
#define CS_VALID 0x00000001
#define CS_GET_TASK_ALLOW 0x00000004 
#define CS_DEBUGGED 0x10000000       

static std::atomic<bool> isMaxShieldActive(false);

// =================================================================
// ========  القسم الأول: حمايات SHADOW MASTER العميقة =============
// =================================================================

// 1. إخفاء متغيرات الحقن (أهم سبب للباند في السايدلود)
static char* (*orig_getenv)(const char *name);
char* my_getenv(const char *name) {
    if (isMaxShieldActive.load(std::memory_order_relaxed) && name) {
        if (strcmp(name, "DYLD_INSERT_LIBRARIES") == 0 || strcmp(name, "Cydia") == 0) {
            return NULL; // اللعبة لن ترى أي هاك محقون!
        }
    }
    return orig_getenv(name);
}

// 2. إخفاء اسم الهاك من ذاكرة اللعبة (Anti-Dump)
static const char* (*orig_dyld_get_image_name)(uint32_t image_index);
const char* my_dyld_get_image_name(uint32_t image_index) {
    const char* name = orig_dyld_get_image_name(image_index);
    if (isMaxShieldActive.load(std::memory_order_relaxed) && name) {
        if (strstr(name, "Shadow") || strstr(name, "AmarShield") || strstr(name, "dylib")) {
            return "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation";
        }
    }
    return name;
}

// 3. منع كشف هوية الدوال عبر dladdr
static int (*orig_dladdr)(const void *addr, Dl_info *info);
int my_dladdr(const void *addr, Dl_info *info) {
    int ret = orig_dladdr(addr, info);
    if (isMaxShieldActive.load(std::memory_order_relaxed) && ret != 0 && info) {
        if (info->dli_fname && (strstr(info->dli_fname, "Shadow") || strstr(info->dli_fname, "AmarShield"))) {
            info->dli_fname = "/usr/lib/system/libsystem_kernel.dylib";
            info->dli_sname = "mach_msg"; // تزييف الدالة لتظهر كأنها دالة نظام آمنة
        }
    }
    return ret;
}

// 4. منع الديباجر (Anti-Debug)
static int (*orig_ptrace)(int request, pid_t pid, caddr_t addr, int data);
int my_ptrace(int request, pid_t pid, caddr_t addr, int data) {
    if (isMaxShieldActive.load(std::memory_order_relaxed) && request == 31) return 0;
    return orig_ptrace(request, pid, addr, data);
}

// 5. مسح علامة التتبع (Anti-Tracing)
static int (*orig_sysctl)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
int my_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int ret = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    if (isMaxShieldActive.load(std::memory_order_relaxed) && ret == 0 && name && namelen >= 3) {
        if (name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID) {
            if (oldp && oldlenp && *oldlenp >= sizeof(struct kinfo_proc)) {
                struct kinfo_proc *info = (struct kinfo_proc *)oldp;
                info->kp_proc.p_flag &= ~P_TRACED;
            }
        }
    }
    return ret;
}

// 6. عمى الذاكرة (Anti-Memory Info)
static kern_return_t (*orig_task_info)(task_name_t target_task, task_flavor_t flavor, task_info_t task_info_out, mach_msg_type_number_t *task_info_outCnt);
kern_return_t my_task_info(task_name_t target_task, task_flavor_t flavor, task_info_t task_info_out, mach_msg_type_number_t *task_info_outCnt) {
    if (isMaxShieldActive.load(std::memory_order_relaxed) && flavor == TASK_DYLD_INFO) return KERN_FAILURE;
    return orig_task_info(target_task, flavor, task_info_out, task_info_outCnt);
}

// =================================================================
// ========  القسم الثاني: دروع AmarShield لملفات اللعبة ===========
// =================================================================

inline bool isStrictLethalPath(const char *path) {
    if (!path) return false;
    // مسارات الباند الخاصة باللعبة + مسارات الجيلبريك الوهمية
    if (strstr(path, "/Logs") || strstr(path, "Saved/Logs") ||
        strstr(path, "RoleInfo.ini") || strstr(path, "Saved/Pandora") ||
        strstr(path, "Saved/CrashSight") || strstr(path, "MMKV") ||
        strstr(path, "tombstone") || strstr(path, "embedded.mobileprovision") ||
        strstr(path, "MobileSubstrate") || strstr(path, "Cydia")) { 
        return true;
    }
    return false;
}

static int (*orig_csops)(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
int my_csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize) {
    int ret = orig_csops(pid, ops, useraddr, usersize);
    if (isMaxShieldActive.load(std::memory_order_relaxed) && ops == CS_OPS_STATUS && useraddr) {
        uint32_t *status = (uint32_t *)useraddr;
        *status |= CS_VALID; *status &= ~CS_GET_TASK_ALLOW; *status &= ~CS_DEBUGGED;          
    }
    return ret;
}

static int (*orig_stat)(const char *path, struct stat *buf);
int my_stat(const char *path, struct stat *buf) {
    if (isMaxShieldActive.load(std::memory_order_relaxed) && isStrictLethalPath(path)) { errno = ENOENT; return -1; }
    return orig_stat(path, buf);
}

static int (*orig_lstat)(const char *path, struct stat *buf);
int my_lstat(const char *path, struct stat *buf) {
    if (isMaxShieldActive.load(std::memory_order_relaxed) && isStrictLethalPath(path)) { errno = ENOENT; return -1; }
    return orig_lstat(path, buf);
}

static int (*orig_access)(const char *path, int amode);
int my_access(const char *path, int amode) {
    if (isMaxShieldActive.load(std::memory_order_relaxed) && isStrictLethalPath(path)) { errno = ENOENT; return -1; }
    return orig_access(path, amode);
}

static int (*orig_open)(const char *path, int oflag, ...);
int my_open(const char *path, int oflag, ...) {
    mode_t mode = 0;
    if (oflag & O_CREAT) { va_list args; va_start(args, oflag); mode = va_arg(args, int); va_end(args); }
    if (isMaxShieldActive.load(std::memory_order_relaxed) && isStrictLethalPath(path)) { errno = EACCES; return -1; }
    if (oflag & O_CREAT) return orig_open(path, oflag, mode);
    return orig_open(path, oflag);
}

static int (*orig_getaddrinfo)(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res);
int my_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res) {
    if (isMaxShieldActive.load(std::memory_order_relaxed) && node) {
        const char* blackhole[] = {
            "ocsp.apple.com", "ppq.apple.com", "world-gen.g.aaplimg.com",
            "app-measurement.com", "crashsight.com", "crashsight.qq.com", "bugly.qq.com",
            "tdatamaster.com", "firebaseio.com", "apm.tencent.com", "adjust.com"
        };
        for (int i = 0; i < 11; i++) { if (strstr(node, blackhole[i])) return EAI_NONAME; }
    }
    return orig_getaddrinfo(node, service, hints, res);
}

static IMP orig_appStoreReceiptURL;
NSURL* my_appStoreReceiptURL(id self, SEL _cmd) {
    if (isMaxShieldActive.load(std::memory_order_relaxed)) {
        NSString *fakeReceipt = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"_MASReceipt/receipt"];
        return [NSURL fileURLWithPath:fakeReceipt];
    }
    return ((NSURL*(*)(id, SEL))orig_appStoreReceiptURL)(self, _cmd);
}

static IMP orig_fileExistsAtPath;
BOOL my_fileExistsAtPath(id self, SEL _cmd, NSString *path) {
    if (isMaxShieldActive.load(std::memory_order_relaxed) && path) {
        if ([path containsString:@"embedded.mobileprovision"]) return NO; 
    }
    return ((BOOL(*)(id, SEL, NSString*))orig_fileExistsAtPath)(self, _cmd, path);
}

// =================================================================
// ========  القسم الثالث: التنظيف الخرساني ========================
// =================================================================

void ExecuteMaxCleanup() {
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
        [@"MAX_SHIELD_ACTIVE" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [fm setAttributes:@{NSFilePosixPermissions: @0000} ofItemAtPath:path error:nil];
        chflags([path UTF8String], UF_IMMUTABLE); 
    }
}

void BackgroundMaxLoop() {
    while (true) {
        if (isMaxShieldActive.load(std::memory_order_relaxed)) ExecuteMaxCleanup();
        std::this_thread::sleep_for(std::chrono::seconds(15)); 
    }
}

void SetupLifecycleRadar() {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        if (isMaxShieldActive.load(std::memory_order_relaxed)) ExecuteMaxCleanup();
    }];
}

// =================================================================
// ========  الإقلاع المدمج (Boot Sequence) ========================
// =================================================================

@interface AmarMaxUI : NSObject
+ (void)igniteMax;
@end

@implementation AmarMaxUI
+ (void)igniteMax {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        bool expected = false;
        if (!isMaxShieldActive.compare_exchange_strong(expected, true)) return;
        
        // ربط جميع الهوكات (12 هوك فولاذي لحماية بيئة اللعبة بالكامل)
        struct rebinding r[] = { 
            {"getenv", (void*)my_getenv, (void**)&orig_getenv},
            {"_dyld_get_image_name", (void*)my_dyld_get_image_name, (void**)&orig_dyld_get_image_name},
            {"dladdr", (void*)my_dladdr, (void**)&orig_dladdr},
            {"ptrace", (void*)my_ptrace, (void**)&orig_ptrace},
            {"sysctl", (void*)my_sysctl, (void**)&orig_sysctl},
            {"task_info", (void*)my_task_info, (void**)&orig_task_info},
            {"stat", (void*)my_stat, (void**)&orig_stat},
            {"lstat", (void*)my_lstat, (void**)&orig_lstat},
            {"access", (void*)my_access, (void**)&orig_access},
            {"open", (void*)my_open, (void**)&orig_open},
            {"csops", (void*)my_csops, (void**)&orig_csops},
            {"getaddrinfo", (void*)my_getaddrinfo, (void**)&orig_getaddrinfo}
        };
        rebind_symbols(r, 12);
        
        Method receiptMethod = class_getInstanceMethod([NSBundle class], @selector(appStoreReceiptURL));
        orig_appStoreReceiptURL = method_getImplementation(receiptMethod);
        method_setImplementation(receiptMethod, (IMP)my_appStoreReceiptURL);
        
        Method fileMethod = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
        orig_fileExistsAtPath = method_getImplementation(fileMethod);
        method_setImplementation(fileMethod, (IMP)my_fileExistsAtPath);
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{ ExecuteMaxCleanup(); });
        SetupLifecycleRadar();
        std::thread(BackgroundMaxLoop).detach();
        
        UIWindow *win = nil;
        for (UIWindowScene* s in [UIApplication sharedApplication].connectedScenes) {
            if (s.activationState == UISceneActivationStateForegroundActive) { win = s.windows.firstObject; break; }
        }
        if (!win) return;
        
        UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 280, 45)];
        toast.center = CGPointMake(win.center.x, 60);
        toast.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.95];
        toast.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:1.0 alpha:1.0]; // لون سيان احترافي
        toast.textAlignment = NSTextAlignmentCenter;
        toast.font = [UIFont boldSystemFontOfSize:14];
        toast.text = @"🌌 AmarShield MAX (Shadow Core Injected)";
        toast.layer.cornerRadius = 22.5;
        toast.clipsToBounds = YES;
        toast.layer.borderWidth = 1.0;
        toast.layer.borderColor = [UIColor cyanColor].CGColor;
        toast.alpha = 0.0;
        
        [win addSubview:toast];
        [UIView animateWithDuration:0.5 animations:^{ toast.alpha = 1.0; } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.5 delay:4.0 options:UIViewAnimationOptionCurveEaseOut animations:^{ toast.alpha = 0.0; } completion:^(BOOL finished) { [toast removeFromSuperview]; }];
        }];
    });
}
@end

__attribute__((constructor)) static void inject_max() { 
    [AmarMaxUI igniteMax]; 
}
