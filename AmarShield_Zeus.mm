// ============================================================================
// [0] ZEUS APEX ULTIMATE - 2026 EDITION (FINAL STABLE REVISION)
// الشمولية المطلقة: نظام استثناءات ماخ + تشفير الأشباح + تجاوز كافة الحمايات
// ============================================================================
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdint.h>
#include <pthread.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <sys/ptrace.h>
#include <sys/utsname.h>
#include <sys/param.h>
#include <sys/mount.h>
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
#include <Security/SecKey.h>

// إصلاح تعريفات النظام
extern "C" void sys_icache_invalidate(void *start, size_t len);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmodule-import-in-extern-c"
#include <openssl/rsa.h>
#include <openssl/x509.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/ssl.h>
#pragma clang diagnostic pop

// ============================================================================
// [1] Advanced Compile-Time XOR String Obfuscator
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
        constexpr char key = 0x1D; \
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
// [2] ZEUS APEX CORE: Mach Exception Engine (BRK Trap)
// ============================================================================
static mach_port_t exception_port;
static pthread_t exception_thread;

struct StealthHook {
    void* target_address;
    void* replacement_address;
    uint32_t original_instruction;
};

#define MAX_HOOKS 256
static StealthHook active_hooks[MAX_HOOKS];
static int hook_count = 0;

#define ARM64_BRK 0xD4200020

