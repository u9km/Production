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
#include <netdb.h>
#include <dlfcn.h>
#include <string.h>

struct rebinding { const char *name; void *replacement; void **replaced; };
extern "C" int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

static bool isShieldActive = false;
static UIView *floatingContainer;
static UIButton *shieldBtn;
static UIButton *cleanBtn;

// =================================================================
// ===============  دوال الذاكرة (محمية ضد الكراش 100%) ============
// =================================================================

void patch_memory(uintptr_t address, const uint8_t* data, size_t size) {
    if (address < 0x100000000 || !data || size == 0) return; 
    
    mach_port_t self = mach_task_self();
    vm_size_t page_size = 16384; // حجم صفحة الذاكرة الافتراضي في iOS
    host_page_size(mach_host_self(), &page_size);
    
    // محاذاة العنوان لتجنب كراش EXC_BAD_ACCESS
    vm_address_t page_start = (vm_address_t)(address & ~(page_size - 1));
    
    kern_return_t kr = vm_protect(self, page_start, page_size, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr == KERN_SUCCESS) {
        memcpy((void *)address, data, size);
        vm_protect(self, page_start, page_size, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    }
}

uintptr_t findPatternInImage(const char* pattern, const char* mask, size_t len, int imageIndex = 0) {
    const struct mach_header_64* header = (const struct mach_header_64*)_dyld_get_image_header(imageIndex);
    if (!header) return 0;
    uintptr_t base = (uintptr_t)header;
    uintptr_t textSize = 0;
    struct load_command* cmd = (struct load_command*)(base + sizeof(struct mach_header_64));
    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cmd->cmd == LC_SEGMENT_64) {
            struct segment_command_64* seg = (struct segment_command_64*)cmd;
            if (strcmp(seg->segname, "__TEXT") == 0) { textSize = seg->vmsize; break; }
        }
        cmd = (struct load_command*)((uintptr_t)cmd + cmd->cmdsize);
    }
    
    if (textSize < len || textSize == 0) return 0; 
    
    for (uintptr_t addr = base; addr <= base + textSize - len; addr++) {
        bool found = true;
        for (size_t i = 0; i < len; i++) {
            if (mask[i] == 'x' && ((uint8_t*)addr)[i] != (uint8_t)pattern[i]) { found = false; break; }
        }
        if (found) return addr;
    }
    return 0;
}

// =================================================================
// ===============  المصفوفة المفلترة للسرعة القصوى  ===============
// =================================================================

// تم تقليل البحث ليركز على أدوات الحماية الحقيقية لمنع كراش المعالج
static const char* criticalLibraries[] = {
    "anogs", "tersafe", "libsubstrate", "Substitute", "Shadow.dylib", 
    "HookKit", "RootBridge", "Choicy", "CrashSight", "MSDKDns", "Cephei"
};

// =================================================================
// ===============  الهوكات الفولاذية (لا تسبب أي تعليق) ===========
// =================================================================

static int (*orig_strcmp)(const char *s1, const char *s2);
int my_strcmp(const char *s1, const char *s2) {
    if (isShieldActive && s1 && s2 && s1[0] != '\0' && s2[0] != '\0') {
        // فلتر فائق السرعة: لا يبحث إلا إذا كانت الكلمة أطول من 4 حروف وتبدأ بحروف محددة
        if (s1[4] != '\0' || s2[4] != '\0') {
            char c = s1[0];
            if (c == 'a' || c == 't' || c == 'l' || c == 'S' || c == 'C' || c == 'H' || c == 'M' || c == 'R') { 
                size_t count = sizeof(criticalLibraries) / sizeof(criticalLibraries[0]);
                for (size_t i = 0; i < count; i++) {
                    if (strstr(s1, criticalLibraries[i]) || strstr(s2, criticalLibraries[i])) return 1;
                }
            }
        }
    }
    return orig_strcmp(s1, s2);
}

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
// ===============  دوال التنظيف والباتش الذكي  ====================
// =================================================================

void ExecuteCleaning() {
    NSArray *paths = @[
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Logs", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/MMKV", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Config", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Pandora", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Pandora2", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Config.ini", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/NetLogin.cfg", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/RoleInfo.ini", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/PlayerPrefs", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Table", NSHomeDirectory()]
    ];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *p in paths) { if ([fm fileExistsAtPath:p]) [fm removeItemAtPath:p error:nil]; }
    NSLog(@"[AMAR] Cleaned sensitive files successfully!");
}

void ExecSmartPatchSafe(uint32_t imageIndex) {
    const struct mach_header_64* header = (const struct mach_header_64*)_dyld_get_image_header(imageIndex);
    if (!header) return;
    uintptr_t baseAddr = (uintptr_t)header;
    uintptr_t textSize = 0;
    
    struct load_command* cmd = (struct load_command*)(baseAddr + sizeof(struct mach_header_64));
    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cmd->cmd == LC_SEGMENT_64) {
            struct segment_command_64* seg = (struct segment_command_64*)cmd;
            if (strcmp(seg->segname, "__TEXT") == 0) { textSize = seg->vmsize; break; }
        }
        cmd = (struct load_command*)((uintptr_t)cmd + cmd->cmdsize);
    }
    if (textSize < 4) return;

    uint8_t SMART_PATCH[] = {0x00, 0x00, 0x80, 0x52}; 
    
    // محاذاة العناوين لتجنب كراش SIGBUS (أهم خطوة)
    uintptr_t startAddr = baseAddr + ((4 - (baseAddr % 4)) % 4);
    
    for (uintptr_t curr = startAddr; curr < baseAddr + textSize - 4; curr += 4) {
        uint32_t val = *(uint32_t*)curr;
        if (val == 0x52800008 || val == 0x52800009) {
            patch_memory(curr, SMART_PATCH, 4);
        }
    }
}

