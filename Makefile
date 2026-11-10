# ===========================================================================
#  Makefile for C++ applications built with g++ (MinGW-w64) on Windows 10
#
#  Works with:
#    - mingw32-make  from cmd.exe or PowerShell
#    - make          from an MSYS2 / Git Bash shell
#    - make          on Linux / Raspberry Pi (bonus)
#
#  Expected layout:
#    project/
#      Makefile
#      include/        your .h / .hpp files
#      src/            your .cpp and .c files (subfolders are fine)
#      build/          created automatically
#
#  Usage:
#    mingw32-make              debug build   -> build/debug/myapp.exe
#    mingw32-make release      release build -> build/release/myapp.exe
#    mingw32-make LINK=static  link statically instead of dynamically
#    mingw32-make run          build and run (debug)
#    mingw32-make run BUILD=release
#    mingw32-make clean        remove current config (debug by default)
#    mingw32-make cleanall     remove the whole build folder
#    mingw32-make rebuild      clean + build
#    mingw32-make -j8          parallel build
# ===========================================================================

# ---- Project settings ------------------------------------------------------
TARGET    := myapp
SRC_DIR   := src
INC_DIR   := include
BUILD_DIR := build

# ---- Toolchain and flags ---------------------------------------------------
CC       := gcc
CXX      := g++
WARNINGS := -Wall -Wextra -Wpedantic
# CPPFLAGS: preprocessor flags (-I, -D), used for both C and C++
# CFLAGS:   flags for .c files    CXXFLAGS: flags for .cpp files
CPPFLAGS := -I$(INC_DIR)
CFLAGS   := -std=c17 $(WARNINGS)
CXXFLAGS := -std=c++17 $(WARNINGS)
LDFLAGS  :=
LDLIBS   :=
# Common Windows libraries, add as needed:
#   LDLIBS += -lws2_32                    (Winsock / networking)
#   LDLIBS += -luser32 -lgdi32            (Win32 GUI)
#   LDFLAGS += -mwindows                  (GUI app without console window)

# Third-party DLLs your app links against (e.g. libpq.dll, sqlite3.dll).
# They are copied next to the .exe when LINK=dynamic. Use forward slashes,
# no spaces in paths. Example:
#   EXTRA_DLLS := C:/libs/postgres/bin/libpq.dll C:/libs/sqlite/sqlite3.dll
EXTRA_DLLS :=

# ---- Build configuration: debug (default) or release ----------------------
BUILD ?= debug

ifeq ($(BUILD),release)
  CFLAGS   += -O2 -DNDEBUG
  CXXFLAGS += -O2 -DNDEBUG
  # -s strips debug symbols from the executable
  LDFLAGS  += -s
else ifeq ($(BUILD),debug)
  CFLAGS   += -O0 -g -DDEBUG
  CXXFLAGS += -O0 -g -DDEBUG
else
  $(error BUILD must be 'debug' or 'release', got '$(BUILD)')
endif

# ---- Linking: dynamic (default) or static ---------------------------------
#   dynamic: small .exe that needs the MinGW runtime DLLs
#            (libstdc++-6.dll, libgcc_s_seh-1.dll, libwinpthread-1.dll).
#            They are copied into the output folder automatically.
#   static:  bigger .exe with the runtime built in, no DLLs needed.
LINK ?= dynamic

ifeq ($(LINK),static)
  LDFLAGS += -static
else ifneq ($(LINK),dynamic)
  $(error LINK must be 'dynamic' or 'static', got '$(LINK)')
endif

# ---- Platform / shell detection --------------------------------------------
ifeq ($(OS),Windows_NT)
  EXE := .exe
  ifdef MSYSTEM
    # MSYS2 or Git Bash: a POSIX shell is available
    FIXPATH = $(1)
    MKDIR   = mkdir -p $(1)
    RMDIR   = rm -rf $(1)
    CP      = cp -f $(1) $(2)
  else
    # Plain cmd.exe / PowerShell with mingw32-make.
    # Force cmd.exe so a stray sh.exe on PATH does not change behaviour.
    SHELL   := cmd.exe
    FIXPATH = $(subst /,\,$(1))
    MKDIR   = if not exist "$(call FIXPATH,$(1))" mkdir "$(call FIXPATH,$(1))"
    RMDIR   = if exist "$(call FIXPATH,$(1))" rmdir /s /q "$(call FIXPATH,$(1))"
    CP      = copy /Y "$(call FIXPATH,$(1))" "$(call FIXPATH,$(2))" >nul
  endif

  # Locate the MinGW bin folder (where the runtime DLLs live) from the
  # compiler itself: <prefix>/lib/gcc/<target>/<version>/libgcc.a -> <prefix>/bin
  # Override if detection fails:  mingw32-make MINGW_BIN=C:/mingw64/bin
  MINGW_BIN ?= $(patsubst %/,%,$(dir $(subst \,/,$(shell $(CC) -print-libgcc-file-name))))/../../../../bin

  # libgcc_s_seh-1.dll = 64-bit toolchain, libgcc_s_dw2-1.dll = 32-bit toolchain
  RUNTIME_DLL_NAMES := libstdc++-6.dll libgcc_s_seh-1.dll libgcc_s_dw2-1.dll libwinpthread-1.dll
  RUNTIME_DLLS      := $(wildcard $(addprefix $(MINGW_BIN)/,$(RUNTIME_DLL_NAMES)))
