#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h> 
#include <mach-o/dyld.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <netdb.h>
#include <errno.h>
#include <stdarg.h>

struct rebinding { const char *name; void *replacement; void **replaced; };
extern "C" int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

static bool isShieldActive = false;
static UIView *floatingContainer;
static UIButton *shieldBtn;
static UIButton *cleanBtn;

// =================================================================
// ===============  1. حماية بصمة التوقيع والغيابي (Integrity) =====
// =================================================================

// فلتر فائق السرعة لمنع اختناق المعالج (O(1) Check)
inline bool isDangerousPath(const char *path) {
    if (!path) return false;
    // نبحث فقط عن الملفات التي تفضح التعديل أو تخزن الباند الغيابي
    if (strstr(path, "embedded.mobileprovision") || // فحص التوقيع الخارجي
        strstr(path, "ShadowTrackerExtra/Saved/Logs") || // سجلات الغيابي
        strstr(path, "anogs") || 
        strstr(path, "Cydia") || 
        strstr(path, "TrollStore")) {
        return true;
    }
    return false;
}

// هوك stat: اللعبة تسأل "هل الملف موجود ومقاسه سليم؟"
static int (*orig_stat)(const char *path, struct stat *buf);
int my_stat(const char *path, struct stat *buf) {
    if (isShieldActive && isDangerousPath(path)) {
        errno = ENOENT; // تزييف: الملف غير موجود!
        return -1;
    }
    return orig_stat(path, buf);
}

// هوك lstat: نفس stat لكن للروابط الرمزية (Symlinks)
static int (*orig_lstat)(const char *path, struct stat *buf);
int my_lstat(const char *path, struct stat *buf) {
    if (isShieldActive && isDangerousPath(path)) {
        errno = ENOENT;
        return -1;
    }
    return orig_lstat(path, buf);
}

// هوك open: اللعبة تحاول فتح الملف لقراءته
static int (*orig_open)(const char *path, int oflag, ...);
int my_open(const char *path, int oflag, ...) {
    mode_t mode = 0;
    if (oflag & O_CREAT) {
        va_list args;
        va_start(args, oflag);
        mode = va_arg(args, int);
        va_end(args);
    }
    
    if (isShieldActive && isDangerousPath(path)) {
        errno = ENOENT; // منع فتح ملفات البصمة وسجلات الغيابي
        return -1;
    }
    
    if (oflag & O_CREAT) return orig_open(path, oflag, mode);
    return orig_open(path, oflag);
}

// =================================================================
// ===============  2. حماية الشهادة وحظر التجسس (Anti-Revoke) =====
// =================================================================

static int (*orig_getaddrinfo)(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res);
int my_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res) {
    if (isShieldActive && node) {
        // سيرفرات أبل (للشهادة) وسيرفرات تنسنت (للغيابي)
        const char* blockedDomains[] = {
            "ocsp.apple.com", "ppq.apple.com", "world-gen.g.aaplimg.com", // حماية الشهادة
            "app-measurement.com", "google-analytics.com", "crashsight"   // حماية الغيابي والإبلاغ
        };
        for (int i = 0; i < 6; i++) { 
            if (strstr(node, blockedDomains[i])) return EAI_NONAME; // تزييف: السيرفر لا يوجد!
        }
    }
    return orig_getaddrinfo(node, service, hints, res);
}

// =================================================================
// ===============  3. التنظيف اليدوي الاحتياطي (Deep Clean) =======
// =================================================================

void ExecuteDeepCleanBackup() {
    NSArray *paths = @[
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Logs", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/MMKV", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Pandora", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/RoleInfo.ini", NSHomeDirectory()]
    ];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *p in paths) { 
        if ([fm fileExistsAtPath:p]) [fm removeItemAtPath:p error:nil]; 
    }
}

// =================================================================
// ===============  أحداث الواجهة (Thread Safe Implementation) =====
// =================================================================

