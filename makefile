include local.config

export CLASP_HOME = $(shell pwd)

export GIT_COMMIT := $(shell cat 'minor-version-id.txt')

export CLASP_INTERNAL_BUILD_TARGET_DIR = $(shell pwd)/build/clasp
export EXTERNALS_BUILD_TARGET_DIR = $(EXTERNALS_SOURCE_DIR)/build


export BOOST_BUILD_SOURCE_DIR = $(CLASP_HOME)/boost_build_v2
export BOOST_BUILD_INSTALL = $(BOOST_BUILD_SOURCE_DIR)

#export BOOST_BUILD_SOURCE_DIR = $(CLASP_HOME)/boost_build_v2
#export BOOST_BUILD_INSTALL = $(CLASP_INTERNAL_BUILD_TARGET_DIR)/Contents/boost_build_v2


export BJAM = $(BOOST_BUILD_INSTALL)/bin/bjam --ignore-site-config --user-config= -q
export CLASP_APP_RESOURCES_DIR = $(CLASP_INTERNAL_BUILD_TARGET_DIR)/Contents/Resources

export PS1 := $(shell printf 'CLASP-ENV>>[\\u@\\h \\W]$ ')

ifeq ($(TARGET_OS),linux)
  export DEVEMACS = emacs -nw ./
else
  export DEVEMACS = open -a emacs ./
endif


#
# If the local.config doesn't define PYTHON2 then provide a default
#
ifeq ($(PYTHON2),)
	export PYTHON2 = /usr/bin/python
endif

ifeq ($(TARGET_OS),linux)
  export EXECUTABLE_DIR=bin
endif
ifeq ($(TARGET_OS),darwin)
  export EXECUTABLE_DIR=MacOS
endif

ifneq ($(EXTERNALS_BUILD_TARGET_DIR),)
	PATH := $(EXTERNALS_BUILD_TARGET_DIR)/release/bin:$(EXTERNALS_BUILD_TARGET_DIR)/common/bin:$(PATH)
	export PATH
endif

export PATH := $(BOOST_BUILD_INSTALL)/bin:$(PATH)
export PATH := $(CLASP_INTERNAL_BUILD_TARGET_DIR)/$(EXECUTABLE_DIR):$(PATH)


ifneq ($(CXXFLAGS),)
  export USE_CXXFLAGS := cxxflags=$(CXXFLAGS)
endif


ifeq ($(WHAT),)
	WHAT = bundle debug release boehm mps
endif

all:
	@echo Dumping local.config
	cat local.config
	make submodules
	make asdf
	make boostbuildv2-build
	make -C src/main scrape-all
	make clasp-boehm
#	make clasp-mps


sub-prebuild:
	make -C src/ $@

