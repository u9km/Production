#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h> 
#import <QuartzCore/QuartzCore.h> 
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <sys/sysctl.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <vector>
#include <thread>
#include <atomic>      // سلاح العمليات الذرية (Pro Level)
#include <netdb.h>
#include <dlfcn.h>
#include <string.h>

// =================================================================
// ===============  تحسينات المعالج (Branch Prediction) ============
// =================================================================
// هذه الماكروات تخبر المعالج بتخطي الفحص إذا لم يكن ضرورياً (تمنع الكراش واللاج)
#define LIKELY(x)   __builtin_expect(!!(x), 1)
#define UNLIKELY(x) __builtin_expect(!!(x), 0)

struct rebinding { const char *name; void *replacement; void **replaced; };
extern "C" int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

// استخدام std::atomic يمنع كراش تداخل المسارات (Race Conditions)
static std::atomic<bool> isShieldActive(false);

static UIView *floatingContainer;
static UIButton *shieldBtn;
static UIButton *cleanBtn;

// =================================================================
// ===============  دوال الذاكرة (مستوى النواة - Kernel Level) =====
// =================================================================

void patch_memory_titan(uintptr_t address, const uint8_t* data, size_t size) {
    if (UNLIKELY(address < 0x100000000 || !data || size == 0)) return; 
    
    mach_port_t self = mach_task_self();
    vm_size_t page_size;
    host_page_size(mach_host_self(), &page_size);
    
    // محاذاة صارمة لصفحات الذاكرة (Strict Page Alignment)
    vm_address_t page_start = (address / page_size) * page_size;
    vm_size_t size_to_protect = ((address + size + page_size - 1) / page_size) * page_size - page_start;
    
    if (LIKELY(vm_protect(self, page_start, size_to_protect, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) == KERN_SUCCESS)) {
        memcpy((void *)address, data, size);
        vm_protect(self, page_start, size_to_protect, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    }
}

// =================================================================
// ===============  الهوكات الفائقة (Ultra-Fast Hooks)  ============
// =================================================================

static int (*orig_access)(const char *path, int amode);
int my_access(const char *path, int amode) {
    // UNLIKELY تعني: في 99% من الحالات الدرع غير مفعل أو المسار فارغ، فامضِ بسرعة!
    if (UNLIKELY(isShieldActive.load(std::memory_order_relaxed) && path)) {
        // فحص سريع للحرف الأول قبل استدعاء strstr الثقيلة
        char first = path[0];
        if (first == '/' || first == 'a' || first == 'S' || first == 'C') {
            if (strstr(path, "anogs") || strstr(path, "Shadow") || strstr(path, "Cydia")) {
                return -1; // إيهام فوري
            }
        }
    }
    return orig_access(path, amode);
}

static int (*orig_stat)(const char *path, struct stat *buf);
int my_stat(const char *path, struct stat *buf) {
    if (UNLIKELY(isShieldActive.load(std::memory_order_relaxed) && path)) {
        if (strstr(path, "anogs") || strstr(path, "Shadow")) return -1; 
    }
    return orig_stat(path, buf);
}

static int (*orig_getaddrinfo)(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res);
int my_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res) {
    if (UNLIKELY(isShieldActive.load(std::memory_order_relaxed) && node)) {
        if (strstr(node, "apple.com") || strstr(node, "google-analytics")) return EAI_NONAME; 
    }
    return orig_getaddrinfo(node, service, hints, res);
}

// =================================================================
// ===============  المهام الخلفية العميقة (Deep Threads) ==========
// =================================================================

void ExecuteCleaningTitan() {
    NSArray *paths = @[
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Logs", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/MMKV", NSHomeDirectory()]
    ];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *p in paths) { 
        if ([fm fileExistsAtPath:p]) [fm removeItemAtPath:p error:nil]; 
    }
}

