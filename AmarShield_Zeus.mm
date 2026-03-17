// ============================================================================
// [0] ZEUS APEX ELITE - 2026 (PURE MACH EXCEPTION ENGINE - ZERO DOBBY)
// ============================================================================
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdint.h>
#include <pthread.h>
#include <sys/mman.h>
#include <sys/sysctl.h>
#include <sys/ptrace.h>
#include <sys/utsname.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <mach/task.h>
#include <mach/mach_port.h>
#include <mach/thread_act.h>
#include <mach/thread_status.h>
#include <mach-o/dyld.h>
#include <TargetConditionals.h>
#include <time.h>

#if TARGET_OS_IPHONE
#import <objc/runtime.h>
#import <objc/message.h>
#import <LocalAuthentication/LocalAuthentication.h>
#endif

#include <CommonCrypto/CommonCryptor.h>
#include <Security/Security.h>

extern "C" void sys_icache_invalidate(void *start, size_t len);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmodule-import-in-extern-c"
#include <openssl/rsa.h>
#include <openssl/x509.h>
#include <openssl/evp.h>
#include <openssl/ssl.h>
#pragma clang diagnostic pop

// ============================================================================
// [1] Compile-Time XOR String Obfuscator (Ghost Strings)
// ============================================================================
template <size_t N>
struct XorString {
    char data[N];
    constexpr XorString(const char* str, char key) : data{0} {
        for (size_t i = 0; i < N; ++i) data[i] = str[i] ^ key;
    }
};

#define OBF(str) \
    ([]() -> char* { \
        constexpr char key = 0x3F; \
        constexpr XorString<sizeof(str)> xs(str, key); \
        static char decrypted[sizeof(str)]; \
        static bool init = false; \
        if (!init) { \
            for (size_t i = 0; i < sizeof(str); ++i) decrypted[i] = xs.data[i] ^ key; \
            init = true; \
        } \
        return decrypted; \
    }())

// ============================================================================
// [2] ZEUS APEX CORE: PURE MACH EXCEPTION ENGINE (NO DOBBY)
// ============================================================================
static mach_port_t exception_port = MACH_PORT_NULL;
static pthread_t exception_thread;

struct StealthHook {
    void* target_address;
    void* replacement_address;
};

#define MAX_HOOKS 256
static StealthHook active_hooks[MAX_HOOKS];
static int hook_count = 0;

// أمر نقطة التوقف لمعمارية ARM64
#define ARM64_BRK 0xD4200020

extern "C" boolean_t exc_server(mach_msg_header_t *request, mach_msg_header_t *reply);
kern_return_t catch_exception_raise(mach_port_t exception_port, mach_port_t thread, mach_port_t task, exception_type_t exception, exception_data_t code, mach_msg_type_number_t codeCnt) {
    arm_thread_state64_t state;
    mach_msg_type_number_t state_count = ARM_THREAD_STATE64_COUNT;
    
    // سحب حالة المعالج عند الكراش المفتعل
    if (thread_get_state(thread, ARM_THREAD_STATE64, (thread_state_t)&state, &state_count) != KERN_SUCCESS) return KERN_FAILURE;
    void* crashed_pc = (void*)state.__pc;

    for (int i = 0; i < hook_count; i++) {
        if (active_hooks[i].target_address == crashed_pc) {
            // توجيه المعالج للدالة المزيفة (Replacement) وتجاوز الخطأ
            state.__pc = (uint64_t)active_hooks[i].replacement_address;
            thread_set_state(thread, ARM_THREAD_STATE64, (thread_state_t)&state, state_count);
            return KERN_SUCCESS;
        }
    }
    return KERN_FAILURE;
}

void* exception_handler_thread(void* arg) {
    mach_msg_server(exc_server, 2048, exception_port, 0);
    return NULL;
}

void init_zeus_engine() {
    if (exception_port != MACH_PORT_NULL) return;
    mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &exception_port);
    mach_port_insert_right(mach_task_self(), exception_port, exception_port, MACH_MSG_TYPE_MAKE_SEND);
    task_set_exception_ports(mach_task_self(), EXC_MASK_BREAKPOINT, exception_port, EXCEPTION_DEFAULT, ARM_THREAD_STATE64);
    pthread_create(&exception_thread, NULL, exception_handler_thread, NULL);
}

