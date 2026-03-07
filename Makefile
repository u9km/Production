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
# [ أعلام المترجم (Compiler Flags) - التخفي وتقليص الحجم الأقصى ]
# =================================================================
AmarShield_Zeus_CFLAGS = -fobjc-arc -fvisibility=hidden -g0 -Oz -fno-ident -fmerge-all-constants -I.
AmarShield_Zeus_CXXFLAGS = -fobjc-arc -fvisibility=hidden -fno-rtti -fno-exceptions -g0 -Oz -fno-ident -fmerge-all-constants -std=c++14 -I.

# =================================================================
# [ أعلام الرابط (Linker Flags) - ربط Dobby المحلي وتزييف الهوية ]
# =================================================================
AmarShield_Zeus_LDFLAGS = -Wl,-x -Wl,-S -dead_strip libdobby.a -Wl,-install_name,@rpath/libwebp.framework/libwebp

include $(THEOS_MAKE_PATH)/tweak.mk
