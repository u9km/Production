#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <UIKit/UIKit.h>
#include <sys/sysctl.h>
#include <dlfcn.h>
#include <vector>
#include <random>
#include <chrono>
#include <mach-o/dyld.h>

// =================================================================
// [ نظام الربط الصامت لـ Dobby ]
// =================================================================
extern "C" int DobbyHook(void *address, void *replace_call, void **origin_call);

// =================================================================
// [ محرك التشفير الجيني للنصوص ]
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
// [ محرك السلوك البشري الإحصائي (Telemetry ML Evasion) ]
// =================================================================
struct Vector2D { float x, y; };
class AmmarTelemetrySpoofer {
private:
    std::mt19937 rng;
public:
    AmmarTelemetrySpoofer() { rng.seed(std::chrono::high_resolution_clock::now().time_since_epoch().count()); }
    Vector2D Humanize(Vector2D target) {
        std::normal_distribution<float> dist(0, 0.4f);
        return { target.x + dist(rng), target.y + dist(rng) };
    }
};
static AmmarTelemetrySpoofer* GlobalSpoofer = nullptr;

// =================================================================
// [ واجهة API الديناميكية الموحدة ]
// =================================================================
namespace API {
    typedef int (*strcmp_t)(const char*, const char*);
    typedef Class (*objc_getClass_t)(const char*);
    typedef SEL (*sel_registerName_t)(const char*);
    typedef Method (*class_getInstanceMethod_t)(Class, SEL);
    typedef IMP (*class_replaceMethod_t)(Class, SEL, IMP, const char*);

    static strcmp_t sys_strcmp = nullptr;
    static objc_getClass_t sys_objc_getClass = nullptr;
    static sel_registerName_t sys_sel_registerName = nullptr;
    static class_getInstanceMethod_t sys_class_getInstanceMethod = nullptr;
    static class_replaceMethod_t sys_class_replaceMethod = nullptr;

    static bool Init() {
        void* h = RTLD_DEFAULT;
        sys_strcmp = (strcmp_t)dlsym(h, OBFUSCATE("strcmp"));
        sys_objc_getClass = (objc_getClass_t)dlsym(h, OBFUSCATE("objc_getClass"));
        sys_sel_registerName = (sel_registerName_t)dlsym(h, OBFUSCATE("sel_registerName"));
        sys_class_getInstanceMethod = (class_getInstanceMethod_t)dlsym(h, OBFUSCATE("class_getInstanceMethod"));
        sys_class_replaceMethod = (class_replaceMethod_t)dlsym(h, OBFUSCATE("class_replaceMethod"));
        return (sys_strcmp && sys_objc_getClass && sys_sel_registerName);
    }
}

// =================================================================
// [ دوال الأشباح (Phantom Functions) لمنع الـ Crash ]
// تمت إضافة unused لمنع المترجم من إيقاف البناء إذا لم نستخدم الدالة
// =================================================================
__attribute__((visibility("hidden"), unused)) static void _dummy_void(id self, SEL _cmd, ...) {}
__attribute__((visibility("hidden"), unused)) static BOOL _dummy_bool_no(id self, SEL _cmd, ...) { return NO; }
__attribute__((visibility("hidden"), unused)) static BOOL _dummy_bool_yes(id self, SEL _cmd, ...) { return YES; }
__attribute__((visibility("hidden"), unused)) static int  _dummy_int_0(id self, SEL _cmd, ...) { return 0; }
__attribute__((visibility("hidden"), unused)) static int  _dummy_int_1(id self, SEL _cmd, ...) { return 1; }
__attribute__((visibility("hidden"), unused)) static int  _dummy_int_1024(id self, SEL _cmd, ...) { return 1024; }
__attribute__((visibility("hidden"), unused)) static id   _dummy_id_nil(id self, SEL _cmd, ...) { return nil; }

