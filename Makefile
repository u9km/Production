# =================================================================
# [ إعدادات البيئة والتجميع الصارم ]
# =================================================================
DEBUG = 0
FINALPACKAGE = 1
ARCHS = arm64
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AmarShield_Zeus
# تم حذف fishhook.c والاعتماد على ملف واحد فقط
AmarShield_Zeus_FILES = AmarShield_Zeus.mm

# =================================================================
# [ أعلام المترجم والرابط - إطفاء النور وتزييف الهوية ]
# =================================================================
# استخدام -g0 و -O3 لمسح معلومات التصحيح وتسريع الكود
AmarShield_Zeus_CFLAGS = -fobjc-arc -fvisibility=hidden -g0 -O3
AmarShield_Zeus_CXXFLAGS = -fobjc-arc -fvisibility=hidden -fno-rtti -fno-exceptions -g0 -O3 -std=c++14

# الضربة القاضية: ربط Dobby واستنساخ هوية libwebp الأصلية
AmarShield_Zeus_LDFLAGS = -Wl,-x -Wl,-S -dead_strip -ldobby -Wl,-install_name,@rpath/libwebp.framework/libwebp

include $(THEOS_MAKE_PATH)/tweak.mk

after-package::
	@echo "💎 [AmarShield Zeus] Compiled Successfully with Zero-Trace Flags & libwebp Identity."
