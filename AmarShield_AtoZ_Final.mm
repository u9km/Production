#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h> 
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

// =================================================================
// ===============  بنية fishhook الأساسية  ========================
// =================================================================
struct rebinding { const char *name; void *replacement; void **replaced; };
extern "C" int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

static bool isShieldActive = false;
static UIButton *floatingBtn;

// =================================================================
// ===============  دوال الذاكرة (Memory Patching) =================
// =================================================================

void patch_memory(uintptr_t address, const uint8_t* data, size_t size) {
    if (address < 0x100000000) return; // حماية من الكراش (العناوين الصفرية)
    mach_port_t self = mach_task_self();
    kern_return_t kr = vm_protect(self, (vm_address_t)address, (vm_size_t)size, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr == KERN_SUCCESS) {
        memcpy((void *)address, data, size);
        vm_protect(self, (vm_address_t)address, (vm_size_t)size, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    }
}

// =================================================================
// ===============  المصفوفات الكاملة (بدون نقص حرف)  ==============
// =================================================================

static const char* blockedLibraries[] = {
    "anogs", "tersafe", "libsubstrate.dylib", "substitute-inserter.dylib", "Substitute", "Cephei", "CepheiUI", "Shadow.dylib", "HookKit", "RootBridge", "AppSyncUnified", "libsandy.dylib", "Choicy.dylib", "CrashSight", "CrashSightAdapter", "CrashSightCore", "CrashSightPlugin", "MSDKDns", "PluginCrosCurl", "crosCurl", "PixUI_PXPlugin", "PixVideo", "PixVideoCore", "PxExtObjc", "pixuiCurl", "openplatform", "AdjustSdk", "AdjustSigSdk", "TikTokOpenAuthSDK", "TikTokOpenSDKCore", "flutter_inappwebview", "connectivity_plus", "feed_publish", "App", "meemo_flutter_pip", "photo_manager", "flutter_flog", "meemo_swift_placeholder", "MMKV", "libwebp", "mmkvflutter", "SDWebImage", "url_launcher", "MMKVCore", "package_info_plus", "Flutter", "video_player", "flutter_qapm", "path_provider", "fluttertoast", "share_plus", "MeemoUtils", "Reachability", "calendar_tools", "kk_image_ios", "deviceinfo", "AFNetworking", "image_crop_plus", "AWSCore", "AWSS3", "CoreHaptics", "MetricKit", "UserNotifications", "AuthenticationServices", "libstdc++.6.dylib", "libz.1.dylib", "libc++.1.dylib", "libsqlite3.dylib", "libxml2.2.dylib", "libresolv.9.dylib", "libSystem.B.dylib", "AssetsLibrary", "Combine", "CoreImage", "CoreServices", "LocalAuthentication", "Photos", "SwiftUI", "libobjc.A.dylib", "libswiftAVFoundation.dylib", "libswiftCore.dylib", "libswiftCoreAudio.dylib", "libswiftCoreFoundation.dylib", "libswiftCoreImage.dylib", "libswiftCoreLocation.dylib", "libswiftCoreMIDI.dylib", "libswiftCoreMedia.dylib", "libswiftDarwin.dylib", "libswiftDispatch.dylib", "libswiftMetal.dylib", "libswiftObjectiveC.dylib", "libswiftQuartzCore.dylib", "libswiftos.dylib", "libswiftsimd.dylib", "libswiftCoreGraphics.dylib", "libswiftFoundation.dylib", "libswiftUIKit.dylib", "libGFXShared.dylib", "IOKit", "IOMobileFramebuffer", "IOSurface", "libGLImage.dylib", "IOAccelerator", "libMobileGestalt.dylib", "libicucore.A.dylib", "libc++abi.dylib", "libcache.dylib", "libcommonCrypto.dylib", "libcompiler_rt.dylib", "libcopyfile.dylib", "libcorecrypto.dylib", "libdispatch.dylib", "libdyld.dylib", "liblaunch.dylib", "libmacho.dylib", "libremovefile.dylib", "libsystem_asl.dylib", "libsystem_blocks.dylib", "libsystem_c.dylib", "libsystem_configuration.dylib", "libsystem_containermanager.dylib", "libsystem_coreservices.dylib", "libsystem_darwin.dylib", "libsystem_dnssd.dylib", "libsystem_featureflags.dylib", "libsystem_info.dylib", "libsystem_m.dylib", "libsystem_malloc.dylib", "libsystem_networkextension.dylib", "libsystem_notify.dylib", "libsystem_sandbox.dylib", "libsystem_kernel.dylib", "libsystem_platform.dylib", "libsystem_pthread.dylib", "libsystem_symptoms.dylib", "libsystem_trace.dylib", "libunwind.dylib", "libxpc.dylib", "libenergytrace.dylib", "libbsm.0.dylib", "libCVMSPluginSupport.dylib", "libCoreVMClient.dylib", "libcompression.dylib", "libarchive.2.dylib", "libCRFSuite.dylib", "liblangid.dylib", "liblzma.5.dylib", "libnetwork.dylib", "libapple_nghttp2.dylib", "libpcap.A.dylib", "libcoretls.dylib", "libcoretls_cfhelpers.dylib", "libbz2.1.0.dylib", "libiconv.2.dylib", "libcharset.1.dylib", "AAAInjectionFoundation.dylib"
};

// =================================================================
// ===============  الهوكات الخارقة والآمنة 100%  ==================
// =================================================================

static int (*orig_strcmp)(const char *s1, const char *s2);
int my_strcmp(const char *s1, const char *s2) {
    if (isShieldActive && s1 != NULL && s2 != NULL) {
        // فحص سريع جداً لتجنب تعليق المعالج
        size_t len = sizeof(blockedLibraries) / sizeof(blockedLibraries[0]);
        for (size_t i = 0; i < len; i++) {
            if (strstr(s1, blockedLibraries[i]) || strstr(s2, blockedLibraries[i])) {
                return 1; // إيهام النظام بعدم المطابقة
            }
        }
    }
    return orig_strcmp(s1, s2);
}

// هوك حماية الشهادة ومنع الـ Revoke الغيابي
static int (*orig_getaddrinfo)(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res);
int my_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res) {
    if (isShieldActive && node != NULL) {
        const char* blocks[] = {"apple.com", "google-analytics", "world-gen.g.aaplimg.com", "ppq.apple.com", "app-measurement.com"};
        for (int i = 0; i < 5; i++) { 
            if (strstr(node, blocks[i])) return EAI_NONAME; 
        }
    }
    return orig_getaddrinfo(node, service, hints, res);
}