// دالة الهوك العبقرية: تعدل بايت واحد فقط باستخدام mach_vm_protect 
void apex_hook(void* target, void* replacement) {
    if (!target || hook_count >= MAX_HOOKS) return;
    active_hooks[hook_count++] = {target, replacement};
    
    mach_vm_address_t addr = (mach_vm_address_t)target;
    if (mach_vm_protect(mach_task_self(), addr, 4, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY) == KERN_SUCCESS) {
        *(uint32_t*)target = ARM64_BRK;
        mach_vm_protect(mach_task_self(), addr, 4, FALSE, VM_PROT_READ | VM_PROT_EXEC);
        sys_icache_invalidate(target, 4);
    }
}

static void safe_hook_by_name(const char* func_name, void* replacement) {
    void* target_sym = dlsym(RTLD_DEFAULT, func_name);
    if (target_sym) apex_hook(target_sym, replacement);
}

// ============================================================================
// [3] Original Pointers (Marked Unused to satisfy the compiler)
// ============================================================================
__attribute__((unused)) static int (*orig_ptrace)(int request, pid_t pid, caddr_t addr, int data);
__attribute__((unused)) static int (*orig_sysctl)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
__attribute__((unused)) static const char* (*orig_dyld_get_image_name)(uint32_t image_index);
__attribute__((unused)) static int (*orig_task_for_pid)(mach_port_t target_tport, int pid, mach_port_t *tn);
__attribute__((unused)) static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef query, CFTypeRef *result);
__attribute__((unused)) static OSStatus (*orig_SecItemAdd)(CFDictionaryRef attributes, CFTypeRef *result);
__attribute__((unused)) static SecKeyRef (*orig_SecKeyCreateRandomKey)(CFDictionaryRef parameters, CFErrorRef *error);
__attribute__((unused)) static Boolean (*orig_SecKeyVerifySignature)(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFDataRef signature, CFErrorRef *error);
__attribute__((unused)) static CCCryptorStatus (*orig_CCCrypt)(CCOperation op, CCAlgorithm alg, CCOptions options, const void *key, size_t keyLength, const void *iv, const void *dataIn, size_t dataInLength, void *dataOut, size_t dataAvailable, size_t *dataMoved);
__attribute__((unused)) static int (*orig_RSA_verify)(int type, const unsigned char *m, unsigned int m_len, const unsigned char *sig, unsigned int sig_len, RSA *rsa);
__attribute__((unused)) static int (*orig_X509_verify_cert)(X509_STORE_CTX *ctx);
__attribute__((unused)) static IMP orig_LAContext_evaluatePolicy;
__attribute__((unused)) static IMP orig_UIDevice_identifierForVendor;

// ============================================================================
// [4] Intelligent Replacements (Anti-Crash Bypasses)
// بدلاً من إيقاف الدوال تماماً (وهو ما يسبب كراش)، نرد بإجابات مزيفة!
// ============================================================================

// 1. هوك ptrace الذكي
static int my_ptrace(int request, pid_t pid, caddr_t addr, int data) {
    if (request == PT_DENY_ATTACH) return 0; // تجاوز حماية المنع
    return 0; 
}

// 2. هوك sysctl الذكي لتنظيف علامات التنقيح من الذاكرة
static int my_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (oldp && namelen == 4 && name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID) {
        struct kinfo_proc *kp = (struct kinfo_proc *)oldp;
        kp->kp_proc.p_flag &= ~P_TRACED; // إزالة P_TRACED
        return 0;
    }
    return -1;
}

// 3. هوك إخفاء المكتبات (البديل العبقري لـ dlopen الذي كان يسبب كراش)
// بدلاً من تجميد dlopen، نقوم بإخفاء أسماء أدواتنا إذا حاول التطبيق فحص المكتبات المحملة
static const char* my_dyld_get_image_name(uint32_t image_index) {
    // نجلب دالة الفحص الأصلية لحظياً من النظام
    static const char* (*real_dyld_get_image_name)(uint32_t) = (const char* (*)(uint32_t))dlsym(RTLD_NEXT, "_dyld_get_image_name");
    const char* name = real_dyld_get_image_name ? real_dyld_get_image_name(image_index) : NULL;
    
    if (name) {
        if (strstr(name, OBF("Frida")) || strstr(name, OBF("Substrate")) || strstr(name, OBF("Cydia"))) {
            return OBF("/usr/lib/system/libsystem_kernel.dylib"); // نعطيه مسار مكتبة نظامية آمنة!
        }
    }
    return name;
}

