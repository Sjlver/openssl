ifeq ($(LLVM_DIR),)
    $(error "Please set LLVM_DIR")
endif

CC=$(LLVM_DIR)/bin/clang
OPT=$(LLVM_DIR)/bin/opt

CFLAGS  = -flto -fsanitize=address -fno-omit-frame-pointer -fno-sanitize-recover \
          -fsanitize-blacklist=$(realpath ../asap/asan_blacklist.txt) \
          -DOPENSSL_NO_HW_PADLOCK \
          -g
CONFIGURE_ENV=CC="$(CC)"
MAKE_FLAGS=

ifeq ($(shell ls $(LLVM_DIR)/lib/LLVMgold.so 2>&1),$(LLVM_DIR)/lib/LLVMgold.so)
    LINUX=1

    AR=ar --plugin=$(LLVM_DIR)/lib/LLVMgold.so -r
    RANLIB=ar --plugin=$(LLVM_DIR)/lib/LLVMgold.so -s
    CFLAGS += -Wl,--export-dynamic

    ASAP_LIB=$(LLVM_DIR)/lib/SanityChecks.so
    GCOV_FLAGS=-L$(LLVM_DIR)/lib/clang/3.4/lib/linux -lclang_rt.profile-x86_64
    SAVE_TEMPS=-Wl,--plugin-opt=save-temps 

    CONFIGURE_ENV += RANLIB="$(RANLIB)"
    MAKE_FLAGS    += AR="$(AR)"
    CONFIGURE_TARGET=linux-x86_64
else
    ASAP_LIB=$(LLVM_DIR)/lib/SanityChecks.dylib
    GCOV_FLAGS=-L$(LLVM_DIR)/lib/clang/3.4/lib/darwin -lclang_rt.profile_osx
    SAVE_TEMPS=-Wl,-save-temps
    CONFIGURE_TARGET=darwin64-x86_64-cc
endif

stamps/configure:
	mkdir -p stamps
	cd .. && $(CONFIGURE_ENV) ./Configure $(CFLAGS) $(SAVE_TEMPS) $(CONFIGURE_TARGET)
	touch stamps/configure

stamps/depend: stamps/configure
	cd .. && $(MAKE) clean depend
	touch stamps/depend

../apps/openssl: stamps/depend
	cd .. && $(MAKE) $(MAKE_FLAGS)

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

