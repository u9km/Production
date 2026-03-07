# =================================================================
# [ إعدادات البيئة الأساسية ]
# =================================================================
DEBUG = 0
FINALPACKAGE = 1
ARCHS = arm64
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AmarShield_Zeus
AmarShield_Zeus_FILES = AmarShield_Zeus.mm

# =================================================================
# [ أعلام المترجم (Compiler Flags) - التخفي وتقليص الحجم ]
# =================================================================
# -Oz : خوارزمية ضغط الحجم القصوى في Clang (تجعل الحجم مطابقاً للملفات الأصلية)
# -fno-ident : تمنع المترجم من ترك بصمة إصدار Clang/Xcode داخل الملف
# -fmerge-all-constants : دمج الثوابت المتشابهة لتقليل مساحة قسم __rodata
AmarShield_Zeus_CFLAGS = -fobjc-arc -fvisibility=hidden -g0 -Oz -fno-ident -fmerge-all-constants -I.
AmarShield_Zeus_CXXFLAGS = -fobjc-arc -fvisibility=hidden -fno-rtti -fno-exceptions -g0 -Oz -fno-ident -fmerge-all-constants -std=c++14 -I.

# =================================================================
# [ أعلام الرابط (Linker Flags) - الإعدام وتزييف الهوية ]
# =================================================================
# -Wl,-x و -Wl,-S : مسح جميع الرموز المحلية وبيانات تصحيح الأخطاء من جدول الرموز
# -dead_strip : إزالة أي دالة أو متغير لم يتم استخدامه فعلياً في الكود
# -install_name : حقن الهوية الأصلية لملف الصور داخل الـ Header
AmarShield_Zeus_LDFLAGS = -Wl,-x -Wl,-S -dead_strip -L. -ldobby -Wl,-install_name,@rpath/libwebp.framework/libwebp

include $(THEOS_MAKE_PATH)/tweak.mk

after-package::
	@echo "💎 [Zeus Engine] Compiled with Maximum Size Optimization & Zero-Trace Symbols."
