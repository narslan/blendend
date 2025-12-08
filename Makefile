# --- Makefile for Blend2D NIF project ---

PRIV_DIR := $(MIX_APP_PATH)/priv
NIF_PATH := $(PRIV_DIR)/blendend.so
C_SRC := $(shell pwd)/c_src
SOURCES := $(wildcard $(C_SRC)/*.cpp $(C_SRC)/*/*.cpp)

# Compiler and linker flags
CXX := g++
CPPFLAGS := -shared -fPIC -fvisibility=hidden -std=c++17 -Wall -Wextra
CPPFLAGS += -I$(ERTS_INCLUDE_DIR)
LDFLAGS :=  -lblend2d

ifdef DEBUG
  CPPFLAGS += -g
else
  CPPFLAGS += -O3
endif

# Handle macOS specifics
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
  CPPFLAGS += -undefined dynamic_lookup -flat_namespace
endif

# Source and target definitions
all: $(NIF_PATH)
	@ echo > /dev/null # Dummy command to avoid the default output "Nothing to be done"

$(NIF_PATH): $(SOURCES)
	@ mkdir -p $(PRIV_DIR)
	$(CXX) $(CPPFLAGS) $(SOURCES) -o $(NIF_PATH)  $(LDFLAGS)
