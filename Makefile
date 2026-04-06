# المعماريات المطلوبة
ARCHS = arm64 arm64e

# إصدار النظام المستهدف
TARGET = iphone:clang:latest:13.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BlackIOS

# ملف الكود البرمجي
BlackIOS_FILES = Tweak.mm
# أطر العمل المطلوبة للواجهة والنظام
BlackIOS_FRAMEWORKS = UIKit Foundation CoreGraphics
# تفعيل إدارة الذاكرة التلقائية
BlackIOS_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
