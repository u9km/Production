#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <errno.h>
#include <stdarg.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <dlfcn.h>

// =================================================================
// ======== بيئة الخداع الشامل (Non-Jailbreak Mirage Environment) ==
// =================================================================
struct rebinding { const char *name; void *replacement; void **replaced; };
extern "C" int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

#define CS_OPS_STATUS 0
#define CS_VALID 0x00000001
#define CS_GET_TASK_ALLOW 0x00000004 
#define CS_DEBUGGED 0x10000000       

// =================================================================
// ======== 1. الفلتر الذكي للمسارات (Smart Path Filter) ===========
// =================================================================

inline bool isBlacklistedPath(const char *path) {
    if (!path) return false;
    if (strstr(path, "/Logs") || strstr(path, "Saved/Logs") ||
        strstr(path, "RoleInfo.ini") || strstr(path, "Saved/Pandora") ||
        strstr(path, "Saved/CrashSight") || strstr(path, "MMKV") ||
        strstr(path, "tombstone") || strstr(path, "embedded.mobileprovision") ||
        strstr(path, "MobileSubstrate") || strstr(path, "Cydia")) { 
        return true;
    }
    return false;
}

// =================================================================
// ======== 2. نظام السراب للملفات (Mirage Filesystem) =============
// =================================================================
// بدلاً من القفل العنيف الذي يسبب باند، نوجه اللعبة للكتابة في الفراغ (/dev/null)

static int (*orig_open)(const char *path, int oflag, ...);
int my_open(const char *path, int oflag, ...) {
    mode_t mode = 0;
    if (oflag & O_CREAT) { va_list args; va_start(args, oflag); mode = va_arg(args, int); va_end(args); }
    
    if (isBlacklistedPath(path)) {
        if (oflag & O_CREAT) return orig_open("/dev/null", oflag, mode);
        return orig_open("/dev/null", oflag);
    }
    
    if (oflag & O_CREAT) return orig_open(path, oflag, mode);
    return orig_open(path, oflag);
}

static int (*orig_stat)(const char *path, struct stat *buf);
int my_stat(const char *path, struct stat *buf) {
    if (isBlacklistedPath(path)) return orig_stat("/dev/null", buf);
    return orig_stat(path, buf);
}

static int (*orig_lstat)(const char *path, struct stat *buf);
int my_lstat(const char *path, struct stat *buf) {
    if (isBlacklistedPath(path)) return orig_lstat("/dev/null", buf);
    return orig_lstat(path, buf);
}

static int (*orig_access)(const char *path, int amode);
int my_access(const char *path, int amode) {
    if (isBlacklistedPath(path)) return orig_access("/dev/null", amode);
    return orig_access(path, amode);
}

// =================================================================
// ======== 3. التلاعب بالشبكة (Network Mirage & Spoofer) ==========
// =================================================================

// إيهام الحماية بضعف الإنترنت بدلاً من القطع المفاجئ
static int (*orig_connect)(int socket, const struct sockaddr *address, socklen_t address_len);
int my_connect(int socket, const struct sockaddr *address, socklen_t address_len) {
    if (address && address->sa_family == AF_INET) {
        struct sockaddr_in *ipv4 = (struct sockaddr_in *)address;
        char ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &(ipv4->sin_addr), ip, INET_ADDRSTRLEN);
        
        // خنق بورتات التبليغ وسيرفرات تنسنت
        if (ntohs(ipv4->sin_port) == 8081 || strstr(ip, "119.29.") || strstr(ip, "101.32.")) {
            errno = ETIMEDOUT; // خطأ "انتهى وقت الاتصال" (يبدو طبيعياً للسيرفر)
            return -1;
        }
    }
    return orig_connect(socket, address, address_len);
}

static int (*orig_getaddrinfo)(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res);
int my_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **res) {
    if (node) {
        const char* blackhole[] = {
            "ocsp.apple.com", "ppq.apple.com", "world-gen.g.aaplimg.com",
            "app-measurement.com", "crashsight.com", "crashsight.qq.com", "bugly.qq.com"
        };
        for (int i = 0; i < 7; i++) { if (strstr(node, blackhole[i])) return EAI_NONAME; }
    }
    return orig_getaddrinfo(node, service, hints, res);
}

// =================================================================
// ======== 4. نواة شادو ماستر (Memory & Hardware Exploiter) =======
// =================================================================

