// =================================================================
// =============== AmarShield 2026 - Full Protection ===============
// =================================================================

#import <Foundation/Foundation.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <sys/sysctl.h>
#include <unistd.h>
#include <vector>
#include <thread>
#include <netdb.h>
#include <dlfcn.h>
#include <string>

// --- إعدادات الحماية (مفعلة تلقائياً) ---
struct {
    struct {
        bool HideJB = true;
        bool AntiScan = true;
        bool DynamicAntiCheatBypass = true;
        bool AmarVip2026 = true;
        bool SmartHook2026 = true;
        bool AntiDebug = true;
        bool DnsCertBlock = true;
    } Protection;
} preferences;

// --- تعريف مكتبة fishhook للهوك بدون جلبريك ---
struct rebinding {
  const char *name;
  void *replacement;
  void **replaced;
};
extern "C" int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

// =================================================================
// ===============  دوال الحماية والتعديل (Protection) =============
// =================================================================

#ifndef VM_PROT_EXECUTE
#define VM_PROT_EXECUTE VM_PROT_EXEC
#endif

uintptr_t get_real_offset(uintptr_t offset) {
    return _dyld_get_image_vmaddr_slide(0) + offset;
}

void patch_memory(uintptr_t address, const uint8_t* data, size_t size) {
    mach_port_t self = mach_task_self();
    vm_protect(self, (vm_address_t)address, (vm_size_t)size, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    memcpy((void *)address, data, size);
    vm_protect(self, (vm_address_t)address, (vm_size_t)size, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
}

bool isJailbroken() {
    const char* jailbreakPaths[] = {
        "/Applications/Cydia.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/bin/bash",
        "/usr/sbin/sshd",
        "/etc/apt",
        "/private/var/lib/apt/"
    };
    for (const char* path : jailbreakPaths) {
        if (access(path, F_OK) == 0) return true;
    }
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
    uintptr_t textStart = base;
    uintptr_t textSize = 0;
    struct load_command* cmd = (struct load_command*)(base + sizeof(struct mach_header_64));
    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cmd->cmd == LC_SEGMENT_64) {
            struct segment_command_64* seg = (struct segment_command_64*)cmd;
            if (strcmp(seg->segname, "__TEXT") == 0) {
                textSize = seg->vmsize;
                break;
            }
        }
        cmd = (struct load_command*)((uintptr_t)cmd + cmd->cmdsize);
    }
    if (textSize == 0) return 0;
    uintptr_t end = textStart + textSize;
    for (uintptr_t addr = textStart; addr < end; addr++) {
        bool found = true;
        for (size_t i = 0; i < len; i++) {
            if (mask[i] == 'x' && ((uint8_t*)addr)[i] != (uint8_t)pattern[i]) {
                found = false;
                break;
            }
        }
        if (found) return addr;
    }
    return 0;
}

// =================================================================
// ===============  نظام الهوك وإخفاء المكتبات (Strcmp) ============
// =================================================================