fix-scraping:
	for d in src/*/; do cd "$$d"; export PYTHONPATH="$$PWD:$$PYTHONPATH"; python ../../src/common/symbolScraper.py symbols_scraped.inc *.h *.cc *.scrape.inc; cd ../..; done

fix-scraping2:
	-(cd src/asttooling; bjam meta)
	-(cd src/cffi; bjam meta)
	-(cd src/clbind; bjam meta)
	-(cd src/core; bjam meta)
	-(cd src/gctools; bjam meta)
	-(cd src/llvmo; bjam meta)
	-(cd src/main; bjam meta)
	-(cd src/mpip; bjam meta)
	-(cd src/mps; bjam meta)
	-(cd src/serveEvent; bjam meta)
	-(cd src/sockets; bjam meta)


submodules:
	make submodules-boehm
	make submodules-mps

submodules-boehm:
	-git submodule update --init src/lisp/kernel/contrib/sicl
	-git submodule update --init src/lisp/kernel/asdf
	-(cd src/lisp/kernel/asdf; git checkout master; git pull origin master)

submodules-mps:
	-git submodule update --init src/mps

asdf:
	(cd src/lisp/kernel/asdf; make)

only-boehm:
	make submodules-boehm
	make boostbuildv2-build
	make clasp-boehm

boehm-build-mps-interface:
	make submodules
	make boostbuildv2-build
	make clasp-boehm
	(cd src/main; make mps-interface)


#
# Tell ASDF where to find the SICL/Code/Cleavir systems - the final // means search subdirs
#
#export CL_SOURCE_REGISTRY = $(shell echo `pwd`/src/lisp/kernel/contrib/sicl/Code/Cleavir//):$(shell echo `pwd`/src/lisp/kernel/contrib/slime//)

#
# When developing, set the CLASP_LISP_SOURCE_DIR environment variable
# to tell clasp to use the development source directly rather than the
# stuff in the clasp build target directory.  This saves us the trouble of
# constantly having to copy the lisp sources to the target directory.
export DEV_CLASP_LISP_SOURCE_DIR := $(shell echo `pwd`/src/lisp)

devemacs:
	@echo This shell sets up environment variables like BJAM
	@echo as they are defined when commands execute within the makefile
	@echo EXTERNALS_BUILD_TARGET_DIR = $(EXTERNALS_BUILD_TARGET_DIR)
	(CLASP_LISP_SOURCE_DIR=$(DEV_CLASP_LISP_SOURCE_DIR) $(DEVEMACS))

devshell:
	@echo This shell sets up environment variables like BJAM
	@echo as they are defined when commands execute within the makefile
	@echo EXTERNALS_BUILD_TARGET_DIR = $(EXTERNALS_BUILD_TARGET_DIR)
	(CLASP_LISP_SOURCE_DIR=$(DEV_CLASP_LISP_SOURCE_DIR) bash)


testing:
	which clang++

clasp-mps-cpp:
	(cd src/main; $(BJAM) -j$(PJOBS) $(USE_CXXFLAGS) link=$(LINK) bundle release mps)

clasp-mps:
	make clasp-mps-cpp
	(cd src/main; make mps)

# Compile the CL sources for min-mps: and full-mps
cl-mps:
	(cd src/main; make mps)

# Compile the CL sources for min-mps: using the existing min-mps: - FAST
cl-min-mps-recompile:
	(cd src/main; make min-mps-recompile)

# Compile the CL sources for full-mps:
cl-full-mps:
	(cd src/main; make full-mps)


clasp-boehm-cpp:
	(cd src/main; $(BJAM) -j$(PJOBS) $(USE_CXXFLAGS) link=$(LINK) release boehm)

clasp-boehm:
	make clasp-boehm-cpp
	(cd src/main; make boehm)

# Compile the CL sources for min-boehm: and full-boehm
cl-boehm:
	(cd src/main; make boehm)

# Compile the CL sources for min-boehm: using the existing min-boehm: - FAST
cl-min-boehm-recompile:
	(cd src/main; make min-boehm-recompile)

# Compile the CL sources for full-boehm:
cl-full-boehm:
	(cd src/main; make full-boehm)


boostbuildv2-build:
	(cd $(BOOST_BUILD_SOURCE_DIR); export BOOST_BUILD_PATH=`pwd`; ./bootstrap.sh; ./b2 toolset=clang install --prefix=$(BOOST_BUILD_INSTALL) --ignore-site-config)

compile-commands:
	(cd src/main; make compile-commands)


clean:
	(cd src/main; rm -rf bin bundle)
	(cd src/core; rm -rf bin bundle)
	(cd src/gctools; rm -rf bin bundle)
	(cd src/llvmo; rm -rf bin bundle)
	(cd src/asttooling; rm -rf bin bundle)
	(cd src/cffi; rm -rf bin bundle)
	(cd src/clbind; rm -rf bin bundle)
	(cd src/sockets; rm -rf bin bundle)
	(cd src/serveEvent; rm -rf bin bundle)
ifneq ($(CLASP_INTERNAL_BUILD_TARGET_DIR),)
	install -d $(CLASP_INTERNAL_BUILD_TARGET_DIR)
	-(find $(CLASP_INTERNAL_BUILD_TARGET_DIR) -type f -print0 | xargs -0 rm -f)
endif



mps-submodule:
	git submodule add -b dev/2014-08-18/non-incremental  https://github.com/Ravenbrook/mps-temporary ./src/mps


asdf-submodule:
	git submodule add --name updatedAsdf https://github.com/drmeister/asdf.git ./src/lisp/kernel/asdf


git-push-master:
	git rev-parse HEAD > minor-version-id.txt
	git commit -am "updated minor-version-id.txt"
	git push origin master
