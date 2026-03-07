#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <UIKit/UIKit.h>
#include <sys/sysctl.h>
#include <sys/socket.h>
#include <mach/mach.h>
#include <dlfcn.h>
#include <math.h>
#include <stdarg.h>
#include <string.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>

#ifndef P_TRACED
#define P_TRACED 0x00000800
#endif

// استخدام الهيكل الجديد المموه
struct ios_mem_task { const char *name; void *replacement; void **replaced; };
extern "C" int ios_memory_sync(struct ios_mem_task tasks[], size_t tasks_nel);

// =================================================================
// [ الجزء الأول: محرك طحن النصوص C++14/17 (التمويه الجيني) ]
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
            for (size_t i = 0; i < sizeof(str); ++i) { \
                decrypted[i] = obfuscated.data[i] ^ key; \
            } \
            init = true; \
        } \
        return decrypted; \
    }())

// =================================================================
// [ الجزء الثاني: API الديناميكية (إخفاء دوال النظام) ]
// =================================================================
namespace API {
    typedef char* (*strstr_t)(const char*, const char*);
    typedef int (*strcmp_t)(const char*, const char*);
    typedef void* (*memmem_t)(const void*, size_t, const void*, size_t);
    typedef size_t (*strlen_t)(const char*);
    typedef Class (*objc_getClass_t)(const char*);
    typedef SEL (*sel_registerName_t)(const char*);
    typedef Method (*class_getInstanceMethod_t)(Class, SEL);
    typedef IMP (*class_replaceMethod_t)(Class, SEL, IMP, const char*);
    typedef const char* (*method_getTypeEncoding_t)(Method);

    static strstr_t sys_strstr = nullptr;
    static strcmp_t sys_strcmp = nullptr;
    static memmem_t sys_memmem = nullptr;
    static strlen_t sys_strlen = nullptr;
    static objc_getClass_t sys_objc_getClass = nullptr;
    static sel_registerName_t sys_sel_registerName = nullptr;
    static class_getInstanceMethod_t sys_class_getInstanceMethod = nullptr;
    static class_replaceMethod_t sys_class_replaceMethod = nullptr;
    static method_getTypeEncoding_t sys_method_getTypeEncoding = nullptr;

    static void Init() {
        sys_strstr = (strstr_t)dlsym(RTLD_DEFAULT, OBFUSCATE("strstr"));
        sys_strcmp = (strcmp_t)dlsym(RTLD_DEFAULT, OBFUSCATE("strcmp"));
        sys_memmem = (memmem_t)dlsym(RTLD_DEFAULT, OBFUSCATE("memmem"));
        sys_strlen = (strlen_t)dlsym(RTLD_DEFAULT, OBFUSCATE("strlen"));
        sys_objc_getClass = (objc_getClass_t)dlsym(RTLD_DEFAULT, OBFUSCATE("objc_getClass"));
        sys_sel_registerName = (sel_registerName_t)dlsym(RTLD_DEFAULT, OBFUSCATE("sel_registerName"));
        sys_class_getInstanceMethod = (class_getInstanceMethod_t)dlsym(RTLD_DEFAULT, OBFUSCATE("class_getInstanceMethod"));
        sys_class_replaceMethod = (class_replaceMethod_t)dlsym(RTLD_DEFAULT, OBFUSCATE("class_replaceMethod"));
        sys_method_getTypeEncoding = (method_getTypeEncoding_t)dlsym(RTLD_DEFAULT, OBFUSCATE("method_getTypeEncoding"));
    }
}

static inline id DynStr(const char* str) {
    Class nsstr = API::sys_objc_getClass(OBFUSCATE("NSString"));
    SEL alloc_sel = API::sys_sel_registerName(OBFUSCATE("alloc"));
    SEL init_sel = API::sys_sel_registerName(OBFUSCATE("initWithUTF8String:"));
    id allocated = ((id(*)(id, SEL))objc_msgSend)((id)nsstr, alloc_sel);
    return ((id(*)(id, SEL, const char*))objc_msgSend)(allocated, init_sel, str);
}

// =================================================================
// [ الجزء الثالث: حوض الاستنساخ العشوائي (300 عنوان) لمنع فحص الـ IMP ]
// =================================================================
namespace NativeSpoof {
    static IMP pool_ret_0[300];
    static IMP pool_ret_1[300];
    static IMP pool_ret_void[300];
    static int count_0 = 0, count_1 = 0, count_void = 0;

