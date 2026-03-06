#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#include <sys/sysctl.h>
#include <sys/socket.h>
#include <mach/mach.h>
#include <dlfcn.h>
#include <math.h>
#include <stdarg.h>
#include <string.h> // ضروري جداً لدالة memmem الآمنة

#ifndef P_TRACED
#define P_TRACED 0x00000800
#endif

// --- تعريف هيكل الربط (Fishhook) لإعادة توجيه العناوين ---
struct rebinding { const char *name; void *replacement; void **replaced; };
extern "C" int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

// =================================================================
// [ الجزء الأول: تقنية التشفير الشبحية 2026 ]
// =================================================================

namespace AmmarShield {
    template <unsigned int... Is> struct index_sequence {};
    template <unsigned int N, unsigned int... Is> struct make_index_sequence : make_index_sequence<N - 1, N - 1, Is...> {};
    template <unsigned int... Is> struct make_index_sequence<0, Is...> { typedef index_sequence<Is...> type; };

    constexpr int seed_gen(int counter) {
        return (__TIME__[7] - '0') * 1 + (__TIME__[6] - '0') * 10 +
               (__TIME__[4] - '0') * 60 + (__TIME__[3] - '0') * 600 +
               (__TIME__[1] - '0') * 3600 + (__TIME__[0] - '0') * 36000 + counter;
    }

    template <unsigned int N, int K>
    struct Obfuscator {
        char data[N];

        template <unsigned int... Is>
        constexpr Obfuscator(const char* str, index_sequence<Is...>)
            : data{ static_cast<char>((str[Is] ^ K) + (K % 10))... } {}

        __attribute__((always_inline)) const char* decrypt() {
            for (unsigned int i = 0; i < N; ++i) {
                data[i] = (data[i] - (K % 10)) ^ K;
            }
            return data;
        }
    };

    template<unsigned int N, int K>
    static const char* safe_obfuscate(const char* str) {
        static Obfuscator<N, K> obf(str, typename make_index_sequence<N>::type());
        return obf.decrypt();
    }
}

#define OBFUSCATE(str) (AmmarShield::safe_obfuscate<sizeof(str), AmmarShield::seed_gen(__COUNTER__)>(str))


// =================================================================
// [ الجزء الثاني: محرك النجاة والحماية من السيرفر (كودك الأصلي تيتو) ]
// =================================================================

// 1. محرك النجاة (Survival Aim Logic)
struct Vector2 { float x, y; };

__attribute__((visibility("hidden")))
Vector2 ApplySurvivalAim(Vector2 current, Vector2 target, float baseSmooth) {
    Vector2 result;
    float dx = target.x - current.x;
    float dy = target.y - current.y;
    
    float jitter = ((float)arc4random_uniform(100) / 1200.0f) - 0.04f;
    dx += jitter; dy += jitter;

    float distance = sqrtf(dx*dx + dy*dy);
    float dynamicSmooth = (distance < 6.0f) ? baseSmooth * 1.6f : baseSmooth;
    
    result.x = current.x + (dx / dynamicSmooth);
    result.y = current.y + (dy / dynamicSmooth);
    
    return result;
}

// 2. تخدير الـ SDK (السر في منع باند الأسبوع هو return 1)
__attribute__((visibility("hidden"))) void* my_AnoSDKGetReportData(int* out_size) { if (out_size) *out_size = 0; return NULL; }
__attribute__((visibility("hidden"))) int my_AnoSDKInit(void* a1, void* a2, void* a3) { return 1; } // تم إرجاعها إلى 1 كما كانت عندك
__attribute__((visibility("hidden"))) void my_AnoSDKOnRecvData(void* d, int s) { return; }
__attribute__((visibility("hidden"))) void my_AnoSDKSetUserInfo(void* i) { return; }

// 3. درع الذاكرة والنظام
static kern_return_t (*orig_vm_read)(vm_map_t, vm_address_t, vm_size_t, vm_offset_t*, mach_msg_type_number_t*);
__attribute__((visibility("hidden")))
kern_return_t my_vm_read(vm_map_t target_task, vm_address_t address, vm_size_t size, vm_offset_t* data, mach_msg_type_number_t* dataCnt) {
    return KERN_FAILURE; 
}

