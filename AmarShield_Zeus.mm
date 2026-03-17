// ============================================================================
// [0] System Headers
// ============================================================================
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdint.h>
#include <pthread.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <sys/ptrace.h>
#include <sys/utsname.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <TargetConditionals.h>

#if TARGET_OS_IPHONE
#import <objc/runtime.h>
#import <objc/message.h>
#import <LocalAuthentication/LocalAuthentication.h>
#endif
#include <CommonCrypto/CommonCryptor.h>
#include <Security/Security.h>
#include <Security/SecKey.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmodule-import-in-extern-c"

#include <openssl/rsa.h>
#include <openssl/x509.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/ssl.h>
#include "dobby.h"

#pragma clang diagnostic pop

// ============================================================================
// [1] Advanced Compile-Time XOR String Obfuscator (Optimized for Boot Speed)
// ============================================================================
template <size_t N>
struct XorString {
    char data[N];
    constexpr XorString(const char* str, char key) : data{0} {
        for (size_t i = 0; i < N; ++i) {
            data[i] = str[i] ^ key;
        }
    }
};

#define OBF(str) \
    ([]() -> char* { \
        constexpr char key = 0x5A; \
        constexpr XorString<sizeof(str)> xs(str, key); \
        static char decrypted[sizeof(str)]; \
        static bool init = false; \
        if (!init) { \
            for (size_t i = 0; i < sizeof(str); ++i) { \
                decrypted[i] = xs.data[i] ^ key; \
            } \
            init = true; \
        } \
        return decrypted; \
    }())

// ============================================================================
// [2] Dobby Safe Hook Engine (No Crashes!)
// ============================================================================
static void safe_hook(const char* func_name, void* replacement, void** original) {
    // نستخدم محرك Dobby الداخلي للبحث عن الدوال (أقوى وأكثر أماناً من dlsym)
    void* target_sym = DobbySymbolResolver(NULL, func_name);
    
    // إذا لم يجده، نحاول استخدام dlsym كخطة بديلة
    if (!target_sym) {
        target_sym = dlsym(RTLD_DEFAULT, func_name);
    }
    
    // تأمين الكراش: الـ Hook يتم فقط إذا كانت الدالة موجودة فعلياً
    if (target_sym != NULL) {
        DobbyHook(target_sym, replacement, original);
    }
}

static inline void junk_code(void) {
    volatile int a = 5;
    volatile int b = 10;
    volatile int c = a * b + a - b;
    (void)c;
}

// ============================================================================
// [3] Original Pointers
// ============================================================================
static int (*orig_ptrace)(int request, pid_t pid, caddr_t addr, int data);
static int (*orig_sysctl)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
static int (*orig_sysctlbyname)(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
static int (*orig_task_for_pid)(mach_port_t target_tport, int pid, mach_port_t *tn);

static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef query, CFTypeRef *result);
static OSStatus (*orig_SecItemAdd)(CFDictionaryRef attributes, CFTypeRef *result);
static OSStatus (*orig_SecItemUpdate)(CFDictionaryRef query, CFDictionaryRef attributesToUpdate);
static OSStatus (*orig_SecItemDelete)(CFDictionaryRef query);
static SecKeyRef (*orig_SecKeyCreateRandomKey)(CFDictionaryRef parameters, CFErrorRef *error);
static SecKeyRef (*orig_SecKeyCopyPublicKey)(SecKeyRef key);
static CFDataRef (*orig_SecKeyCreateSignature)(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFErrorRef *error);
static Boolean (*orig_SecKeyVerifySignature)(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFDataRef signature, CFErrorRef *error);

static CCCryptorStatus (*orig_CCCrypt)(CCOperation op, CCAlgorithm alg, CCOptions options, const void *key, size_t keyLength, const void *iv, const void *dataIn, size_t dataInLength, void *dataOut, size_t dataOutAvailable, size_t *dataOutMoved);

