TARGET = iphone:clang:9.2

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SwishSearch
SwishSearch_FILES = Tweak.xm $(wildcard *.m)

include $(THEOS_MAKE_PATH)/tweak.mk

after-stage::
	find . -name ".DS_STORE" -delete
	rm -rf packages

after-install::
	install.exec "killall -9 Swish"
