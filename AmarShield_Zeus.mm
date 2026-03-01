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

// =================================================================
// ===============  إعدادات النظام الأساسية =========================
// =================================================================

struct rebinding { const char *name; void *replacement; void **replaced; };
extern "C" int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

static std::atomic<bool> isDoomsdayActive(false);

inline bool isLethalPath(const char *path) {
    if (!path) return false;
    if (strstr(path, "Saved/Logs") || 
        strstr(path, "Saved/RoleInfo") ||
        strstr(path, "Saved/Pandora") ||
        strstr(path, "Saved/CrashSight") ||
        strstr(path, "MMKV") ||
        strstr(path, "tombstone") ||
        strstr(path, "embedded.mobileprovision")) { 
        return true;
    }
    return false;
}

// =================================================================
// ===============  [الجديد] الطبقة 1: التخفي المطلق في الذاكرة ====
// =================================================================

// 1. إخفاء أداة AmarShield من قائمة المكتبات المحقونة
static const char* (*orig_dyld_get_image_name)(uint32_t image_index);
const char* my_dyld_get_image_name(uint32_t image_index) {
    const char* name = orig_dyld_get_image_name(image_index);
    if (isDoomsdayActive.load(std::memory_order_relaxed) && name) {
        // إذا رأت اللعبة أداتك أو أي أداة جيلبريك، سيتم تمويهها!
        if (strstr(name, "AmarShield") || strstr(name, "Substrate") || strstr(name, "Cydia") || strstr(name, "Substitute")) {
            return "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"; // تزييف كأنها ملف نظام أبل
        }
    }
    return name;
}

// 2. إخفاء متغيرات بيئة الحقن (Environment Spoofing)
static char* (*orig_getenv)(const char *name);
char* my_getenv(const char *name) {
    if (isDoomsdayActive.load(std::memory_order_relaxed) && name) {
        if (strcmp(name, "DYLD_INSERT_LIBRARIES") == 0 || strcmp(name, "CYDIA") == 0) {
            return NULL; // اللعبة تظن أنه لا يوجد حقن خارجي!
        }
    }
    return orig_getenv(name);
}

// 3. تعطيل محاولات anogs لكشف الديباجر
static int (*orig_isatty)(int fd);
int my_isatty(int fd) {
    if (isDoomsdayActive.load(std::memory_order_relaxed)) {
        return 0; // إيهام anogs بأنه لا توجد أطرافية (Terminal/Debugger) متصلة باللعبة
    }
    return orig_isatty(fd);
}

static int (*orig_sysctl)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
int my_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int ret = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    if (isDoomsdayActive.load(std::memory_order_relaxed) && ret == 0 && name && namelen >= 3) {
        if (name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID) {
            if (oldp && oldlenp && *oldlenp >= sizeof(struct kinfo_proc)) {
                struct kinfo_proc *info = (struct kinfo_proc *)oldp;
                info->kp_proc.p_flag &= ~P_TRACED; // مسح علامة التتبع بصمت تام
            }
        }
    }
    return ret;
}

// =================================================================
// ===============  الطبقة 2: اعتراض ملفات النظام (File Choke) =====
// =================================================================

static int (*orig_stat)(const char *path, struct stat *buf);
int my_stat(const char *path, struct stat *buf) {
    if (isDoomsdayActive.load(std::memory_order_relaxed) && isLethalPath(path)) {
        errno = ENOENT; return -1;
    }
    return orig_stat(path, buf);
}

static int (*orig_access)(const char *path, int amode);
int my_access(const char *path, int amode) {
    if (isDoomsdayActive.load(std::memory_order_relaxed) && isLethalPath(path)) {
        errno = ENOENT; return -1;
    }
    return orig_access(path, amode);
}

static int (*orig_open)(const char *path, int oflag, ...);
int my_open(const char *path, int oflag, ...) {
    mode_t mode = 0;
    if (oflag & O_CREAT) {
        va_list args; va_start(args, oflag); mode = va_arg(args, int); va_end(args);
    }
    if (isDoomsdayActive.load(std::memory_order_relaxed) && isLethalPath(path)) {
        errno = EACCES; return -1; 
    }
    if (oflag & O_CREAT) return orig_open(path, oflag, mode);
    return orig_open(path, oflag);
}

static FILE* (*orig_fopen)(const char *path, const char *mode);
FILE* my_fopen(const char *path, const char *mode) {
    if (isDoomsdayActive.load(std::memory_order_relaxed) && isLethalPath(path)) {
        errno = EACCES; return NULL; 
    }
    return orig_fopen(path, mode);
}

// =================================================================
// ===============  الطبقة 3: الثقب الأسود للشبكات (DNS Hole) ======
// =================================================================

static int (*orig_getaddrinfo)(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res);
int my_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res) {
    if (isDoomsdayActive.load(std::memory_order_relaxed) && node) {
        const char* blackhole[] = {
            "ocsp.apple.com", "ppq.apple.com", "world-gen.g.aaplimg.com", "crl.apple.com",
            "app-measurement.com", "crashsight.com", "crashsight.qq.com", "bugly.qq.com",
            "tdatamaster.com", "firebaseio.com", "apm.tencent.com",
            "adjust.com", "appsflyer.com", "google-analytics.com", "log.bytebase.com",
            "cloud.gsdk.pro", "igexin.com", "talkingdata.com" // المزيد من سيرفرات التتبع
        };
        for (int i = 0; i < 18; i++) { 
            if (strstr(node, blackhole[i])) return EAI_NONAME; 
        }
    }
    return orig_getaddrinfo(node, service, hints, res);
}