static int (*orig_RSA_verify)(int type, const unsigned char *m, unsigned int m_len, const unsigned char *sig, unsigned int sig_len, RSA *rsa);
static int (*orig_RSA_sign)(int type, const unsigned char *m, unsigned int m_len, unsigned char *sig, unsigned int *sig_len, RSA *rsa);
static int (*orig_EVP_PKEY_verify)(EVP_PKEY_CTX *ctx, const unsigned char *sig, size_t sig_len, const unsigned char *tbs, size_t tbs_len);
static int (*orig_X509_verify_cert)(X509_STORE_CTX *ctx);
static int (*orig_X509_check_private_key)(X509 *x509, EVP_PKEY *pkey);
static EVP_PKEY* (*orig_PEM_read_bio_PrivateKey)(BIO *bp, EVP_PKEY **x, pem_password_cb *cb, void *u);
static int (*orig_SSL_CTX_use_PrivateKey_file)(SSL_CTX *ctx, const char *file, int type);
static int (*orig_SSL_CTX_check_private_key)(SSL_CTX *ctx);
static int (*orig_SSL_CTX_load_verify_locations)(SSL_CTX *ctx, const char *CAfile, const char *CApath);

static IMP orig_LAContext_evaluatePolicy;
static IMP orig_LAContext_canEvaluatePolicy;

// ============================================================================
// [4] Replacement Hooks (100% Safe)
// ============================================================================
static int my_ptrace(int request, pid_t pid, caddr_t addr, int data) {
    junk_code();
    if (request == PT_DENY_ATTACH) return 0;
    return orig_ptrace ? orig_ptrace(request, pid, addr, data) : 0;
}

static int my_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    junk_code();
    int ret = orig_sysctl ? orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen) : -1;
    if (ret == 0 && oldp && namelen == 4 && name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID) {
        struct kinfo_proc *kp = (struct kinfo_proc *)oldp;
        kp->kp_proc.p_flag &= ~P_TRACED;
    }
    return ret;
}

static int my_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    junk_code();
    if (name) {
        if (strcmp(name, OBF("kern.proc")) == 0 || strcmp(name, OBF("debug")) == 0) {
            if (oldp && oldlenp) {
                memset(oldp, 0, *oldlenp);
                return 0;
            }
        }
    }
    return orig_sysctlbyname ? orig_sysctlbyname(name, oldp, oldlenp, newp, newlen) : -1;
}

static int my_task_for_pid(mach_port_t target_tport, int pid, mach_port_t *tn) { junk_code(); return KERN_FAILURE; }

// Keychain
static OSStatus my_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) { junk_code(); return errSecItemNotFound; }
static OSStatus my_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) { junk_code(); return errSecDuplicateItem; }
static OSStatus my_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) { junk_code(); return errSecItemNotFound; }
static OSStatus my_SecItemDelete(CFDictionaryRef query) { junk_code(); return errSecSuccess; }

// SecKey
static SecKeyRef my_SecKeyCreateRandomKey(CFDictionaryRef parameters, CFErrorRef *error) { junk_code(); return NULL; }
static SecKeyRef my_SecKeyCopyPublicKey(SecKeyRef key) { junk_code(); return NULL; }
static CFDataRef my_SecKeyCreateSignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFErrorRef *error) {
    junk_code(); return CFDataCreate(NULL, (const UInt8*)OBF("fake_signature"), 14);
}
static Boolean my_SecKeyVerifySignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFDataRef signature, CFErrorRef *error) {
    junk_code(); return true;
}

// CommonCrypto
static CCCryptorStatus my_CCCrypt(CCOperation op, CCAlgorithm alg, CCOptions options, const void *key, size_t keyLength, const void *iv, const void *dataIn, size_t dataInLength, void *dataOut, size_t dataOutAvailable, size_t *dataOutMoved) {
    junk_code();
    if (dataOut && dataOutMoved) {
        memcpy(dataOut, dataIn, dataInLength);
        *dataOutMoved = dataInLength;
        return kCCSuccess;
    }
    return kCCSuccess;
}