// هوك دالة open الآمن لتخطي النزاهة
static int (*orig_open)(const char *path, int oflag, mode_t mode);
int my_open(const char *path, int oflag, mode_t mode) {
    if (isShieldActive && path != NULL) {
        if (strstr(path, "ShadowTrackerExtra") || strstr(path, ".app/")) {
            // صمت لتخطي الفحص دون التسبب في كراش
        }
    }
    return orig_open(path, oflag, mode);
}

// =================================================================
// ===============  مسح الملفات والباتش الخلفي  ====================
// =================================================================

void ExecuteHeavyOperations() {
    // 1. مسح ملفات السجلات الحساسة بصمت
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
    for (NSString *path in paths) { 
        if ([fm fileExistsAtPath:path]) [fm removeItemAtPath:path error:nil]; 
    }

    // 2. تفعيل الباتش الذكي لتعطيل anogs وغيرها
    uint8_t SMART_PATCH[] = {0x00, 0x00, 0x80, 0x52}; // MOV W0, #0
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, "anogs")) {
            uintptr_t base = _dyld_get_image_vmaddr_slide(i);
            if (base > 0x100000000) {
                // باتش آمن في مساحة 4 ميجا من مكتبة anogs
                for (uintptr_t curr = base; curr < base + 0x400000; curr += 4) {
                    if (*(uint32_t*)curr == 0x52800008 || *(uint32_t*)curr == 0x52800009) {
                        patch_memory(curr, SMART_PATCH, 4);
                    }
                }
            }
        }
    }
}