    static void ScanGameMemory() {
        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(0);
        intptr_t slide = _dyld_get_image_vmaddr_slide(0);
        if (!header) return;

        struct load_command *cmd = (struct load_command *)((char *)header + sizeof(struct mach_header_64));
        for (uint32_t i = 0; i < header->ncmds; i++) {
            if (cmd->cmd == LC_SEGMENT_64) {
                struct segment_command_64 *seg = (struct segment_command_64 *)cmd;
                if (API::sys_strcmp(seg->segname, "__TEXT") == 0) {
                    struct section_64 *sec = (struct section_64 *)((char *)seg + sizeof(struct segment_command_64));
                    for (uint32_t j = 0; j < seg->nsects; j++) {
                        if (API::sys_strcmp(sec->sectname, "__text") == 0) {
                            uint32_t *start = (uint32_t *)(sec->addr + slide);
                            uint32_t *end = (uint32_t *)((char *)start + sec->size);
                            for (uint32_t *p = start; p < end - 1; p++) {
                                if (count_0 < 300 && p[0] == 0xD2800000 && p[1] == 0xD65F03C0) pool_ret_0[count_0++] = (IMP)p;
                                if (count_1 < 300 && p[0] == 0xD2800020 && p[1] == 0xD65F03C0) pool_ret_1[count_1++] = (IMP)p;
                                if (count_void < 300 && p[0] == 0xD65F03C0) pool_ret_void[count_void++] = (IMP)p;
                                if (count_0 == 300 && count_1 == 300 && count_void == 300) return;
                            }
                        }
                        sec = (struct section_64 *)((char *)sec + sizeof(struct section_64));
                    }
                }
            }
            cmd = (struct load_command *)((char *)cmd + cmd->cmdsize);
        }
    }
    static IMP GetRandomRet0() { return count_0 > 0 ? pool_ret_0[arc4random_uniform(count_0)] : NULL; }
    static IMP GetRandomRet1() { return count_1 > 0 ? pool_ret_1[arc4random_uniform(count_1)] : NULL; }
    static IMP GetRandomRetVoid() { return count_void > 0 ? pool_ret_void[arc4random_uniform(count_void)] : NULL; }
}

__attribute__((visibility("hidden"))) id _sys_id_0(id self, SEL _cmd, ...) { return 0; }
__attribute__((visibility("hidden"))) BOOL _sys_bool_yes(id self, SEL _cmd, ...) { return YES; }
__attribute__((visibility("hidden"))) void _sys_void_empty(id self, SEL _cmd, ...) { }

__attribute__((visibility("hidden")))
static void _sys_bind_native(const char* className, const char* selectorName, int retType) {
    Class cls = API::sys_objc_getClass(className);
    if (cls) {
        SEL sel = API::sys_sel_registerName(selectorName);
        Method m = API::sys_class_getInstanceMethod(cls, sel);
        if (m) {
            IMP targetIMP = NULL;
            if (retType == 0) targetIMP = NativeSpoof::GetRandomRet0();
            else if (retType == 1) targetIMP = NativeSpoof::GetRandomRet1();
            else if (retType == 2) targetIMP = NativeSpoof::GetRandomRetVoid();
            
            if (!targetIMP) { 
                if (retType == 0) targetIMP = (IMP)_sys_id_0;
                else if (retType == 1) targetIMP = (IMP)_sys_bool_yes;
                else if (retType == 2) targetIMP = (IMP)_sys_void_empty;
            }
            API::sys_class_replaceMethod(cls, sel, targetIMP, API::sys_method_getTypeEncoding(m));
        }
    }
}

// =================================================================
// [ الجزء الرابع: درع النظام والتلاعب الجراحي بالحزم ]
// =================================================================

static const char* (*orig_dyld_get_image_name)(uint32_t image_index);
__attribute__((visibility("hidden"))) const char* my_dyld_get_image_name(uint32_t image_index) {
    const char* name = orig_dyld_get_image_name(image_index);
    if (name && (API::sys_strstr(name, OBFUSCATE("Ammar")) || API::sys_strstr(name, OBFUSCATE("AmarShield")))) return OBFUSCATE("/usr/lib/system/libsystem_kernel.dylib");
    return name;
}

