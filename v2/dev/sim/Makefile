TOP := tb_ad7626_min_loopback
BUILD_DIR := build
ISIM_PRJ := isim.prj
ISIM_TCL := isim_run.tcl
ISIM_EXE := $(BUILD_DIR)/$(TOP)_isim.exe

RTL_SRCS := \
	../rtl/ad7626_min_timing_gen.v \
	../rtl/ad7626_min_rx_core.v \
	../rtl/ad7626_min_loopback_top.v

TB_SRCS := \
	../tb/tb_ad7626_min_loopback.v

all: run

build: isim_build

isim_build:
	mkdir -p $(BUILD_DIR)
	fuse work.$(TOP) -prj $(ISIM_PRJ) -o $(ISIM_EXE)

isim_run: isim_build
	./$(ISIM_EXE) -tclbatch $(ISIM_TCL) -log $(BUILD_DIR)/$(TOP)_isim.log

iverilog_build:
	mkdir -p $(BUILD_DIR)
	iverilog -g2005-sv -o $(BUILD_DIR)/$(TOP)_iverilog.out $(RTL_SRCS) $(TB_SRCS)

iverilog_run: iverilog_build
	cd $(BUILD_DIR) && vvp $(TOP)_iverilog.out

run: isim_run

clean:
	rm -rf $(BUILD_DIR)
	rm -f ../tb/*.vcd isim.wdb isim.log fuse.log

.PHONY: all build run clean isim_build isim_run iverilog_build iverilog_run
