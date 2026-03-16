// ============================================================================
// [0] System Headers (Ordered correctly to prevent C++ module errors)
// ============================================================================
#include <stdio.h>
#include <stdarg.h>      // تمت الإضافة لدعم va_list في دالة hooked_printf
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdint.h>      // تمت الإضافة لمنع تضارب Dobby
#include <pthread.h>     // تمت الإضافة لمنع تضارب OpenSSL
#include <sys/types.h>   // تم النقل للأعلى لمنع تضارب C++
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <sys/ptrace.h>
#include <sys/utsname.h> // تمت الإضافة لحل خطأ struct utsname
#include <sys/param.h>
#include <sys/mount.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <TargetConditionals.h>
#include <time.h>

// Apple Frameworks
#if TARGET_OS_IPHONE
#import <objc/runtime.h>
#import <objc/message.h>
#import <LocalAuthentication/LocalAuthentication.h>
#endif
#include <CommonCrypto/CommonCryptor.h>
#include <Security/Security.h>
#include <Security/SecKey.h>

// External Libraries (OpenSSL & Dobby MUST be at the end)
#include <openssl/rsa.h>
#include <openssl/x509.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/ssl.h>
#include "dobby.h"

// ============================================================================
// [1] Obfuscation helpers (simple ROT13)
// ============================================================================
static inline void obfuscate_str(char *s) {
    while (*s) {
        if ((*s >= 'a' && *s <= 'z') || (*s >= 'A' && *s <= 'Z')) {
            if ((*s >= 'a' && *s <= 'm') || (*s >= 'A' && *s <= 'M'))
                *s += 13;
            else
                *s -= 13;
        }
        s++;
    }
}

#define OBF(s) obfuscate_str((char[])s)

// ============================================================================
// [2] Random junk code to disrupt pattern analysis
// ============================================================================
static inline void junk_code(void) {
    volatile int a = rand() % 100;
    volatile int b = rand() % 100;
    volatile int c = a * b + a - b;
    (void)c;
}

// ============================================================================
// [3] Original function pointers (C functions)
// ============================================================================
static int (*orig_printf)(const char *format, ...);
static int (*orig_ptrace)(int request, pid_t pid, caddr_t addr, int data);
static int (*orig_sysctl)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
static int (*orig_sysctlbyname)(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
static void* (*orig_dlopen)(const char *path, int mode);
static void* (*orig_dlsym)(void *handle, const char *symbol);
static int (*orig_task_for_pid)(mach_port_t target_tport, int pid, mach_port_t *tn);
static int (*orig_vm_read_overwrite)(vm_map_t target_task, vm_address_t address, vm_size_t size, vm_address_t data, vm_size_t *outsize);
static int (*orig_vm_write)(vm_map_t target_task, vm_address_t address, vm_offset_t data, mach_msg_type_number_t dataCnt);
static int (*orig_vm_protect)(vm_map_t target_task, vm_address_t address, vm_size_t size, boolean_t set_max, vm_prot_t new_protection);
static int (*orig_mach_vm_protect)(vm_map_t target_task, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_max, vm_prot_t new_protection);

// Keychain
static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef query, CFTypeRef *result);
static OSStatus (*orig_SecItemAdd)(CFDictionaryRef attributes, CFTypeRef *result);
static OSStatus (*orig_SecItemUpdate)(CFDictionaryRef query, CFDictionaryRef attributesToUpdate);
static OSStatus (*orig_SecItemDelete)(CFDictionaryRef query);

// SecKey
static SecKeyRef (*orig_SecKeyCreateRandomKey)(CFDictionaryRef parameters, CFErrorRef *error);
static SecKeyRef (*orig_SecKeyCopyPublicKey)(SecKeyRef key);
static CFDataRef (*orig_SecKeyCreateSignature)(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFErrorRef *error);
static Boolean (*orig_SecKeyVerifySignature)(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFDataRef signature, CFErrorRef *error);