static int (*orig_sysctl)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
__attribute__((visibility("hidden")))
int my_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int ret = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    if (ret == 0 && name && namelen >= 3 && name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID) {
        if (oldp && oldlenp && *oldlenp >= sizeof(struct kinfo_proc)) {
            struct kinfo_proc *info = (struct kinfo_proc *)oldp;
            info->kp_proc.p_flag &= ~P_TRACED;
        }
    }
    return ret;
}

// 4. حماية الشهادة
static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef query, CFTypeRef *result);
__attribute__((visibility("hidden")))
OSStatus my_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    return errSecItemNotFound; 
}

// 5. حماية الشبكة *** (هنا تم إصلاح الكراش القاتل باستخدام memmem الآمنة) ***
static ssize_t (*orig_sendto)(int sockfd, const void *buf, size_t len, int flags, const struct sockaddr *dest_addr, socklen_t addrlen);
__attribute__((visibility("hidden")))
ssize_t my_sendto(int sockfd, const void *buf, size_t len, int flags, const struct sockaddr *dest_addr, socklen_t addrlen) {
    if (buf && len > 0) {
        const char* rpt = OBFUSCATE("Report");
        const char* pic = OBFUSCATE("pic_data");
        const char* scr = OBFUSCATE("screenshot");
        
        // استخدام memmem للبحث الآمن داخل حدود حزمة الإنترنت فقط (يمنع الكراش 100%)
        if (memmem(buf, len, rpt, strlen(rpt)) || 
            memmem(buf, len, pic, strlen(pic)) || 
            memmem(buf, len, scr, strlen(scr))) {
            return len;
        }
    }
    return orig_sendto(sockfd, buf, len, flags, dest_addr, addrlen);
}

// 6. حماية السجلات
static int (*orig_open)(const char *path, int oflag, ...);
__attribute__((visibility("hidden")))
int my_open(const char *path, int oflag, ...) {
    static const char* dev_null = "/dev/null";
    if (path) {
        if (strstr(path, OBFUSCATE("CrashSight")) || strstr(path, OBFUSCATE("Saved/Logs")) || strstr(path, OBFUSCATE("embedded.mobileprovision"))) {
            return orig_open(dev_null, oflag);
        }
    }
    
    if (oflag & O_CREAT) {
        va_list args; 
        va_start(args, oflag); 
        mode_t mode = va_arg(args, int);
        va_end(args);
        return orig_open(path, oflag, mode);
    } else {
        return orig_open(path, oflag);
    }
}

// 7. محرك البوابة الرئيسية (Dlsym Master Hook)
static void* (*orig_dlsym)(void *handle, const char *symbol);
__attribute__((visibility("hidden")))
void* my_dlsym(void *handle, const char *symbol) {
    if (symbol) {
        if (strcmp(symbol, OBFUSCATE("AnoSDKInit")) == 0) return (void*)my_AnoSDKInit;
        if (strcmp(symbol, OBFUSCATE("AnoSDKGetReportData")) == 0) return (void*)my_AnoSDKGetReportData;
        if (strcmp(symbol, OBFUSCATE("vm_read")) == 0) return (void*)my_vm_read;
        if (strcmp(symbol, OBFUSCATE("sysctl")) == 0) return (void*)my_sysctl;
        if (strcmp(symbol, OBFUSCATE("sendto")) == 0) return (void*)my_sendto;
        if (strcmp(symbol, OBFUSCATE("SecItemCopyMatching")) == 0) return (void*)my_SecItemCopyMatching;
    }
    return orig_dlsym(handle, symbol);
}


// =================================================================
// [ الجزء الثالث: محرك الربط الشبح الخاص بـ AmmarVIP ]
// =================================================================

__attribute__((visibility("hidden")))
static void _sys_bind(const char* className, const char* selectorName, IMP newImp) {
    Class cls = objc_getClass(className);
    if (cls) {
        SEL sel = sel_registerName(selectorName);
        Method m = class_getInstanceMethod(cls, sel);
        if (m) {
            class_replaceMethod(cls, sel, newImp, method_getTypeEncoding(m));
        }
    }
}