extern "C" boolean_t exc_server(mach_msg_header_t *request, mach_msg_header_t *reply);
kern_return_t catch_exception_raise(mach_port_t exception_port, mach_port_t thread, mach_port_t task, exception_type_t exception, exception_data_t code, mach_msg_type_number_t codeCnt) {
    arm_thread_state64_t state;
    mach_msg_type_number_t state_count = ARM_THREAD_STATE64_COUNT;
    thread_get_state(thread, ARM_THREAD_STATE64, (thread_state_t)&state, &state_count);
    void* crashed_pc = (void*)state.__pc;

    for (int i = 0; i < hook_count; i++) {
        if (active_hooks[i].target_address == crashed_pc) {
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
    mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &exception_port);
    mach_port_insert_right(mach_task_self(), exception_port, exception_port, MACH_MSG_TYPE_MAKE_SEND);
    task_set_exception_ports(mach_task_self(), EXC_MASK_BREAKPOINT, exception_port, EXCEPTION_DEFAULT, ARM_THREAD_STATE64);
    pthread_create(&exception_thread, NULL, exception_handler_thread, NULL);
}

void apex_hook(void* target, void* replacement) {
    if (!target || hook_count >= MAX_HOOKS) return;
    active_hooks[hook_count].target_address = target;
    active_hooks[hook_count].replacement_address = replacement;
    active_hooks[hook_count].original_instruction = *(uint32_t*)target;
    hook_count++;
    
    mprotect((void*)(((uintptr_t)target) & ~(PAGE_SIZE - 1)), PAGE_SIZE, PROT_READ | PROT_WRITE | PROT_EXEC);
    *(uint32_t*)target = ARM64_BRK;
    mprotect((void*)(((uintptr_t)target) & ~(PAGE_SIZE - 1)), PAGE_SIZE, PROT_READ | PROT_EXEC);
    sys_icache_invalidate(target, 4);
}

static void safe_hook_by_name(const char* func_name, void* replacement) {
    void* target_sym = dlsym(RTLD_DEFAULT, func_name);
    if (target_sym) apex_hook(target_sym, replacement);
}

// دالة الضجيج البرمجي (junk_code) - تم تفعيلها لمنع خطأ unused
static inline void junk_code(void) {
    volatile int a = 5, b = 10;
    volatile int c = a * b + a - b;
    (void)c;
}

// ============================================================================
// [3] All Original Function Pointers
// ============================================================================
__attribute__((unused)) static int (*orig_printf)(const char *format, ...);
__attribute__((unused)) static int (*orig_ptrace)(int request, pid_t pid, caddr_t addr, int data);
__attribute__((unused)) static int (*orig_sysctl)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
__attribute__((unused)) static int (*orig_sysctlbyname)(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
__attribute__((unused)) static void* (*orig_dlopen)(const char *path, int mode);
__attribute__((unused)) static void* (*orig_dlsym)(void *handle, const char *symbol);
__attribute__((unused)) static int (*orig_task_for_pid)(mach_port_t target_tport, int pid, mach_port_t *tn);
__attribute__((unused)) static int (*orig_vm_read_overwrite)(vm_map_t target_task, vm_address_t address, vm_size_t size, vm_address_t data, vm_size_t *outsize);
__attribute__((unused)) static int (*orig_vm_write)(vm_map_t target_task, vm_address_t address, vm_offset_t data, mach_msg_type_number_t dataCnt);
__attribute__((unused)) static int (*orig_vm_protect)(vm_map_t target_task, vm_address_t address, vm_size_t size, boolean_t set_max, vm_prot_t new_protection);
__attribute__((unused)) static int (*orig_mach_vm_protect)(vm_map_t target_task, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_max, vm_prot_t new_protection);

__attribute__((unused)) static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef query, CFTypeRef *result);
__attribute__((unused)) static OSStatus (*orig_SecItemAdd)(CFDictionaryRef attributes, CFTypeRef *result);
__attribute__((unused)) static OSStatus (*orig_SecItemUpdate)(CFDictionaryRef query, CFDictionaryRef attributesToUpdate);
__attribute__((unused)) static OSStatus (*orig_SecItemDelete)(CFDictionaryRef query);
__attribute__((unused)) static SecKeyRef (*orig_SecKeyCreateRandomKey)(CFDictionaryRef parameters, CFErrorRef *error);
__attribute__((unused)) static SecKeyRef (*orig_SecKeyCopyPublicKey)(SecKeyRef key);
__attribute__((unused)) static CFDataRef (*orig_SecKeyCreateSignature)(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFErrorRef *error);
__attribute__((unused)) static Boolean (*orig_SecKeyVerifySignature)(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFDataRef signature, CFErrorRef *error);

__attribute__((unused)) static CCCryptorStatus (*orig_CCCrypt)(CCOperation op, CCAlgorithm alg, CCOptions options, const void *key, size_t keyLength, const void *iv, const void *dataIn, size_t dataInLength, void *dataOut, size_t dataAvailable, size_t *dataMoved);

__attribute__((unused)) static int (*orig_RSA_verify)(int type, const unsigned char *m, unsigned int m_len, const unsigned char *sig, unsigned int sig_len, RSA *rsa);
__attribute__((unused)) static int (*orig_RSA_sign)(int type, const unsigned char *m, unsigned int m_len, unsigned char *sig, unsigned int *sig_len, RSA *rsa);
__attribute__((unused)) static int (*orig_EVP_PKEY_verify)(EVP_PKEY_CTX *ctx, const unsigned char *sig, size_t sig_len, const unsigned char *tbs, size_t tbs_len);
__attribute__((unused)) static int (*orig_X509_verify_cert)(X509_STORE_CTX *ctx);
__attribute__((unused)) static int (*orig_X509_check_private_key)(X509 *x509, EVP_PKEY *pkey);
__attribute__((unused)) static EVP_PKEY* (*orig_PEM_read_bio_PrivateKey)(BIO *bp, EVP_PKEY **x, pem_password_cb *cb, void *u);
__attribute__((unused)) static int (*orig_SSL_CTX_use_PrivateKey_file)(SSL_CTX *ctx, const char *file, int type);
__attribute__((unused)) static int (*orig_SSL_CTX_check_private_key)(SSL_CTX *ctx);
__attribute__((unused)) static int (*orig_SSL_CTX_load_verify_locations)(SSL_CTX *ctx, const char *CAfile, const char *CApath);

__attribute__((unused)) static bool (*orig_is_jb)(void);
__attribute__((unused)) static bool (*orig_ROOTED)(void);
__attribute__((unused)) static bool (*orig_DEBUGGER_ATTACHED)(void);
__attribute__((unused)) static bool (*orig_isDebuggerAttached)(void);
__attribute__((unused)) static bool (*orig_checkJailbreak)(void);
__attribute__((unused)) static bool (*orig_hasCydia)(void);
__attribute__((unused)) static bool (*orig_isJailbroken)(void);
__attribute__((unused)) static bool (*orig_amIBeingDebugged)(void);

__attribute__((unused)) static IMP orig_LAContext_evaluatePolicy;
__attribute__((unused)) static IMP orig_LAContext_canEvaluatePolicy;
__attribute__((unused)) static IMP orig_UIDevice_identifierForVendor;

// ============================================================================
// [4] Intelligent Replacement Functions (Bypass Logic)
// ============================================================================
static int my_ptrace(int request, pid_t pid, caddr_t addr, int data) {
    junk_code();
    if (request == PT_DENY_ATTACH) return 0;
    return 0;
}

static int my_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    junk_code();
    if (oldp && namelen == 4 && name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID) {
        struct kinfo_proc *kp = (struct kinfo_proc *)oldp;
        kp->kp_proc.p_flag &= ~P_TRACED;
        return 0;
    }
    return -1;
}

static int my_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    junk_code();
    if (name) {
        if (strcmp(name, OBF("kern.proc")) == 0 || strcmp(name, OBF("debug")) == 0) {
            if (oldp && oldlenp) { memset(oldp, 0, *oldlenp); return 0; }
        }
    }
    return -1;
}

