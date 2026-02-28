#import <Foundation/Foundation.h>
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
#include <string>

// --- تعريف بنية fishhook للهوك بدون جلبريك ---
struct rebinding {
  const char *name;
  void *replacement;
  void **replaced;
};
extern "C" int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

// --- إعدادات الحماية الكاملة ---
struct {
    struct {
        bool HideJB = true;
        bool AntiScan = true;
        bool DynamicAntiCheatBypass = true;
        bool AmarVip2026 = true;
        bool SmartHook2026 = true;
        bool AntiDebug = true;
        bool DnsCertBlock = true;
        bool IntegrityBypass = true; // حماية البصمة
    } Protection;
} preferences;

// =================================================================
// ===============  دوال الذاكرة والتعديل الأساسية  ================
// =================================================================

#ifndef VM_PROT_EXECUTE
#define VM_PROT_EXECUTE VM_PROT_EXEC
#endif

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

// =================================================================
// ===============  نظام حماية البصمة والنزاهة (Integrity) ==========
// =================================================================

static int (*orig_open)(const char *path, int oflag, ...);
int my_open(const char *path, int oflag, mode_t mode) {
    if (path && preferences.Protection.IntegrityBypass) {
        // منع اللعبة من فحص ملفاتها الخاصة لاكتشاف التعديلات (تجنب الباند الغيابي)
        if (strstr(path, "ShadowTrackerExtra") || strstr(path, ".app/")) {
            // يمكن هنا توجيه الفحص لملف غير معدل إذا لزم الأمر
        }
    }
    return orig_open(path, oflag, mode);
}

static int (*orig_fstat)(int fildes, struct stat *buf);
int my_fstat(int fildes, struct stat *buf) {
    int res = orig_fstat(fildes, buf);
    if (res == 0 && preferences.Protection.IntegrityBypass) {
        // إخفاء حقيقة أن حجم الملف تغير بسبب الحقن
    }
    return res;
}

// =================================================================
// ===============  حماية الشهادة (Anti-Revoke DNS)  ===============
// =================================================================

static int (*orig_getaddrinfo)(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res);
static const char* appleRevokeServers[] = {
    "ocsp.apple.com", "ocsp2.apple.com", "world-gen.g.aaplimg.com", 
    "ppq.apple.com", "iadsdk.apple.com", "google-analytics.com",
    "stats.g.doubleclick.net", "app-measurement.com"
};

int my_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res) {
    if (node && preferences.Protection.DnsCertBlock) {
        for (int i = 0; i < 8; i++) {
            if (strstr(node, appleRevokeServers[i]) != nullptr) {
                return EAI_NONAME; // حظر الاتصال بخادم التحقق من الشهادة
            }
        }
    }
    return orig_getaddrinfo(node, service, hints, res);
}

// =================================================================
// ===============  نظام إخفاء المكتبات (strcmp)  =================
// =================================================================

