#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <UIKit/UIKit.h>
#include <sys/sysctl.h>
#include <dlfcn.h>
#include <vector>
#include <random>
#include <chrono>
#include <dispatch/dispatch.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>

// ================================================================
// [ سيادة Dobby النقية ]
// ================================================================
extern "C" int DobbyHook(void *address, void *replace_call, void **origin_call);

// ================================================================
// 1. محرك التشفير الجيني (Zero-Leak)
// ================================================================
#include <utility>
namespace CoreMemUtils { 
    template <size_t N, char K, size_t... Is>
    constexpr auto EncryptString(const char (&str)[N], std::index_sequence<Is...>) {
        struct { char data[N]; } result = { { static_cast<char>(str[Is] ^ K)... } };
        return result;
    }
}
#define OBFUSCATE(str) \
    ([]() -> char* { \
        constexpr char key = (__TIME__[7] ^ __LINE__) % 127 + 1; \
        constexpr auto obfuscated = CoreMemUtils::EncryptString<sizeof(str), key>(str, std::make_index_sequence<sizeof(str)>{}); \
        static char decrypted[sizeof(str)]; \
        static bool init = false; \
        if (!init) { \
            for (size_t i = 0; i < sizeof(str); ++i) { decrypted[i] = obfuscated.data[i] ^ key; } \
            init = true; \
        } \
        return decrypted; \
    }())

// ================================================================
// 2. محرك السلوك البشري الإحصائي (Telemetry Evasion)
// ================================================================
struct Vector2D { float x, y; };
class AmmarTelemetrySpoofer {
public:
    Vector2D Humanize(Vector2D target) {
        float noiseX = ((float)arc4random_uniform(100) / 100.0f) * 0.8f - 0.4f;
        float noiseY = ((float)arc4random_uniform(100) / 100.0f) * 0.8f - 0.4f;
        return { target.x + noiseX, target.y + noiseY };
    }
};
static AmmarTelemetrySpoofer* GlobalSpoofer = nullptr;

// ================================================================
// 3. رادار 2027: GhostROP Scanner
// ================================================================
namespace GhostROP {
    static IMP native_ret_void = nullptr;
    static IMP native_ret_0 = nullptr;
    static IMP native_ret_1 = nullptr;

    static void ScanGameMemory() {
        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(0);
        intptr_t slide = _dyld_get_image_vmaddr_slide(0);
        if (!header) return;

        struct load_command *cmd = (struct load_command *)((char *)header + sizeof(struct mach_header_64));
        for (uint32_t i = 0; i < header->ncmds; i++) {
            if (cmd->cmd == LC_SEGMENT_64) {
                struct segment_command_64 *seg = (struct segment_command_64 *)cmd;
                if (strcmp(seg->segname, "__TEXT") == 0) {
                    struct section_64 *sec = (struct section_64 *)((char *)seg + sizeof(struct segment_command_64));
                    for (uint32_t j = 0; j < seg->nsects; j++) {
                        if (strcmp(sec->sectname, "__text") == 0) {
                            uint32_t *start = (uint32_t *)(sec->addr + slide);
                            uint32_t *end = (uint32_t *)((char *)start + sec->size);
                            for (uint32_t *p = start; p < end - 1; p++) {
                                if (!native_ret_0 && p[0] == 0xD2800000 && p[1] == 0xD65F03C0) native_ret_0 = (IMP)p;
                                if (!native_ret_1 && p[0] == 0xD2800020 && p[1] == 0xD65F03C0) native_ret_1 = (IMP)p;
                                if (!native_ret_void && p[0] == 0xD65F03C0) native_ret_void = (IMP)p;
                                if (native_ret_0 && native_ret_1 && native_ret_void) return;
                            }
                        }
                        sec = (struct section_64 *)((char *)sec + sizeof(struct section_64));
                    }
                }
            }
            cmd = (struct load_command *)((char *)cmd + cmd->cmdsize);
        }
    }
}

// ================================================================
// 4. API Resolver
// ================================================================
namespace API {
    typedef Class (*objc_getClass_t)(const char *);
    typedef SEL (*sel_registerName_t)(const char *);
    typedef Method (*class_getInstanceMethod_t)(Class, SEL);
    typedef IMP (*class_replaceMethod_t)(Class, SEL, IMP, const char *);

    static objc_getClass_t sys_objc_getClass = nullptr;
    static sel_registerName_t sys_sel_registerName = nullptr;
    static class_getInstanceMethod_t sys_class_getInstanceMethod = nullptr;
    static class_replaceMethod_t sys_class_replaceMethod = nullptr;

    static bool Init() {
        void* handle = RTLD_DEFAULT;
        sys_objc_getClass = (objc_getClass_t)dlsym(handle, OBFUSCATE("objc_getClass"));
        sys_sel_registerName = (sel_registerName_t)dlsym(handle, OBFUSCATE("sel_registerName"));
        sys_class_getInstanceMethod = (class_getInstanceMethod_t)dlsym(handle, OBFUSCATE("class_getInstanceMethod"));
        sys_class_replaceMethod = (class_replaceMethod_t)dlsym(handle, OBFUSCATE("class_replaceMethod"));
        return (sys_objc_getClass && sys_sel_registerName && sys_class_getInstanceMethod && sys_class_replaceMethod);
    }
}

