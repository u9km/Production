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

// --- تعريف هيكل مكتبة fishhook للعمل بدون جيلبريك ---
struct rebinding { const char *name; void *replacement; void **replaced; };
extern "C" int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

static bool isShieldActive = false;
static UIButton *floatingBtn;

// =================================================================
// ===============  دوال الحماية والتعديل (Protection) =============
// =================================================================

void patch_memory(uintptr_t address, const uint8_t* data, size_t size) {
    if (!address) return;
    mach_port_t self = mach_task_self();
    vm_protect(self, (vm_address_t)address, (vm_size_t)size, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    memcpy((void *)address, data, size);
    vm_protect(self, (vm_address_t)address, (vm_size_t)size, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
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
    if (textSize == 0) return 0;
    for (uintptr_t addr = base; addr < base + textSize; addr++) {
        bool found = true;
        for (size_t i = 0; i < len; i++) {
            if (mask[i] == 'x' && ((uint8_t*)addr)[i] != (uint8_t)pattern[i]) { found = false; break; }
        }
        if (found) return addr;
    }
    return 0;
}

// =================================================================
// ===============  نظام الهوك (قائمة المكتبات الكاملة) ============
// =================================================================

static int (*orig_strcmp)(const char *s1, const char *s2);
static const char* blockedLibraries[] = { "anogs", "tersafe", "libsubstrate.dylib", "substitute-inserter.dylib", "Substitute", "Cephei", "CepheiUI", "Shadow.dylib", "HookKit", "RootBridge", "AppSyncUnified", "libsandy.dylib", "Choicy.dylib", "CrashSight", "CrashSightAdapter", "CrashSightCore", "CrashSightPlugin", "MSDKDns", "PluginCrosCurl", "crosCurl", "PixUI_PXPlugin", "PixVideo", "PixVideoCore", "PxExtObjc", "pixuiCurl", "openplatform", "AdjustSdk", "AdjustSigSdk", "TikTokOpenAuthSDK", "TikTokOpenSDKCore", "flutter_inappwebview", "connectivity_plus", "feed_publish", "App", "meemo_flutter_pip", "photo_manager", "flutter_flog", "meemo_swift_placeholder", "MMKV", "libwebp", "mmkvflutter", "SDWebImage", "url_launcher", "MMKVCore", "package_info_plus", "Flutter", "video_player", "flutter_qapm", "path_provider", "fluttertoast", "share_plus", "MeemoUtils", "Reachability", "calendar_tools", "kk_image_ios", "deviceinfo", "AFNetworking", "image_crop_plus", "AWSCore", "AWSS3", "CoreHaptics", "MetricKit", "UserNotifications", "AuthenticationServices", "libstdc++.6.dylib", "libz.1.dylib", "libc++.1.dylib", "libsqlite3.dylib", "libxml2.2.dylib", "libresolv.9.dylib", "libSystem.B.dylib", "AssetsLibrary", "Combine", "CoreImage", "CoreServices", "LocalAuthentication", "Photos", "SwiftUI", "libobjc.A.dylib", "libswiftAVFoundation.dylib", "libswiftCore.dylib", "libswiftCoreAudio.dylib", "libswiftCoreFoundation.dylib", "libswiftCoreImage.dylib", "libswiftCoreLocation.dylib", "libswiftCoreMIDI.dylib", "libswiftCoreMedia.dylib", "libswiftDarwin.dylib", "libswiftDispatch.dylib", "libswiftMetal.dylib", "libswiftObjectiveC.dylib", "libswiftQuartzCore.dylib", "libswiftos.dylib", "libswiftsimd.dylib", "libswiftCoreGraphics.dylib", "libswiftFoundation.dylib", "libswiftUIKit.dylib", "libGFXShared.dylib", "IOKit", "IOMobileFramebuffer", "IOSurface", "libGLImage.dylib", "IOAccelerator", "libMobileGestalt.dylib", "libicucore.A.dylib", "libc++abi.dylib", "libcache.dylib", "libcommonCrypto.dylib", "libcompiler_rt.dylib", "libcopyfile.dylib", "libcorecrypto.dylib", "libdispatch.dylib", "libdyld.dylib", "liblaunch.dylib", "libmacho.dylib", "libremovefile.dylib", "libsystem_asl.dylib", "libsystem_blocks.dylib", "libsystem_c.dylib", "libsystem_configuration.dylib", "libsystem_containermanager.dylib", "libsystem_coreservices.dylib", "libsystem_darwin.dylib", "libsystem_dnssd.dylib", "libsystem_featureflags.dylib", "libsystem_info.dylib", "libsystem_m.dylib", "libsystem_malloc.dylib", "libsystem_networkextension.dylib", "libsystem_notify.dylib", "libsystem_sandbox.dylib", "libsystem_kernel.dylib", "libsystem_platform.dylib", "libsystem_pthread.dylib", "libsystem_symptoms.dylib", "libsystem_trace.dylib", "libunwind.dylib", "libxpc.dylib", "libenergytrace.dylib", "libbsm.0.dylib", "libCVMSPluginSupport.dylib", "libCoreVMClient.dylib", "libcompression.dylib", "libarchive.2.dylib", "libCRFSuite.dylib", "liblangid.dylib", "liblzma.5.dylib", "libnetwork.dylib", "libapple_nghttp2.dylib", "libpcap.A.dylib", "libcoretls.dylib", "libcoretls_cfhelpers.dylib", "libbz2.1.0.dylib", "libiconv.2.dylib", "libcharset.1.dylib", "AAAInjectionFoundation.dylib" };

int my_strcmp(const char *s1, const char *s2) {
    if (isShieldActive && s1 && s2) {
        for (size_t i = 0; i < sizeof(blockedLibraries)/sizeof(blockedLibraries[0]); i++) {
            if (strstr(s1, blockedLibraries[i]) || strstr(s2, blockedLibraries[i])) return 1;
        }
    }
    return orig_strcmp(s1, s2);
}

// هوك حماية الشهادة والنزاهة
static int (*orig_getaddrinfo)(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res);
int my_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res) {
    if (isShieldActive && node) {
        const char* blocks[] = {"apple.com", "google-analytics", "world-gen.g.aaplimg.com", "ppq.apple.com"};
        for (int i = 0; i < 4; i++) { if (strstr(node, blocks[i])) return EAI_NONAME; }
    }
    return orig_getaddrinfo(node, service, hints, res);
}

static int (*orig_open)(const char *path, int oflag, ...);
int my_open(const char *path, int oflag, mode_t mode) {
    if (isShieldActive && path) { if (strstr(path, "ShadowTrackerExtra") || strstr(path, ".app/")) { } }
    return orig_open(path, oflag, mode);
}

// =================================================================
// ===============  دوال التنظيف والبحث الذكي  ======================
// =================================================================

void DeleteFiles() {
    NSArray *p = @[[NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Logs", NSHomeDirectory()], [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/MMKV", NSHomeDirectory()]];
    for (NSString *path in p) { [[NSFileManager defaultManager] removeItemAtPath:path error:nil]; }
}

void ExecSmartPatch(uintptr_t base) {
    uint8_t patch[] = {0x00, 0x00, 0x80, 0x52};
    for (uintptr_t c = base; c < base + 0x400000; c += 4) { if (*(uint32_t*)c == 0x52800008 || *(uint32_t*)c == 0x52800009) patch_memory(c, patch, 4); }
}

void AutoSearch() {
    bool done = false;
    while (!done) {
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char* n = _dyld_get_image_name(i);
            if (n && strstr(n, "anogs")) { uintptr_t b = _dyld_get_image_vmaddr_slide(i); if (b > 0) { ExecSmartPatch(b); done = true; break; } }
        }
        if (!done) std::this_thread::sleep_for(std::chrono::seconds(1));
    }
}