static int (*orig_dladdr)(const void *addr, Dl_info *info);
__attribute__((visibility("hidden"))) int my_dladdr(const void *addr, Dl_info *info) {
    int ret = orig_dladdr(addr, info);
    if (ret != 0 && info && info->dli_fname) {
        if (API::sys_strstr(info->dli_fname, OBFUSCATE("Ammar")) || API::sys_strstr(info->dli_fname, OBFUSCATE("AmarShield"))) {
            info->dli_fname = OBFUSCATE("/usr/lib/system/libsystem_c.dylib");
            info->dli_sname = OBFUSCATE("malloc"); 
        }
    }
    return ret;
}

static int (*orig_access)(const char *p, int m);
__attribute__((visibility("hidden"))) int my_access(const char *p, int m) {
    if (p && (API::sys_strstr(p, OBFUSCATE("Cydia")) || API::sys_strstr(p, OBFUSCATE("frida")))) return -1;
    return orig_access(p, m);
}

static int (*orig_sysctl)(int *n, u_int nl, void *op, size_t *ol, void *np, size_t nl2);
__attribute__((visibility("hidden"))) int my_sysctl(int *n, u_int nl, void *op, size_t *ol, void *np, size_t nl2) {
    int r = orig_sysctl(n, nl, op, ol, np, nl2);
    if (r == 0 && n && nl >= 3 && n[0] == CTL_KERN && n[1] == KERN_PROC && n[2] == KERN_PROC_PID) {
        if (op) ((struct kinfo_proc *)op)->kp_proc.p_flag &= ~P_TRACED;
    }
    return r;
}

static ssize_t (*orig_sendto)(int sockfd, const void *buf, size_t len, int flags, const struct sockaddr *dest_addr, socklen_t addrlen);
__attribute__((visibility("hidden"))) ssize_t my_sendto(int sockfd, const void *buf, size_t len, int flags, const struct sockaddr *dest_addr, socklen_t addrlen) {
    if (buf && len > 0) {
        const char* rpt = OBFUSCATE("Report");
        const char* pic = OBFUSCATE("pic_data");
        void* rpt_ptr = API::sys_memmem(buf, len, rpt, API::sys_strlen(rpt));
        void* pic_ptr = API::sys_memmem(buf, len, pic, API::sys_strlen(pic));
        
        if (rpt_ptr || pic_ptr) {
            char* safe_buf = (char*)malloc(len);
            memcpy(safe_buf, buf, len);
            if (rpt_ptr) {
                size_t offset = (char*)rpt_ptr - (char*)buf;
                memset(safe_buf + offset, 0x00, API::sys_strlen(rpt)); 
            }
            if (pic_ptr) {
                size_t offset = (char*)pic_ptr - (char*)buf;
                memset(safe_buf + offset, 0x00, API::sys_strlen(pic));
            }
            ssize_t ret = orig_sendto(sockfd, safe_buf, len, flags, dest_addr, addrlen);
            free(safe_buf);
            return ret;
        }
    }
    return orig_sendto(sockfd, buf, len, flags, dest_addr, addrlen);
}