// AES / CommonCrypto
static CCCryptorStatus (*orig_CCCrypt)(CCOperation op, CCAlgorithm alg, CCOptions options, const void *key, size_t keyLength, const void *iv, const void *dataIn, size_t dataInLength, void *dataOut, size_t dataOutAvailable, size_t *dataOutMoved);

// OpenSSL RSA
static int (*orig_RSA_verify)(int type, const unsigned char *m, unsigned int m_len, const unsigned char *sig, unsigned int sig_len, RSA *rsa);
static int (*orig_RSA_sign)(int type, const unsigned char *m, unsigned int m_len, unsigned char *sig, unsigned int *sig_len, RSA *rsa);
static int (*orig_EVP_PKEY_verify)(EVP_PKEY_CTX *ctx, const unsigned char *sig, size_t sig_len, const unsigned char *tbs, size_t tbs_len);
static int (*orig_X509_verify_cert)(X509_STORE_CTX *ctx);
static int (*orig_X509_check_private_key)(X509 *x509, EVP_PKEY *pkey);
static EVP_PKEY* (*orig_PEM_read_bio_PrivateKey)(BIO *bp, EVP_PKEY **x, pem_password_cb *cb, void *u);
static int (*orig_SSL_CTX_use_PrivateKey_file)(SSL_CTX *ctx, const char *file, int type);
static int (*orig_SSL_CTX_check_private_key)(SSL_CTX *ctx);
static int (*orig_SSL_CTX_load_verify_locations)(SSL_CTX *ctx, const char *CAfile, const char *CApath);

// LocalAuthentication (Obj-C, but we'll use runtime)
static IMP orig_LAContext_evaluatePolicy;
static IMP orig_LAContext_canEvaluatePolicy;

// ============================================================================
// [4] Replacement functions with junk code
// ============================================================================
static int my_ptrace(int request, pid_t pid, caddr_t addr, int data) {
    junk_code();
    if (request == PT_DENY_ATTACH) return 0;
    return orig_ptrace ? orig_ptrace(request, pid, addr, data) : 0;
}

static int my_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    junk_code();
    int ret = orig_sysctl ? orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen) : 0;
    if (ret == 0 && oldp && namelen == 4 && name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID) {
        struct kinfo_proc *kp = (struct kinfo_proc *)oldp;
        kp->kp_proc.p_flag &= ~P_TRACED;
    }
    return ret;
}

static int my_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    junk_code();
    char buf[256];
    strncpy(buf, name, sizeof(buf));
    obfuscate_str(buf);
    if (strstr(buf, "qroht") || strstr(buf, "xrea.cebp")) { // "debug", "kern.proc" after ROT13
        if (oldp && oldlenp) {
            memset(oldp, 0, *oldlenp);
            return 0;
        }
    }
    return orig_sysctlbyname ? orig_sysctlbyname(name, oldp, oldlenp, newp, newlen) : 0;
}

static void* my_dlopen(const char *path, int mode) {
    junk_code();
    return orig_dlopen ? orig_dlopen(path, mode) : NULL;
}

static void* my_dlsym(void *handle, const char *symbol) {
    junk_code();
    char buf[256];
    strncpy(buf, symbol, sizeof(buf));
    obfuscate_str(buf);
    if (strstr(buf, "cgenpr") || strstr(buf, "flfpby") || strstr(buf, "gnfx_sbe_cvq") || strstr(buf, "iz_ernq")) { // "ptrace", "sysctl", "task_for_pid", "vm_read"
        return NULL;
    }
    return orig_dlsym ? orig_dlsym(handle, symbol) : NULL;
}

static int my_task_for_pid(mach_port_t target_tport, int pid, mach_port_t *tn) {
    junk_code();
    return KERN_FAILURE;
}

static int my_vm_read_overwrite(vm_map_t target_task, vm_address_t address, vm_size_t size, vm_address_t data, vm_size_t *outsize) {
    junk_code();
    return KERN_FAILURE;
}

