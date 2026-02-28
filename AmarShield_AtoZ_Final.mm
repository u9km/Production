#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <mach-o/dyld.h>
#include <mach-o/getsect.h>
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

// --- المتغيرات والحالات ---
static bool isShieldActive = false;
static UIButton *floatingBtn;

#ifndef VM_PROT_EXECUTE
#define VM_PROT_EXECUTE VM_PROT_EXEC
#endif

// --- الإعدادات الأصلية ---
struct {
    struct {
        bool HideJB = true;
        bool AntiScan = true;
        bool DynamicAntiCheatBypass = true;
        bool AmarVip2026 = true;
        bool SmartHook2026 = true;
        bool AntiDebug = true;
        bool DnsCertBlock = true;
        bool IntegrityBypass = true;
    } Protection;
} preferences;

// =================================================================
// ===============  دوال الحماية والتعديل (Protection) =============
// =================================================================

uintptr_t get_real_offset(uintptr_t offset) {
    return _dyld_get_image_vmaddr_slide(0) + offset;
}

void patch_memory(uintptr_t address, const uint8_t* data, size_t size) {
    if (!address) return;
    mach_port_t self = mach_task_self();
    vm_protect(self, (vm_address_t)address, (vm_size_t)size, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    memcpy((void *)address, data, size);
    vm_protect(self, (vm_address_t)address, (vm_size_t)size, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
}

bool isJailbroken() {
    const char* jailbreakPaths[] = { "/Applications/Cydia.app", "/Library/MobileSubstrate/MobileSubstrate.dylib", "/bin/bash", "/usr/sbin/sshd", "/etc/apt", "/private/var/lib/apt/" };
    for (const char* path : jailbreakPaths) { if (access(path, F_OK) == 0) return true; }
    return false;
}

bool isDebugged() {
    int name[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) return false;
    return (info.kp_proc.p_flag & P_TRACED) != 0;
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
static const char* blockedLibraries[] = {
    "anogs", "tersafe", "libsubstrate.dylib", "substitute-inserter.dylib", "Substitute", "Cephei", "CepheiUI", "Shadow.dylib", "HookKit", "RootBridge", "AppSyncUnified", "libsandy.dylib", "Choicy.dylib", "CrashSight", "CrashSightAdapter", "CrashSightCore", "CrashSightPlugin", "MSDKDns", "PluginCrosCurl", "crosCurl", "PixUI_PXPlugin", "PixVideo", "PixVideoCore", "PxExtObjc", "pixuiCurl", "openplatform", "AdjustSdk", "AdjustSigSdk", "TikTokOpenAuthSDK", "TikTokOpenSDKCore", "flutter_inappwebview", "connectivity_plus", "feed_publish", "App", "meemo_flutter_pip", "photo_manager", "flutter_flog", "meemo_swift_placeholder", "MMKV", "libwebp", "mmkvflutter", "SDWebImage", "url_launcher", "MMKVCore", "package_info_plus", "Flutter", "video_player", "flutter_qapm", "path_provider", "fluttertoast", "share_plus", "MeemoUtils", "Reachability", "calendar_tools", "kk_image_ios", "deviceinfo", "AFNetworking", "image_crop_plus", "AWSCore", "AWSS3", "CoreHaptics", "MetricKit", "UserNotifications", "AuthenticationServices", "libstdc++.6.dylib", "libz.1.dylib", "libc++.1.dylib", "libsqlite3.dylib", "libxml2.2.dylib", "libresolv.9.dylib", "libSystem.B.dylib", "AssetsLibrary", "Combine", "CoreImage", "CoreServices", "LocalAuthentication", "Photos", "SwiftUI", "libobjc.A.dylib", "libswiftAVFoundation.dylib", "libswiftCore.dylib", "libswiftCoreAudio.dylib", "libswiftCoreFoundation.dylib", "libswiftCoreImage.dylib", "libswiftCoreLocation.dylib", "libswiftCoreMIDI.dylib", "libswiftCoreMedia.dylib", "libswiftDarwin.dylib", "libswiftDispatch.dylib", "libswiftMetal.dylib", "libswiftObjectiveC.dylib", "libswiftQuartzCore.dylib", "libswiftos.dylib", "libswiftsimd.dylib", "libswiftCoreGraphics.dylib", "libswiftFoundation.dylib", "libswiftUIKit.dylib", "libGFXShared.dylib", "IOKit", "IOMobileFramebuffer", "IOSurface", "libGLImage.dylib", "IOAccelerator", "libMobileGestalt.dylib", "libicucore.A.dylib", "libc++abi.dylib", "libcache.dylib", "libcommonCrypto.dylib", "libcompiler_rt.dylib", "libcopyfile.dylib", "libcorecrypto.dylib", "libdispatch.dylib", "libdyld.dylib", "liblaunch.dylib", "libmacho.dylib", "libremovefile.dylib", "libsystem_asl.dylib", "libsystem_blocks.dylib", "libsystem_c.dylib", "libsystem_configuration.dylib", "libsystem_containermanager.dylib", "libsystem_coreservices.dylib", "libsystem_darwin.dylib", "libsystem_dnssd.dylib", "libsystem_featureflags.dylib", "libsystem_info.dylib", "libsystem_m.dylib", "libsystem_malloc.dylib", "libsystem_networkextension.dylib", "libsystem_notify.dylib", "libsystem_sandbox.dylib", "libsystem_kernel.dylib", "libsystem_platform.dylib", "libsystem_pthread.dylib", "libsystem_symptoms.dylib", "libsystem_trace.dylib", "libunwind.dylib", "libxpc.dylib", "libenergytrace.dylib", "libbsm.0.dylib", "libCVMSPluginSupport.dylib", "libCoreVMClient.dylib", "libcompression.dylib", "libarchive.2.dylib", "libCRFSuite.dylib", "liblangid.dylib", "liblzma.5.dylib", "libnetwork.dylib", "libapple_nghttp2.dylib", "libpcap.A.dylib", "libcoretls.dylib", "libcoretls_cfhelpers.dylib", "libbz2.1.0.dylib", "libiconv.2.dylib", "libcharset.1.dylib", "AAAInjectionFoundation.dylib"
};

int my_strcmp(const char *s1, const char *s2) {
    if (isShieldActive && s1 && s2) {
        for (size_t i = 0; i < sizeof(blockedLibraries)/sizeof(blockedLibraries[0]); i++) {
            if (strstr(s1, blockedLibraries[i]) || strstr(s2, blockedLibraries[i])) return 1;
        }
    }
    return orig_strcmp(s1, s2);
}

// 2. هوك حماية الشهادة (DNS Block)
static int (*orig_getaddrinfo)(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res);
int my_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res) {
    if (isShieldActive && node) {
        const char* blocks[] = {"apple.com", "google-analytics", "world-gen.g.aaplimg.com", "ppq.apple.com", "app-measurement.com"};
        for (int i = 0; i < 5; i++) { if (strstr(node, blocks[i])) return EAI_NONAME; }
    }
    return orig_getaddrinfo(node, service, hints, res);
}

// =================================================================
// ===============  دالة الحذف والبحث الذكي  ======================
// =================================================================

void DeleteSensitiveFiles() {
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
    for (NSString *path in paths) { if ([fm fileExistsAtPath:path]) [fm removeItemAtPath:path error:nil]; }
}

void ExecSmartPatch(uintptr_t baseAddr) {
    uint8_t SMART_PATCH[] = {0x00, 0x00, 0x80, 0x52}; // MOV W0, #0
    for (uintptr_t curr = baseAddr; curr < baseAddr + 0x400000; curr += 4) {
        if (*(uint32_t*)curr == 0x52800008 || *(uint32_t*)curr == 0x52800009) patch_memory(curr, SMART_PATCH, 4);
    }
}

void AutoSearchAnogs() {
    bool patched = false;
    while (!patched) {
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char* name = _dyld_get_image_name(i);
            if (name && strstr(name, "anogs")) {
                uintptr_t base = _dyld_get_image_vmaddr_slide(i);
                if (base > 0) { ExecSmartPatch(base); patched = true; break; }
            }
        }
        if (!patched) std::this_thread::sleep_for(std::chrono::seconds(1));
    }
}

// =================================================================
// ===============  الواجهة والتفعيل (15 ثانية) ====================
// =================================================================

void ActivateEverything() {
    if (isShieldActive) return;
    struct rebinding rebinds[] = { {"strcmp", (void*)my_strcmp, (void**)&orig_strcmp}, {"getaddrinfo", (void*)my_getaddrinfo, (void**)&orig_getaddrinfo} };
    rebind_symbols(rebinds, 2);

    uint8_t ret[] = {0xC0, 0x03, 0x5F, 0xD6};
    const char* pats[] = {"\xFF\x43\x01\xD1\xF6\x57\x02\xA9", "\xF0\x4F\x01\xD1\xFD\x7B\x06\xA9", "\xF5\x4F\x01\xD1\xF3\x5F\x02\xA9\xFD\x7B\x04\xA9\xFD\x83\x00\x91\x68\x12\x40\xF9\x08\x01\x00\x34", "\xF8\x5F\x02\xA9\xF6\x57\x03\xA9\xF4\x4F\x04\xA9\xFD\x7B\x05\xA9\xFD\x43\x00\x91", "\xFC\x6F\x05\xA9\xFA\x67\x06\xA9\xF8\x5F\x07\xA9\xF6\x57\x08\xA9\xF4\x4F\x09\xA9\xFD\x7B\x0A\xA9\xFD\x43\x01\x91"};
    for(int i=0; i<5; i++) {
        uintptr_t addr = findPatternInImage(pats[i], "xxxxxxxx", 8, 0); // تم التبسيط للمثال، أضف الأطوال الحقيقية
        if(addr) patch_memory(addr, ret, 4);
    }

    DeleteSensitiveFiles();
    std::thread(AutoSearchAnogs).detach();
    isShieldActive = true;
    dispatch_async(dispatch_get_main_queue(), ^{ [floatingBtn setTitle:@"🛡️ ON" forState:UIControlStateNormal]; floatingBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.0 alpha:0.8]; });
}

@interface AmarAtoZ : NSObject
+ (void)setup;
@end
@implementation AmarAtoZ
+ (void)setup {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = [[UIApplication sharedApplication] keyWindow]; if (!win) return;
        floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [floatingBtn setTitle:@"🛡️ OFF" forState:UIControlStateNormal];
        floatingBtn.frame = CGRectMake(50, 150, 80, 80);
        floatingBtn.backgroundColor = [UIColor colorWithRed:0.7 green:0.0 blue:0.0 alpha:0.8];
        floatingBtn.layer.cornerRadius = 40;
        [floatingBtn addTarget:self action:@selector(click) forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *p = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
        [floatingBtn addGestureRecognizer:p];
        [win addSubview:floatingBtn];
    });
}
+ (void)pan:(UIPanGestureRecognizer *)p { CGPoint t = [p translationInView:p.view.superview]; p.view.center = CGPointMake(p.view.center.x + t.x, p.view.center.y + t.y); [p setTranslation:CGPointZero inView:p.view.superview]; }
+ (void)click { ActivateEverything(); }
@end

__attribute__((constructor)) static void start() { [AmarAtoZ setup]; }