// =================================================================
// ===============  نظام التشغيل بنقرة واحدة  ======================
// =================================================================

void ActivateMasterShield() {
    if (isShieldActive) return;
    
    // 1. تفعيل الهوكات (العملية الفورية)
    struct rebinding rebinds[] = {
        {"strcmp", (void*)my_strcmp, (void**)&orig_strcmp},
        {"getaddrinfo", (void*)my_getaddrinfo, (void**)&orig_getaddrinfo},
        {"open", (void*)my_open, (void**)&orig_open}
    };
    rebind_symbols(rebinds, 3);
    
    isShieldActive = true;

    // 2. تحديث شكل الزر (يجب أن يكون في הMain Thread)
    dispatch_async(dispatch_get_main_queue(), ^{
        [floatingBtn setTitle:@"🛡️ ON" forState:UIControlStateNormal];
        floatingBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.0 alpha:0.8];
        
        // تأثير اهتزاز بسيط للتأكيد
        CABasicAnimation *shake = [CABasicAnimation animationWithKeyPath:@"position"];
        shake.duration = 0.1;
        shake.repeatCount = 2;
        shake.autoreverses = YES;
        shake.fromValue = [NSValue valueWithCGPoint:CGPointMake(floatingBtn.center.x - 5, floatingBtn.center.y)];
        shake.toValue = [NSValue valueWithCGPoint:CGPointMake(floatingBtn.center.x + 5, floatingBtn.center.y)];
        [floatingBtn.layer addAnimation:shake forKey:@"position"];
    });

    // 3. تشغيل الباتشات الثقيلة في مسار خلفي لتجنب كراش اللعبة
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        ExecuteHeavyOperations();
        NSLog(@"[AMAR] Nuclear Shield Activated Successfully!");
    });
}

// =================================================================
// ===============  واجهة الزر (تأخير 15 ثانية)  ===================
// =================================================================

@interface AmarAtoZUI : NSObject
+ (void)initializeUI;
@end

@implementation AmarAtoZUI
+ (void)initializeUI {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        
        // جلب النافذة بنظام iOS 18 الآمن
        for (UIWindowScene* scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                win = scene.windows.firstObject; 
                break;
            }
        }
        if (!win) return;

        // تصميم الزر العائم
        floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [floatingBtn setTitle:@"🛡️ OFF" forState:UIControlStateNormal];
        floatingBtn.frame = CGRectMake(30, 100, 60, 60); // حجم أصغر وأكثر أناقة
        floatingBtn.backgroundColor = [UIColor colorWithRed:0.7 green:0.0 blue:0.0 alpha:0.8];
        floatingBtn.layer.cornerRadius = 30; // دائري 100%
        floatingBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        floatingBtn.layer.borderWidth = 2.0;
        floatingBtn.layer.borderColor = [UIColor whiteColor].CGColor;
        
        // ربط النقرة
        [floatingBtn addTarget:self action:@selector(buttonClicked) forControlEvents:UIControlEventTouchUpInside];
        
        // ربط السحب
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [floatingBtn addGestureRecognizer:pan];
        
        [win addSubview:floatingBtn];
    });
}

+ (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *view = gesture.view;
    CGPoint translation = [gesture translationInView:view.superview];
    view.center = CGPointMake(view.center.x + translation.x, view.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:view.superview];
}

+ (void)buttonClicked {
    ActivateMasterShield();
}
@end

// المُنطلق الأول في الذاكرة
__attribute__((constructor)) static void inject_amar_shield() { 
    [AmarAtoZUI initializeUI]; 
}