// OpenSSL
static int my_RSA_verify(int type, const unsigned char *m, unsigned int m_len, const unsigned char *sig, unsigned int sig_len, RSA *rsa) { return 1; }
static int my_RSA_sign(int type, const unsigned char *m, unsigned int m_len, unsigned char *sig, unsigned int *sig_len, RSA *rsa) { return 1; }
static int my_EVP_PKEY_verify(EVP_PKEY_CTX *ctx, const unsigned char *sig, size_t sig_len, const unsigned char *tbs, size_t tbs_len) { return 1; }
static int my_X509_verify_cert(X509_STORE_CTX *ctx) { return 1; }
static int my_X509_check_private_key(X509 *x509, EVP_PKEY *pkey) { return 1; }
static EVP_PKEY* my_PEM_read_bio_PrivateKey(BIO *bp, EVP_PKEY **x, pem_password_cb *cb, void *u) { return NULL; }
static int my_SSL_CTX_use_PrivateKey_file(SSL_CTX *ctx, const char *file, int type) { return 1; }
static int my_SSL_CTX_check_private_key(SSL_CTX *ctx) { return 1; }
static int my_SSL_CTX_load_verify_locations(SSL_CTX *ctx, const char *CAfile, const char *CApath) { return 1; }

// ============================================================================
// [5] Custom Checks Replacements
// ============================================================================
static bool (*orig_is_jb)(void);
static bool (*orig_ROOTED)(void);
static bool (*orig_DEBUGGER_ATTACHED)(void);
static bool (*orig_isDebuggerAttached)(void);
static bool (*orig_checkJailbreak)(void);
static bool (*orig_hasCydia)(void);
static bool (*orig_isJailbroken)(void);
static bool (*orig_amIBeingDebugged)(void);

static bool my_is_jb(void) { return false; }
static bool my_ROOTED(void) { return false; }
static bool my_DEBUGGER_ATTACHED(void) { return false; }
static bool my_isDebuggerAttached(void) { return false; }
static bool my_checkJailbreak(void) { return false; }
static bool my_hasCydia(void) { return false; }
static bool my_isJailbroken_c(void) { return false; }
static bool my_amIBeingDebugged(void) { return false; }

// ============================================================================
// [6] Objective-C Hooks
// ============================================================================
static IMP orig_UIDevice_identifierForVendor;
static id my_UIDevice_identifierForVendor(id self, SEL _cmd) {
    junk_code();
    return [[NSUUID alloc] initWithUUIDString:@(OBF("00000000-0000-0000-0000-000000000000"))];
}

static void my_LAContext_evaluatePolicy(id self, SEL _cmd, LAPolicy policy, id reply) {
    junk_code();
    void (^replyBlock)(BOOL success, NSError *error) = reply;
    if (replyBlock) replyBlock(YES, nil);
}

static BOOL my_LAContext_canEvaluatePolicy(id self, SEL _cmd, LAPolicy policy, NSError **error) {
    junk_code();
    return YES;
}