static int my_task_for_pid(mach_port_t target_tport, int pid, mach_port_t *tn) { return KERN_FAILURE; }

// --- Crypto & Keychain Bypasses ---
static OSStatus my_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) { return errSecItemNotFound; }
static OSStatus my_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) { return errSecSuccess; }
static SecKeyRef my_SecKeyCreateRandomKey(CFDictionaryRef parameters, CFErrorRef *error) { return NULL; }
static Boolean my_SecKeyVerifySignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFDataRef signature, CFErrorRef *error) { return true; }

static CCCryptorStatus my_CCCrypt(CCOperation op, CCAlgorithm alg, CCOptions options, const void *key, size_t keyLength, const void *iv, const void *dataIn, size_t dataInLength, void *dataOut, size_t dataAvailable, size_t *dataMoved) {
    if (dataOut && dataMoved) { memcpy(dataOut, dataIn, dataInLength); *dataMoved = dataInLength; return kCCSuccess; }
    return kCCSuccess;
}

static int my_RSA_verify(int type, const unsigned char *m, unsigned int m_len, const unsigned char *sig, unsigned int sig_len, RSA *rsa) { return 1; }
static int my_X509_verify_cert(X509_STORE_CTX *ctx) { return 1; }

// --- Objective-C Spoofing ---
static id my_UIDevice_identifierForVendor(id self, SEL _cmd) {
    return [[NSUUID alloc] initWithUUIDString:[NSString stringWithUTF8String:OBF("00000000-0000-0000-0000-000000000000")]];
}

static void my_LAContext_evaluatePolicy(id self, SEL _cmd, LAPolicy policy, id reply) {
    void (^replyBlock)(BOOL success, NSError *error) = reply;
    if (replyBlock) replyBlock(YES, nil); // البصمة ناجحة دائماً
}

// ============================================================================
// [5] Master Hook Installer
// ============================================================================
void hook_all_functions() {
    // هوكات النظام بنظام BRK المخفي
    safe_hook_by_name(OBF("ptrace"), (void*)my_ptrace);
    safe_hook_by_name(OBF("sysctl"), (void*)my_sysctl);
    safe_hook_by_name(OBF("_dyld_get_image_name"), (void*)my_dyld_get_image_name);
    safe_hook_by_name(OBF("task_for_pid"), (void*)my_task_for_pid);

    // التشفير والبنوك
    safe_hook_by_name(OBF("SecItemCopyMatching"), (void*)my_SecItemCopyMatching);
    safe_hook_by_name(OBF("SecItemAdd"), (void*)my_SecItemAdd);
    safe_hook_by_name(OBF("SecKeyCreateRandomKey"), (void*)my_SecKeyCreateRandomKey);
    safe_hook_by_name(OBF("SecKeyVerifySignature"), (void*)my_SecKeyVerifySignature);
    safe_hook_by_name(OBF("CCCrypt"), (void*)my_CCCrypt);
    safe_hook_by_name(OBF("RSA_verify"), (void*)my_RSA_verify);
    safe_hook_by_name(OBF("X509_verify_cert"), (void*)my_X509_verify_cert);

    // هوكات Obj-C باستخدام الـ Runtime الطبيعي (آمن جداً ولا يسبب كراش)
    Class devCls = objc_getClass(OBF("UIDevice"));
    if (devCls) {
        Method m = class_getInstanceMethod(devCls, @selector(identifierForVendor));
        if (m) { orig_UIDevice_identifierForVendor = method_getImplementation(m); method_setImplementation(m, (IMP)my_UIDevice_identifierForVendor); }
    }
    
    Class laCls = objc_getClass(OBF("LAContext"));
    if (laCls) {
        Method m1 = class_getInstanceMethod(laCls, @selector(evaluatePolicy:localizedReason:reply:));
        if (m1) { orig_LAContext_evaluatePolicy = method_getImplementation(m1); method_setImplementation(m1, (IMP)my_LAContext_evaluatePolicy); }
    }
}

// ============================================================================
// [6] Initialization (Boot)
// ============================================================================
__attribute__((constructor))
void init_hook() {
    // إقلاع المحرك السري وزرع الهوكات
    init_zeus_engine();
    hook_all_functions();
}
