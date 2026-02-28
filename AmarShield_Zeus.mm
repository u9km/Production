#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h> 
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <sys/sysctl.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <netdb.h>
#include <errno.h> // ضروري لعكس قيم النظام بشكل قانوني

struct rebinding { const char *name; void *replacement; void **replaced; };
extern "C" int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

static bool isShieldActive = false;
static UIView *floatingContainer;
static UIButton *shieldBtn;
static UIButton *cleanBtn;

// =================================================================
// ===============  عكس قيم الفحص بصمت (Deep Spoofing) =============
// =================================================================

// 1. تزييف فحص الـ Debugger والنظام (إرجاع قيمة نظيفة 100%)
static int (*orig_sysctl)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
int my_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int ret = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    
    // إذا كان الدرع مفعلاً واللعبة تفحص حالة العمليات (KERN_PROC)
    if (isShieldActive && ret == 0 && name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID) {
        if (oldp) {
            struct kinfo_proc *info = (struct kinfo_proc *)oldp;
            // عكس القيمة: نمسح علامة التتبع (P_TRACED) من النتيجة المرجعة دون أن تشعر اللعبة
            if (info->kp_proc.p_flag & P_TRACED) {
                info->kp_proc.p_flag &= ~P_TRACED; 
            }
        }
    }
    return ret;
}

// 2. عكس مسارات فحص الملفات (محاكاة إيقاع النظام بـ ENOENT)
static int (*orig_access)(const char *path, int amode);
int my_access(const char *path, int amode) {
    int ret = orig_access(path, amode);
    if (isShieldActive && path && ret == 0) { // إذا وجد النظام الملف فعلاً
        if (strstr(path, "anogs") || strstr(path, "Shadow") || strstr(path, "Cydia")) {
            errno = ENOENT; // "عكس القيمة": إجبار النظام على إعلان أن الملف تبخر!
            return -1;
        }
    }
    return ret;
}

static int (*orig_stat)(const char *path, struct stat *buf);
int my_stat(const char *path, struct stat *buf) {
    int ret = orig_stat(path, buf);
    if (isShieldActive && path && ret == 0) {
        if (strstr(path, "anogs") || strstr(path, "Shadow") || strstr(path, "Cydia")) {
            errno = ENOENT;
            return -1;
        }
    }
    return ret;
}

// 3. قطع نبض السيرفرات التجسسية
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
// ===============  دوال الذاكرة (بتناغم تام) ======================
// =================================================================

void patch_memory_rhythm(uintptr_t address, const uint8_t* data, size_t size) {
    if (address < 0x100000000 || !data || size == 0) return; 
    mach_port_t self = mach_task_self();
    vm_size_t page_size; host_page_size(mach_host_self(), &page_size);
    vm_address_t page_start = (address / page_size) * page_size;
    vm_size_t size_to_protect = ((address + size + page_size - 1) / page_size) * page_size - page_start;
    
    if (vm_protect(self, page_start, size_to_protect, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) == KERN_SUCCESS) {
        memcpy((void *)address, data, size);
        vm_protect(self, page_start, size_to_protect, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    }
}

void ExecuteDeepClean() {
    NSArray *paths = @[
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Logs", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/MMKV", NSHomeDirectory()]
    ];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *p in paths) { if ([fm fileExistsAtPath:p]) [fm removeItemAtPath:p error:nil]; }
}

// =================================================================
// ===============  التحكم بإيقاع التطبيق (CADisplayLink) ==========
// =================================================================

@interface AmarTurboEngine : NSObject
@property (nonatomic, strong) CADisplayLink *rhythmLink;
+ (instancetype)sharedEngine;
- (void)startSystemRhythm;
@end

@implementation AmarTurboEngine
+ (instancetype)sharedEngine {
    static AmarTurboEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)startSystemRhythm {
    // ربط الحماية بنبض الشاشة (60/120 إطار في الثانية) لمنع الكراش
    self.rhythmLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(rhythmTick)];
    [self.rhythmLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)rhythmTick {
    // هذه الدالة تنبض مع اللعبة.. يمكننا استخدامها لاحقاً لفحص الذاكرة بهدوء دون مسارات خارجية
}
@end

