# 
#--|----------------------------------------------------------------------------|
#--| FILE DESCRIPTION:
#--|   the Makefile is used to aid in building the project.
#--|  
#--|----------------------------------------------------------------------------|
#--| REFERENCES:
#--|   None.
#--|
#--|----------------------------------------------------------------------------|
#

ROOT    = ./
SRC     = $(ROOT)src/
BIN     = $(ROOT)bin/

TOOLCHAIN = arm-none-eabi

ASM_COMPILER = $(TOOLCHAIN)-as
LINKER       = $(TOOLCHAIN)-ld
OBJCOPY      = $(TOOLCHAIN)-objcopy
OBJDUMP      = $(TOOLCHAIN)-objdump

LINKER_SCRIPT = kernel.ld

TARGET = kernel

ELF  = $(BIN)$(TARGET).elf
IMG  = $(TARGET).img
LIST = $(BIN)$(TARGET).list

ASM_OBJS = $(patsubst $(SRC)%.s, $(BIN)%.o,$(wildcard $(SRC)*.s))

all: $(IMG)

$(BIN):
	mkdir $@

$(BIN)%.o: $(SRC)%.s $(BIN)
	$(ASM_COMPILER) $< -o $@

$(ELF) : $(LINKER_SCRIPT) $(ASM_OBJS) $(C_OBJS)
	$(LINKER) $(ASM_OBJS) $(C_OBJS) -T $(LINKER_SCRIPT) -o $(ELF)

$(IMG): $(ELF)
	$(OBJCOPY) -O binary $(ELF) $(IMG)
	$(OBJDUMP) -D $(ELF) > $(LIST)

clean:
	rm -f $(BIN)*.o
	rm -f $(ELF)
	rm -f $(IMG)
	rm -f $(LIST)