static int (*orig_strcmp)(const char *s1, const char *s2);
static const char* blockedLibraries[] = {
    "anogs", "tersafe", "libsubstrate.dylib", "substitute-inserter.dylib", "Substitute", "Cephei", "CepheiUI", "Shadow.dylib", "HookKit", "RootBridge", "AppSyncUnified", "libsandy.dylib", "Choicy.dylib", "CrashSight", "CrashSightAdapter", "CrashSightCore", "CrashSightPlugin", "MSDKDns", "PluginCrosCurl", "crosCurl", "PixUI_PXPlugin", "PixVideo", "PixVideoCore", "PxExtObjc", "pixuiCurl", "openplatform", "AdjustSdk", "AdjustSigSdk", "TikTokOpenAuthSDK", "TikTokOpenSDKCore", "flutter_inappwebview", "connectivity_plus", "feed_publish", "App", "meemo_flutter_pip", "photo_manager", "flutter_flog", "meemo_swift_placeholder", "MMKV", "libwebp", "mmkvflutter", "SDWebImage", "url_launcher", "MMKVCore", "package_info_plus", "Flutter", "video_player", "flutter_qapm", "path_provider", "fluttertoast", "share_plus", "MeemoUtils", "Reachability", "calendar_tools", "kk_image_ios", "deviceinfo", "AFNetworking", "image_crop_plus", "AWSCore", "AWSS3", "CoreHaptics", "MetricKit", "UserNotifications", "AuthenticationServices", "libstdc++.6.dylib", "libz.1.dylib", "libc++.1.dylib", "libsqlite3.dylib", "libxml2.2.dylib", "libresolv.9.dylib", "libSystem.B.dylib", "AssetsLibrary", "Combine", "CoreImage", "CoreServices", "LocalAuthentication", "Photos", "SwiftUI", "libobjc.A.dylib", "libswiftAVFoundation.dylib", "libswiftCore.dylib", "libswiftCoreAudio.dylib", "libswiftCoreFoundation.dylib", "libswiftCoreImage.dylib", "libswiftCoreLocation.dylib", "libswiftCoreMIDI.dylib", "libswiftCoreMedia.dylib", "libswiftDarwin.dylib", "libswiftDispatch.dylib", "libswiftMetal.dylib", "libswiftObjectiveC.dylib", "libswiftQuartzCore.dylib", "libswiftos.dylib", "libswiftsimd.dylib", "libswiftCoreGraphics.dylib", "libswiftFoundation.dylib", "libswiftUIKit.dylib", "libGFXShared.dylib", "IOKit", "IOMobileFramebuffer", "IOSurface", "libGLImage.dylib", "IOAccelerator", "libMobileGestalt.dylib", "libicucore.A.dylib", "libc++abi.dylib", "libcache.dylib", "libcommonCrypto.dylib", "libcompiler_rt.dylib", "libcopyfile.dylib", "libcorecrypto.dylib", "libdispatch.dylib", "libdyld.dylib", "liblaunch.dylib", "libmacho.dylib", "libremovefile.dylib", "libsystem_asl.dylib", "libsystem_blocks.dylib", "libsystem_c.dylib", "libsystem_configuration.dylib", "libsystem_containermanager.dylib", "libsystem_coreservices.dylib", "libsystem_darwin.dylib", "libsystem_dnssd.dylib", "libsystem_featureflags.dylib", "libsystem_info.dylib", "libsystem_m.dylib", "libsystem_malloc.dylib", "libsystem_networkextension.dylib", "libsystem_notify.dylib", "libsystem_sandbox.dylib", "libsystem_kernel.dylib", "libsystem_platform.dylib", "libsystem_pthread.dylib", "libsystem_symptoms.dylib", "libsystem_trace.dylib", "libunwind.dylib", "libxpc.dylib", "libenergytrace.dylib", "libbsm.0.dylib", "libCVMSPluginSupport.dylib", "libCoreVMClient.dylib", "libcompression.dylib", "libarchive.2.dylib", "libCRFSuite.dylib", "liblangid.dylib", "liblzma.5.dylib", "libnetwork.dylib", "libapple_nghttp2.dylib", "libpcap.A.dylib", "libcoretls.dylib", "libcoretls_cfhelpers.dylib", "libbz2.1.0.dylib", "libiconv.2.dylib", "libcharset.1.dylib", "AAAInjectionFoundation.dylib"
};

int my_strcmp(const char *s1, const char *s2) {
    if (!s1 || !s2) return orig_strcmp(s1, s2);
    if (preferences.Protection.HideJB || preferences.Protection.AntiScan || preferences.Protection.DynamicAntiCheatBypass) {
        for (size_t i = 0; i < sizeof(blockedLibraries)/sizeof(blockedLibraries[0]); i++) {
            if (strstr(s1, blockedLibraries[i]) != nullptr || strstr(s2, blockedLibraries[i]) != nullptr) {
                return 1;
            }
        }
    }
    return orig_strcmp(s1, s2);
}

// =================================================================
// ===============  حماية الشهادة (DNS Block Protection) ===========
// =================================================================

static int (*orig_getaddrinfo)(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res);

static const char* appleDnsServers[] = {
    "ocsp.apple.com", "world-gen.g.aaplimg.com", "ppq.apple.com", 
    "iadsdk.apple.com", "google-analytics.com", "stats.g.doubleclick.net",
    "app-measurement.com", "ocsp2.apple.com"
};

int my_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res) {
    if (node && preferences.Protection.DnsCertBlock) {
        for (size_t i = 0; i < sizeof(appleDnsServers)/sizeof(appleDnsServers[0]); i++) {
            if (strstr(node, appleDnsServers[i]) != nullptr) {
                return EAI_NONAME; // إيهام النظام بأن الخادم غير موجود (تعطيل التحقق)
            }
        }
    }
    return orig_getaddrinfo(node, service, hints, res);
}

// =================================================================
// ===============  البحث الذكي وتلقائي (Smart Patch) =============
// =================================================================

uint8_t SMART_PATCH[] = {0x00, 0x00, 0x80, 0x52}; // MOV W0, #0