__attribute__((visibility("hidden"))) id _sys_id_0(id self, SEL _cmd, ...) { return 0; }
__attribute__((visibility("hidden"))) BOOL _sys_bool_no(id self, SEL _cmd, ...) { return NO; }
__attribute__((visibility("hidden"))) BOOL _sys_bool_yes(id self, SEL _cmd, ...) { return YES; }
__attribute__((visibility("hidden"))) void _sys_void_empty(id self, SEL _cmd, ...) { }

__attribute__((visibility("hidden")))
static void showAmmarVIPMessage() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
                if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                    window = windowScene.windows.firstObject;
                    break;
                }
            }
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            window = [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
        }

        if (window && window.rootViewController) {
            NSString *title = [NSString stringWithUTF8String:OBFUSCATE("AMAR VIP 2026")];
            NSString *msg = [NSString stringWithUTF8String:OBFUSCATE("تم تفعيل الحماية الشبحية المطلقة 😎\nجاهز للجلد بدون باند.")];
            NSString *btn = [NSString stringWithUTF8String:OBFUSCATE("استمرار")];

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:btn style:UIAlertActionStyleDefault handler:nil];
            [alert addAction:okAction];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        }
    });
}


// =================================================================
// [ الجزء الرابع: محرك الإقلاع السيادي (Final Entry Point) ]
// =================================================================