// ============================================================================
// [7] The Master Hook Installer
// ============================================================================
void hook_all_functions() {
    // تم إزالة dlsym و dlopen و vm_protect وغيرها لأنها تدمر Dobby
    safe_hook(OBF("ptrace"), (void*)my_ptrace, (void**)&orig_ptrace);
    safe_hook(OBF("sysctl"), (void*)my_sysctl, (void**)&orig_sysctl);
    safe_hook(OBF("sysctlbyname"), (void*)my_sysctlbyname, (void**)&orig_sysctlbyname);
    safe_hook(OBF("task_for_pid"), (void*)my_task_for_pid, (void**)&orig_task_for_pid);

    safe_hook(OBF("SecItemCopyMatching"), (void*)my_SecItemCopyMatching, (void**)&orig_SecItemCopyMatching);
    safe_hook(OBF("SecItemAdd"), (void*)my_SecItemAdd, (void**)&orig_SecItemAdd);
    safe_hook(OBF("SecItemUpdate"), (void*)my_SecItemUpdate, (void**)&orig_SecItemUpdate);
    safe_hook(OBF("SecItemDelete"), (void*)my_SecItemDelete, (void**)&orig_SecItemDelete);

    safe_hook(OBF("SecKeyCreateRandomKey"), (void*)my_SecKeyCreateRandomKey, (void**)&orig_SecKeyCreateRandomKey);
    safe_hook(OBF("SecKeyCopyPublicKey"), (void*)my_SecKeyCopyPublicKey, (void**)&orig_SecKeyCopyPublicKey);
    safe_hook(OBF("SecKeyCreateSignature"), (void*)my_SecKeyCreateSignature, (void**)&orig_SecKeyCreateSignature);
    safe_hook(OBF("SecKeyVerifySignature"), (void*)my_SecKeyVerifySignature, (void**)&orig_SecKeyVerifySignature);

    safe_hook(OBF("CCCrypt"), (void*)my_CCCrypt, (void**)&orig_CCCrypt);

    safe_hook(OBF("RSA_verify"), (void*)my_RSA_verify, (void**)&orig_RSA_verify);
    safe_hook(OBF("RSA_sign"), (void*)my_RSA_sign, (void**)&orig_RSA_sign);
    safe_hook(OBF("EVP_PKEY_verify"), (void*)my_EVP_PKEY_verify, (void**)&orig_EVP_PKEY_verify);
    safe_hook(OBF("X509_verify_cert"), (void*)my_X509_verify_cert, (void**)&orig_X509_verify_cert);
    safe_hook(OBF("X509_check_private_key"), (void*)my_X509_check_private_key, (void**)&orig_X509_check_private_key);
    safe_hook(OBF("PEM_read_bio_PrivateKey"), (void*)my_PEM_read_bio_PrivateKey, (void**)&orig_PEM_read_bio_PrivateKey);
    safe_hook(OBF("SSL_CTX_use_PrivateKey_file"), (void*)my_SSL_CTX_use_PrivateKey_file, (void**)&orig_SSL_CTX_use_PrivateKey_file);
    safe_hook(OBF("SSL_CTX_check_private_key"), (void*)my_SSL_CTX_check_private_key, (void**)&orig_SSL_CTX_check_private_key);
    safe_hook(OBF("SSL_CTX_load_verify_locations"), (void*)my_SSL_CTX_load_verify_locations, (void**)&orig_SSL_CTX_load_verify_locations);

    const char *jb_funcs[] = {OBF("is_jb"), OBF("ROOTED"), OBF("DEBUGGER_ATTACHED"), 
                              OBF("isDebuggerAttached"), OBF("checkJailbreak"), 
                              OBF("hasCydia"), OBF("isJailbroken"), OBF("amIBeingDebugged")};
    void *jb_repl[] = {(void*)my_is_jb, (void*)my_ROOTED, (void*)my_DEBUGGER_ATTACHED, (void*)my_isDebuggerAttached,
                       (void*)my_checkJailbreak, (void*)my_hasCydia, (void*)my_isJailbroken_c, (void*)my_amIBeingDebugged};
    void **jb_orig[] = {(void**)&orig_is_jb, (void**)&orig_ROOTED, (void**)&orig_DEBUGGER_ATTACHED,
                        (void**)&orig_isDebuggerAttached, (void**)&orig_checkJailbreak, (void**)&orig_hasCydia,
                        (void**)&orig_isJailbroken, (void**)&orig_amIBeingDebugged};

    for (int i = 0; i < 8; i++) {
        safe_hook(jb_funcs[i], jb_repl[i], jb_orig[i]);
    }

    Class deviceCls = objc_getClass(OBF("UIDevice"));
    if (deviceCls) {
        SEL sel = @selector(identifierForVendor);
        Method m = class_getInstanceMethod(deviceCls, sel);
        if (m) {
            orig_UIDevice_identifierForVendor = method_getImplementation(m);
            method_setImplementation(m, (IMP)my_UIDevice_identifierForVendor);
        }
    }

    Class laContextCls = objc_getClass(OBF("LAContext"));
    if (laContextCls) {
        SEL sel = @selector(evaluatePolicy:localizedReason:reply:);
        Method m = class_getInstanceMethod(laContextCls, sel);
        if (m) {
            orig_LAContext_evaluatePolicy = method_getImplementation(m);
            method_setImplementation(m, (IMP)my_LAContext_evaluatePolicy);
        }
        sel = @selector(canEvaluatePolicy:error:);
        m = class_getInstanceMethod(laContextCls, sel);
        if (m) {
            orig_LAContext_canEvaluatePolicy = method_getImplementation(m);
            method_setImplementation(m, (IMP)my_LAContext_canEvaluatePolicy);
        }
    }
}

