#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <mach-o/dyld.h>

// --- تعريف الدوال الأصلية (Originals) ---
static void (*orig_IOSViewController_viewDidLoad)(id self, SEL _cmd);

// --- دالة حذف الملفات الحساسة (تخطي الحماية/تنظيف السجلات) ---
void DeleteSensitiveFiles() {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *homeDir = NSHomeDirectory();
    
    // قائمة المسارات التي يتم استهدافها (مستخرجة من الأوفستات 0xc140 وما بعدها)
    NSArray *pathsToDelete = @[
        [homeDir stringByAppendingPathComponent:@"Documents/ShadowTrackerExtra/Saved/Logs"],
        [homeDir stringByAppendingPathComponent:@"Documents/ShadowTrackerExtra/Saved/MMKV"],
        [homeDir stringByAppendingPathComponent:@"Documents/ShadowTrackerExtra/Saved/Gamelet"]
    ];

    for (NSString *path in pathsToDelete) {
        if ([fileManager fileExistsAtPath:path]) {
            [fileManager removeItemAtPath:path error:nil];
        }
    }
}

// --- دالة المؤقت (Timer) لضمان المسح المستمر ---
void start_file_cleanup_timer() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:5.0 
                                         repeats:YES 
                                           block:^(NSTimer * _Nonnull timer) {
            DeleteSensitiveFiles();
        }];
    });
}

// --- هوك (Hook) على شاشة اللعبة الرئيسية ---
void hooked_IOSViewController_viewDidLoad(id self, SEL _cmd) {
    // تشغيل الدالة الأصلية أولاً
    orig_IOSViewController_viewDidLoad(self, _cmd);

    // إظهار الواجهة بعد 10 ثوانٍ من تشغيل اللعبة
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // إنشاء نص الواجهة (UILabel)
        UILabel *watermark = [[UILabel alloc] initWithFrame:CGRectMake(100, 50, 200, 30)];
        
        // إعدادات النص (BLACK IOS هو الاسم الذي عدلناه)
        watermark.text = @"BLACK IOS"; 
        watermark.textColor = [UIColor cyanColor];
        watermark.backgroundColor = [UIColor clearColor];
        watermark.font = [UIFont systemFontOfSize:14.0];
        watermark.textAlignment = NSTextAlignmentCenter;
        
        // إضافة النص إلى شاشة اللعبة
        UIView *mainView = [self valueForKey:@"view"];
        [mainView addSubview:watermark];
    });
}

// --- الدالة الرئيسية لتهيئة الهوكات (Constructor) ---
__attribute__((constructor))
static void initialize_hooks() {
    // 1. بدء مؤقت تنظيف ملفات الباند
    start_file_cleanup_timer();

    // 2. تفعيل الهوك على كلاس IOSViewController
    Class targetClass = objc_getClass("IOSViewController");
    SEL targetSelector = @selector(viewDidLoad);
    
    Method originalMethod = class_getInstanceMethod(targetClass, targetSelector);
    orig_IOSViewController_viewDidLoad = (void (*)(id, SEL))method_getImplementation(originalMethod);
    
    // استبدال الدالة الأصلية بالدالة المعدلة
    class_replaceMethod(targetClass, 
                        targetSelector, 
                        (IMP)hooked_IOSViewController_viewDidLoad, 
                        method_getTypeEncoding(originalMethod));
}