void ExecSmartPatch(uintptr_t baseAddr) {
    struct Pattern { std::vector<uint8_t> data; int skip; };
    std::vector<Pattern> targets = {
        {{0x08, 0x00, 0x80, 0x52}, 100}, 
        {{0x09, 0x00, 0x80, 0x52}, 100}  
    };
    size_t searchRange = 0x400000; 
    for (auto& target : targets) {
        int found = 0;
        for (uintptr_t curr = baseAddr; curr < baseAddr + searchRange; curr += 4) {
            if (memcmp((void*)curr, target.data.data(), 4) == 0) {
                found++;
                if (found > target.skip) {
                    patch_memory(curr, SMART_PATCH, 4);
                }
            }
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
                if (base > 0) {
                    ExecSmartPatch(base);
                    patched = true;
                    break;
                }
            }
        }
        if (!patched) std::this_thread::sleep_for(std::chrono::seconds(1));
    }
}

void ActivateAmarShield() {
    // ptrace لمنع الديباج
    typedef int (*ptrace_ptr_t)(int _request, pid_t _pid, caddr_t _addr, int _data);
    void* handle = dlopen(0, RTLD_GLOBAL | RTLD_NOW);
    ptrace_ptr_t ptrace_func = (ptrace_ptr_t)dlsym(handle, "ptrace");
    if (ptrace_func) ptrace_func(31, 0, 0, 0); // PT_DENY_ATTACH

    struct { const char* pattern; const char* mask; size_t len; } patterns[] = {
        { "\xFF\x43\x01\xD1\xF6\x57\x02\xA9\xF4\x4F\x03\xA9\xFD\x7B\x04\xA9\xFD\x83\x00\x91", "xxxxxxxxxxxxxxxxxxxx", 20 },
        { "\xF0\x4F\x01\xD1\xFD\x7B\x06\xA9\xFD\x03\x00\x91", "xxxxxxxxxxxx", 12 },
        { "\xF5\x4F\x01\xD1\xF3\x5F\x02\xA9\xFD\x7B\x04\xA9\xFD\x83\x00\x91\x68\x12\x40\xF9\x08\x01\x00\x34", "xxxxxxxxxxxxxxxxxxxxxxxx", 24 },
        { "\xF8\x5F\x02\xA9\xF6\x57\x03\xA9\xF4\x4F\x04\xA9\xFD\x7B\x05\xA9\xFD\x43\x00\x91", "xxxxxxxxxxxxxxxxxxxx", 20 },
        { "\xFC\x6F\x05\xA9\xFA\x67\x06\xA9\xF8\x5F\x07\xA9\xF6\x57\x08\xA9\xF4\x4F\x09\xA9\xFD\x7B\x0A\xA9\xFD\x43\x01\x91", "xxxxxxxxxxxxxxxxxxxxxxxxxxxx", 28 },
    };
    uint8_t ret[] = {0xC0, 0x03, 0x5F, 0xD6}; // RET
    for (size_t i = 0; i < sizeof(patterns)/sizeof(patterns[0]); i++) {
        uintptr_t addr = findPatternInImage(patterns[i].pattern, patterns[i].mask, patterns[i].len, 0);
        if (addr) patch_memory(addr, ret, 4);
    }
}

// =================================================================
// ===============  دالة التنظيف والتشغيل النهائي ==================
// =================================================================

void DeleteSensitiveFiles() {
    NSArray *paths = @[
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Logs", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/MMKV", NSHomeDirectory()],
        [NSString stringWithFormat:@"%@/Documents/ShadowTrackerExtra/Saved/Config", NSHomeDirectory()]
    ];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in paths) {
        if ([fm fileExistsAtPath:path]) [fm removeItemAtPath:path error:nil];
    }
}

void ApplyProtectionSettings() {
    // تفعيل الهوكات (Strcmp + DNS Block) باستخدام fishhook
    struct rebinding rebinds[] = {
        {"strcmp", (void*)my_strcmp, (void**)&orig_strcmp},
        {"getaddrinfo", (void*)my_getaddrinfo, (void**)&orig_getaddrinfo}
    };
    rebind_symbols(rebinds, 2);

    if (preferences.Protection.AmarVip2026) ActivateAmarShield();
    if (preferences.Protection.SmartHook2026) std::thread(AutoSearchAnogs).detach();
    DeleteSensitiveFiles();
}

// المُنطلق التلقائي عند تشغيل التطبيق
__attribute__((constructor))
static void initialize() {
    // تشغيل الحماية بعد 5 ثوانٍ لضمان استقرار التطبيق
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        ApplyProtectionSettings();
    });
}