else
  # Linux / Raspberry Pi: shared libraries come from the system
  EXE     :=
  FIXPATH = $(1)
  MKDIR   = mkdir -p $(1)
  RMDIR   = rm -rf $(1)
  CP      = cp -f $(1) $(2)
  RUNTIME_DLLS :=
endif

# ---- Files -----------------------------------------------------------------
# Recursive wildcard: finds sources in src/ and all its subfolders
rwildcard = $(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$(d),$(2)) $(filter $(subst *,%,$(2)),$(d)))

OUT_DIR := $(BUILD_DIR)/$(BUILD)
OBJ_DIR := $(OUT_DIR)/obj
BIN     := $(OUT_DIR)/$(TARGET)$(EXE)

SRCS_CPP := $(call rwildcard,$(SRC_DIR),*.cpp)
SRCS_C   := $(call rwildcard,$(SRC_DIR),*.c)
SRCS     := $(SRCS_CPP) $(SRCS_C)

# Object names keep the source extension (main.cpp -> main.cpp.o,
# uart.c -> uart.c.o) so foo.c and foo.cpp in one folder never collide.
OBJS := $(SRCS:$(SRC_DIR)/%=$(OBJ_DIR)/%.o)
DEPS := $(OBJS:.o=.d)

# DLLs to place next to the executable (dynamic linking only)
ifeq ($(LINK),dynamic)
  COPY_DLLS := $(strip $(RUNTIME_DLLS) $(EXTRA_DLLS))
endif
DLL_TARGETS := $(addprefix $(OUT_DIR)/,$(notdir $(COPY_DLLS)))

# Fail early if there is nothing to compile (but allow clean/help/info)
ifeq ($(filter clean cleanall help info,$(MAKECMDGOALS)),)
  ifeq ($(strip $(SRCS)),)
    $(error No .cpp or .c files found in '$(SRC_DIR)/')
  endif
endif

# ---- Targets ---------------------------------------------------------------
.PHONY: all debug release run clean cleanall rebuild info help

all: $(BIN) $(DLL_TARGETS)

# Link with g++ so the C++ standard library is included even when
# C and C++ objects are mixed.
$(BIN): $(OBJS)
	@$(call MKDIR,$(@D))
	$(CXX) $(LDFLAGS) $^ -o $@ $(LDLIBS)
	@echo Built $@

# Compile. -MMD -MP generates .d files so changing a header
# recompiles every source file that includes it.
$(OBJ_DIR)/%.cpp.o: $(SRC_DIR)/%.cpp
	@$(call MKDIR,$(@D))
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -MMD -MP -c $< -o $@

$(OBJ_DIR)/%.c.o: $(SRC_DIR)/%.c
	@$(call MKDIR,$(@D))
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

-include $(DEPS)

# One copy rule per DLL: copied only when missing or when the source is newer
define COPY_DLL_RULE
$(OUT_DIR)/$(notdir $(1)): $(1)
	@$$(call MKDIR,$$(@D))
	@$$(call CP,$(1),$$@)
	@echo Copied $(notdir $(1))
endef
$(foreach f,$(COPY_DLLS),$(eval $(call COPY_DLL_RULE,$(f))))

debug:
	@$(MAKE) --no-print-directory BUILD=debug

release:
	@$(MAKE) --no-print-directory BUILD=release

run: all
	$(call FIXPATH,./$(BIN))

clean:
	@$(call RMDIR,$(OUT_DIR))
	@echo Removed $(OUT_DIR)

cleanall:
	@$(call RMDIR,$(BUILD_DIR))
	@echo Removed $(BUILD_DIR)

rebuild:
	@$(MAKE) --no-print-directory clean
	@$(MAKE) --no-print-directory all

info:
	@echo BUILD    = $(BUILD)
	@echo LINK     = $(LINK)
	@echo DLLS     = $(COPY_DLLS)
	@echo CC       = $(CC)
	@echo CXX      = $(CXX)
	@echo CPPFLAGS = $(CPPFLAGS)
	@echo CFLAGS   = $(CFLAGS)
	@echo CXXFLAGS = $(CXXFLAGS)
	@echo LDFLAGS  = $(LDFLAGS)
	@echo LDLIBS   = $(LDLIBS)
	@echo SRCS     = $(SRCS)
	@echo BIN      = $(BIN)

help:
	@echo Targets:
	@echo   all       build current config, default is debug
	@echo   debug     build debug version
	@echo   release   build optimized version
	@echo   run       build and run, e.g. make run BUILD=release
	@echo Options:
	@echo   BUILD=debug or release, default debug
	@echo   LINK=dynamic or static, default dynamic
	@echo   clean     remove current config build output
	@echo   cleanall  remove the whole build folder
	@echo   rebuild   clean and build
	@echo   info      show detected sources and flags