// =================================================================
// ===============  واجهة المستخدم المرتبطة بالنظام ================
// =================================================================

void ActionTapShieldTurbo() {
    if (isShieldActive) return;
    
    // تفعيل الهوكات التي تعكس قيم الفحص
    struct rebinding r[] = { 
        {"sysctl", (void*)my_sysctl, (void**)&orig_sysctl},
        {"access", (void*)my_access, (void**)&orig_access},
        {"stat", (void*)my_stat, (void**)&orig_stat},
        {"getaddrinfo", (void*)my_getaddrinfo, (void**)&orig_getaddrinfo}
    };
    rebind_symbols(r, 4);
    
    isShieldActive = true;
    
    // تشغيل محرك الإيقاع الخاص بنا
    [[AmarTurboEngine sharedEngine] startSystemRhythm];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [shieldBtn setTitle:@"⚡ TURBO" forState:UIControlStateNormal];
        shieldBtn.backgroundColor = [UIColor colorWithRed:0.5 green:0.0 blue:0.8 alpha:0.9]; // لون ديب ويب 😈
        
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        pulse.duration = 0.2; pulse.repeatCount = 1; pulse.autoreverses = YES;
        pulse.fromValue = @(1.0); pulse.toValue = @(1.15);
        [shieldBtn.layer addAnimation:pulse forKey:@"transform"];
    });

    // باتش الذاكرة الخفيف
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        uint32_t count = _dyld_image_count();
        uint8_t SMART_PATCH[] = {0x00, 0x00, 0x80, 0x52}; 
        for (uint32_t i = 0; i < count; i++) {
            const char* name = _dyld_get_image_name(i);
            if (name && strstr(name, "anogs")) {
                const struct mach_header_64* header = (const struct mach_header_64*)_dyld_get_image_header(i);
                if (!header) continue;
                uintptr_t baseAddr = (uintptr_t)header;
                
                struct load_command* cmd = (struct load_command*)(baseAddr + sizeof(struct mach_header_64));
                for (uint32_t j = 0; j < header->ncmds; j++) {
                    if (cmd->cmd == LC_SEGMENT_64) {
                        struct segment_command_64* seg = (struct segment_command_64*)cmd;
                        if (strcmp(seg->segname, "__TEXT") == 0) {
                            struct section_64* sec = (struct section_64*)((uintptr_t)seg + sizeof(struct segment_command_64));
                            for (uint32_t k = 0; k < seg->nsects; k++) {
                                if (strcmp(sec[k].sectname, "__text") == 0) {
                                    for (uintptr_t curr = baseAddr + sec[k].offset; curr < baseAddr + sec[k].offset + sec[k].size - 4; curr += 4) {
                                        if (*(uint32_t*)curr == 0x52800008 || *(uint32_t*)curr == 0x52800009) {
                                            patch_memory_rhythm(curr, SMART_PATCH, 4);
                                        }
                                    }
                                }
                            }
                            break;
                        }
                    }
                    cmd = (struct load_command*)((uintptr_t)cmd + cmd->cmdsize);
                }
                break;
            }
        }
    });
}

void ActionTapCleanTurbo() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        ExecuteDeepClean(); 
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
// ===============  الواجهة المبنية على الإيقاع ====================
// =================================================================

@interface AmarTurboUI : NSObject
+ (void)initializeUI;
@end

@implementation AmarTurboUI
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
        floatingContainer.layer.borderColor = [UIColor purpleColor].CGColor; // لمسة الـ Turbo
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

+ (void)tapShield { ActionTapShieldTurbo(); }
+ (void)tapClean { ActionTapCleanTurbo(); }
@end

__attribute__((constructor)) static void inject_turbo() { 
    [AmarTurboUI initializeUI]; 
}