// ================================================================
// 5. Safe ROP Binder
// ================================================================
static void _bind_rop(const char* cls, const char* sel, int ret_type) {
    if (!API::sys_objc_getClass || !API::sys_sel_registerName || !API::sys_class_getInstanceMethod || !API::sys_class_replaceMethod) return;
    Class c = API::sys_objc_getClass(cls);
    if (!c) return;
    SEL s = API::sys_sel_registerName(sel);
    if (!s) return;
    Method m = API::sys_class_getInstanceMethod(c, s);
    if (!m) return;

    IMP safe_imp = nullptr;
    if (ret_type == 0) safe_imp = GhostROP::native_ret_void;
    else if (ret_type == 1) safe_imp = GhostROP::native_ret_0;
    else if (ret_type == 2) safe_imp = GhostROP::native_ret_1;

    if (!safe_imp) return;
    API::sys_class_replaceMethod(c, s, safe_imp, method_getTypeEncoding(m));
}

// ================================================================
// 6. sysctl Hook (Anti-Debugging Bypass)
// ================================================================
static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
int my_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (!orig_sysctl) return 0;
    int ret = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    if (ret == 0 && name && namelen >= 3 && name[0] == 1 && name[1] == 14 && name[2] == getpid()) {
        if (oldp) {
            struct kinfo_proc *kp = (struct kinfo_proc *)oldp;
            kp->kp_proc.p_flag &= ~0x00000800; // Remove P_TRACED flag
        }
    }
    return ret;
}

// ================================================================
// 7. Ultimate Constructor (Ignition)
// ================================================================
__attribute__((constructor))
static void Ignite_Ammar_Zeus_2027() {

    // 1. حقن الحماية الأساسية فوراً
    void* sysctl_ptr = dlsym(RTLD_DEFAULT, OBFUSCATE("sysctl"));
    if (sysctl_ptr) {
        DobbyHook(sysctl_ptr, (void*)my_sysctl, (void**)&orig_sysctl);
    }

    // 2. استخدام خيط خلفي (Background Queue) لمنع تجميد شاشة اللعبة أثناء مسح الذاكرة
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        if (!API::Init()) return;
        
        GlobalSpoofer = new AmmarTelemetrySpoofer();
        GhostROP::ScanGameMemory();

        if (!GhostROP::native_ret_void || !GhostROP::native_ret_0 || !GhostROP::native_ret_1) return;

        // --- كتيبة الأمن والتحليل (Core Security) ---
        _bind_rop(OBFUSCATE("SecurityChecker"), OBFUSCATE("IsFileSystemModified"), 1); // Return 0 (NO)
        _bind_rop(OBFUSCATE("SecurityChecker"), OBFUSCATE("isJailbroken"), 1);         // Return 0 (NO)
        _bind_rop(OBFUSCATE("SecurityChecker"), OBFUSCATE("checkDylibs"), 1);          // Return 0 (NO)
        _bind_rop(OBFUSCATE("GSDKInGameManager"), OBFUSCATE("GSDKRealTimeDetect"), 0); // Return Void
        _bind_rop(OBFUSCATE("GSDKInGameSystem"), OBFUSCATE("GSDKInnerRealTimeDetect"), 0);
        _bind_rop(OBFUSCATE("GSDKInGameSystem"), OBFUSCATE("GSDKInnerEnd"), 0);
        _bind_rop(OBFUSCATE("GSDKCPU"), OBFUSCATE("getSystemCPUCircle"), 1);           // Return 0
        _bind_rop(OBFUSCATE("GSDKDetectPort_isConnection"), OBFUSCATE("Port_"), 1);    // Return 0 (NO)
        _bind_rop(OBFUSCATE("NetworkManager"), OBFUSCATE("SendSecurityReport"), 0);

        // --- كتيبة الأداء والمراقبة (APM Monitoring) ---
        _bind_rop(OBFUSCATE("APMMonitor"), OBFUSCATE("startMonitoring:"), 0);
        _bind_rop(OBFUSCATE("APMMonitor"), OBFUSCATE("handleEvent:"), 0);
        _bind_rop(OBFUSCATE("APMCollector"), OBFUSCATE("reportNow"), 0);
        _bind_rop(OBFUSCATE("TApmSceneMarker"), OBFUSCATE("markLoadLevel:"), 0);
        _bind_rop(OBFUSCATE("APMDeviceInfoSupport"), OBFUSCATE("getBatteryState"), 2); // Return 1 (YES/Good)

        // --- كتيبة الصوت والشبكة (GCloud & Network) ---
        _bind_rop(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableLog:"), 0);
        _bind_rop(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("APITrace:callInfo:"), 0);
        _bind_rop(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StartTve"), 1);
        _bind_rop(OBFUSCATE("GCloudVoiceExtension"), OBFUSCATE("CheckDeviceMuteStat"), 1);
        _bind_rop(OBFUSCATE("GSDKPing"), OBFUSCATE("ping"), 0);
        _bind_rop(OBFUSCATE("GSDKUdpDetect_isUDPConnect"), OBFUSCATE("Port_"), 1);
        _bind_rop(OBFUSCATE("SimplePing"), OBFUSCATE("start"), 0);

        // --- كتيبة الإحصائيات (IMSDK & Firebase) ---
        _bind_rop(OBFUSCATE("IMSDKStatAdjustManager"), OBFUSCATE("reportEvent_eventBody"), 0);
        _bind_rop(OBFUSCATE("TDataMasterApplication"), OBFUSCATE("reportEventWithSrcID_eventName"), 0);
        _bind_rop(OBFUSCATE("FIRMessaging"), OBFUSCATE("retrieveFCMTokenForSenderID:completion:"), 0);

        // --- كتيبة الإعلانات (Ads & Social) ---
        _bind_rop(OBFUSCATE("FBAdViewabilityValidator"), OBFUSCATE("checkViewability:"), 0);
        _bind_rop(OBFUSCATE("GADMobileAds"), OBFUSCATE("initializationStatus"), 2);    // Return 1 (Ready)
        _bind_rop(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendReq:resultBlock:"), 0);

    });
}