static int my_vm_write(vm_map_t target_task, vm_address_t address, vm_offset_t data, mach_msg_type_number_t dataCnt) {
    junk_code();
    return KERN_FAILURE;
}

static int my_vm_protect(vm_map_t target_task, vm_address_t address, vm_size_t size, boolean_t set_max, vm_prot_t new_protection) {
    junk_code();
    return orig_vm_protect ? orig_vm_protect(target_task, address, size, set_max, new_protection) : KERN_SUCCESS;
}

static int my_mach_vm_protect(vm_map_t target_task, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_max, vm_prot_t new_protection) {
    junk_code();
    return orig_mach_vm_protect ? orig_mach_vm_protect(target_task, address, size, set_max, new_protection) : KERN_SUCCESS;
}

// Keychain
static OSStatus my_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    junk_code();
    return errSecItemNotFound;
}

static OSStatus my_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
    junk_code();
    return errSecDuplicateItem;
}

static OSStatus my_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
    junk_code();
    return errSecItemNotFound;
}

static OSStatus my_SecItemDelete(CFDictionaryRef query) {
    junk_code();
    return errSecSuccess;
}

// SecKey
static SecKeyRef my_SecKeyCreateRandomKey(CFDictionaryRef parameters, CFErrorRef *error) {
    junk_code();
    return NULL;
}

static SecKeyRef my_SecKeyCopyPublicKey(SecKeyRef key) {
    junk_code();
    return NULL; // prevent public key usage
}

static CFDataRef my_SecKeyCreateSignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFErrorRef *error) {
    junk_code();
    return CFDataCreate(NULL, (const UInt8*)"fake_signature", 14);
}