static void* my_dlopen(const char *path, int mode) {
    junk_code();
    if (path && (strstr(path, OBF("Frida")) || strstr(path, OBF("Substrate")))) return NULL;
    return dlsym(RTLD_NEXT, "dlopen");
}

static void* my_dlsym(void *handle, const char *symbol) {
    junk_code();
    if (symbol) {
        if (strcmp(symbol, OBF("ptrace")) == 0 || strcmp(symbol, OBF("sysctl")) == 0 || 
            strcmp(symbol, OBF("task_for_pid")) == 0 || strcmp(symbol, OBF("vm_read")) == 0) { return NULL; }
    }
    return NULL;
}

static int my_task_for_pid(mach_port_t target_tport, int pid, mach_port_t *tn) { junk_code(); return KERN_FAILURE; }
static int my_vm_read_overwrite(vm_map_t target_task, vm_address_t address, vm_size_t size, vm_address_t data, vm_size_t *outsize) { junk_code(); return KERN_FAILURE; }
static int my_vm_protect(vm_map_t target_task, vm_address_t address, vm_size_t size, boolean_t set_max, vm_prot_t new_protection) { junk_code(); return KERN_SUCCESS; }

// Keychain & SecKey Bypass
static OSStatus my_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) { junk_code(); return errSecItemNotFound; }
static OSStatus my_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) { junk_code(); return errSecDuplicateItem; }
static OSStatus my_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) { junk_code(); return errSecItemNotFound; }
static OSStatus my_SecItemDelete(CFDictionaryRef query) { junk_code(); return errSecSuccess; }
static SecKeyRef my_SecKeyCreateRandomKey(CFDictionaryRef parameters, CFErrorRef *error) { junk_code(); return NULL; }
static CFDataRef my_SecKeyCreateSignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFErrorRef *error) { junk_code(); return CFDataCreate(NULL, (const UInt8*)OBF("fake_sig"), 8); }
static Boolean my_SecKeyVerifySignature(SecKeyRef key, SecKeyAlgorithm algorithm, CFDataRef dataToSign, CFDataRef signature, CFErrorRef *error) { junk_code(); return true; }

// CommonCrypto
static CCCryptorStatus my_CCCrypt(CCOperation op, CCAlgorithm alg, CCOptions options, const void *key, size_t keyLength, const void *iv, const void *dataIn, size_t dataInLength, void *dataOut, size_t dataAvailable, size_t *dataMoved) { junk_code(); if (dataOut && dataMoved) { memcpy(dataOut, dataIn, dataInLength); *dataMoved = dataInLength; return kCCSuccess; } return kCCSuccess; }

// OpenSSL
static int my_RSA_verify(int type, const unsigned char *m, unsigned int m_len, const unsigned char *sig, unsigned int sig_len, RSA *rsa) { return 1; }
static int my_X509_verify_cert(X509_STORE_CTX *ctx) { return 1; }
static int my_SSL_CTX_check_private_key(SSL_CTX *ctx) { return 1; }

// Environment Hooks
static bool my_is_jb(void) { return false; }
static bool my_ROOTED(void) { return false; }
static bool my_DEBUGGER_ATTACHED(void) { return false; }
static bool my_isDebuggerAttached(void) { return false; }
static bool my_checkJailbreak(void) { return false; }
static bool my_hasCydia(void) { return false; }
static bool my_isJailbroken_c(void) { return false; }
static bool my_amIBeingDebugged(void) { return false; }

static id my_UIDevice_identifierForVendor(id self, SEL _cmd) { junk_code(); return [[NSUUID alloc] initWithUUIDString:[NSString stringWithUTF8String:OBF("00000000-0000-0000-0000-000000000000")]]; }
static void my_LAContext_evaluatePolicy(id self, SEL _cmd, LAPolicy policy, id reply) { junk_code(); void (^replyBlock)(BOOL success, NSError *error) = reply; if (replyBlock) replyBlock(YES, nil); }
static BOOL my_LAContext_canEvaluatePolicy(id self, SEL _cmd, LAPolicy policy, NSError **error) { junk_code(); return YES; }

// ============================================================================
// [5] Master Environment Checks
// ============================================================================
int is_simulator() { struct utsname s; uname(&s); if (strcmp(s.machine, OBF("x86_64")) == 0 || strcmp(s.machine, OBF("i386")) == 0) return 1; return 0; }
int is_jailbroken_paths() {
    const char *paths[] = {OBF("/Applications/Cydia.app"), OBF("/usr/sbin/sshd"), OBF("/bin/bash"), OBF("/etc/apt"), OBF("/usr/bin/ssh"), OBF("/usr/sbin/frida-server"), OBF("/.bootstrapped"), NULL};
    for (int i = 0; paths[i]; i++) { if (access(paths[i], F_OK) == 0) return 1; }
    return 0;
}
int is_debugger_attached() { int n[4]={CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()}; struct kinfo_proc k; size_t s=sizeof(k); sysctl(n,4,&k,&s,NULL,0); return (k.kp_proc.p_flag & P_TRACED); }

