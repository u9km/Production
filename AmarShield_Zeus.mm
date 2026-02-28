#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h> 
#include <mach-o/dyld.h>
#include <netdb.h>
#include <string.h>
#include <unistd.h>

struct rebinding { const char *name; void *replacement; void **replaced; };
extern "C" int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

static bool isShieldActive = false;
static UIView *floatingContainer;
static UIButton *shieldBtn;
static UIButton *cleanBtn;

// =================================================================
// ===============  الهوكات الآمنة (AMFI Safe Hooks) ===============
// =================================================================

// 1. هوك التخفي الفائق (بدون إرهاق المعالج)
static int (*orig_strcmp)(const char *s1, const char *s2);
int my_strcmp(const char *s1, const char *s2) {
    if (isShieldActive && s1 && s2 && s1[0] != '\0' && s2[0] != '\0') {
        // فحص سريع ومحدود جداً لمنع أي كراش في المعالج
        char c = s1[0];
        if (c == 'a' || c == 'S' || c == 'C') { 
            if (strstr(s1, "anogs") || strstr(s2, "anogs") || 
                strstr(s1, "Shadow") || strstr(s2, "Shadow") ||
                strstr(s1, "Cydia") || strstr(s2, "Cydia")) {
                return 1; // إخفاء المكتبة بصمت
            }
        }
    }
    return orig_strcmp(s1, s2);
}

// 2. هوك حماية الشهادات (Anti-Revoke)
static int (*orig_getaddrinfo)(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res);
int my_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res) {
    if (isShieldActive && node) {
        const char* blocks[] = {"apple.com", "google-analytics.com", "world-gen.g.aaplimg.com", "ppq.apple.com", "app-measurement.com"};
        for (int i = 0; i < 5; i++) { 
            if (strstr(node, blocks[i])) return EAI_NONAME; 
        }
    }
    return orig_getaddrinfo(node, service, hints, res);
}

// =================================================================
// ===============  نظام التنظيف العميق (Anti-Ban) =================
// =================================================================

void ExecuteDeepCleanSafe() {
    NSArray *paths = @[
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Logs", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/MMKV", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Config", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Pandora", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/RoleInfo.ini", NSHomeDirectory()]
    ];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *p in paths) { 
        if ([fm fileExistsAtPath:p]) {
            [fm removeItemAtPath:p error:nil]; 
        }
    }
}

// =================================================================
// ===============  أحداث واجهة المستخدم (Thread Safe) =============
// =================================================================

void ActionTapShieldSafe() {
    if (isShieldActive) return;
    
    // تفعيل الهوكات الآمنة فقط (لا نلمس access ولا stat ولا الذاكرة المباشرة)
    struct rebinding r[] = { 
        {"strcmp", (void*)my_strcmp, (void**)&orig_strcmp},
        {"getaddrinfo", (void*)my_getaddrinfo, (void**)&orig_getaddrinfo}
    };
    rebind_symbols(r, 2);
    
    isShieldActive = true;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [shieldBtn setTitle:@"🛡️ ON" forState:UIControlStateNormal];
        shieldBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.2 alpha:0.9]; 
        
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        pulse.duration = 0.2; pulse.repeatCount = 1; pulse.autoreverses = YES;
        pulse.fromValue = @(1.0); pulse.toValue = @(1.15);
        [shieldBtn.layer addAnimation:pulse forKey:@"transform"];
    });
}

void ActionTapCleanSafe() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        ExecuteDeepCleanSafe(); 
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
// ===============  تصميم اللوحة القابلة للسحب =====================
// =================================================================

@interface AmarSurvivalUI : NSObject
+ (void)initializeUI;
@end

@implementation AmarSurvivalUI
+ (void)initializeUI {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIWindowScene* s in [UIApplication sharedApplication].connectedScenes) {
            if (s.activationState == UISceneActivationStateForegroundActive) { win = s.windows.firstObject; break; }
        }
        if (!win) return;
        
        floatingContainer = [[UIView alloc] initWithFrame:CGRectMake(50, 150, 160, 75)];
        floatingContainer.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.85];
        floatingContainer.layer.cornerRadius = 37.5;
        floatingContainer.layer.borderWidth = 1.5;
        floatingContainer.layer.borderColor = [UIColor greenColor].CGColor; // لون النجاة
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

+ (void)tapShield { ActionTapShieldSafe(); }
+ (void)tapClean { ActionTapCleanSafe(); }
@end

__attribute__((constructor)) static void inject_survival() { 
    [AmarSurvivalUI initializeUI]; 
}