void ActionActivateIllusion() {
    if (isShieldActive) return;
    
    // زرع هوكات التخفي والبصمة فقط (بدون باتشات ذاكرة مدمرة)
    struct rebinding r[] = { 
        {"stat", (void*)my_stat, (void**)&orig_stat},
        {"lstat", (void*)my_lstat, (void**)&orig_lstat},
        {"open", (void*)my_open, (void**)&orig_open},
        {"getaddrinfo", (void*)my_getaddrinfo, (void**)&orig_getaddrinfo}
    };
    rebind_symbols(r, 4);
    
    isShieldActive = true;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [shieldBtn setTitle:@"🛡️ SAFE" forState:UIControlStateNormal];
        shieldBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.2 alpha:0.9]; 
        
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        pulse.duration = 0.2; pulse.repeatCount = 1; pulse.autoreverses = YES;
        pulse.fromValue = @(1.0); pulse.toValue = @(1.15);
        [shieldBtn.layer addAnimation:pulse forKey:@"transform"];
    });
}

void ActionCleanIllusion() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        ExecuteDeepCleanBackup(); 
        dispatch_async(dispatch_get_main_queue(), ^{
            [cleanBtn setTitle:@"✨ DONE" forState:UIControlStateNormal];
            cleanBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.2 alpha:0.9];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [cleanBtn setTitle:@"🧹 CLN" forState:UIControlStateNormal];
                cleanBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:0.9];
            });
        });
    });
}

// =================================================================
// ===============  واجهة المستخدم المزدوجة ========================
// =================================================================

@interface AmarIllusionUI : NSObject
+ (void)initializeUI;
@end

@implementation AmarIllusionUI
+ (void)initializeUI {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIWindowScene* s in [UIApplication sharedApplication].connectedScenes) {
            if (s.activationState == UISceneActivationStateForegroundActive) { win = s.windows.firstObject; break; }
        }
        if (!win) return;
        
        floatingContainer = [[UIView alloc] initWithFrame:CGRectMake(50, 150, 160, 75)];
        floatingContainer.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.85];
        floatingContainer.layer.cornerRadius = 37.5;
        floatingContainer.layer.borderWidth = 1.5;
        floatingContainer.layer.borderColor = [UIColor cyanColor].CGColor; 
        floatingContainer.clipsToBounds = YES;
        
        shieldBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        shieldBtn.frame = CGRectMake(5, 5, 65, 65);
        [shieldBtn setTitle:@"🛡️ OFF" forState:UIControlStateNormal];
        shieldBtn.backgroundColor = [UIColor colorWithRed:0.8 green:0.0 blue:0.0 alpha:1.0];
        shieldBtn.layer.cornerRadius = 32.5;
        shieldBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        [shieldBtn addTarget:self action:@selector(tapShield) forControlEvents:UIControlEventTouchUpInside];
        
        cleanBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        cleanBtn.frame = CGRectMake(90, 5, 65, 65);
        [cleanBtn setTitle:@"🧹 CLN" forState:UIControlStateNormal];
        cleanBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1.0];
        cleanBtn.layer.cornerRadius = 32.5;
        cleanBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        [cleanBtn addTarget:self action:@selector(tapClean) forControlEvents:UIControlEventTouchUpInside];
        
        [floatingContainer addSubview:shieldBtn];
        [floatingContainer addSubview:cleanBtn];
        
        UIPanGestureRecognizer *p = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
        [floatingContainer addGestureRecognizer:p];
        [win addSubview:floatingContainer];
    });
}

+ (void)pan:(UIPanGestureRecognizer *)p {
    CGPoint t = [p translationInView:p.view.superview];
    p.view.center = CGPointMake(p.view.center.x + t.x, p.view.center.y + t.y);
    [p setTranslation:CGPointZero inView:p.view.superview];
}

+ (void)tapShield { ActionActivateIllusion(); }
+ (void)tapClean { ActionCleanIllusion(); }
@end

__attribute__((constructor)) static void inject_illusion() { 
    [AmarIllusionUI initializeUI]; 
}