// ============================================================================
// [8] Safe Environment checks
// ============================================================================
int is_simulator() {
    junk_code();
#if TARGET_IPHONE_SIMULATOR
    return 1;
#else
    struct utsname systemInfo;
    uname(&systemInfo);
    if (strcmp(systemInfo.machine, OBF("x86_64")) == 0 || strcmp(systemInfo.machine, OBF("i386")) == 0) {
        return 1;
    }
    return 0;
#endif
}

int is_jailbroken_paths() {
    junk_code();
    const char *paths[] = {
        OBF("/Applications/Cydia.app"),
        OBF("/Library/MobileSubstrate/MobileSubstrate.dylib"),
        OBF("/bin/bash"),
        OBF("/usr/sbin/sshd"),
        OBF("/etc/apt"),
        OBF("/usr/sbin/frida-server"),
        NULL
    };
    for (int i = 0; paths[i] != NULL; i++) {
        if (access(paths[i], F_OK) == 0) return 1;
    }
    return 0;
}

int is_dyld_hijacked() {
    junk_code();
    if (getenv(OBF("DYLD_INSERT_LIBRARIES")) != NULL) return 1;
    if (getenv(OBF("DYLD_FORCE_FLAT_NAMESPACE")) != NULL) return 1;
    return 0;
}

int is_debugger_attached() {
    junk_code();
    int name[4];
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    info.kp_proc.p_flag = 0;
    name[0] = CTL_KERN;
    name[1] = KERN_PROC;
    name[2] = KERN_PROC_PID;
    name[3] = getpid();
    if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) return 0;
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

int check_provisioning() {
    junk_code();
    FILE *fp = NULL;
    uint32_t size = 0;
    
    _NSGetExecutablePath(NULL, &size);
    char *execPath = (char *)malloc(size); 
    if (!execPath) return 0;
    
    _NSGetExecutablePath(execPath, &size);
    char *lastSlash = strrchr(execPath, '/');
    if (lastSlash) {
        *lastSlash = '\0';
        char path[MAXPATHLEN];
        snprintf(path, sizeof(path), OBF("%s/embedded.mobileprovision"), execPath);
        fp = fopen(path, OBF("r"));
    }
    free(execPath);
    
    if (!fp) return 0;
    
    fseek(fp, 0, SEEK_END);
    long len = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    
    char *data = (char *)malloc(len + 1);
    if (!data) { fclose(fp); return 0; }
    
    fread(data, 1, len, fp);
    fclose(fp);
    data[len] = '\0';
    
    int is_debuggable = strstr(data, OBF("<key>get-task-allow</key><true/>")) != NULL;
    free(data);
    return is_debuggable;
}

void perform_security_checks() {
    int threat_level = 0;
    if (is_simulator()) threat_level += 10;
    if (is_jailbroken_paths()) threat_level += 20;
    if (is_dyld_hijacked()) threat_level += 30;
    if (is_debugger_attached()) threat_level += 50;
    if (check_provisioning()) threat_level += 30;
    
    if (threat_level > 50) {
        _exit(1); // إغلاق فوري إذا كان هناك تهديد أمني عالي بدون تأخير يسبب Deadlock
    }
}

// ============================================================================
// [9] Initialization
// ============================================================================
__attribute__((constructor))
void init_hook() {
    perform_security_checks();
    hook_all_functions();
    // تمت إزالة الـ Hook الخاص بـ printf لأنه يسبب Crash أثناء الإقلاع!
}
