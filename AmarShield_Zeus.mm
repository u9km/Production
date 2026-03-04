#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

// --- [ الجزء الأول: تقنية التشفير الشبحية 2026 (Compile-Time String Obfuscation) ] ---

namespace AmmarShield {
    // توليد مفتاح عشوائي وقت الترجمة بناءً على الوقت والعداد
    constexpr int seed_gen(int counter) {
        return (__TIME__[7] - '0') * 1 + (__TIME__[6] - '0') * 10 +
               (__TIME__[4] - '0') * 60 + (__TIME__[3] - '0') * 600 +
               (__TIME__[1] - '0') * 3600 + (__TIME__[0] - '0') * 36000 + counter;
    }

    template <unsigned int N, int K>
    struct Obfuscator {
        char data[N];

        // التشفير وقت الترجمة (XOR + إزاحة)
        constexpr Obfuscator(const char* str) : data{0} {
            for (unsigned int i = 0; i < N; ++i) {
                char c = str[i];
                data[i] = (c ^ K) + (K % 10); 
            }
        }

        // فك التشفير وقت التشغيل (مخفي برمجياً في الذاكرة فقط)
        __attribute__((always_inline)) const char* decrypt() {
            for (unsigned int i = 0; i < N; ++i) {
                data[i] = (data[i] - (K % 10)) ^ K;
            }
            return data;
        }
    };
}

// الماكرو السحري لتشفير النصوص
#define OBFUSCATE(str) (AmmarShield::Obfuscator<sizeof(str), AmmarShield::seed_gen(__COUNTER__)>(str).decrypt())


// --- [ الجزء الثاني: محرك الربط الشبح (مخفي عن جدول الرموز) ] ---
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


// --- [ الجزء الثالث: الدوال الوهمية المركزية (بدون أسماء مريبة) ] ---
__attribute__((visibility("hidden"))) id _sys_id_0(id self, SEL _cmd, ...) { return 0; }
__attribute__((visibility("hidden"))) BOOL _sys_bool_no(id self, SEL _cmd, ...) { return NO; }
__attribute__((visibility("hidden"))) BOOL _sys_bool_yes(id self, SEL _cmd, ...) { return YES; }
__attribute__((visibility("hidden"))) void _sys_void_empty(id self, SEL _cmd, ...) { }


// --- [ الجزء الرابع: المحرك الرئيسي لتفعيل كل المسارات المشفرة ] ---
__attribute__((constructor))
static void _init_core_services() {

    // --- حماية السيرفر والضرر ---
    _sys_bind(OBFUSCATE("serviceCommunication"), OBFUSCATE("getValueForKeypath"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("WeaponProcessor"), OBFUSCATE("CalculateDamage"), (IMP)_sys_id_0);
    _sys_bind(OBFUSCATE("CharacterMovement"), OBFUSCATE("IsSpeedExceeded"), (IMP)_sys_bool_no);
    _sys_bind(OBFUSCATE("NetworkManager"), OBFUSCATE("SendSecurityReport"), (IMP)_sys_void_empty);
    _sys_bind(OBFUSCATE("SecurityChecker"), OBFUSCATE("IsFileSystemModified"), (IMP)_sys_bool_no);
    _sys_bind(OBFUSCATE("BulletSimulator"), OBFUSCATE("CheckWallCollision"), (IMP)_sys_id_0);

    // --- دوال GSDK و Ping والشبكة ---
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

    // --- حماية APM ومراقبة الأداء ---
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

    // --- حماية GCloud بالكامل ---
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

    // --- حماية Facebook Ads و Firebase و Tencent ---
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

    // --- حماية Unity و TikTok و VK و SnapChat ---
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