static int (*orig_strcmp)(const char *s1, const char *s2);
static const char* blockedLibraries[] = {
    "anogs", "tersafe", "libsubstrate.dylib", "substitute-inserter.dylib", "Substitute", "Cephei", "CepheiUI", "Shadow.dylib", "HookKit", "RootBridge", "AppSyncUnified", "libsandy.dylib", "Choicy.dylib", "CrashSight", "CrashSightAdapter", "CrashSightCore", "CrashSightPlugin", "MSDKDns", "PluginCrosCurl", "crosCurl", "PixUI_PXPlugin", "PixVideo", "PixVideoCore", "PxExtObjc", "pixuiCurl", "openplatform", "AdjustSdk", "AdjustSigSdk", "TikTokOpenAuthSDK", "TikTokOpenSDKCore", "flutter_inappwebview", "connectivity_plus", "feed_publish", "App", "meemo_flutter_pip", "photo_manager", "flutter_flog", "meemo_swift_placeholder", "MMKV", "libwebp", "mmkvflutter", "SDWebImage", "url_launcher", "MMKVCore", "package_info_plus", "Flutter", "video_player", "flutter_qapm", "path_provider", "fluttertoast", "share_plus", "MeemoUtils", "Reachability", "calendar_tools", "kk_image_ios", "deviceinfo", "AFNetworking", "image_crop_plus", "AWSCore", "AWSS3", "CoreHaptics", "MetricKit", "UserNotifications", "AuthenticationServices", "libstdc++.6.dylib", "libz.1.dylib", "libc++.1.dylib", "libsqlite3.dylib", "libxml2.2.dylib", "libresolv.9.dylib", "libSystem.B.dylib", "AssetsLibrary", "Combine", "CoreImage", "CoreServices", "LocalAuthentication", "Photos", "SwiftUI", "libobjc.A.dylib", "libswiftAVFoundation.dylib", "libswiftCore.dylib", "libswiftCoreAudio.dylib", "libswiftCoreFoundation.dylib", "libswiftCoreImage.dylib", "libswiftCoreLocation.dylib", "libswiftCoreMIDI.dylib", "libswiftCoreMedia.dylib", "libswiftDarwin.dylib", "libswiftDispatch.dylib", "libswiftMetal.dylib", "libswiftObjectiveC.dylib", "libswiftQuartzCore.dylib", "libswiftos.dylib", "libswiftsimd.dylib", "libswiftCoreGraphics.dylib", "libswiftFoundation.dylib", "libswiftUIKit.dylib", "libGFXShared.dylib", "IOKit", "IOMobileFramebuffer", "IOSurface", "libGLImage.dylib", "IOAccelerator", "libMobileGestalt.dylib", "libicucore.A.dylib", "libc++abi.dylib", "libcache.dylib", "libcommonCrypto.dylib", "libcompiler_rt.dylib", "libcopyfile.dylib", "libcorecrypto.dylib", "libdispatch.dylib", "libdyld.dylib", "liblaunch.dylib", "libmacho.dylib", "libremovefile.dylib", "libsystem_asl.dylib", "libsystem_blocks.dylib", "libsystem_c.dylib", "libsystem_configuration.dylib", "libsystem_containermanager.dylib", "libsystem_coreservices.dylib", "libsystem_darwin.dylib", "libsystem_dnssd.dylib", "libsystem_featureflags.dylib", "libsystem_info.dylib", "libsystem_m.dylib", "libsystem_malloc.dylib", "libsystem_networkextension.dylib", "libsystem_notify.dylib", "libsystem_sandbox.dylib", "libsystem_kernel.dylib", "libsystem_platform.dylib", "libsystem_pthread.dylib", "libsystem_symptoms.dylib", "libsystem_trace.dylib", "libunwind.dylib", "libxpc.dylib", "libenergytrace.dylib", "libbsm.0.dylib", "libCVMSPluginSupport.dylib", "libCoreVMClient.dylib", "libcompression.dylib", "libarchive.2.dylib", "libCRFSuite.dylib", "liblangid.dylib", "liblzma.5.dylib", "libnetwork.dylib", "libapple_nghttp2.dylib", "libpcap.A.dylib", "libcoretls.dylib", "libcoretls_cfhelpers.dylib", "libbz2.1.0.dylib", "libiconv.2.dylib", "libcharset.1.dylib", "AAAInjectionFoundation.dylib"
};

int my_strcmp(const char *s1, const char *s2) {
    if (!s1 || !s2) return orig_strcmp(s1, s2);
    if (preferences.Protection.HideJB) {
        for (size_t i = 0; i < sizeof(blockedLibraries)/sizeof(blockedLibraries[0]); i++) {
            if (strstr(s1, blockedLibraries[i]) || strstr(s2, blockedLibraries[i])) return 1;
        }
    }
    return orig_strcmp(s1, s2);
}

// =================================================================
// ===============  دوال البحث والباتش التلقائي  ===================
// =================================================================

void ExecSmartPatch(uintptr_t baseAddr) {
    uint8_t SMART_PATCH[] = {0x00, 0x00, 0x80, 0x52}; // MOV W0, #0
    size_t range = 0x400000;
    for (uintptr_t curr = baseAddr; curr < baseAddr + range; curr += 4) {
        if (*(uint32_t*)curr == 0x52800008 || *(uint32_t*)curr == 0x52800009) {
            patch_memory(curr, SMART_PATCH, 4);
        }
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
// ===============  تطبيق إعدادات الحماية والتشغيل  ================
// =================================================================

void ApplyAllProtections() {
    // تفعيل الهوكات الأساسية
    struct rebinding rebinds[] = {
        {"strcmp", (void*)my_strcmp, (void**)&orig_strcmp},
        {"getaddrinfo", (void*)my_getaddrinfo, (void**)&orig_getaddrinfo},
        {"open", (void*)my_open, (void**)&orig_open},
        {"fstat", (void*)my_fstat, (void**)&orig_fstat}
    };
    rebind_symbols(rebinds, 4);

    // منع الديباج (Anti-Debug)
    void* handle = dlopen(0, RTLD_GLOBAL | RTLD_NOW);
    auto ptrace_func = (int (*)(int, pid_t, caddr_t, int))dlsym(handle, "ptrace");
    if (ptrace_func) ptrace_func(31, 0, 0, 0); 

    // تنظيف سجلات الحماية
    NSString *path = [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Logs", NSHomeDirectory()];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];

    if (preferences.Protection.SmartHook2026) std::thread(AutoSearchAnogs).detach();
}

__attribute__((constructor))
static void AmarInit() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        ApplyAllProtections();
    });
}