void perform_security_checks() {
    int t = 0;
    if (is_simulator()) t += 10;
    if (is_jailbroken_paths()) t += 20;
    if (is_debugger_attached()) t += 50;
    if (t > 50) _exit(1);
}

// ============================================================================
// [6] Master Ignition (The Apex Hook List)
// ============================================================================
void hook_all_functions() {
    safe_hook_by_name(OBF("ptrace"), (void*)my_ptrace);
    safe_hook_by_name(OBF("sysctl"), (void*)my_sysctl);
    safe_hook_by_name(OBF("sysctlbyname"), (void*)my_sysctlbyname);
    safe_hook_by_name(OBF("dlopen"), (void*)my_dlopen);
    safe_hook_by_name(OBF("dlsym"), (void*)my_dlsym);
    safe_hook_by_name(OBF("task_for_pid"), (void*)my_task_for_pid);
    safe_hook_by_name(OBF("vm_read_overwrite"), (void*)my_vm_read_overwrite);
    safe_hook_by_name(OBF("vm_protect"), (void*)my_vm_protect);
    
    // تفعيل هوكات Keychain & SecKey لضمان استخدام الدوال وعدم ظهور خطأ unused
    safe_hook_by_name(OBF("SecItemCopyMatching"), (void*)my_SecItemCopyMatching);
    safe_hook_by_name(OBF("SecItemAdd"), (void*)my_SecItemAdd);
    safe_hook_by_name(OBF("SecItemUpdate"), (void*)my_SecItemUpdate);
    safe_hook_by_name(OBF("SecItemDelete"), (void*)my_SecItemDelete);
    safe_hook_by_name(OBF("SecKeyCreateRandomKey"), (void*)my_SecKeyCreateRandomKey);
    safe_hook_by_name(OBF("SecKeyCreateSignature"), (void*)my_SecKeyCreateSignature);
    safe_hook_by_name(OBF("SecKeyVerifySignature"), (void*)my_SecKeyVerifySignature);
    
    safe_hook_by_name(OBF("CCCrypt"), (void*)my_CCCrypt);
    safe_hook_by_name(OBF("RSA_verify"), (void*)my_RSA_verify);
    safe_hook_by_name(OBF("X509_verify_cert"), (void*)my_X509_verify_cert);
    safe_hook_by_name(OBF("SSL_CTX_check_private_key"), (void*)my_SSL_CTX_check_private_key);

    const char *jb_f[] = {OBF("is_jb"), OBF("ROOTED"), OBF("DEBUGGER_ATTACHED"), OBF("isDebuggerAttached"), OBF("checkJailbreak"), OBF("hasCydia"), OBF("isJailbroken"), OBF("amIBeingDebugged")};
    void *jb_r[] = {(void*)my_is_jb, (void*)my_ROOTED, (void*)my_DEBUGGER_ATTACHED, (void*)my_isDebuggerAttached, (void*)my_checkJailbreak, (void*)my_hasCydia, (void*)my_isJailbroken_c, (void*)my_amIBeingDebugged};
    for (int i = 0; i < 8; i++) { safe_hook_by_name(jb_f[i], jb_r[i]); }

    Class dev = objc_getClass(OBF("UIDevice"));
    if (dev) {
        Method m = class_getInstanceMethod(dev, @selector(identifierForVendor));
        if (m) { orig_UIDevice_identifierForVendor = method_getImplementation(m); method_setImplementation(m, (IMP)my_UIDevice_identifierForVendor); }
    }
    Class la = objc_getClass(OBF("LAContext"));
    if (la) {
        Method m1 = class_getInstanceMethod(la, @selector(evaluatePolicy:localizedReason:reply:));
        if (m1) { orig_LAContext_evaluatePolicy = method_getImplementation(m1); method_setImplementation(m1, (IMP)my_LAContext_evaluatePolicy); }
        Method m2 = class_getInstanceMethod(la, @selector(canEvaluatePolicy:error:));
        if (m2) { orig_LAContext_canEvaluatePolicy = method_getImplementation(m2); method_setImplementation(m2, (IMP)my_LAContext_canEvaluatePolicy); }
    }
}

// ============================================================================
// [7] Initialization
// ============================================================================
static int hooked_printf(const char * __restrict format, ...) { va_list a; va_start(a, format); int r = vprintf(format, a); va_end(a); return r; }

__attribute__((constructor))
void init_hook() {
    srand((unsigned int)time(NULL));
    perform_security_checks();
    init_zeus_engine();
    hook_all_functions();
    safe_hook_by_name(OBF("printf"), (void *)hooked_printf);
}