// =================================================================
// [ الرابط الآمن لمنع انهيار الذاكرة ]
// =================================================================
__attribute__((visibility("hidden")))
static void _safe_bind(const char* cls, const char* sel, IMP imp) {
    Class c = API::sys_objc_getClass(cls);
    if (!c) return;
    SEL s = API::sys_sel_registerName(sel);
    Method m = API::sys_class_getInstanceMethod(c, s);
    if (m && API::sys_class_replaceMethod) {
        API::sys_class_replaceMethod(c, s, imp, method_getTypeEncoding(m));
    }
}

// =================================================================
// [ هوك الحماية الأساسي - تفادي P_TRACED ]
// =================================================================
static int (*orig_sysctl)(int *n, u_int nl, void *op, size_t *ol, void *np, size_t nl2);
int my_sysctl(int *n, u_int nl, void *op, size_t *ol, void *np, size_t nl2) {
    int r = orig_sysctl(n, nl, op, ol, np, nl2);
    if (r == 0 && n && nl >= 3 && n[0] == 1 && n[1] == 14 && n[2] == getpid()) {
        if (op) ((struct kinfo_proc *)op)->kp_proc.p_flag &= ~0x00000800;
    }
    return r;
}

// =================================================================
// [ الإقلاع السيادي - الكتيبة الكاملة (159 مسار) ]
// =================================================================
__attribute__((constructor))
static void Ignite_Ammar_Zeus_Full_Arsenal() {
    if (!API::Init()) return;
    
    // تهيئة محرك السلوك البشري
    GlobalSpoofer = new AmmarTelemetrySpoofer();

    // هوك Sysctl عبر Dobby
    void* s_ptr = dlsym(RTLD_DEFAULT, OBFUSCATE("sysctl"));
    if (s_ptr) DobbyHook(s_ptr, (void*)my_sysctl, (void**)&orig_sysctl);

    // -----------------------------------------------------------------
    // [1] كتيبة الأمن الأساسي واكتشاف الهاكات (Core Security & GSDK)
    // -----------------------------------------------------------------
    _safe_bind(OBFUSCATE("SecurityChecker"), OBFUSCATE("IsFileSystemModified"), (IMP)_dummy_bool_no);
    _safe_bind(OBFUSCATE("SecurityChecker"), OBFUSCATE("isJailbroken"), (IMP)_dummy_bool_no);
    _safe_bind(OBFUSCATE("SecurityChecker"), OBFUSCATE("checkDylibs"), (IMP)_dummy_bool_no);
    _safe_bind(OBFUSCATE("GSDKInGameManager"), OBFUSCATE("GSDKRealTimeDetect"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GSDKInGameSystem"), OBFUSCATE("GSDKInnerRealTimeDetect"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GSDKInGameSystem"), OBFUSCATE("GSDKInnerEnd"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GSDKInitManager"), OBFUSCATE("detectOperation_"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GSDKCPU"), OBFUSCATE("getSystemCPUCircle"), (IMP)_dummy_int_0);
    _safe_bind(OBFUSCATE("GSDKMemory"), OBFUSCATE("getSystemAvailableMemory"), (IMP)_dummy_int_1024);
    _safe_bind(OBFUSCATE("GSDKDetectPort_isConnection"), OBFUSCATE("Port_"), (IMP)_dummy_bool_no);
    _safe_bind(OBFUSCATE("serviceCommunication"), OBFUSCATE("getValueForKeypath"), (IMP)_dummy_id_nil);
    _safe_bind(OBFUSCATE("NetworkManager"), OBFUSCATE("SendSecurityReport"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GSDKInGameSystem_GSDKInnerSaveFPS"), OBFUSCATE("FpsDots_"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GSDKInGameSystem_GSDKInnerStart_SceneID"), OBFUSCATE("RoomIP_"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GSDKPayEvent_GSDKPay_Tag_Status"), OBFUSCATE("Msg_"), (IMP)_dummy_void);

    // -----------------------------------------------------------------
    // [2] كتيبة المراقبة والأداء (APM Monitoring)
    // -----------------------------------------------------------------
    _safe_bind(OBFUSCATE("APMMonitor"), OBFUSCATE("startMonitoring:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("APMMonitor"), OBFUSCATE("handleEvent:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("APMCollector"), OBFUSCATE("collectMetrics:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("APMCollector"), OBFUSCATE("reportNow"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("TApmSceneMarker"), OBFUSCATE("markLoadLevel:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("TApmSceneMarker"), OBFUSCATE("markLevelFin"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("TApmSceneMarker"), OBFUSCATE("postStepEvent:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("TApmSceneMarker"), OBFUSCATE("postStreamEvent:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("APMDeviceInfoSupport"), OBFUSCATE("getBatteryState"), (IMP)_dummy_int_1);
    _safe_bind(OBFUSCATE("APMDeviceInfoSupport"), OBFUSCATE("getThermalState"), (IMP)_dummy_int_0);

    // -----------------------------------------------------------------
    // [3] كتيبة محرك الصوت والاستخبارات (GCloud Voice Engine)
    // -----------------------------------------------------------------
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableLog:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("APITrace:callInfo:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StartTve"), (IMP)_dummy_int_0);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableMultiRoom:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableRoomMicrophone:enable:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableRoomSpeaker:enable:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StartRecording:"), (IMP)_dummy_int_0);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("StopRecording"), (IMP)_dummy_int_0);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetLogCallBack:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("GetMicLevel"), (IMP)_dummy_int_0);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("GetSpeakerLevel"), (IMP)_dummy_int_0);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetMicVolume:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetSpeakerVolume:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("TestMic"), (IMP)_dummy_int_0);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableReportALL:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableReportALLAbroad:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("EnableReportForAbroad:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("ReportPlayer:arg1:arg2:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GCloudVoiceEngine"), OBFUSCATE("SetReportBufferTime:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GCloudVoiceExtension"), OBFUSCATE("CheckDeviceMuteStat"), (IMP)_dummy_bool_no);
    _safe_bind(OBFUSCATE("GCloudVoiceExtension"), OBFUSCATE("EnableKeyWordsDetect_"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GCloudVoiceExtension"), OBFUSCATE("GetBGMPlayState"), (IMP)_dummy_int_0);
    _safe_bind(OBFUSCATE("GCloudVoiceExtension"), OBFUSCATE("GetMicState"), (IMP)_dummy_int_0);
    _safe_bind(OBFUSCATE("GCloudVoiceExtension"), OBFUSCATE("GetSpeakerState"), (IMP)_dummy_int_0);
    _safe_bind(OBFUSCATE("GVoiceMuteSwitch"), OBFUSCATE("detectMuteSwitch"), (IMP)_dummy_bool_no);
    _safe_bind(OBFUSCATE("AudioDeviceMgr"), OBFUSCATE("GetAudioDeviceConnectState"), (IMP)_dummy_int_1);
    _safe_bind(OBFUSCATE("AudioDeviceMgr"), OBFUSCATE("UpdateDeviceState_"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GVGCloudVoice"), OBFUSCATE("openMic"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GVGCloudVoice"), OBFUSCATE("openSpeaker"), (IMP)_dummy_void);

    // -----------------------------------------------------------------
    // [4] كتيبة رصد الشبكة والـ Ping
    // -----------------------------------------------------------------
    _safe_bind(OBFUSCATE("GSDKPing"), OBFUSCATE("ping"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GSDKPing"), OBFUSCATE("stopPing"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GSDKPing"), OBFUSCATE("dealloc"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GSDKPingDetect"), OBFUSCATE("ping"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GSDKPingDetect"), OBFUSCATE("dealloc"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GSDKRealTimeDetect"), OBFUSCATE("pingDelayDetect_"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GSDKRealTimeDetect_updDelayDetect"), OBFUSCATE("Port_"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GSDKUdpDetect_isUDPConnect"), OBFUSCATE("Port_"), (IMP)_dummy_bool_no);
    _safe_bind(OBFUSCATE("GSDKWIFI"), OBFUSCATE("ping_"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("SimplePing"), OBFUSCATE("start"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("SimplePing"), OBFUSCATE("stop"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("SimplePing"), OBFUSCATE("sendPingWithData_"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("PingDelegate"), OBFUSCATE("pingTimer"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("AReachability"), OBFUSCATE("isConnectionRequired"), (IMP)_dummy_bool_no);
    _safe_bind(OBFUSCATE("AReachability"), OBFUSCATE("isConnectionOnDemand"), (IMP)_dummy_bool_no);

    // -----------------------------------------------------------------
    // [5] كتيبة الإحصائيات (IMSDK, Tencent, Firebase)
    // -----------------------------------------------------------------
    _safe_bind(OBFUSCATE("IMSDKStatAdjustManager"), OBFUSCATE("reportEvent_eventBody"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("IMSDKStatAdjustManager"), OBFUSCATE("reportEvent_params"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("IMSDKStatAdjustManager"), OBFUSCATE("reportPurchase_currentCode_expense"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("IMSDKStatAdjustManager"), OBFUSCATE("reportRevenue_currencyCode_revenueValue_params"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("TDataMasterApplication"), OBFUSCATE("reportEventWithSrcID_eventName"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("IMSDKNoticeIMSDKManager"), OBFUSCATE("imsdkCoreKitNoticeImageFileHash_"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("INTLWebViewManager_openURL_observerID"), OBFUSCATE("baseParams_"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("FIRMessaging"), OBFUSCATE("retrieveFCMTokenForSenderID:completion:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("FIRMessaging"), OBFUSCATE("deleteFCMTokenForSenderID:completion:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("FIRMessaging"), OBFUSCATE("subscribeToTopic:completion:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("FIRMessaging"), OBFUSCATE("setAPNSToken:withUserInfo:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("FIRMessagingRmqManager"), OBFUSCATE("openDatabase"), (IMP)_dummy_void);

    // -----------------------------------------------------------------
    // [6] كتيبة الإعلانات والتواصل الاجتماعي (Social & Ads)
    // -----------------------------------------------------------------
    _safe_bind(OBFUSCATE("FBAdViewabilityValidator"), OBFUSCATE("checkViewability:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("FBAdViewabilityValidator"), OBFUSCATE("stopMonitoring"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("FBAdMonitor"), OBFUSCATE("startMonitoringAd:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("FBAdMonitor"), OBFUSCATE("stopMonitoring"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("FBAdEvent"), OBFUSCATE("logEvent:withParameters:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("FBAdLogger"), OBFUSCATE("logMessage:withLevel:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GADMobileAds"), OBFUSCATE("initializationStatus"), (IMP)_dummy_int_1);
    _safe_bind(OBFUSCATE("GADAppOpenAd"), OBFUSCATE("adDidRecordClick_"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GADAppOpenAd"), OBFUSCATE("adDidRecordImpression_"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GADAppOpenAd"), OBFUSCATE("setPaidEventHandler_"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendReq:resultBlock:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendThirdAppBindGroupReq:resultBlock:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("QQApiInterface"), OBFUSCATE("sendQueryQQGroupProInfo:resultBlock:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("QQOpenApiUtility"), OBFUSCATE("cgiRequestGetSdkConfig_"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GCloudUnityPlugin"), OBFUSCATE("Initialize"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("GCloudUnityPlugin"), OBFUSCATE("ReportEvent"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("TikTokAuth"), OBFUSCATE("authorizeWithPermissions:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("VKAuth"), OBFUSCATE("authorizeWithPermissions:"), (IMP)_dummy_void);
    _safe_bind(OBFUSCATE("SCSDKLoginClient"), OBFUSCATE("loginWithCompletion:"), (IMP)_dummy_void);
}
