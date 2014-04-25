ifeq ($(LLVM_DIR),)
    $(error "Please set LLVM_DIR")
endif

CC=$(LLVM_DIR)/bin/clang
OPT=$(LLVM_DIR)/bin/opt

CFLAGS  = -flto -fsanitize=address -fno-omit-frame-pointer -fno-sanitize-recover \
          -fsanitize-blacklist=$(realpath asan_blacklist.txt) \
          -DOPENSSL_NO_HW_PADLOCK -DOPENSSL_NO_BUF_FREELISTS \
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

.PHONY: clean
clean:
	rm -f stamps/* openssl.lto.opt.gc* asap.*.out

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
../apps/openssl.gcov.o: ../apps/openssl
	$(OPT) -load $(ASAP_LIB) -full-gcov-profiling -exit-instead-of-abort -o $@ $<.lto.opt.bc

../apps/openssl.gcov: ../apps/openssl.gcov.o
	$(CC) $(CFLAGS) -o $@ $< $(GCOV_FLAGS) -L.. -lssl -L.. -lcrypto

# Generate profiling data
openssl.lto.opt.gcda: ../apps/openssl.gcov
	rm -f $@
	../apps/openssl.gcov s_server -cert ../apps/server.pem -WWW & \
	    pid=$$! && \
	    sleep 2 && \
	    (./hb-test.py -p 4433 -l 4096 localhost || true) && \
	    sleep 2 && \
	    gdb --pid=$$pid --ex "print exit(0)" --ex "quit"

# Compile a version of openssl with ASAP optimization
../apps/openssl.as.%.bc: ../apps/openssl openssl.lto.opt.gcda
	$(OPT) -load $(ASAP_LIB) -almost-sane -sanity-level=0.$* \
	       -print-removed-checks \
	       -gcda=openssl.lto.opt.gcda \
	       -gcno=openssl.lto.opt.gcno \
	       -o $@ $<.lto.opt.bc > asap.$*.out 2>&1

../apps/openssl.as.%.opt.o: ../apps/openssl.as.%.bc
	$(OPT) -O3 -o $@ $<

../apps/openssl.as.%: ../apps/openssl.as.%.opt.o
	$(CC) $(CFLAGS) -o $@ $< -L.. -lssl -L.. -lcrypto

# Compile a test with ASAP optimization
../test/%.gcov.o: ../test/%.lto.opt.bc ../test/%
	$(OPT) -load $(ASAP_LIB) -full-gcov-profiling -exit-instead-of-abort -o $@ $<

../test/%.gcov: ../test/%.gcov.o
	$(CC) $(CFLAGS) -o $@ $< $(GCOV_FLAGS) -L.. -lssl -L.. -lcrypto

%.lto.opt.gcda: ../test/%.gcov
	rm -f $@
	$<
	[ -f $@ ]

../test/%.as.00.bc: ../test/%.lto.opt.bc %.lto.opt.gcda
	$(OPT) -load $(ASAP_LIB) -almost-sane -sanity-level=0.00 \
	       -print-removed-checks \
	       -gcda=$*.lto.opt.gcda \
	       -gcno=$*.lto.opt.gcno \
	       -o $@ $< > asap.$*.00.out 2>&1

../test/%.as.00.opt.o: ../test/%.as.00.bc
	$(OPT) -O3 -o $@ $<

../test/%.as.00: ../test/%.as.00.opt.o
	$(CC) $(CFLAGS) -o $@ $< -L.. -lssl -L.. -lcrypto