static struct hostent* (*orig_gethostbyname)(const char *name);
struct hostent* my_gethostbyname(const char *name) {
    if (isDoomsdayActive.load(std::memory_order_relaxed) && name) {
        if (strstr(name, "apple.com") || strstr(name, "crashsight") || strstr(name, "tencent")) {
            return NULL;
        }
    }
    return orig_gethostbyname(name);
}

// =================================================================
// ===============  الطبقة 4: إخفاء البصمة بأسلوب أبل (Swizzling) ==
// =================================================================

static IMP orig_fileExistsAtPath;
BOOL my_fileExistsAtPath(id self, SEL _cmd, NSString *path) {
    if (isDoomsdayActive.load(std::memory_order_relaxed) && path) {
        if ([path containsString:@"embedded.mobileprovision"] || [path containsString:@"ShadowTracker"]) {
            return NO; 
        }
    }
    return ((BOOL(*)(id, SEL, NSString*))orig_fileExistsAtPath)(self, _cmd, path);
}

void ApplyObjectiveCSwizzling() {
    Method origMethod = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    orig_fileExistsAtPath = method_getImplementation(origMethod);
    method_setImplementation(origMethod, (IMP)my_fileExistsAtPath);
}

// =================================================================
// ===============  الطبقة 5: التشميع الخرساني (Unix Kernel Lock) ==
// =================================================================

void ExecuteConcreteLockdown() {
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
        [@"DEAD_ZONE" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [fm setAttributes:@{NSFilePosixPermissions: @0000} ofItemAtPath:path error:nil];
        chflags([path UTF8String], UF_IMMUTABLE); 
    }
}

void SetupLifecycleRadar() {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        if (isDoomsdayActive.load(std::memory_order_relaxed)) ExecuteConcreteLockdown();
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        if (isDoomsdayActive.load(std::memory_order_relaxed)) ExecuteConcreteLockdown();
    }];
}

void BackgroundFortressLoop() {
    while (true) {
        if (isDoomsdayActive.load(std::memory_order_relaxed)) {
            ExecuteConcreteLockdown();
        }
        std::this_thread::sleep_for(std::chrono::seconds(10)); // تقليل وقت الكنس إلى 10 ثواني لمزيد من الشراسة
    }
}

// =================================================================
// ===============  محرك الإطلاق الشبح (Doomsday Engine) ===========
// =================================================================

@interface AmarDoomsdayUI : NSObject
+ (void)engageDoomsdayFortress;
@end

@implementation AmarDoomsdayUI
+ (void)engageDoomsdayFortress {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        bool expected = false;
        if (!isDoomsdayActive.compare_exchange_strong(expected, true)) return;
        
        // 1. تفعيل 10 هوكات فتاكة دفعة واحدة!
        struct rebinding r[] = { 
            {"stat", (void*)my_stat, (void**)&orig_stat},
            {"access", (void*)my_access, (void**)&orig_access},
            {"open", (void*)my_open, (void**)&orig_open},
            {"fopen", (void*)my_fopen, (void**)&orig_fopen},
            {"getaddrinfo", (void*)my_getaddrinfo, (void**)&orig_getaddrinfo},
            {"gethostbyname", (void*)my_gethostbyname, (void**)&orig_gethostbyname},
            {"_dyld_get_image_name", (void*)my_dyld_get_image_name, (void**)&orig_dyld_get_image_name}, // التخفي
            {"getenv", (void*)my_getenv, (void**)&orig_getenv}, // إخفاء البيئة
            {"isatty", (void*)my_isatty, (void**)&orig_isatty}, // إعماء الديباجر
            {"sysctl", (void*)my_sysctl, (void**)&orig_sysctl}  // مسح التتبع
        };
        rebind_symbols(r, 10);
        
        // 2. تفعيل هوك البصمة
        ApplyObjectiveCSwizzling();
        
        // 3. التشميع الفوري
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            ExecuteConcreteLockdown();
        });
        
        // 4. الرادارات الخلفية
        SetupLifecycleRadar();
        std::thread(BackgroundFortressLoop).detach();
        
        // 5. الإشعار الشبح
        UIWindow *win = nil;
        for (UIWindowScene* s in [UIApplication sharedApplication].connectedScenes) {
            if (s.activationState == UISceneActivationStateForegroundActive) { win = s.windows.firstObject; break; }
        }
        if (!win) return;
        
        UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 260, 45)];
        toast.center = CGPointMake(win.center.x, 60);
        toast.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.95];
        toast.textColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.0 alpha:1.0]; // ذهبي / نووي
        toast.textAlignment = NSTextAlignmentCenter;
        toast.font = [UIFont boldSystemFontOfSize:14];
        toast.text = @"☢️ تم تفعيل محرك يوم القيامة للعبة";
        toast.layer.cornerRadius = 22.5;
        toast.clipsToBounds = YES;
        toast.layer.borderWidth = 1.0;
        toast.layer.borderColor = [UIColor orangeColor].CGColor;
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

__attribute__((constructor)) static void inject_doomsday() { 
    [AmarDoomsdayUI engageDoomsdayFortress]; 
}