__attribute__((visibility("hidden")))
static void showAmmarVIPMessage() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        Class uiAppCls = API::sys_objc_getClass(OBFUSCATE("UIApplication"));
        SEL sharedAppSel = API::sys_sel_registerName(OBFUSCATE("sharedApplication"));
        id app = ((id(*)(id, SEL))objc_msgSend)((id)uiAppCls, sharedAppSel);

        SEL keyWinSel = API::sys_sel_registerName(OBFUSCATE("keyWindow"));
        id window = ((id(*)(id, SEL))objc_msgSend)(app, keyWinSel);

        SEL rootVCSel = API::sys_sel_registerName(OBFUSCATE("rootViewController"));
        id rootVC = ((id(*)(id, SEL))objc_msgSend)(window, rootVCSel);

        if (rootVC) {
            Class alertCtrlCls = API::sys_objc_getClass(OBFUSCATE("UIAlertController"));
            SEL alertCtrlSel = API::sys_sel_registerName(OBFUSCATE("alertControllerWithTitle:message:preferredStyle:"));
            id title = DynStr(OBFUSCATE("AMAR VIP 2026"));
            id msg = DynStr(OBFUSCATE("تم تفعيل بروتوكول الظل العميق 😈\n(Zero-Trace Mode)"));
            id alert = ((id(*)(id, SEL, id, id, NSInteger))objc_msgSend)((id)alertCtrlCls, alertCtrlSel, title, msg, 1);

            Class alertActCls = API::sys_objc_getClass(OBFUSCATE("UIAlertAction"));
            SEL actSel = API::sys_sel_registerName(OBFUSCATE("actionWithTitle:style:handler:"));
            id btn = DynStr(OBFUSCATE("بدء الجلد المظلم"));
            id action = ((id(*)(id, SEL, id, NSInteger, id))objc_msgSend)((id)alertActCls, actSel, btn, 0, nil);

            SEL addActSel = API::sys_sel_registerName(OBFUSCATE("addAction:"));
            ((void(*)(id, SEL, id))objc_msgSend)(alert, addActSel, action);

            SEL presentSel = API::sys_sel_registerName(OBFUSCATE("presentViewController:animated:completion:"));
            ((void(*)(id, SEL, id, BOOL, id))objc_msgSend)(rootVC, presentSel, alert, YES, nil);
        }
    });
}

// =================================================================
// [ الجزء الخامس: محرك الإقلاع السيادي الكامل ]
// =================================================================