// تزييف الهاردوير لمنع حظر الجهاز (Hardware ID Spoofer)
static int (*orig_sysctlbyname)(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
int my_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (name && (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.model") == 0)) {
        if (oldp && oldlenp) {
            const char* fake_device = "iPhone15,2"; // تزييف كآيفون 14 برو
            size_t len = strlen(fake_device) + 1;
            if (*oldlenp >= len) { memcpy(oldp, fake_device, len); *oldlenp = len; return 0; }
        }
    }
    return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
}

static char* (*orig_getenv)(const char *name);
char* my_getenv(const char *name) {
    if (name && (strcmp(name, "DYLD_INSERT_LIBRARIES") == 0 || strcmp(name, "Cydia") == 0)) return NULL;
    return orig_getenv(name);
}

static const char* (*orig_dyld_get_image_name)(uint32_t image_index);
const char* my_dyld_get_image_name(uint32_t image_index) {
    const char* name = orig_dyld_get_image_name(image_index);
    if (name && (strstr(name, "Shadow") || strstr(name, "AmarShield") || strstr(name, "dylib"))) {
        return "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation";
    }
    return name;
}

static int (*orig_dladdr)(const void *addr, Dl_info *info);
int my_dladdr(const void *addr, Dl_info *info) {
    int ret = orig_dladdr(addr, info);
    if (ret != 0 && info && info->dli_fname && (strstr(info->dli_fname, "Shadow") || strstr(info->dli_fname, "AmarShield"))) {
        info->dli_fname = "/usr/lib/system/libsystem_kernel.dylib";
        info->dli_sname = "mach_msg"; 
    }
    return ret;
}

static kern_return_t (*orig_task_info)(task_name_t target_task, task_flavor_t flavor, task_info_t task_info_out, mach_msg_type_number_t *task_info_outCnt);
kern_return_t my_task_info(task_name_t target_task, task_flavor_t flavor, task_info_t task_info_out, mach_msg_type_number_t *task_info_outCnt) {
    if (flavor == TASK_DYLD_INFO) return KERN_FAILURE;
    return orig_task_info(target_task, flavor, task_info_out, task_info_outCnt);
}

static int (*orig_sysctl)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
int my_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int ret = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    if (ret == 0 && name && namelen >= 3 && name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID) {
        if (oldp && oldlenp && *oldlenp >= sizeof(struct kinfo_proc)) {
            struct kinfo_proc *info = (struct kinfo_proc *)oldp;
            info->kp_proc.p_flag &= ~P_TRACED; // مسح التتبع
        }
    }
    return ret;
}

static int (*orig_csops)(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
int my_csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize) {
    int ret = orig_csops(pid, ops, useraddr, usersize);
    if (ops == CS_OPS_STATUS && useraddr) {
        uint32_t *status = (uint32_t *)useraddr;
        *status |= CS_VALID; *status &= ~CS_GET_TASK_ALLOW; *status &= ~CS_DEBUGGED;          
    }
    return ret;
}

// =================================================================
// ======== 5. تجاوز المتجر والتوقيع (Store & Cert Bypass) =========
// =================================================================

static IMP orig_appStoreReceiptURL;
NSURL* my_appStoreReceiptURL(id self, SEL _cmd) {
    NSString *fakeReceipt = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"_MASReceipt/receipt"];
    return [NSURL fileURLWithPath:fakeReceipt];
}

static IMP orig_fileExistsAtPath;
BOOL my_fileExistsAtPath(id self, SEL _cmd, NSString *path) {
    if (path && [path containsString:@"embedded.mobileprovision"]) return NO; 
    return ((BOOL(*)(id, SEL, NSString*))orig_fileExistsAtPath)(self, _cmd, path);
}

// =================================================================
// ======== محرك الإقلاع الفوري والمخفي (Stealth Zero-Delay Boot) ==
// =================================================================

void IgniteUltimateMirage() {
    // ربط 13 أداة دفاعية (تشمل نظام السراب للملفات والشبكة، ونظام شادو للذاكرة والهاردوير)
    struct rebinding r[] = { 
        {"open", (void*)my_open, (void**)&orig_open},
        {"stat", (void*)my_stat, (void**)&orig_stat},
        {"lstat", (void*)my_lstat, (void**)&orig_lstat},
        {"access", (void*)my_access, (void**)&orig_access},
        {"connect", (void*)my_connect, (void**)&orig_connect},
        {"getaddrinfo", (void*)my_getaddrinfo, (void**)&orig_getaddrinfo},
        {"sysctlbyname", (void*)my_sysctlbyname, (void**)&orig_sysctlbyname},
        {"getenv", (void*)my_getenv, (void**)&orig_getenv},
        {"_dyld_get_image_name", (void*)my_dyld_get_image_name, (void**)&orig_dyld_get_image_name},
        {"dladdr", (void*)my_dladdr, (void**)&orig_dladdr},
        {"task_info", (void*)my_task_info, (void**)&orig_task_info},
        {"sysctl", (void*)my_sysctl, (void**)&orig_sysctl},
        {"csops", (void*)my_csops, (void**)&orig_csops}
    };
    rebind_symbols(r, 13);
    
    // ربط تجاوزات متجر أبل
    Method receiptMethod = class_getInstanceMethod([NSBundle class], @selector(appStoreReceiptURL));
    orig_appStoreReceiptURL = method_getImplementation(receiptMethod);
    method_setImplementation(receiptMethod, (IMP)my_appStoreReceiptURL);
    
    Method fileMethod = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    orig_fileExistsAtPath = method_getImplementation(fileMethod);
    method_setImplementation(fileMethod, (IMP)my_fileExistsAtPath);
}

// نقطة الانطلاق في الثانية صفر (لا يوجد أي تأخير زمني ليكتشفنا anogs)
__attribute__((constructor)) static void inject_ultimate_mirage() { 
    IgniteUltimateMirage(); 
}
