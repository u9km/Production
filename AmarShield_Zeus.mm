#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <errno.h>
#include <stdarg.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <dlfcn.h>

struct rebinding { const char *name; void *replacement; void **replaced; };
extern "C" int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel);

#define CS_OPS_STATUS 0
#define CS_VALID 0x00000001
#define CS_GET_TASK_ALLOW 0x00000004 
#define CS_DEBUGGED 0x10000000       

// =================================================================
// ======== 1. الفلتر المصحح (السماح بتسجيل الدخول) ================
// =================================================================

inline bool isDangerousPath(const char *path) {
    if (!path) return false;
    // تم إزالة MMKV و RoleInfo.ini لكي لا يحدث كراش في تسجيل الدخول
    return (strstr(path, "/Logs") || strstr(path, "Saved/Logs") ||
            strstr(path, "Saved/Pandora") || strstr(path, "Saved/CrashSight") ||
            strstr(path, "tombstone") || strstr(path, "embedded.mobileprovision") ||
            strstr(path, "MobileSubstrate") || strstr(path, "Cydia"));
}

static int (*orig_open)(const char *path, int oflag, ...);
int my_open(const char *path, int oflag, ...) {
    mode_t mode = 0;
    if (oflag & O_CREAT) { va_list args; va_start(args, oflag); mode = va_arg(args, int); va_end(args); }
    if (isDangerousPath(path)) {
        if (oflag & O_CREAT) return orig_open("/dev/null", oflag, mode);
        return orig_open("/dev/null", oflag);
    }
    if (oflag & O_CREAT) return orig_open(path, oflag, mode);
    return orig_open(path, oflag);
}

static int (*orig_stat)(const char *path, struct stat *buf);
int my_stat(const char *path, struct stat *buf) {
    if (isDangerousPath(path)) return orig_stat("/dev/null", buf);
    return orig_stat(path, buf);
}

// =================================================================
// ======== 2. التلاعب بالشبكة (الخنق التكتيكي) ====================
// =================================================================

static int (*orig_connect)(int socket, const struct sockaddr *address, socklen_t address_len);
int my_connect(int socket, const struct sockaddr *address, socklen_t address_len) {
    if (address && address->sa_family == AF_INET) {
        struct sockaddr_in *ipv4 = (struct sockaddr_in *)address;
        char ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &(ipv4->sin_addr), ip, INET_ADDRSTRLEN);
        if (ntohs(ipv4->sin_port) == 8081 || strstr(ip, "119.29.") || strstr(ip, "101.32.")) {
            errno = ETIMEDOUT; return -1;
        }
    }
    return orig_connect(socket, address, address_len);
}

// =================================================================
// ======== 3. حماية "التفعيلات الفل" (Memory & Anti-Dump) ========
// =================================================================

static kern_return_t (*orig_task_info)(task_name_t target_task, task_flavor_t flavor, task_info_t task_info_out, mach_msg_type_number_t *task_info_outCnt);
kern_return_t my_task_info(task_name_t target_task, task_flavor_t flavor, task_info_t task_info_out, mach_msg_type_number_t *task_info_outCnt) {
    if (flavor == TASK_DYLD_INFO) return KERN_FAILURE;
    return orig_task_info(target_task, flavor, task_info_out, task_info_outCnt);
}

static const char* (*orig_dyld_get_image_name)(uint32_t image_index);
const char* my_dyld_get_image_name(uint32_t image_index) {
    const char* name = orig_dyld_get_image_name(image_index);
    if (name && (strstr(name, "Shadow") || strstr(name, "AmarShield") || strstr(name, "dylib"))) {
        return "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation";
    }
    return name;
}

static int (*orig_sysctl)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
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

static void* (*orig_dlsym)(void *handle, const char *symbol);
void* my_dlsym(void *handle, const char *symbol) {
    if (symbol) {
        if (strcmp(symbol, "open") == 0) return (void*)my_open;
        if (strcmp(symbol, "stat") == 0) return (void*)my_stat;
        if (strcmp(symbol, "connect") == 0) return (void*)my_connect;
        if (strcmp(symbol, "task_info") == 0) return (void*)my_task_info;
        if (strcmp(symbol, "sysctl") == 0) return (void*)my_sysctl;
        
        if (strcmp(symbol, "vm_read") == 0 || strcmp(symbol, "vm_region") == 0) {
            return NULL; 
        }
    }
    return orig_dlsym(handle, symbol);
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
// ======== الإقلاع الآمن ==========================================
// =================================================================

void IgniteMontazerCore() {
    struct rebinding r[] = { 
        {"open", (void*)my_open, (void**)&orig_open},
        {"stat", (void*)my_stat, (void**)&orig_stat},
        {"connect", (void*)my_connect, (void**)&orig_connect},
        {"task_info", (void*)my_task_info, (void**)&orig_task_info},
        {"_dyld_get_image_name", (void*)my_dyld_get_image_name, (void**)&orig_dyld_get_image_name},
        {"sysctl", (void*)my_sysctl, (void**)&orig_sysctl},
        {"csops", (void*)my_csops, (void**)&orig_csops},
        {"dlsym", (void*)my_dlsym, (void**)&orig_dlsym}
    };
    rebind_symbols(r, 8);
    
    Method receiptMethod = class_getInstanceMethod([NSBundle class], @selector(appStoreReceiptURL));
    orig_appStoreReceiptURL = method_getImplementation(receiptMethod);
    method_setImplementation(receiptMethod, (IMP)my_appStoreReceiptURL);
    
    Method fileMethod = class_getInstanceMethod([NSFileManager class], @selector(fileExistsAtPath:));
    orig_fileExistsAtPath = method_getImplementation(fileMethod);
    method_setImplementation(fileMethod, (IMP)my_fileExistsAtPath);

    // إشعار التحقق الآمن (تم إصلاح الكراش المحتمل هنا أيضاً بتأكد من وجود الـ window)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIWindowScene* s in [UIApplication sharedApplication].connectedScenes) {
            if (s.activationState == UISceneActivationStateForegroundActive) { win = s.windows.firstObject; break; }
        }
        if (!win) return;
        
        UILabel *toast = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 260, 45)];
        toast.center = CGPointMake(win.center.x, 60);
        toast.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.95];
        toast.textColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.4 alpha:1.0]; 
        toast.textAlignment = NSTextAlignmentCenter;
        toast.font = [UIFont boldSystemFontOfSize:15];
        toast.text = @"✅ V6.1 Shield (Login Fixed)";
        toast.layer.cornerRadius = 22.5;
        toast.clipsToBounds = YES;
        toast.layer.borderWidth = 1.5;
        toast.layer.borderColor = [UIColor greenColor].CGColor;
        toast.alpha = 0.0;
        
        [win addSubview:toast];
        [UIView animateWithDuration:0.5 animations:^{ toast.alpha = 1.0; } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.5 delay:3.0 options:UIViewAnimationOptionCurveEaseOut animations:^{ toast.alpha = 0.0; } completion:^(BOOL finished) { [toast removeFromSuperview]; }];
        }];
    });
}

__attribute__((constructor)) static void inject_montazer_core() { 
    IgniteMontazerCore(); 
}
