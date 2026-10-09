SRC ?= fw_compartment.S
LDSCRIPT ?= fw_compartment.ldS

.PHONY: all install clean
all: fw_compartment.elf

fw_compartment.o: $(SRC)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(ASFLAGS) -c "$(SRC)" -o $@

fw_compartment.elf: fw_compartment.o $(LDSCRIPT)
	$(CC) $(CFLAGS) $(LDFLAGS) -nostdlib -nostartfiles -T $(LDSCRIPT) -o $@ fw_compartment.o $(LDLIBS)

install: all
	install -d "$(DESTDIR)"
	install -m 755 fw_compartment.elf "$(DESTDIR)/"

clean:
	rm -f fw_compartment.o fw_compartment.elf