void ActivateAmarOriginalPatterns() {
    struct { const char* pattern; const char* mask; size_t len; } patterns[] = {
        { "\xFF\x43\x01\xD1\xF6\x57\x02\xA9\xF4\x4F\x03\xA9\xFD\x7B\x04\xA9\xFD\x83\x00\x91", "xxxxxxxxxxxxxxxxxxxx", 20 },
        { "\xF0\x4F\x01\xD1\xFD\x7B\x06\xA9\xFD\x03\x00\x91", "xxxxxxxxxxxx", 12 },
        { "\xF5\x4F\x01\xD1\xF3\x5F\x02\xA9\xFD\x7B\x04\xA9\xFD\x83\x00\x91\x68\x12\x40\xF9\x08\x01\x00\x34", "xxxxxxxxxxxxxxxxxxxxxxxx", 24 },
        { "\xF8\x5F\x02\xA9\xF6\x57\x03\xA9\xF4\x4F\x04\xA9\xFD\x7B\x05\xA9\xFD\x43\x00\x91", "xxxxxxxxxxxxxxxxxxxx", 20 },
        { "\xFC\x6F\x05\xA9\xFA\x67\x06\xA9\xF8\x5F\x07\xA9\xF6\x57\x08\xA9\xF4\x4F\x09\xA9\xFD\x7B\x0A\xA9\xFD\x43\x01\x91", "xxxxxxxxxxxxxxxxxxxxxxxxxxxx", 28 }
    };
    uint8_t ret[] = {0xC0, 0x03, 0x5F, 0xD6}; 
    for (size_t i = 0; i < sizeof(patterns)/sizeof(patterns[0]); i++) {
        uintptr_t addr = findPatternInImage(patterns[i].pattern, patterns[i].mask, patterns[i].len, 0);
        if (addr) patch_memory(addr, ret, 4);
    }
}

// =================================================================
// ===============  أحداث الأزرار (في الخلفية بدون تجميد) ==========
// =================================================================

void ActionTapShield() {
    if (isShieldActive) return;
    
    struct rebinding r[] = { 
        {"strcmp", (void*)my_strcmp, (void**)&orig_strcmp},
        {"getaddrinfo", (void*)my_getaddrinfo, (void**)&orig_getaddrinfo}
    };
    rebind_symbols(r, 2);
    isShieldActive = true;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [shieldBtn setTitle:@"🛡️ ON" forState:UIControlStateNormal];
        shieldBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.0 alpha:0.9];
        CABasicAnimation *shake = [CABasicAnimation animationWithKeyPath:@"position"];
        shake.duration = 0.08; shake.repeatCount = 2; shake.autoreverses = YES;
        shake.fromValue = [NSValue valueWithCGPoint:CGPointMake(shieldBtn.center.x-5, shieldBtn.center.y)];
        shake.toValue = [NSValue valueWithCGPoint:CGPointMake(shieldBtn.center.x+5, shieldBtn.center.y)];
        [shieldBtn.layer addAnimation:shake forKey:@"position"];
    });

    // التنفيذ في المعالج الخلفي لحماية الواجهة من التجميد والكراش
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        ActivateAmarOriginalPatterns();
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char* name = _dyld_get_image_name(i);
            if (name && strstr(name, "anogs")) {
                ExecSmartPatchSafe(i);
                break;
            }
        }
    });
}

void ActionTapClean() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        ExecuteCleaning(); 
        dispatch_async(dispatch_get_main_queue(), ^{
            [cleanBtn setTitle:@"✨ Done" forState:UIControlStateNormal];
            cleanBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:0.9];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [cleanBtn setTitle:@"🧹 Clean" forState:UIControlStateNormal];
                cleanBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:0.9];
            });
        });
    });
}

// =================================================================
// ===============  لوحة التحكم المزدوجة (تأخير 15 ثانية)  =========
// =================================================================

@interface AmarDualPanelUI : NSObject
+ (void)showPanel;
@end

@implementation AmarDualPanelUI
+ (void)showPanel {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIWindowScene* s in [UIApplication sharedApplication].connectedScenes) {
            if (s.activationState == UISceneActivationStateForegroundActive) { win = s.windows.firstObject; break; }
        }
        if (!win) return;
        
        floatingContainer = [[UIView alloc] initWithFrame:CGRectMake(50, 150, 150, 70)];
        floatingContainer.backgroundColor = [UIColor clearColor];
        
        shieldBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        shieldBtn.frame = CGRectMake(0, 0, 70, 70);
        [shieldBtn setTitle:@"🛡️ OFF" forState:UIControlStateNormal];
        shieldBtn.backgroundColor = [UIColor colorWithRed:0.8 green:0.0 blue:0.0 alpha:0.9];
        shieldBtn.layer.cornerRadius = 35;
        shieldBtn.layer.borderWidth = 2;
        shieldBtn.layer.borderColor = [UIColor whiteColor].CGColor;
        shieldBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        [shieldBtn addTarget:self action:@selector(tapShield) forControlEvents:UIControlEventTouchUpInside];
        
        cleanBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        cleanBtn.frame = CGRectMake(80, 0, 70, 70);
        [cleanBtn setTitle:@"🧹 Clean" forState:UIControlStateNormal];
        cleanBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:0.9];
        cleanBtn.layer.cornerRadius = 35;
        cleanBtn.layer.borderWidth = 2;
        cleanBtn.layer.borderColor = [UIColor whiteColor].CGColor;
        cleanBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
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

__attribute__((constructor)) static void init_dual_panel() { 
    [AmarDualPanelUI showPanel]; 
}
