#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <netdb.h>
#include <errno.h>
#include <stdarg.h>
#include <atomic>
#include <thread>

struct rebinding { const char *name; void *replacement; void **replaced; };
extern "C" int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

// متغير الحالة لضمان التفعيل مرة واحدة فقط
static std::atomic<bool> isIronActive(false);

// =================================================================
// ===============  الحديد الأول: درع الباند الغيابي (File Block) ==
// =================================================================

inline bool isOfflineBanTarget(const char *path) {
    if (!path) return false;
    if (strstr(path, "Saved/Logs") || 
        strstr(path, "Saved/RoleInfo") ||
        strstr(path, "Saved/Pandora") ||
        strstr(path, "Saved/CrashSight") ||
        strstr(path, "MMKV") ||
        strstr(path, "tombstone")) { 
        return true;
    }
    return false;
}

static int (*orig_stat)(const char *path, struct stat *buf);
int my_stat(const char *path, struct stat *buf) {
    if (isIronActive.load(std::memory_order_relaxed) && isOfflineBanTarget(path)) {
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
    if (isIronActive.load(std::memory_order_relaxed) && isOfflineBanTarget(path)) {
        errno = EACCES; return -1; 
    }
    if (oflag & O_CREAT) return orig_open(path, oflag, mode);
    return orig_open(path, oflag);
}

static FILE* (*orig_fopen)(const char *path, const char *mode);
FILE* my_fopen(const char *path, const char *mode) {
    if (isIronActive.load(std::memory_order_relaxed) && isOfflineBanTarget(path)) {
        errno = EACCES; return NULL; 
    }
    return orig_fopen(path, mode);
}

// =================================================================
// ===============  الحديد الثاني: درع الشهادة (Network Block) =====
// =================================================================

static int (*orig_getaddrinfo)(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res);
int my_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res) {
    if (isIronActive.load(std::memory_order_relaxed) && node) {
        const char* blackHoleServers[] = {
            "ocsp.apple.com", "ppq.apple.com", "world-gen.g.aaplimg.com",
            "app-measurement.com", "google-analytics.com", "crashsight.com", 
            "tdatamaster.com", "firebaseio.com", "bugly.qq.com"
        };
        for (int i = 0; i < 9; i++) { 
            if (strstr(node, blackHoleServers[i])) return EAI_NONAME; 
        }
    }
    return orig_getaddrinfo(node, service, hints, res);
}

// =================================================================
// ===============  المكنسة الحديدية (Iron Sweeper) ================
// =================================================================

void ExecuteIronClean() {
    NSArray *targetPaths = @[
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Logs", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/MMKV", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Pandora", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/RoleInfo.ini", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/CrashSight", NSHomeDirectory()]
    ];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in targetPaths) { 
        if ([fm fileExistsAtPath:path]) {
            [fm removeItemAtPath:path error:nil]; 
        }
        // إغلاق المنطقة بعد التنظيف
        [@"IRON_LOCKED" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [fm setAttributes:@{NSFilePosixPermissions: @0000} ofItemAtPath:path error:nil];
    }
}

void IronBackgroundLoop() {
    while (true) {
        if (isIronActive.load(std::memory_order_relaxed)) {
            ExecuteIronClean();
        }
        std::this_thread::sleep_for(std::chrono::seconds(15)); // كنس آلي كل 15 ثانية
    }
}

// =================================================================
// ===============  رادار مراقبة الخروج (Safe Exit) ================
// =================================================================

void RegisterAppLifecycleHooks() {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        if (isIronActive.load(std::memory_order_relaxed)) {
            ExecuteIronClean();
        }
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        if (isIronActive.load(std::memory_order_relaxed)) {
            ExecuteIronClean();
        }
    }];
}

// =================================================================
// ===============  محرك التفعيل التلقائي (Auto Engage) ============
// =================================================================

void AutoEngageProtection() {
    bool expected = false;
    if (!isIronActive.compare_exchange_strong(expected, true)) return;
    
    struct rebinding r[] = { 
        {"stat", (void*)my_stat, (void**)&orig_stat},
        {"open", (void*)my_open, (void**)&orig_open},
        {"fopen", (void*)my_fopen, (void**)&orig_fopen},
        {"getaddrinfo", (void*)my_getaddrinfo, (void**)&orig_getaddrinfo}
    };
    rebind_symbols(r, 4);
    
    RegisterAppLifecycleHooks();
    
    // تشغيل المكنسة الخلفية
    std::thread(IronBackgroundLoop).detach();
    
    // إرسال أمر تنظيف فوري عند التفعيل
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        ExecuteIronClean();
    });
}

// =================================================================
// ===============  الإشعار المؤقت (Toast Notification) ============
// =================================================================

@interface AmarGhostUI : NSObject
+ (void)startGhostMode;
@end

@implementation AmarGhostUI
+ (void)startGhostMode {
    // ننتظر 5 ثوانٍ بعد فتح اللعبة لتجنب التعارض مع شاشات التحميل
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        AutoEngageProtection(); // تفعيل الحماية بالخلفية
        
        UIWindow *win = nil;
        for (UIWindowScene* s in [UIApplication sharedApplication].connectedScenes) {
            if (s.activationState == UISceneActivationStateForegroundActive) { win = s.windows.firstObject; break; }
        }
        if (!win) return;
        
        // تصميم رسالة الإشعار
        UILabel *toastLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 220, 45)];
        toastLabel.center = CGPointMake(win.center.x, 60); // تظهر في الأعلى
        toastLabel.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85]; // أسود شفاف
        toastLabel.textColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.2 alpha:1.0]; // أخضر فاقع
        toastLabel.textAlignment = NSTextAlignmentCenter;
        toastLabel.font = [UIFont boldSystemFontOfSize:14];
        toastLabel.text = @"🛡️ تم تفعيل الحماية بنجاح";
        toastLabel.layer.cornerRadius = 22.5;
        toastLabel.clipsToBounds = YES;
        toastLabel.layer.borderWidth = 1.0;
        toastLabel.layer.borderColor = [UIColor greenColor].CGColor;
        toastLabel.alpha = 0.0; // تبدأ مخفية
        
        [win addSubview:toastLabel];
        
        // حركة الظهور والغياب (Animation)
        [UIView animateWithDuration:0.5 animations:^{
            toastLabel.alpha = 1.0; // تظهر ببطء
        } completion:^(BOOL finished) {
            // تبقى ظاهرة لمدة 3 ثواني، ثم تختفي
            [UIView animateWithDuration:0.5 delay:3.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                toastLabel.alpha = 0.0; // تختفي ببطء
            } completion:^(BOOL finished) {
                [toastLabel removeFromSuperview]; // يتم مسحها من الشاشة نهائياً
            }];
        }];
    });
}
@end

__attribute__((constructor)) static void inject_ghost() { 
    [AmarGhostUI startGhostMode]; 
}
