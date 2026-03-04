#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

// --- [ الجزء الأول: محرك الربط الشبح (مخفي عن جدول الرموز) ] ---
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

// --- [ الجزء الثاني: الدوال الوهمية المركزية (بدون أسماء مريبة) ] ---
__attribute__((visibility("hidden"))) id _sys_id_0(id self, SEL _cmd, ...) { return 0; }
__attribute__((visibility("hidden"))) BOOL _sys_bool_no(id self, SEL _cmd, ...) { return NO; }
__attribute__((visibility("hidden"))) BOOL _sys_bool_yes(id self, SEL _cmd, ...) { return YES; }
__attribute__((visibility("hidden"))) void _sys_void_empty(id self, SEL _cmd, ...) { }

// --- [ الجزء الثالث: المحرك الرئيسي لتفعيل كل المسارات بالكامل ] ---
__attribute__((constructor))
static void _init_core_services() {

    // --- حماية السيرفر والضرر ---
    _sys_bind("serviceCommunication", 
              "getValueForKeypath", 
              (IMP)_sys_id_0);

    _sys_bind("WeaponProcessor", 
              "CalculateDamage", 
              (IMP)_sys_id_0);

    _sys_bind("CharacterMovement", 
              "IsSpeedExceeded", 
              (IMP)_sys_bool_no);

    _sys_bind("NetworkManager", 
              "SendSecurityReport", 
              (IMP)_sys_void_empty);

    _sys_bind("SecurityChecker", 
              "IsFileSystemModified", 
              (IMP)_sys_bool_no);

    _sys_bind("BulletSimulator", 
              "CheckWallCollision", 
              (IMP)_sys_id_0);

    _sys_bind("serviceCommunication", 
              "getValueForKeypath", 
              (IMP)_sys_id_0);

    // --- دوال GSDK و Ping والشبكة ---
    _sys_bind("AReachability", 
              "isConnectionOnDemand", 
              (IMP)_sys_bool_yes);

    _sys_bind("AReachability", 
              "isConnectionRequired", 
              (IMP)_sys_bool_yes);

    _sys_bind("AudioDeviceMgr", 
              "GetAudioDeviceConnectState", 
              (IMP)_sys_id_0);

    _sys_bind("AudioDeviceMgr", 
              "UpdateDeviceState_", 
              (IMP)_sys_id_0);

    _sys_bind("FIRMessagingRmqManager", 
              "openDatabase", 
              (IMP)_sys_id_0);

    _sys_bind("GADAdNetworkResponseInfo", 
              "adUnitMapping", 
              (IMP)_sys_id_0);

    _sys_bind("GADAppOpenAd_ad", 
              "didFailToPresentFullScreenContentWithError_", 
              (IMP)_sys_id_0);

    _sys_bind("GADAppOpenAd", 
              "adDidDismissFullScreenContent_", 
              (IMP)_sys_bool_yes);

    _sys_bind("GADAppOpenAd", 
              "adDidRecordClick_", 
              (IMP)_sys_id_0);

    _sys_bind("GADAppOpenAd", 
              "adDidRecordImpression_", 
              (IMP)_sys_id_0);

    _sys_bind("GADAppOpenAd", 
              "adWillDismissFullScreenContent_", 
              (IMP)_sys_bool_yes);

    _sys_bind("GADAppOpenAd", 
              "adWillPresentFullScreenContent_", 
              (IMP)_sys_id_0);

    _sys_bind("GADAppOpenAd_canPresentFromRootViewController", 
              "error_", 
              (IMP)_sys_id_0);

    _sys_bind("GADAppOpenAd", 
              "responseInfo", 
              (IMP)_sys_id_0);

    _sys_bind("GADAppOpenAd", 
              "setPaidEventHandler_", 
              (IMP)_sys_id_0);

    _sys_bind("GADMobileAds", 
              "initializationStatus", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKCPU", 
              "getSystemCPUCircle", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKDetectPort_isConnection", 
              "Port_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKHttpDnsResolver", 
              "dealloc", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKHttpRequest", 
              "dealloc", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKHttpRequest_requestControl_Openid_Acctype_Zoneid", 
              "Env_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKInGameManager", 
              "GSDKRealTimeDetect", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKInGameSystem", 
              "GSDKInnerEnd", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKInGameSystem", 
              "GSDKInnerRealTimeDetect", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKInGameSystem_GSDKInnerSaveFPS", 
              "FpsDots_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKInGameSystem_GSDKInnerStart_SceneID", 
              "RoomIP_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKInitManager", 
              "detectOperation_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKMemory", 
              "getSystemAvailableMemory", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPayEvent_GSDKPay_Tag_Status", 
              "Msg_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPing", 
              "dealloc", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPing", 
              "ping", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPing_simplePing_didFailToSendPacket_sequenceNumber", 
              "error_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPing_simplePing", 
              "didFailWithError_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPing_simplePing_didReceivePingResponsePacket", 
              "sequenceNumber_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPing_simplePing", 
              "didReceiveUnexpectedPacket_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPing_simplePing_didSendPacket", 
              "sequenceNumber_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPing_simplePing", 
              "didStartWithAddress_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPing", 
              "stopPing", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPingDetect", 
              "dealloc", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPingDetect", 
              "ping", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPingDetect_simplePing_didFailToSendPacket_sequenceNumber", 
              "error_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPingDetect_simplePing", 
              "didFailWithError_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPingDetect_simplePing_didReceivePingResponsePacket", 
              "sequenceNumber_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPingDetect_simplePing", 
              "didReceiveUnexpectedPacket_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPingDetect_simplePing_didSendPacket", 
              "sequenceNumber_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKPingDetect_simplePing", 
              "didStartWithAddress_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKRealTimeDetect", 
              "pingDelayDetect_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKRealTimeDetect_updDelayDetect", 
              "Port_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKUdpDetect_isUDPConnect", 
              "Port_", 
              (IMP)_sys_id_0);

    _sys_bind("GSDKWIFI", 
              "ping_", 
              (IMP)_sys_id_0);

    _sys_bind("GTMSessionFetcher_setSystemCompletionHandler", 
              "forSessionIdentifier_", 
              (IMP)_sys_id_0);

    _sys_bind("GVGCloudVoice", 
              "openMic", 
              (IMP)_sys_id_0);

    _sys_bind("GVGCloudVoice", 
              "openSpeaker", 
              (IMP)_sys_id_0);

    _sys_bind("GVGCloudVoice_setAppInfo_withKey", 
              "andOpenID_", 
              (IMP)_sys_id_0);

    _sys_bind("GVGCloudVoiceExtension", 
              "CheckDeviceMuteStat", 
              (IMP)_sys_bool_yes);

    _sys_bind("GVGCloudVoiceExtension", 
              "EnableKeyWordsDetect_", 
              (IMP)_sys_id_0);

    _sys_bind("GVGCloudVoiceExtension", 
              "GetBGMPlayState", 
              (IMP)_sys_id_0);

    _sys_bind("GVGCloudVoiceExtension", 
              "GetMicState", 
              (IMP)_sys_id_0);

    _sys_bind("GVGCloudVoiceExtension", 
              "GetSpeakerState", 
              (IMP)_sys_id_0);

    _sys_bind("GVoiceMuteSwitch", 
              "detectMuteSwitch", 
              (IMP)_sys_id_0);

    _sys_bind("IMSDKCustomWebView", 
              "dealloc", 
              (IMP)_sys_id_0);

    _sys_bind("IMSDKNoticeIMSDKManager_getImageCache_imagePath_imageHash_queue", 
              "completeHandle_", 
              (IMP)_sys_id_0);

    _sys_bind("IMSDKNoticeIMSDKManager", 
              "imsdkCoreKitNoticeImageFileHash_", 
              (IMP)_sys_id_0);

    _sys_bind("IMSDKStatAdjustManager_reportEvent_eventBody", 
              "isRealtime_", 
              (IMP)_sys_bool_yes);

    _sys_bind("IMSDKStatAdjustManager_reportEvent_params", 
              "isRealtime_", 
              (IMP)_sys_bool_yes);

    _sys_bind("IMSDKStatAdjustManager_reportPurchase_currentCode_expense", 
              "isRealTime_", 
              (IMP)_sys_bool_yes);

    _sys_bind("IMSDKStatAdjustManager_reportRevenue_currencyCode_revenueValue_params", 
              "extraJson_", 
              (IMP)_sys_id_0);

    _sys_bind("INTLWebViewManager_openURL_observerID", 
              "baseParams_", 
              (IMP)_sys_id_0);

    _sys_bind("PingDelegate", 
              "pingTimer", 
              (IMP)_sys_id_0);

    _sys_bind("PingDelegate_simplePing_didFailToSendPacket_sequenceNumber", 
              "error_", 
              (IMP)_sys_id_0);

    _sys_bind("PingDelegate_simplePing_didSendPacket", 
              "sequenceNumber_", 
              (IMP)_sys_id_0);

    _sys_bind("QQOpenApiUtility", 
              "cgiRequestGetSdkConfig_", 
              (IMP)_sys_id_0);

    _sys_bind("SimplePing", 
              "dealloc", 
              (IMP)_sys_id_0);

    _sys_bind("SimplePing", 
              "didFailWithError_", 
              (IMP)_sys_id_0);

    _sys_bind("SimplePing_pingPacketWithType_payload", 
              "requiresChecksum_", 
              (IMP)_sys_bool_yes);

    _sys_bind("SimplePing", 
              "readData", 
              (IMP)_sys_id_0);

    _sys_bind("SimplePing", 
              "sendPingWithData_", 
              (IMP)_sys_id_0);

    _sys_bind("SimplePing", 
              "start", 
              (IMP)_sys_id_0);

    _sys_bind("SimplePing", 
              "startWithHostAddress", 
              (IMP)_sys_id_0);

    _sys_bind("SimplePing_validatePingResponsePacket", 
              "sequenceNumber_", 
              (IMP)_sys_id_0);

    _sys_bind("TDataMasterApplication", 
              "handleOpenURL_", 
              (IMP)_sys_id_0);

    _sys_bind("TDataMasterApplication_reportEventWithSrcID_eventName", 
              "AndEventKVArray_", 
              (IMP)_sys_id_0);

    _sys_bind("TcApiTool", 
              "openUniversallinkIfNeed_", 
              (IMP)_sys_id_0);

    // --- حماية APM ومراقبة الأداء ---
    _sys_bind("APMMonitor", 
              "handleEvent:", 
              (IMP)_sys_id_0);

    _sys_bind("APMMonitor", 
              "startMonitoring:", 
              (IMP)_sys_id_0);

    _sys_bind("APMDeviceInfoSupport", 
              "getBatteryState", 
              (IMP)_sys_id_0);

    _sys_bind("APMDeviceInfoSupport", 
              "getThermalState", 
              (IMP)_sys_id_0);

    _sys_bind("APMCollector", 
              "collectMetrics:", 
              (IMP)_sys_id_0);

    _sys_bind("APMCollector", 
              "reportNow", 
              (IMP)_sys_id_0);

    _sys_bind("TApmSceneMarker", 
              "markLoadLevel:", 
              (IMP)_sys_id_0);

    _sys_bind("TApmSceneMarker", 
              "markLevelFin", 
              (IMP)_sys_id_0);

    _sys_bind("TApmSceneMarker", 
              "postStepEvent:", 
              (IMP)_sys_id_0);

    _sys_bind("TApmSceneMarker", 
              "postStreamEvent:", 
              (IMP)_sys_id_0);

    // --- حماية GCloud بالكامل ---
    _sys_bind("GCloudCoreRemoteConfig", 
              "updateConfig:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudCoreRemoteConfig", 
              "getConfig:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "StartTve", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "JoinTeamRoom_Scenes:roomName:timeout:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "QuitRoom_Scenes:timeout:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "EnableMultiRoom:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "EnableRoomMicrophone:enable:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "EnableRoomSpeaker:enable:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "ApplyMessageKey:timestamp:timeout:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "StartRecording:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "StopRecording", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "UploadRecordedFile:timeout:fileProperty:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "DownloadRecordedFile:filePath:timeout:fileProperty:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "EnableLog:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "SetLogCallBack:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "GetMicLevel", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "GetSpeakerLevel", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "SetMicVolume:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "SetSpeakerVolume:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "SpeechToText:token:timestamp:timeout:language:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "ForbidMemberVoice:enable:inRoom:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "TestMic", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "GetFileParam:data:time:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "SetBGMPath:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "StartBGMPlay", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "StopBGMPlay", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "PauseBGMPlay", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "ResumeBGMPlay", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "EnableNativeBGMPlay:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "SetBitRate:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "SetDataFree:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "RSTSStartRecording:targetLang:targetLangCnt:action:timeout:recordFilePath:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "RSTSSpeechToSpeech:targetLang:targetLangCnt:dirPath:voiceType:voiceRate:volume:timeout:recordFilePath:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "RSTSSpeechToText:targetLang:targetLangCnt:timeout:recordFilePath:srcLangStr:extInfo:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "RSTSStopRecording", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "TextToStreamSpeechStart:voiceType:timeout:filePath:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "TextToStreamSpeechStop", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "EnableTranslate:isEnable:lang:transType:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "EnableMagicVoice:isEnable:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "EnableRecvMagicVoice:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "RoomGeneralDataChannel:content:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "APITrace:callInfo:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "SetPlayerInfoAbroad:members:lang:count:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "EnableReportALL:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "EnableReportALLAbroad:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "EnableReportForAbroad:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "ReportFileForAbroad:bTranslate:bChangeVoice:time:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "EnableCivilFile:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "EnableCivilVoice:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "SetCivilBinPath:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "EnableEarBack:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "StartKaraokeRecording:accfile:orifile:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "StopKaraokeRecording", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "EnableAccFilePlay:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "SetKaraokeVoiceVol:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "SetKaraokeAccVol:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "SetKaraokeVoiceDelay:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "StartPreview", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "StopPreview", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "SeekTimeMsForPreview:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "SeekTimeMsForAcc:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "PauseKaraoke", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "ResumeKaraoke", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "GetRecordKaraokeTotalTime", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "GetBGMLevel", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "SetReportedPlayerInfo:arg1:arg2:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "ReportPlayer:arg1:arg2:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "SetReportBufferTime:", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "GetBGMFileTime", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "GetBGMPlayTime", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudVoiceEngine", 
              "SetBGMPlayTime:", 
              (IMP)_sys_id_0);

    // --- حماية Facebook Ads و Firebase و Tencent ---
    _sys_bind("FBAdViewabilityValidator", 
              "checkViewability:", 
              (IMP)_sys_id_0);

    _sys_bind("FBAdViewabilityValidator", 
              "stopMonitoring", 
              (IMP)_sys_id_0);

    _sys_bind("FBAdMonitor", 
              "startMonitoringAd:", 
              (IMP)_sys_id_0);

    _sys_bind("FBAdMonitor", 
              "stopMonitoring", 
              (IMP)_sys_id_0);

    _sys_bind("FBAdEvent", 
              "logEvent:withParameters:", 
              (IMP)_sys_id_0);

    _sys_bind("FBAdLogger", 
              "logMessage:withLevel:", 
              (IMP)_sys_id_0);

    _sys_bind("FIRMessaging", 
              "retrieveFCMTokenForSenderID:completion:", 
              (IMP)_sys_id_0);

    _sys_bind("FIRMessaging", 
              "deleteFCMTokenForSenderID:completion:", 
              (IMP)_sys_id_0);

    _sys_bind("FIRMessaging", 
              "subscribeToTopic:completion:", 
              (IMP)_sys_id_0);

    _sys_bind("FIRMessaging", 
              "unsubscribeFromTopic:completion:", 
              (IMP)_sys_id_0);

    _sys_bind("FIRMessaging", 
              "setAPNSToken:withUserInfo:", 
              (IMP)_sys_id_0);

    _sys_bind("FIRMessaging", 
              "APNSToken", 
              (IMP)_sys_id_0);

    _sys_bind("QQApiInterface", 
              "sendReq:resultBlock:", 
              (IMP)_sys_id_0);

    _sys_bind("QQApiInterface", 
              "sendThirdAppBindGroupReq:resultBlock:", 
              (IMP)_sys_id_0);

    _sys_bind("QQApiInterface", 
              "sendThirdAppUnBindGroupReq:resultBlock:", 
              (IMP)_sys_id_0);

    _sys_bind("QQApiInterface", 
              "sendThirdAppJoinGroupReq:resultBlock:", 
              (IMP)_sys_id_0);

    _sys_bind("QQApiInterface", 
              "sendQueryQQGroupProInfo:resultBlock:", 
              (IMP)_sys_id_0);

    _sys_bind("QQApiInterface", 
              "sendMessageToQQAuthWithReq:", 
              (IMP)_sys_id_0);

    _sys_bind("QQApiInterface", 
              "sendMessageToQQAvatarWithReq:", 
              (IMP)_sys_id_0);

    _sys_bind("QQApiInterface", 
              "sendMessageToFaceCollectionWithReq:", 
              (IMP)_sys_id_0);

    // --- حماية Unity و TikTok و VK و SnapChat ---
    _sys_bind("GCloudUnityPlugin", 
              "Initialize", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudUnityPlugin", 
              "ReportEvent", 
              (IMP)_sys_id_0);

    _sys_bind("GCloudUnityPlugin", 
              "SetGameObjectName:", 
              (IMP)_sys_id_0);

    _sys_bind("TikTokAuth", 
              "authorizeWithPermissions:", 
              (IMP)_sys_id_0);

    _sys_bind("TikTokAuth", 
              "handleOpenURL:", 
              (IMP)_sys_id_0);

    _sys_bind("VKAuth", 
              "authorizeWithPermissions:", 
              (IMP)_sys_id_0);

    _sys_bind("VKAuth", 
              "logout", 
              (IMP)_sys_id_0);

    _sys_bind("SCSDKLoginClient", 
              "loginWithCompletion:", 
              (IMP)_sys_id_0);

    _sys_bind("SCSDKLoginClient", 
              "logout", 
              (IMP)_sys_id_0);
}
