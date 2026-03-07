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

extern "C" int DobbyHook(void *address, void *replace_call, void **origin_call);

// =================================================================
// [ 1. محرك التشفير الجيني ]
// =================================================================
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

// =================================================================
// [ 2. رادار 2027: استخراج أوامر اللعبة الأصلية (ROP Gadgets) ]
// =================================================================
namespace GhostROP {
    static IMP native_ret_void = NULL;
    static IMP native_ret_0 = NULL;
    static IMP native_ret_1 = NULL;

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
                            
                            // البحث عن أوامر ARM64 داخل اللعبة الأصلية لتفادي Boundary Checks
                            for (uint32_t *p = start; p < end - 1; p++) {
                                // MOV X0, #0 ; RET
                                if (!native_ret_0 && p[0] == 0xD2800000 && p[1] == 0xD65F03C0) native_ret_0 = (IMP)p;
                                // MOV X0, #1 ; RET
                                if (!native_ret_1 && p[0] == 0xD2800020 && p[1] == 0xD65F03C0) native_ret_1 = (IMP)p;
                                // RET
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

// =================================================================
// [ 3. واجهة API والربط الشرياني (Safe Binding) ]
// =================================================================
namespace API {
    typedef Class (*objc_getClass_t)(const char*);
    typedef SEL (*sel_registerName_t)(const char*);
    typedef Method (*class_getInstanceMethod_t)(Class, SEL);
    typedef IMP (*class_replaceMethod_t)(Class, SEL, IMP, const char*);

    static objc_getClass_t sys_objc_getClass = nullptr;
    static sel_registerName_t sys_sel_registerName = nullptr;
    static class_getInstanceMethod_t sys_class_getInstanceMethod = nullptr;
    static class_replaceMethod_t sys_class_replaceMethod = nullptr;

    static bool Init() {
        void* h = RTLD_DEFAULT;
        sys_objc_getClass = (objc_getClass_t)dlsym(h, OBFUSCATE("objc_getClass"));
        sys_sel_registerName = (sel_registerName_t)dlsym(h, OBFUSCATE("sel_registerName"));
        sys_class_getInstanceMethod = (class_getInstanceMethod_t)dlsym(h, OBFUSCATE("class_getInstanceMethod"));
        sys_class_replaceMethod = (class_replaceMethod_t)dlsym(h, OBFUSCATE("class_replaceMethod"));
        return (sys_objc_getClass && sys_sel_registerName && sys_class_getInstanceMethod && sys_class_replaceMethod);
    }
}

__attribute__((visibility("hidden")))
static void _bind_rop(const char* cls, const char* sel, int ret_type) {
    Class c = API::sys_objc_getClass(cls);
    if (!c) return;
    SEL s = API::sys_sel_registerName(sel);
    Method m = API::sys_class_getInstanceMethod(c, s);
    if (m && API::sys_class_replaceMethod) {
        IMP safe_imp = NULL;
        // 0 = Void, 1 = False/0, 2 = True/1
        if (ret_type == 0 && GhostROP::native_ret_void) safe_imp = GhostROP::native_ret_void;
        else if (ret_type == 1 && GhostROP::native_ret_0) safe_imp = GhostROP::native_ret_0;
        else if (ret_type == 2 && GhostROP::native_ret_1) safe_imp = GhostROP::native_ret_1;
        
        if (safe_imp) {
            API::sys_class_replaceMethod(c, s, safe_imp, method_getTypeEncoding(m));
        }
    }
}

// =================================================================
// [ 4. هوك Dobby (Sysctl Bypass) ]
// =================================================================
static int (*orig_sysctl)(int *n, u_int nl, void *op, size_t *ol, void *np, size_t nl2);
int my_sysctl(int *n, u_int nl, void *op, size_t *ol, void *np, size_t nl2) {
    if (!orig_sysctl) return 0;
    int r = orig_sysctl(n, nl, op, ol, np, nl2);
    if (r == 0 && n && nl >= 3 && n[0] == 1 && n[1] == 14 && n[2] == getpid()) {
        if (op) ((struct kinfo_proc *)op)->kp_proc.p_flag &= ~0x00000800;
    }
    return r;
}

// =================================================================
// [ 5. الإقلاع السيادي 2027 (تأخير الحقن + ROP) ]
// =================================================================
__attribute__((constructor))
static void Ignite_Ammar_Zeus_2027() {
    
    // 1. تفعيل Dobby فوراً لحماية الذاكرة
    void* s_ptr = dlsym(RTLD_DEFAULT, OBFUSCATE("sysctl"));
    if (s_ptr) DobbyHook(s_ptr, (void*)my_sysctl, (void**)&orig_sysctl);

    // 2. الانتظار 5 ثوانٍ حتى تنتهي اللعبة من فك التشفير وتهيئة الذاكرة
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        if (!API::Init()) return;
        
        // مسح الذاكرة واستخراج جادجيت اللعبة الأصلية
        GhostROP::ScanGameMemory();
        
        // إذا فشل في العثور على ROP (مستحيل تقريباً)، ننسحب لتفادي الكراش
        if (!GhostROP::native_ret_void || !GhostROP::native_ret_0 || !GhostROP::native_ret_1) return;

        // -----------------------------------------------------------------
        // [ كتيبة الـ 159 مساراً بالتقنية الجديدة ROP ]
        // نوع الإرجاع: 0 = Void, 1 = Return 0/NO, 2 = Return 1/YES
        // -----------------------------------------------------------------
        
        // Core Security
        _bind_rop(OBFUSCATE("SecurityChecker"), OBFUSCATE("IsFileSystemModified"), 1);
        _bind_rop(OBFUSCATE("SecurityChecker"), OBFUSCATE("isJailbroken"), 1);
        _bind_rop(OBFUSCATE("SecurityChecker"), OBFUSCATE("checkDylibs"), 1);
        _bind_rop(OBFUSCATE("GSDKInGameManager"), OBFUSCATE("GSDKRealTimeDetect"), 0);
        _bind_rop(OBFUSCATE("GSDKInGameSystem"), OBFUSCATE("GSDKInnerRealTimeDetect"), 0);
        _bind_rop(OBFUSCATE("GSDKInGameSystem"), OBFUSCATE("GSDKInnerEnd"), 0);
        _bind_rop(OBFUSCATE("GSDKInitManager"), OBFUSCATE("detectOperation_"), 0);
        _bind_rop(OBFUSCATE("GSDKCPU"), OBFUSCATE("getSystemCPUCircle"), 1);
        _bind_rop(OBFUSCATE("GSDKDetectPort_isConnection"), OBFUSCATE("Port_"), 1);
        _bind_rop(OBFUSCATE("NetworkManager"), OBFUSCATE("SendSecurityReport"), 0);
        
        // APM Monitoring
        _bind_rop(OBFUSCATE("APMMonitor"), OBFUSCATE("startMonitoring:"), 0);
        _bind_rop(OBFUSCATE("APMMonitor"), OBFUSCATE("handleEvent:"), 0);
        _bind_rop(OBFUSCATE("APMCollector"), OBFUSCATE("collectMetrics:"), 0);
        _bind_rop(OBFUSCATE("APMCollector"), OBFUSCATE("reportNow"), 0);
        _bind_rop(OBFUSCATE("TApmSceneMarker"), OBFUSCATE("markLoadLevel:"), 0);
        _bind_rop(OBFUSCATE("TApmSceneMarker"), OBFUSCATE("markLevelFin"), 0);
        
        // GCloud Voice
        _bind_rop(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableLog:"), 0);
        _bind_rop(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("APITrace:callInfo:"), 0);
        _bind_rop(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StartTve"), 1);
        _bind_rop(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("TestMic"), 1);
        _bind_rop(OBFUSCATE("GCloudVoiceExtension"), OBFUSCATE("CheckDeviceMuteStat"), 1);
        
        // Network & Ping
        _bind_rop(OBFUSCATE("GSDKPing"), OBFUSCATE("ping"), 0);
        _bind_rop(OBFUSCATE("GSDKPing"), OBFUSCATE("stopPing"), 0);
        _bind_rop(OBFUSCATE("GSDKUdpDetect_isUDPConnect"), OBFUSCATE("Port_"), 1);
        _bind_rop(OBFUSCATE("SimplePing"), OBFUSCATE("start"), 0);
        _bind_rop(OBFUSCATE("AReachability"), OBFUSCATE("isConnectionRequired"), 1);
        
        // IMSDK & Stats
        _bind_rop(OBFUSCATE("IMSDKStatAdjustManager"), OBFUSCATE("reportEvent_eventBody"), 0);
        _bind_rop(OBFUSCATE("TDataMasterApplication"), OBFUSCATE("reportEventWithSrcID_eventName"), 0);
        _bind_rop(OBFUSCATE("FIRMessaging"), OBFUSCATE("retrieveFCMTokenForSenderID:completion:"), 0);
        
        // Ads & Social
        _bind_rop(OBFUSCATE("FBAdViewabilityValidator"), OBFUSCATE("checkViewability:"), 0);
        _bind_rop(OBFUSCATE("FBAdMonitor"), OBFUSCATE("startMonitoringAd:"), 0);
        _bind_rop(OBFUSCATE("GADMobileAds"), OBFUSCATE("initializationStatus"), 2); // Return 1
        _bind_rop(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendReq:resultBlock:"), 0);
        _bind_rop(OBFUSCATE("GCloudUnityPlugin"), OBFUSCATE("Initialize"), 0);

        // تم اختصار القائمة هنا لتوضيح البنية، يمكنك إكمال بقية الـ 159 بنفس نمط _bind_rop

    });
}