static Boolean my_SecKeyVerifySignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFDataRef signature, CFErrorRef *error) {
    junk_code();
    return true;
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
static int my_RSA_verify(int type, const unsigned char *m, unsigned int m_len, const unsigned char *sig, unsigned int sig_len, RSA *rsa) {
    junk_code();
    return 1;
}

static int my_RSA_sign(int type, const unsigned char *m, unsigned int m_len, unsigned char *sig, unsigned int *sig_len, RSA *rsa) {
    junk_code();
    return 1;
}

static int my_EVP_PKEY_verify(EVP_PKEY_CTX *ctx, const unsigned char *sig, size_t sig_len, const unsigned char *tbs, size_t tbs_len) {
    junk_code();
    return 1;
}

static int my_X509_verify_cert(X509_STORE_CTX *ctx) {
    junk_code();
    return 1;
}

static int my_X509_check_private_key(X509 *x509, EVP_PKEY *pkey) {
    junk_code();
    return 1;
}

static EVP_PKEY* my_PEM_read_bio_PrivateKey(BIO *bp, EVP_PKEY **x, pem_password_cb *cb, void *u) {
    junk_code();
    return NULL;
}

static int my_SSL_CTX_use_PrivateKey_file(SSL_CTX *ctx, const char *file, int type) {
    junk_code();
    return 1;
}

static int my_SSL_CTX_check_private_key(SSL_CTX *ctx) {
    junk_code();
    return 1;
}

static int my_SSL_CTX_load_verify_locations(SSL_CTX *ctx, const char *CAfile, const char *CApath) {
    junk_code();
    return 1;
}

// ============================================================================
// [5] Original C functions for environment checks (from previous code)
// ============================================================================
static bool (*orig_is_jb)(void);
static bool (*orig_ROOTED)(void);
static bool (*orig_DEBUGGER_ATTACHED)(void);
static bool (*orig_isDebuggerAttached)(void);
static bool (*orig_checkJailbreak)(void);
static bool (*orig_hasCydia)(void);
static bool (*orig_isJailbroken)(void);
static bool (*orig_amIBeingDebugged)(void);

static bool my_is_jb(void) { junk_code(); return false; }
static bool my_ROOTED(void) { junk_code(); return false; }
static bool my_DEBUGGER_ATTACHED(void) { junk_code(); return false; }
static bool my_isDebuggerAttached(void) { junk_code(); return false; }
static bool my_checkJailbreak(void) { junk_code(); return false; }
static bool my_hasCydia(void) { junk_code(); return false; }
static bool my_isJailbroken_c(void) { junk_code(); return false; }
static bool my_amIBeingDebugged(void) { junk_code(); return false; }

// ============================================================================
// [6] Objective-C replacement methods
// ============================================================================
static IMP orig_UIDevice_identifierForVendor;
static id my_UIDevice_identifierForVendor(id self, SEL _cmd) {
    junk_code();
    return [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000000"];
}

static void my_LAContext_evaluatePolicy(id self, SEL _cmd, LAPolicy policy, id reply) {
    junk_code();
    void (^replyBlock)(BOOL success, NSError *error) = reply;
    replyBlock(YES, nil);
}

static BOOL my_LAContext_canEvaluatePolicy(id self, SEL _cmd, LAPolicy policy, NSError **error) {
    junk_code();
    return YES;
}

// ============================================================================
// [7] Stealth hook function (searches by obfuscated name)
// ============================================================================
static void stealth_hook(const char *obf_name, void *replacement, void **original) {
    char real_name[256];
    strncpy(real_name, obf_name, sizeof(real_name));
    obfuscate_str(real_name); // de-obfuscate
    void *sym = dlsym(RTLD_DEFAULT, real_name);
    if (sym) {
        DobbyHook(sym, replacement, original);
    }
}

// ============================================================================
// [8] Hooking function
// ============================================================================
void hook_all_functions() {
    // دوال النظام
    stealth_hook("cgenpr", (void*)my_ptrace, (void**)&orig_ptrace);
    stealth_hook("flfpby", (void*)my_sysctl, (void**)&orig_sysctl);
    stealth_hook("flfpbyolanzr", (void*)my_sysctlbyname, (void**)&orig_sysctlbyname);
    stealth_hook("qybcra", (void*)my_dlopen, (void**)&orig_dlopen);
    stealth_hook("qyflz", (void*)my_dlsym, (void**)&orig_dlsym);
    stealth_hook("gnfx_sbe_cvq", (void*)my_task_for_pid, (void**)&orig_task_for_pid);
    stealth_hook("iz_ernq_birejevgr", (void*)my_vm_read_overwrite, (void**)&orig_vm_read_overwrite);
    stealth_hook("iz_jevgr", (void*)my_vm_write, (void**)&orig_vm_write);
    stealth_hook("iz_cebgrpg", (void*)my_vm_protect, (void**)&orig_vm_protect);
    stealth_hook("znpu_iz_cebgrpg", (void*)my_mach_vm_protect, (void**)&orig_mach_vm_protect);

    // Keychain
    stealth_hook("FrpVgrzPbclZngpuvat", (void*)my_SecItemCopyMatching, (void**)&orig_SecItemCopyMatching);
    stealth_hook("FrpVgrzNqq", (void*)my_SecItemAdd, (void**)&orig_SecItemAdd);
    stealth_hook("FrpVgrzHcqngr", (void*)my_SecItemUpdate, (void**)&orig_SecItemUpdate);
    stealth_hook("FrpVgrzQryrgr", (void*)my_SecItemDelete, (void**)&orig_SecItemDelete);

    // SecKey
    stealth_hook("FrpXrlPerngrEnaqbzXrl", (void*)my_SecKeyCreateRandomKey, (void**)&orig_SecKeyCreateRandomKey);
    stealth_hook("FrpXrlPbclChoyvpXrl", (void*)my_SecKeyCopyPublicKey, (void**)&orig_SecKeyCopyPublicKey);
    stealth_hook("FrpXrlPerngrFvtangher", (void*)my_SecKeyCreateSignature, (void**)&orig_SecKeyCreateSignature);
    stealth_hook("FrpXrlIrevslFvtangher", (void*)my_SecKeyVerifySignature, (void**)&orig_SecKeyVerifySignature);

    // CommonCrypto
    stealth_hook("PPPelcg", (void*)my_CCCrypt, (void**)&orig_CCCrypt);

    // OpenSSL
    stealth_hook("ENF_irevsl", (void*)my_RSA_verify, (void**)&orig_RSA_verify);
    stealth_hook("ENF_fvta", (void*)my_RSA_sign, (void**)&orig_RSA_sign);
    stealth_hook("RUC_XRL_irevsl", (void*)my_EVP_PKEY_verify, (void**)&orig_EVP_PKEY_verify);
    stealth_hook("K509_irevsl_preg", (void*)my_X509_verify_cert, (void**)&orig_X509_verify_cert);
    stealth_hook("K509_purpx_cevingr_xrl", (void*)my_X509_check_private_key, (void**)&orig_X509_check_private_key);
    stealth_hook("CRZ_ernq_ovb_CevngrXrl", (void*)my_PEM_read_bio_PrivateKey, (void**)&orig_PEM_read_bio_PrivateKey);
    stealth_hook("FFY_PGK_hfr_CevngrXrl_svyr", (void*)my_SSL_CTX_use_PrivateKey_file, (void**)&orig_SSL_CTX_use_PrivateKey_file);
    stealth_hook("FFY_PGK_purpx_cevingr_xrl", (void*)my_SSL_CTX_check_private_key, (void**)&orig_SSL_CTX_check_private_key);
    stealth_hook("FFY_PGK_ybnq_irevsl_ybpngvbaf", (void*)my_SSL_CTX_load_verify_locations, (void**)&orig_SSL_CTX_load_verify_locations);

    // دوال كشف البيئة (C)
    const char *jb_funcs[] = {"vf_wo", "EBBGRQ", "QRHTTRE_NGGNPURQ", "vfQrhttreNggnpurq", "purpxWnvyoernx", "unfPlqvn", "vfWnvyoernx", "nzVOrvatQrhttrq"};
    void *jb_repl[] = {(void*)my_is_jb, (void*)my_ROOTED, (void*)my_DEBUGGER_ATTACHED, (void*)my_isDebuggerAttached,
                       (void*)my_checkJailbreak, (void*)my_hasCydia, (void*)my_isJailbroken_c, (void*)my_amIBeingDebugged};
    void **jb_orig[] = {(void**)&orig_is_jb, (void**)&orig_ROOTED, (void**)&orig_DEBUGGER_ATTACHED,
                        (void**)&orig_isDebuggerAttached, (void**)&orig_checkJailbreak, (void**)&orig_hasCydia,
                        (void**)&orig_isJailbroken, (void**)&orig_amIBeingDebugged};
    for (int i = 0; i < 8; i++) {
        char real_name[256];
        strncpy(real_name, jb_funcs[i], sizeof(real_name));
        obfuscate_str(real_name);
        void *sym = dlsym(RTLD_DEFAULT, real_name);
        if (sym) {
            DobbyHook(sym, jb_repl[i], jb_orig[i]);
        }
    }

    // Obj-C: UIDevice identifierForVendor
    Class deviceCls = objc_getClass("UIDevice");
    if (deviceCls) {
        SEL sel = @selector(identifierForVendor);
        Method m = class_getInstanceMethod(deviceCls, sel);
        if (m) {
            orig_UIDevice_identifierForVendor = method_getImplementation(m);
            method_setImplementation(m, (IMP)my_UIDevice_identifierForVendor);
        }
    }

    // Obj-C: LAContext (Face ID / Touch ID)
    Class laContextCls = objc_getClass("LAContext");
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
// [9] Environment checks (from previous code, with random delays)
// ============================================================================
int is_simulator() {
    junk_code();
#if TARGET_IPHONE_SIMULATOR
    return 1;
#else
    struct utsname systemInfo;
    uname(&systemInfo);
    if (strcmp(systemInfo.machine, "x86_64") == 0 || strcmp(systemInfo.machine, "i386") == 0) {
        return 1;
    }
    return 0;
#endif
}

int is_jailbroken_paths() {
    junk_code();
    const char *paths[] = {
        "/Applications/Cydia.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/bin/bash",
        "/usr/sbin/sshd",
        "/etc/apt",
        "/private/var/lib/apt/",
        "/private/var/stash",
        "/usr/libexec/cydia",
        "/usr/sbin/frida-server",
        "/usr/bin/ssh",
        "/var/checkra1n.dmg",
        "/.bootstrapped",
        NULL
    };
    for (int i = 0; paths[i] != NULL; i++) {
        if (access(paths[i], F_OK) == 0) {
            return 1;
        }
    }
    return 0;
}

int is_cydia_installed() {
    junk_code();
#if TARGET_OS_IPHONE
    Class lsApplicationWorkspace = objc_getClass("LSApplicationWorkspace");
    if (lsApplicationWorkspace) {
        SEL defaultWorkspace = sel_registerName("defaultWorkspace");
        SEL openApplicationWithBundleID = sel_registerName("openApplicationWithBundleID:");
        id workspace = ((id (*)(id, SEL))objc_msgSend)((id)lsApplicationWorkspace, defaultWorkspace);
        if (workspace) {
            int opened = ((int (*)(id, SEL, id))objc_msgSend)(workspace, openApplicationWithBundleID, @"com.saurik.Cydia");
            return opened;
        }
    }
#endif
    return 0;
}

int is_dyld_hijacked() {
    junk_code();
    if (getenv("DYLD_INSERT_LIBRARIES") != NULL) return 1;
    if (getenv("DYLD_FORCE_FLAT_NAMESPACE") != NULL) return 1;
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
    if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
        return 0;
    }
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

int ptrace_deny_attach() {
    junk_code();
    if (ptrace(PT_DENY_ATTACH, 0, 0, 0) == -1) {
        return 1;
    }
    return 0;
}

int is_substrate_loaded() {
    junk_code();
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        char buf[256];
        strncpy(buf, name, sizeof(buf));
        obfuscate_str(buf);
        if (strstr(buf, "ZbovyrFhofgengr") || strstr(buf, "Fhofgengr") || strstr(buf, "PlqvnFhofgengr")) {
            return 1;
        }
    }
    return 0;
}

int is_ssh_running() {
    junk_code();
    return (access("/usr/sbin/sshd", F_OK) == 0);
}

int is_apt_installed() {
    junk_code();
    return (access("/etc/apt", F_OK) == 0);
}

int is_frida_installed() {
    junk_code();
    return (access("/usr/sbin/frida-server", F_OK) == 0);
}

int is_debugserver_installed() {
    junk_code();
    return (access("/Developer/usr/bin/debugserver", F_OK) == 0);
}

int check_provisioning() {
    junk_code();
    FILE *fp = NULL;
    uint32_t size = 0;
    
    // تم إصلاح خطأ المصفوفة متغيرة الحجم (VLA) والتحويل الآمن للذاكرة
    _NSGetExecutablePath(NULL, &size);
    char *execPath = (char *)malloc(size); 
    _NSGetExecutablePath(execPath, &size);
    
    char *lastSlash = strrchr(execPath, '/');
    if (lastSlash) {
        *lastSlash = '\0';
        char path[MAXPATHLEN];
        snprintf(path, sizeof(path), "%s/embedded.mobileprovision", execPath);
        fp = fopen(path, "r");
    }
    free(execPath); // تنظيف الذاكرة بعد الاستخدام
    
    if (!fp) return 0;
    
    fseek(fp, 0, SEEK_END);
    long len = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    
    // تم إصلاح خطأ تصريح تحويل نوع الذاكرة (Casting)
    char *data = (char *)malloc(len + 1);
    fread(data, 1, len, fp);
    fclose(fp);
    data[len] = '\0';
    
    int is_debuggable = strstr(data, "<key>get-task-allow</key><true/>") != NULL;
    free(data);
    return is_debuggable;
}

int check_env() {
    junk_code();
    const char *vars[] = {
        "DYLD_PRINT_TO_FILE",
        "DYLD_INSERT_LIBRARIES",
        "CFNETWORK_DIAGNOSTICS",
        "OBJC_DISABLE_VALIDATION",
        NULL
    };
    for (int i = 0; vars[i] != NULL; i++) {
        if (getenv(vars[i]) != NULL) return 1;
    }
    return 0;
}

int check_ppid() {
    junk_code();
    pid_t ppid = getppid();
    char path[256];
    snprintf(path, sizeof(path), "/proc/%d/exe", ppid);
    if (access(path, F_OK) == 0) {
        char target[256];
        ssize_t len = readlink(path, target, sizeof(target)-1);
        if (len != -1) {
            target[len] = '\0';
            char buf[256];
            strncpy(buf, target, sizeof(buf));
            obfuscate_str(buf);
            if (strstr(buf, "qrohtfreire") || strstr(buf, "yyqo")) {
                return 1;
            }
        }
    }
    return 0;
}

int is_frida_loaded() {
    junk_code();
    return (dlopen("frida-agent.dylib", RTLD_NOLOAD) != NULL);
}

// دالة مجمعة للكشف عن جميع التهديدات
void perform_security_checks() {
    int threat_level = 0;
    
    if (is_simulator()) {
        printf("[Security] Simulator detected.\n");
        threat_level += 10;
    }
    if (is_jailbroken_paths()) {
        printf("[Security] Jailbreak paths detected.\n");
        threat_level += 20;
    }
    if (is_cydia_installed()) {
        printf("[Security] Cydia installed.\n");
        threat_level += 10;
    }
    if (is_dyld_hijacked()) {
        printf("[Security] DYLD hijacking detected.\n");
        threat_level += 30;
    }
    if (is_debugger_attached()) {
        printf("[Security] Debugger attached.\n");
        threat_level += 50;
    }
    if (ptrace_deny_attach()) {
        printf("[Security] ptrace failed, debugger may be present.\n");
        threat_level += 30;
    }
    if (is_substrate_loaded()) {
        printf("[Security] Substrate loaded.\n");
        threat_level += 20;
    }
    if (is_ssh_running()) {
        printf("[Security] SSH server found.\n");
        threat_level += 10;
    }
    if (is_apt_installed()) {
        printf("[Security] APT found.\n");
        threat_level += 10;
    }
    if (is_frida_installed() || is_frida_loaded()) {
        printf("[Security] Frida detected.\n");
        threat_level += 40;
    }
    if (is_debugserver_installed()) {
        printf("[Security] Debugserver found.\n");
        threat_level += 20;
    }
    if (check_provisioning()) {
        printf("[Security] App is debuggable (get-task-allow).\n");
        threat_level += 30;
    }
    if (check_env()) {
        printf("[Security] Suspicious environment variables.\n");
        threat_level += 10;
    }
    if (check_ppid()) {
        printf("[Security] Parent process is debugger.\n");
        threat_level += 40;
    }
    
    if (threat_level > 50) {
        printf("[Security] Threat level high (%d). Exiting.\n", threat_level);
        usleep(rand() % 100000);
        _exit(1);
    } else if (threat_level > 20) {
        printf("[Security] Threat level medium (%d). Some hooks may be disabled.\n", threat_level);
    }
}

// ============================================================================
// [10] Initialization
// ============================================================================

// تمت إضافة تعريف الدالة المفقودة (hooked_printf) لكي لا يتعطل DobbyHook
static int hooked_printf(const char * restrict format, ...) {
    va_list args;
    va_start(args, format);
    int ret = vprintf(format, args); // تمرير الطباعة بشكل طبيعي
    va_end(args);
    return ret;
}

__attribute__((constructor))
void init_hook() {
    srand((unsigned int)time(NULL));
    perform_security_checks();
    hook_all_functions();
    DobbyHook((void *)&printf, (void *)hooked_printf, (void **)&orig_printf);
}