// =================================================================
// ===============  واجهة الزر (UI) والتفعيل  ======================
// =================================================================

void ActivateEverything() {
    if (isShieldActive) return;
    struct rebinding r[] = { {"strcmp", (void*)my_strcmp, (void**)&orig_strcmp}, {"getaddrinfo", (void*)my_getaddrinfo, (void**)&orig_getaddrinfo}, {"open", (void*)my_open, (void**)&orig_open} };
    rebind_symbols(r, 3);
    
    uintptr_t a = findPatternInImage("\xFF\x43\x01\xD1\xF6\x57\x02\xA9", "xxxxxxxx", 8, 0);
    if(a) patch_memory(a, (const uint8_t[]){0xC0, 0x03, 0x5F, 0xD6}, 4);
    
    DeleteFiles();
    std::thread(AutoSearch).detach();
    isShieldActive = true;
    dispatch_async(dispatch_get_main_queue(), ^{ [floatingBtn setTitle:@"🛡️ ON" forState:UIControlStateNormal]; floatingBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.0 alpha:0.8]; });
}

@interface AmarUI : NSObject
+ (void)loadUI;
@end
@implementation AmarUI
+ (void)loadUI {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIWindowScene* s in [UIApplication sharedApplication].connectedScenes) {
            if (s.activationState == UISceneActivationStateForegroundActive) { win = s.windows.firstObject; break; }
        }
        if (!win) return;
        floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [floatingBtn setTitle:@"🛡️ OFF" forState:UIControlStateNormal];
        floatingBtn.frame = CGRectMake(100, 100, 80, 80);
        floatingBtn.backgroundColor = [UIColor colorWithRed:0.7 green:0.0 blue:0.0 alpha:0.8];
        floatingBtn.layer.cornerRadius = 40;
        [floatingBtn addTarget:self action:@selector(click) forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *p = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
        [floatingBtn addGestureRecognizer:p];
        [win addSubview:floatingBtn];
    });
}
+ (void)pan:(UIPanGestureRecognizer *)p {
    CGPoint t = [p translationInView:p.view.superview];
    p.view.center = CGPointMake(p.view.center.x + t.x, p.view.center.y + t.y);
    [p setTranslation:CGPointZero inView:p.view.superview];
}
+ (void)click { ActivateEverything(); }
@end

__attribute__((constructor)) static void start() { [AmarUI loadUI]; }