__attribute__((constructor))
static void Ignite_Ammar_Zeus_2026() {
    
    API::Init();
    NativeSpoof::ScanGameMemory();

    // استخدام الفيش هوك المموه ios_memory_sync
    struct ios_mem_task r[] = { 
        {(const char*)OBFUSCATE("sendto"), (void*)my_sendto, (void**)&orig_sendto},
        {(const char*)OBFUSCATE("sysctl"), (void*)my_sysctl, (void**)&orig_sysctl},
        {(const char*)OBFUSCATE("access"), (void*)my_access, (void**)&orig_access},
        {(const char*)OBFUSCATE("dladdr"), (void*)my_dladdr, (void**)&orig_dladdr},
        {(const char*)OBFUSCATE("_dyld_get_image_name"), (void*)my_dyld_get_image_name, (void**)&orig_dyld_get_image_name}
    };
    ios_memory_sync(r, 5);

    showAmmarVIPMessage();

    // =================================================================
    // دوال الحماية الأساسية والشبكة والإعلانات
    // =================================================================
    _sys_bind_native(OBFUSCATE("serviceCommunication"), OBFUSCATE("getValueForKeypath"), 0);
    _sys_bind_native(OBFUSCATE("WeaponProcessor"), OBFUSCATE("CalculateDamage"), 0);
    _sys_bind_native(OBFUSCATE("CharacterMovement"), OBFUSCATE("IsSpeedExceeded"), 0);
    _sys_bind_native(OBFUSCATE("NetworkManager"), OBFUSCATE("SendSecurityReport"), 2);
    _sys_bind_native(OBFUSCATE("SecurityChecker"), OBFUSCATE("IsFileSystemModified"), 0);
    _sys_bind_native(OBFUSCATE("BulletSimulator"), OBFUSCATE("CheckWallCollision"), 0);

    _sys_bind_native(OBFUSCATE("AReachability"), OBFUSCATE("isConnectionOnDemand"), 1);
    _sys_bind_native(OBFUSCATE("AReachability"), OBFUSCATE("isConnectionRequired"), 1);
    _sys_bind_native(OBFUSCATE("AudioDeviceMgr"), OBFUSCATE("GetAudioDeviceConnectState"), 0);
    _sys_bind_native(OBFUSCATE("AudioDeviceMgr"), OBFUSCATE("UpdateDeviceState_"), 0);
    _sys_bind_native(OBFUSCATE("FIRMessagingRmqManager"), OBFUSCATE("openDatabase"), 0);
    _sys_bind_native(OBFUSCATE("GADAdNetworkResponseInfo"), OBFUSCATE("adUnitMapping"), 0);
    _sys_bind_native(OBFUSCATE("GADAppOpenAd_ad"), OBFUSCATE("didFailToPresentFullScreenContentWithError_"), 0);
    _sys_bind_native(OBFUSCATE("GADAppOpenAd"), OBFUSCATE("adDidDismissFullScreenContent_"), 1);
    _sys_bind_native(OBFUSCATE("GADAppOpenAd"), OBFUSCATE("adDidRecordClick_"), 0);
    _sys_bind_native(OBFUSCATE("GADAppOpenAd"), OBFUSCATE("adDidRecordImpression_"), 0);
    _sys_bind_native(OBFUSCATE("GADAppOpenAd"), OBFUSCATE("adWillDismissFullScreenContent_"), 1);
    _sys_bind_native(OBFUSCATE("GADAppOpenAd"), OBFUSCATE("adWillPresentFullScreenContent_"), 0);
    _sys_bind_native(OBFUSCATE("GADAppOpenAd_canPresentFromRootViewController"), OBFUSCATE("error_"), 0);
    _sys_bind_native(OBFUSCATE("GADAppOpenAd"), OBFUSCATE("responseInfo"), 0);
    _sys_bind_native(OBFUSCATE("GADAppOpenAd"), OBFUSCATE("setPaidEventHandler_"), 0);
    _sys_bind_native(OBFUSCATE("GADMobileAds"), OBFUSCATE("initializationStatus"), 0);
    _sys_bind_native(OBFUSCATE("GSDKCPU"), OBFUSCATE("getSystemCPUCircle"), 0);
    _sys_bind_native(OBFUSCATE("GSDKDetectPort_isConnection"), OBFUSCATE("Port_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKHttpDnsResolver"), OBFUSCATE("dealloc"), 0);
    _sys_bind_native(OBFUSCATE("GSDKHttpRequest"), OBFUSCATE("dealloc"), 0);
    _sys_bind_native(OBFUSCATE("GSDKHttpRequest_requestControl_Openid_Acctype_Zoneid"), OBFUSCATE("Env_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKInGameManager"), OBFUSCATE("GSDKRealTimeDetect"), 0);
    _sys_bind_native(OBFUSCATE("GSDKInGameSystem"), OBFUSCATE("GSDKInnerEnd"), 0);
    _sys_bind_native(OBFUSCATE("GSDKInGameSystem"), OBFUSCATE("GSDKInnerRealTimeDetect"), 0);
    _sys_bind_native(OBFUSCATE("GSDKInGameSystem_GSDKInnerSaveFPS"), OBFUSCATE("FpsDots_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKInGameSystem_GSDKInnerStart_SceneID"), OBFUSCATE("RoomIP_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKInitManager"), OBFUSCATE("detectOperation_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKMemory"), OBFUSCATE("getSystemAvailableMemory"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPayEvent_GSDKPay_Tag_Status"), OBFUSCATE("Msg_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPing"), OBFUSCATE("dealloc"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPing"), OBFUSCATE("ping"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPing_simplePing_didFailToSendPacket_sequenceNumber"), OBFUSCATE("error_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPing_simplePing"), OBFUSCATE("didFailWithError_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPing_simplePing_didReceivePingResponsePacket"), OBFUSCATE("sequenceNumber_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPing_simplePing"), OBFUSCATE("didReceiveUnexpectedPacket_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPing_simplePing_didSendPacket"), OBFUSCATE("sequenceNumber_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPing_simplePing"), OBFUSCATE("didStartWithAddress_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPing"), OBFUSCATE("stopPing"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPingDetect"), OBFUSCATE("dealloc"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPingDetect"), OBFUSCATE("ping"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPingDetect_simplePing_didFailToSendPacket_sequenceNumber"), OBFUSCATE("error_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPingDetect_simplePing"), OBFUSCATE("didFailWithError_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPingDetect_simplePing_didReceivePingResponsePacket"), OBFUSCATE("sequenceNumber_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPingDetect_simplePing"), OBFUSCATE("didReceiveUnexpectedPacket_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPingDetect_simplePing_didSendPacket"), OBFUSCATE("sequenceNumber_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKPingDetect_simplePing"), OBFUSCATE("didStartWithAddress_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKRealTimeDetect"), OBFUSCATE("pingDelayDetect_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKRealTimeDetect_updDelayDetect"), OBFUSCATE("Port_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKUdpDetect_isUDPConnect"), OBFUSCATE("Port_"), 0);
    _sys_bind_native(OBFUSCATE("GSDKWIFI"), OBFUSCATE("ping_"), 0);
    _sys_bind_native(OBFUSCATE("GTMSessionFetcher_setSystemCompletionHandler"), OBFUSCATE("forSessionIdentifier_"), 0);
    _sys_bind_native(OBFUSCATE("GVGCloudVoice"), OBFUSCATE("openMic"), 0);
    _sys_bind_native(OBFUSCATE("GVGCloudVoice"), OBFUSCATE("openSpeaker"), 0);
    _sys_bind_native(OBFUSCATE("GVGCloudVoice_setAppInfo_withKey"), OBFUSCATE("andOpenID_"), 0);
    _sys_bind_native(OBFUSCATE("GVGCloudVoiceExtension"), OBFUSCATE("CheckDeviceMuteStat"), 1);
    _sys_bind_native(OBFUSCATE("GVGCloudVoiceExtension"), OBFUSCATE("EnableKeyWordsDetect_"), 0);
    _sys_bind_native(OBFUSCATE("GVGCloudVoiceExtension"), OBFUSCATE("GetBGMPlayState"), 0);
    _sys_bind_native(OBFUSCATE("GVGCloudVoiceExtension"), OBFUSCATE("GetMicState"), 0);
    _sys_bind_native(OBFUSCATE("GVGCloudVoiceExtension"), OBFUSCATE("GetSpeakerState"), 0);
    _sys_bind_native(OBFUSCATE("GVoiceMuteSwitch"), OBFUSCATE("detectMuteSwitch"), 0);
    _sys_bind_native(OBFUSCATE("IMSDKCustomWebView"), OBFUSCATE("dealloc"), 0);
    _sys_bind_native(OBFUSCATE("IMSDKNoticeIMSDKManager_getImageCache_imagePath_imageHash_queue"), OBFUSCATE("completeHandle_"), 0);
    _sys_bind_native(OBFUSCATE("IMSDKNoticeIMSDKManager"), OBFUSCATE("imsdkCoreKitNoticeImageFileHash_"), 0);
    _sys_bind_native(OBFUSCATE("IMSDKStatAdjustManager_reportEvent_eventBody"), OBFUSCATE("isRealtime_"), 1);
    _sys_bind_native(OBFUSCATE("IMSDKStatAdjustManager_reportEvent_params"), OBFUSCATE("isRealtime_"), 1);
    _sys_bind_native(OBFUSCATE("IMSDKStatAdjustManager_reportPurchase_currentCode_expense"), OBFUSCATE("isRealTime_"), 1);
    _sys_bind_native(OBFUSCATE("IMSDKStatAdjustManager_reportRevenue_currencyCode_revenueValue_params"), OBFUSCATE("extraJson_"), 0);
    _sys_bind_native(OBFUSCATE("INTLWebViewManager_openURL_observerID"), OBFUSCATE("baseParams_"), 0);
    _sys_bind_native(OBFUSCATE("PingDelegate"), OBFUSCATE("pingTimer"), 0);
    _sys_bind_native(OBFUSCATE("PingDelegate_simplePing_didFailToSendPacket_sequenceNumber"), OBFUSCATE("error_"), 0);
    _sys_bind_native(OBFUSCATE("PingDelegate_simplePing_didSendPacket"), OBFUSCATE("sequenceNumber_"), 0);
    _sys_bind_native(OBFUSCATE("QQOpenApiUtility"), OBFUSCATE("cgiRequestGetSdkConfig_"), 0);
    _sys_bind_native(OBFUSCATE("SimplePing"), OBFUSCATE("dealloc"), 0);
    _sys_bind_native(OBFUSCATE("SimplePing"), OBFUSCATE("didFailWithError_"), 0);
    _sys_bind_native(OBFUSCATE("SimplePing_pingPacketWithType_payload"), OBFUSCATE("requiresChecksum_"), 1);
    _sys_bind_native(OBFUSCATE("SimplePing"), OBFUSCATE("readData"), 0);
    _sys_bind_native(OBFUSCATE("SimplePing"), OBFUSCATE("sendPingWithData_"), 0);
    _sys_bind_native(OBFUSCATE("SimplePing"), OBFUSCATE("start"), 0);
    _sys_bind_native(OBFUSCATE("SimplePing"), OBFUSCATE("startWithHostAddress"), 0);
    _sys_bind_native(OBFUSCATE("SimplePing_validatePingResponsePacket"), OBFUSCATE("sequenceNumber_"), 0);
    _sys_bind_native(OBFUSCATE("TDataMasterApplication"), OBFUSCATE("handleOpenURL_"), 0);
    _sys_bind_native(OBFUSCATE("TDataMasterApplication_reportEventWithSrcID_eventName"), OBFUSCATE("AndEventKVArray_"), 0);
    _sys_bind_native(OBFUSCATE("TcApiTool"), OBFUSCATE("openUniversallinkIfNeed_"), 0);

    // =================================================================
    // دوال APM
    // =================================================================
    _sys_bind_native(OBFUSCATE("APMMonitor"), OBFUSCATE("handleEvent:"), 0);
    _sys_bind_native(OBFUSCATE("APMMonitor"), OBFUSCATE("startMonitoring:"), 0);
    _sys_bind_native(OBFUSCATE("APMDeviceInfoSupport"), OBFUSCATE("getBatteryState"), 0);
    _sys_bind_native(OBFUSCATE("APMDeviceInfoSupport"), OBFUSCATE("getThermalState"), 0);
    _sys_bind_native(OBFUSCATE("APMCollector"), OBFUSCATE("collectMetrics:"), 0);
    _sys_bind_native(OBFUSCATE("APMCollector"), OBFUSCATE("reportNow"), 0);
    _sys_bind_native(OBFUSCATE("TApmSceneMarker"), OBFUSCATE("markLoadLevel:"), 0);
    _sys_bind_native(OBFUSCATE("TApmSceneMarker"), OBFUSCATE("markLevelFin"), 0);
    _sys_bind_native(OBFUSCATE("TApmSceneMarker"), OBFUSCATE("postStepEvent:"), 0);
    _sys_bind_native(OBFUSCATE("TApmSceneMarker"), OBFUSCATE("postStreamEvent:"), 0);

    // =================================================================
    // دوال GCloud Voice
    // =================================================================
    _sys_bind_native(OBFUSCATE("GCloudCoreRemoteConfig"), OBFUSCATE("updateConfig:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudCoreRemoteConfig"), OBFUSCATE("getConfig:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StartTve"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("JoinTeamRoom_Scenes:roomName:timeout:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("QuitRoom_Scenes:timeout:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableMultiRoom:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableRoomMicrophone:enable:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableRoomSpeaker:enable:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("ApplyMessageKey:timestamp:timeout:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StartRecording:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StopRecording"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("UploadRecordedFile:timeout:fileProperty:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("DownloadRecordedFile:filePath:timeout:fileProperty:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableLog:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetLogCallBack:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("GetMicLevel"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("GetSpeakerLevel"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetMicVolume:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetSpeakerVolume:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SpeechToText:token:timestamp:timeout:language:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("ForbidMemberVoice:enable:inRoom:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("TestMic"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("GetFileParam:data:time:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetBGMPath:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StartBGMPlay"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StopBGMPlay"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("PauseBGMPlay"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("ResumeBGMPlay"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableNativeBGMPlay:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetBitRate:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetDataFree:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("RSTSStartRecording:targetLang:targetLangCnt:action:timeout:recordFilePath:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("RSTSSpeechToSpeech:targetLang:targetLangCnt:dirPath:voiceType:voiceRate:volume:timeout:recordFilePath:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("RSTSSpeechToText:targetLang:targetLangCnt:timeout:recordFilePath:srcLangStr:extInfo:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("RSTSStopRecording"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("TextToStreamSpeechStart:voiceType:timeout:filePath:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("TextToStreamSpeechStop"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableTranslate:isEnable:lang:transType:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableMagicVoice:isEnable:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableRecvMagicVoice:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("RoomGeneralDataChannel:content:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("APITrace:callInfo:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetPlayerInfoAbroad:members:lang:count:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableReportALL:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableReportALLAbroad:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableReportForAbroad:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("ReportFileForAbroad:bTranslate:bChangeVoice:time:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableCivilFile:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableCivilVoice:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetCivilBinPath:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableEarBack:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StartKaraokeRecording:accfile:orifile:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StopKaraokeRecording"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableAccFilePlay:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetKaraokeVoiceVol:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetKaraokeAccVol:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetKaraokeVoiceDelay:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StartPreview"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StopPreview"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SeekTimeMsForPreview:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SeekTimeMsForAcc:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("PauseKaraoke"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("ResumeKaraoke"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("GetRecordKaraokeTotalTime"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("GetBGMLevel"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetReportedPlayerInfo:arg1:arg2:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("ReportPlayer:arg1:arg2:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetReportBufferTime:"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("GetBGMFileTime"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("GetBGMPlayTime"), 0);
    _sys_bind_native(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetBGMPlayTime:"), 0);

    // =================================================================
    // دوال Facebook Ads, Firebase, Tencent
    // =================================================================
    _sys_bind_native(OBFUSCATE("FBAdViewabilityValidator"), OBFUSCATE("checkViewability:"), 0);
    _sys_bind_native(OBFUSCATE("FBAdViewabilityValidator"), OBFUSCATE("stopMonitoring"), 0);
    _sys_bind_native(OBFUSCATE("FBAdMonitor"), OBFUSCATE("startMonitoringAd:"), 0);
    _sys_bind_native(OBFUSCATE("FBAdMonitor"), OBFUSCATE("stopMonitoring"), 0);
    _sys_bind_native(OBFUSCATE("FBAdEvent"), OBFUSCATE("logEvent:withParameters:"), 0);
    _sys_bind_native(OBFUSCATE("FBAdLogger"), OBFUSCATE("logMessage:withLevel:"), 0);
    _sys_bind_native(OBFUSCATE("FIRMessaging"), OBFUSCATE("retrieveFCMTokenForSenderID:completion:"), 0);
    _sys_bind_native(OBFUSCATE("FIRMessaging"), OBFUSCATE("deleteFCMTokenForSenderID:completion:"), 0);
    _sys_bind_native(OBFUSCATE("FIRMessaging"), OBFUSCATE("subscribeToTopic:completion:"), 0);
    _sys_bind_native(OBFUSCATE("FIRMessaging"), OBFUSCATE("unsubscribeFromTopic:completion:"), 0);
    _sys_bind_native(OBFUSCATE("FIRMessaging"), OBFUSCATE("setAPNSToken:withUserInfo:"), 0);
    _sys_bind_native(OBFUSCATE("FIRMessaging"), OBFUSCATE("APNSToken"), 0);
    _sys_bind_native(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendReq:resultBlock:"), 0);
    _sys_bind_native(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendThirdAppBindGroupReq:resultBlock:"), 0);
    _sys_bind_native(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendThirdAppUnBindGroupReq:resultBlock:"), 0);
    _sys_bind_native(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendThirdAppJoinGroupReq:resultBlock:"), 0);
    _sys_bind_native(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendQueryQQGroupProInfo:resultBlock:"), 0);
    _sys_bind_native(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendMessageToQQAuthWithReq:"), 0);
    _sys_bind_native(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendMessageToQQAvatarWithReq:"), 0);
    _sys_bind_native(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendMessageToFaceCollectionWithReq:"), 0);

    // =================================================================
    // دوال Unity, TikTok, VK, SnapChat
    // =================================================================
    _sys_bind_native(OBFUSCATE("GCloudUnityPlugin"), OBFUSCATE("Initialize"), 0);
    _sys_bind_native(OBFUSCATE("GCloudUnityPlugin"), OBFUSCATE("ReportEvent"), 0);
    _sys_bind_native(OBFUSCATE("GCloudUnityPlugin"), OBFUSCATE("SetGameObjectName:"), 0);
    _sys_bind_native(OBFUSCATE("TikTokAuth"), OBFUSCATE("authorizeWithPermissions:"), 0);
    _sys_bind_native(OBFUSCATE("TikTokAuth"), OBFUSCATE("handleOpenURL:"), 0);
    _sys_bind_native(OBFUSCATE("VKAuth"), OBFUSCATE("authorizeWithPermissions:"), 0);
    _sys_bind_native(OBFUSCATE("VKAuth"), OBFUSCATE("logout"), 0);
    _sys_bind_native(OBFUSCATE("SCSDKLoginClient"), OBFUSCATE("loginWithCompletion:"), 0);
    _sys_bind_native(OBFUSCATE("SCSDKLoginClient"), OBFUSCATE("logout"), 0);
}