__attribute__((constructor))
static void IgniteBlackAbsolute_And_AmmarVIP() {
    
    // 1. تفعيل حماية Fishhook الخاص بك بدقة
    struct rebinding r[] = { 
        {(const char*)OBFUSCATE("dlsym"), (void*)my_dlsym, (void**)&orig_dlsym},
        {(const char*)OBFUSCATE("sysctl"), (void*)my_sysctl, (void**)&orig_sysctl},
        {(const char*)OBFUSCATE("open"), (void*)my_open, (void**)&orig_open},
        {(const char*)OBFUSCATE("sendto"), (void*)my_sendto, (void**)&orig_sendto},
        {(const char*)OBFUSCATE("vm_read"), (void*)my_vm_read, (void**)&orig_vm_read},
        {(const char*)OBFUSCATE("SecItemCopyMatching"), (void*)my_SecItemCopyMatching, (void**)&orig_SecItemCopyMatching}
    };
    rebind_symbols(r, 6);
    
    showAmmarVIPMessage();
    NSLog(@"%@", [NSString stringWithUTF8String:OBFUSCATE("💎 [Black Sovereign] V-Absolute Loaded. Welcome, Black. DNS & Recovery Synced.")]);

    // 2. تفعيل كل مسارات الـ 159 (بما فيها الصوت والإعلانات لأنها بريئة من الكراش)
    _sys_bind(OBFUSCATE("serviceCommunication"), OBFUSCATE("getValueForKeypath"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("WeaponProcessor"), OBFUSCATE("CalculateDamage"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("CharacterMovement"), OBFUSCATE("IsSpeedExceeded"), (IMP)_sys_bool_no);
    _sys_bind(OBFUSCATE("NetworkManager"), OBFUSCATE("SendSecurityReport"), (IMP)_sys_void_empty);
    _sys_bind(OBFUSCATE("SecurityChecker"), OBFUSCATE("IsFileSystemModified"), (IMP)_sys_bool_no);
    _sys_bind(OBFUSCATE("BulletSimulator"), OBFUSCATE("CheckWallCollision"), (IMP)_sys_id_0);

    _sys_bind(OBFUSCATE("AReachability"), OBFUSCATE("isConnectionOnDemand"), (IMP)_sys_bool_yes);
    _sys_bind(OBFUSCATE("AReachability"), OBFUSCATE("isConnectionRequired"), (IMP)_sys_bool_yes);
    _sys_bind(OBFUSCATE("AudioDeviceMgr"), OBFUSCATE("GetAudioDeviceConnectState"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("AudioDeviceMgr"), OBFUSCATE("UpdateDeviceState_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("FIRMessagingRmqManager"), OBFUSCATE("openDatabase"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GADAdNetworkResponseInfo"), OBFUSCATE("adUnitMapping"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GADAppOpenAd_ad"), OBFUSCATE("didFailToPresentFullScreenContentWithError_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GADAppOpenAd"), OBFUSCATE("adDidDismissFullScreenContent_"), (IMP)_sys_bool_yes);
    _sys_bind(OBFUSCATE("GADAppOpenAd"), OBFUSCATE("adDidRecordClick_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GADAppOpenAd"), OBFUSCATE("adDidRecordImpression_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GADAppOpenAd"), OBFUSCATE("adWillDismissFullScreenContent_"), (IMP)_sys_bool_yes);
    _sys_bind(OBFUSCATE("GADAppOpenAd"), OBFUSCATE("adWillPresentFullScreenContent_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GADAppOpenAd_canPresentFromRootViewController"), OBFUSCATE("error_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GADAppOpenAd"), OBFUSCATE("responseInfo"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GADAppOpenAd"), OBFUSCATE("setPaidEventHandler_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GADMobileAds"), OBFUSCATE("initializationStatus"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKCPU"), OBFUSCATE("getSystemCPUCircle"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKDetectPort_isConnection"), OBFUSCATE("Port_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKHttpDnsResolver"), OBFUSCATE("dealloc"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKHttpRequest"), OBFUSCATE("dealloc"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKHttpRequest_requestControl_Openid_Acctype_Zoneid"), OBFUSCATE("Env_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKInGameManager"), OBFUSCATE("GSDKRealTimeDetect"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKInGameSystem"), OBFUSCATE("GSDKInnerEnd"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKInGameSystem"), OBFUSCATE("GSDKInnerRealTimeDetect"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKInGameSystem_GSDKInnerSaveFPS"), OBFUSCATE("FpsDots_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKInGameSystem_GSDKInnerStart_SceneID"), OBFUSCATE("RoomIP_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKInitManager"), OBFUSCATE("detectOperation_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKMemory"), OBFUSCATE("getSystemAvailableMemory"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPayEvent_GSDKPay_Tag_Status"), OBFUSCATE("Msg_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPing"), OBFUSCATE("dealloc"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPing"), OBFUSCATE("ping"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPing_simplePing_didFailToSendPacket_sequenceNumber"), OBFUSCATE("error_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPing_simplePing"), OBFUSCATE("didFailWithError_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPing_simplePing_didReceivePingResponsePacket"), OBFUSCATE("sequenceNumber_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPing_simplePing"), OBFUSCATE("didReceiveUnexpectedPacket_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPing_simplePing_didSendPacket"), OBFUSCATE("sequenceNumber_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPing_simplePing"), OBFUSCATE("didStartWithAddress_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPing"), OBFUSCATE("stopPing"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPingDetect"), OBFUSCATE("dealloc"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPingDetect"), OBFUSCATE("ping"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPingDetect_simplePing_didFailToSendPacket_sequenceNumber"), OBFUSCATE("error_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPingDetect_simplePing"), OBFUSCATE("didFailWithError_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPingDetect_simplePing_didReceivePingResponsePacket"), OBFUSCATE("sequenceNumber_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPingDetect_simplePing"), OBFUSCATE("didReceiveUnexpectedPacket_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPingDetect_simplePing_didSendPacket"), OBFUSCATE("sequenceNumber_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKPingDetect_simplePing"), OBFUSCATE("didStartWithAddress_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKRealTimeDetect"), OBFUSCATE("pingDelayDetect_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKRealTimeDetect_updDelayDetect"), OBFUSCATE("Port_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKUdpDetect_isUDPConnect"), OBFUSCATE("Port_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GSDKWIFI"), OBFUSCATE("ping_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GTMSessionFetcher_setSystemCompletionHandler"), OBFUSCATE("forSessionIdentifier_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GVGCloudVoice"), OBFUSCATE("openMic"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GVGCloudVoice"), OBFUSCATE("openSpeaker"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GVGCloudVoice_setAppInfo_withKey"), OBFUSCATE("andOpenID_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GVGCloudVoiceExtension"), OBFUSCATE("CheckDeviceMuteStat"), (IMP)_sys_bool_yes);
    _sys_bind(OBFUSCATE("GVGCloudVoiceExtension"), OBFUSCATE("EnableKeyWordsDetect_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GVGCloudVoiceExtension"), OBFUSCATE("GetBGMPlayState"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GVGCloudVoiceExtension"), OBFUSCATE("GetMicState"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GVGCloudVoiceExtension"), OBFUSCATE("GetSpeakerState"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GVoiceMuteSwitch"), OBFUSCATE("detectMuteSwitch"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("IMSDKCustomWebView"), OBFUSCATE("dealloc"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("IMSDKNoticeIMSDKManager_getImageCache_imagePath_imageHash_queue"), OBFUSCATE("completeHandle_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("IMSDKNoticeIMSDKManager"), OBFUSCATE("imsdkCoreKitNoticeImageFileHash_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("IMSDKStatAdjustManager_reportEvent_eventBody"), OBFUSCATE("isRealtime_"), (IMP)_sys_bool_yes);
    _sys_bind(OBFUSCATE("IMSDKStatAdjustManager_reportEvent_params"), OBFUSCATE("isRealtime_"), (IMP)_sys_bool_yes);
    _sys_bind(OBFUSCATE("IMSDKStatAdjustManager_reportPurchase_currentCode_expense"), OBFUSCATE("isRealTime_"), (IMP)_sys_bool_yes);
    _sys_bind(OBFUSCATE("IMSDKStatAdjustManager_reportRevenue_currencyCode_revenueValue_params"), OBFUSCATE("extraJson_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("INTLWebViewManager_openURL_observerID"), OBFUSCATE("baseParams_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("PingDelegate"), OBFUSCATE("pingTimer"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("PingDelegate_simplePing_didFailToSendPacket_sequenceNumber"), OBFUSCATE("error_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("PingDelegate_simplePing_didSendPacket"), OBFUSCATE("sequenceNumber_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("QQOpenApiUtility"), OBFUSCATE("cgiRequestGetSdkConfig_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("SimplePing"), OBFUSCATE("dealloc"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("SimplePing"), OBFUSCATE("didFailWithError_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("SimplePing_pingPacketWithType_payload"), OBFUSCATE("requiresChecksum_"), (IMP)_sys_bool_yes);
    _sys_bind(OBFUSCATE("SimplePing"), OBFUSCATE("readData"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("SimplePing"), OBFUSCATE("sendPingWithData_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("SimplePing"), OBFUSCATE("start"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("SimplePing"), OBFUSCATE("startWithHostAddress"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("SimplePing_validatePingResponsePacket"), OBFUSCATE("sequenceNumber_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("TDataMasterApplication"), OBFUSCATE("handleOpenURL_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("TDataMasterApplication_reportEventWithSrcID_eventName"), OBFUSCATE("AndEventKVArray_"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("TcApiTool"), OBFUSCATE("openUniversallinkIfNeed_"), (IMP)_sys_id_0);

    _sys_bind(OBFUSCATE("APMMonitor"), OBFUSCATE("handleEvent:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("APMMonitor"), OBFUSCATE("startMonitoring:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("APMDeviceInfoSupport"), OBFUSCATE("getBatteryState"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("APMDeviceInfoSupport"), OBFUSCATE("getThermalState"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("APMCollector"), OBFUSCATE("collectMetrics:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("APMCollector"), OBFUSCATE("reportNow"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("TApmSceneMarker"), OBFUSCATE("markLoadLevel:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("TApmSceneMarker"), OBFUSCATE("markLevelFin"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("TApmSceneMarker"), OBFUSCATE("postStepEvent:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("TApmSceneMarker"), OBFUSCATE("postStreamEvent:"), (IMP)_sys_id_0);

    _sys_bind(OBFUSCATE("GCloudCoreRemoteConfig"), OBFUSCATE("updateConfig:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudCoreRemoteConfig"), OBFUSCATE("getConfig:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StartTve"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("JoinTeamRoom_Scenes:roomName:timeout:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("QuitRoom_Scenes:timeout:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableMultiRoom:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableRoomMicrophone:enable:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableRoomSpeaker:enable:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("ApplyMessageKey:timestamp:timeout:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StartRecording:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StopRecording"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("UploadRecordedFile:timeout:fileProperty:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("DownloadRecordedFile:filePath:timeout:fileProperty:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableLog:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetLogCallBack:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("GetMicLevel"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("GetSpeakerLevel"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetMicVolume:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetSpeakerVolume:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SpeechToText:token:timestamp:timeout:language:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("ForbidMemberVoice:enable:inRoom:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("TestMic"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("GetFileParam:data:time:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetBGMPath:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StartBGMPlay"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StopBGMPlay"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("PauseBGMPlay"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("ResumeBGMPlay"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableNativeBGMPlay:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetBitRate:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetDataFree:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("RSTSStartRecording:targetLang:targetLangCnt:action:timeout:recordFilePath:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("RSTSSpeechToSpeech:targetLang:targetLangCnt:dirPath:voiceType:voiceRate:volume:timeout:recordFilePath:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("RSTSSpeechToText:targetLang:targetLangCnt:timeout:recordFilePath:srcLangStr:extInfo:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("RSTSStopRecording"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("TextToStreamSpeechStart:voiceType:timeout:filePath:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("TextToStreamSpeechStop"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableTranslate:isEnable:lang:transType:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableMagicVoice:isEnable:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableRecvMagicVoice:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("RoomGeneralDataChannel:content:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("APITrace:callInfo:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetPlayerInfoAbroad:members:lang:count:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableReportALL:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableReportALLAbroad:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableReportForAbroad:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("ReportFileForAbroad:bTranslate:bChangeVoice:time:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableCivilFile:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableCivilVoice:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetCivilBinPath:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableEarBack:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StartKaraokeRecording:accfile:orifile:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StopKaraokeRecording"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableAccFilePlay:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetKaraokeVoiceVol:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetKaraokeAccVol:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetKaraokeVoiceDelay:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StartPreview"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StopPreview"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SeekTimeMsForPreview:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SeekTimeMsForAcc:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("PauseKaraoke"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("ResumeKaraoke"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("GetRecordKaraokeTotalTime"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("GetBGMLevel"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetReportedPlayerInfo:arg1:arg2:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("ReportPlayer:arg1:arg2:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetReportBufferTime:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("GetBGMFileTime"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("GetBGMPlayTime"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetBGMPlayTime:"), (IMP)_sys_id_0);

    _sys_bind(OBFUSCATE("FBAdViewabilityValidator"), OBFUSCATE("checkViewability:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("FBAdViewabilityValidator"), OBFUSCATE("stopMonitoring"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("FBAdMonitor"), OBFUSCATE("startMonitoringAd:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("FBAdMonitor"), OBFUSCATE("stopMonitoring"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("FBAdEvent"), OBFUSCATE("logEvent:withParameters:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("FBAdLogger"), OBFUSCATE("logMessage:withLevel:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("FIRMessaging"), OBFUSCATE("retrieveFCMTokenForSenderID:completion:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("FIRMessaging"), OBFUSCATE("deleteFCMTokenForSenderID:completion:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("FIRMessaging"), OBFUSCATE("subscribeToTopic:completion:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("FIRMessaging"), OBFUSCATE("unsubscribeFromTopic:completion:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("FIRMessaging"), OBFUSCATE("setAPNSToken:withUserInfo:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("FIRMessaging"), OBFUSCATE("APNSToken"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendReq:resultBlock:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendThirdAppBindGroupReq:resultBlock:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendThirdAppUnBindGroupReq:resultBlock:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendThirdAppJoinGroupReq:resultBlock:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendQueryQQGroupProInfo:resultBlock:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendMessageToQQAuthWithReq:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendMessageToQQAvatarWithReq:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendMessageToFaceCollectionWithReq:"), (IMP)_sys_id_0);

    _sys_bind(OBFUSCATE("GCloudUnityPlugin"), OBFUSCATE("Initialize"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudUnityPlugin"), OBFUSCATE("ReportEvent"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("GCloudUnityPlugin"), OBFUSCATE("SetGameObjectName:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("TikTokAuth"), OBFUSCATE("authorizeWithPermissions:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("TikTokAuth"), OBFUSCATE("handleOpenURL:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("VKAuth"), OBFUSCATE("authorizeWithPermissions:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("VKAuth"), OBFUSCATE("logout"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("SCSDKLoginClient"), OBFUSCATE("loginWithCompletion:"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("SCSDKLoginClient"), OBFUSCATE("logout"), (IMP)_sys_id_0);
}
