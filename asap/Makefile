ifeq ($(LLVM_DIR),)
    $(error "Please set LLVM_DIR")
endif

CC=$(LLVM_DIR)/bin/clang
OPT=$(LLVM_DIR)/bin/opt

CFLAGS  = -flto -fsanitize=address -fno-omit-frame-pointer -fno-sanitize-recover \
          -fsanitize-blacklist=$(realpath ../asap/asan_blacklist.txt) \
          -g
LINUX_CFLAGS = -Wl,--plugin-opt=save-temps -Wl,--export-dynamic
MACOS_CFLAGS = -Wl,-save-temps

ifeq ($(shell ls $(LLVM_DIR)/lib/LLVMgold.so 2>&1),$(LLVM_DIR)/lib/LLVMgold.so)
    LINUX=1

    AR=ar --plugin=$(LLVM_DIR) -r
    RANLIB=ar --plugin=$(LLVM_DIR) -s
    ASAP_LIB=$(LLVM_DIR)/lib/SanityChecks.so
    GCOV_FLAGS=-L$(LLVM_DIR)/lib/clang/3.4/lib/linux -lclang_rt.profile-x86_64
else
    ASAP_LIB=$(LLVM_DIR)/lib/SanityChecks.dylib
    GCOV_FLAGS=-L$(LLVM_DIR)/lib/clang/3.4/lib/darwin -lclang_rt.profile_osx
endif

stamps/configure:
	mkdir stamps
ifeq ($(LINUX),1)
	cd .. && CC=$(CC) RANLIB=$(RANLIB) ./Configure $(CFLAGS) $(LINUX_CFLAGS)
else
	cd .. && CC=$(CC)                  ./Configure $(CFLAGS) $(MACOS_CFLAGS)
endif
	touch stamps/configure

stamps/depend: stamps/configure
	cd .. && $(MAKE) clean depend
	touch stamps/depend

../apps/openssl: stamps/depend
ifeq ($(LINUX),1)
	cd .. && $(MAKE) AR=$(AR)
else
	cd .. && $(MAKE)
endif

# Compile a version of openssl with profiling
../apps/openssl.gcov.o: ../apps/openssl.lto.opt.bc
	$(OPT) -load $(ASAP_LIB) -full-gcov-profiling -exit-instead-of-abort -o $@ $<

../apps/openssl.gcov: ../apps/openssl.gcov.o
	$(CC) $(CFLAGS) -o $@ $< $(GCOV_FLAGS) -L.. -lssl -L.. -lcrypto

# Compile a version of openssl with ASAP optimization
../apps/openssl.as.%.bc: ../apps/openssl.lto.opt.bc openssl.lto.opt.gcda
	$(OPT) -load $(ASAP_LIB) -almost-sane -sanity-level=0.$* \
	       -print-removed-checks \
	       -gcda=openssl.lto.opt.gcda \
	       -gcno=openssl.lto.opt.gcno \
	       -o $@ $< > asap.$*.out 2>&1

../apps/openssl.as.%.opt.o: ../apps/openssl.as.%.bc
	$(OPT) -O3 -o $@ $<

../apps/openssl.as.%: ../apps/openssl.as.%.opt.o
	$(CC) $(CFLAGS) -o $@ $< -L.. -lssl -L.. -lcrypto

