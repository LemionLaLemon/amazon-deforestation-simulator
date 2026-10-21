APP      := deforest
SRC_DIR  := src
BUILD_DIR := build

NASM     := nasm
LD       := gcc
STRIP    := strip
OBJCOPY  := objcopy

SOURCES  := $(wildcard $(SRC_DIR)/*.asm)
OBJECTS  := $(patsubst $(SRC_DIR)/%.asm,$(BUILD_DIR)/%.o,$(SOURCES))
TARGET   := $(BUILD_DIR)/$(APP)
STRIPPED_TARGET := $(BUILD_DIR)/$(APP)-stripped

NASMFLAGS := -f elf64 -g -F dwarf
LDFLAGS   := -no-pie -z noseparate-code
LDLIBS    := -lc -lncursesw

.PHONY: all build strip stripped run debug clean

all: $(TARGET)

build: all

strip: stripped

stripped: $(STRIPPED_TARGET)

$(STRIPPED_TARGET): $(TARGET)
	cp $(TARGET) $@
	$(STRIP) --strip-all $@
	$(OBJCOPY) --strip-section-headers $@

$(TARGET): $(OBJECTS)
	@test -n "$^" || { echo "No NASM source files found in $(SRC_DIR)/" >&2; exit 1; }
	@mkdir -p $(BUILD_DIR)
	$(LD) $(LDFLAGS) -o $@ $^ $(LDLIBS)

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.asm
	@mkdir -p $(BUILD_DIR)
	$(NASM) $(NASMFLAGS) -o $@ $<

run: $(TARGET)
	./$(TARGET)

debug: $(TARGET)
	gdb ./$(TARGET)

clean:
	rm -rf $(BUILD_DIR)