void ExecuteHeavyPatching() {
    uint32_t count = _dyld_image_count();
    uint8_t SMART_PATCH[] = {0x00, 0x00, 0x80, 0x52}; // MOV W0, #0
    
    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (UNLIKELY(name && strstr(name, "anogs"))) {
            const struct mach_header_64* header = (const struct mach_header_64*)_dyld_get_image_header(i);
            if (!header) continue;
            
            uintptr_t baseAddr = (uintptr_t)header;
            uintptr_t textStart = 0;
            uintptr_t textSize = 0;
            
            struct load_command* cmd = (struct load_command*)(baseAddr + sizeof(struct mach_header_64));
            for (uint32_t j = 0; j < header->ncmds; j++) {
                if (cmd->cmd == LC_SEGMENT_64) {
                    struct segment_command_64* seg = (struct segment_command_64*)cmd;
                    if (strcmp(seg->segname, "__TEXT") == 0) {
                        struct section_64* sec = (struct section_64*)((uintptr_t)seg + sizeof(struct segment_command_64));
                        for (uint32_t k = 0; k < seg->nsects; k++) {
                            if (strcmp(sec[k].sectname, "__text") == 0) {
                                textStart = baseAddr + sec[k].offset;
                                textSize = sec[k].size;
                                break;
                            }
                        }
                        break;
                    }
                }
                cmd = (struct load_command*)((uintptr_t)cmd + cmd->cmdsize);
            }

            if (textSize > 4) {
                for (uintptr_t curr = textStart; curr < textStart + textSize - 4; curr += 4) {
                    if (*(uint32_t*)curr == 0x52800008 || *(uint32_t*)curr == 0x52800009) {
                        patch_memory_titan(curr, SMART_PATCH, 4);
                    }
                }
            }
            break; // الخروج فور العثور على anogs وعمل الباتش
        }
    }
}

// =================================================================
// ===============  أحداث واجهة المستخدم (Thread-Safe UI) ==========
// =================================================================

void ActionTapShield() {
    bool expected = false;
    // إذا كانت مفعلة مسبقاً، لا تفعل شيئاً (يمنع كراش التفعيل المزدوج)
    if (!isShieldActive.compare_exchange_strong(expected, true)) return;
    
    struct rebinding r[] = { 
        {"access", (void*)my_access, (void**)&orig_access},
        {"stat", (void*)my_stat, (void**)&orig_stat},
        {"getaddrinfo", (void*)my_getaddrinfo, (void**)&orig_getaddrinfo}
    };
    rebind_symbols(r, 3);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [shieldBtn setTitle:@"🛡️ TITAN" forState:UIControlStateNormal];
        shieldBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.2 alpha:0.9];
        
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        pulse.duration = 0.3; pulse.repeatCount = 1; pulse.autoreverses = YES;
        pulse.fromValue = @(1.0); pulse.toValue = @(1.2);
        [shieldBtn.layer addAnimation:pulse forKey:@"transform"];
    });

    std::thread([]() {
        ExecuteHeavyPatching();
    }).detach();
}

void ActionTapClean() {
    std::thread([]() {
        ExecuteCleaningTitan();
        dispatch_async(dispatch_get_main_queue(), ^{
            [cleanBtn setTitle:@"✨ DONE" forState:UIControlStateNormal];
            cleanBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.2 alpha:0.9];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [cleanBtn setTitle:@"🧹 CLEAN" forState:UIControlStateNormal];
                cleanBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:0.9];
            });
        });
    }).detach();
}

// =================================================================
// ===============  تصميم اللوحة (Pro Max UI) ======================
// =================================================================

@interface AmarTitanUI : NSObject
+ (void)initializeUI;
@end

@implementation AmarTitanUI
+ (void)initializeUI {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIWindowScene* s in [UIApplication sharedApplication].connectedScenes) {
            if (s.activationState == UISceneActivationStateForegroundActive) { win = s.windows.firstObject; break; }
        }
        if (!win) return;
        
        floatingContainer = [[UIView alloc] initWithFrame:CGRectMake(50, 150, 160, 75)];
        floatingContainer.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.8]; // خلفية زجاجية داكنة
        floatingContainer.layer.cornerRadius = 37.5;
        floatingContainer.layer.borderWidth = 1.5;
        floatingContainer.layer.borderColor = [UIColor darkGrayColor].CGColor;
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

+ (void)tapShield { ActionTapShield(); }
+ (void)tapClean { ActionTapClean(); }
@end

__attribute__((constructor)) static void inject_titan() { 
    [AmarTitanUI initializeUI]; 
}
