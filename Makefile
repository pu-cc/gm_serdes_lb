## tools
YOSYS = yosys
PR = p_r
NEXTPNR = nextpnr-himbaechel
PACK = gmpack
OFL = openFPGALoader

TOP = serdes_lb
PRFLAGS  = -ccf src/$(TOP).ccf -cCP -crc
NEXTPNRFLAGS = --vopt allow-unconstrained
OFLFLAGS = --index-chain 0

## target sources
VLOG_SRC = $(shell find ./src/verilog/ -type f \( -iname \*.v -o -iname \*.sv \))
VHDL_SRC = $(shell find ./src/vhdl/ -type f \( -iname \*.vhd -o -iname \*.vhdl \))

## legacy toolchain
net/$(TOP)_synth.v: $(VLOG_SRC)
	$(YOSYS) -l log/synth.log -p 'read_verilog -sv $^; synth_gatemate -top $(TOP) $(YSFLAGS) -vlog net/$(TOP)_synth.v'

synth_vhdl: $(VHDL_SRC)
	$(YOSYS) -m ghdl -l log/synth.log -p 'ghdl --std=08 --warn-no-binding --ieee=synopsys -C $^ -e $(TOP); synth_gatemate -top $(TOP) $(YSFLAGS) -vlog net/$(TOP)_synth.v'

$(TOP)_00.cfg.bit: net/$(TOP)_synth.v
	$(PR) -i net/$(TOP)_synth.v -o $(TOP) $(PRFLAGS)

jtag_legacy: $(TOP)_00.cfg.bit
	$(OFL) $(OFLFLAGS) -b gatemate_evb_jtag $(TOP)_00.cfg

## open source toolchain
net/$(TOP)_synth.json: $(VLOG_SRC)
	$(YOSYS) -l log/synth.log -p 'read_verilog -sv $^; synth_gatemate -top $(TOP) -luttree $(YSFLAGS) -vlog net/$(TOP)_synth.v -json net/$(TOP)_synth.json'

$(TOP).txt: net/$(TOP)_synth.json src/$(TOP).ccf
	$(NEXTPNR) --device CCGM1A1 --json net/$(TOP)_synth.json --vopt ccf=src/$(TOP).ccf $(NEXTPNRFLAGS) --vopt out=$(TOP).txt --router router2

$(TOP).bit: $(TOP).txt
	$(PACK) $(TOP).txt $(TOP).bit

jtag: $(TOP).bit
	$(OFL) $(OFLFLAGS) -b gatemate_evb_jtag $(TOP).bit

clean:
	$(RM) rm log/*.log
	$(RM) net/*_synth.json
	$(RM) net/*_synth.v
	$(RM) work-obj*.cf
	$(RM) *.txt
	$(RM) *.crf
	$(RM) *.refwire
	$(RM) *.refparam
	$(RM) *.refcomp
	$(RM) *.pos
	$(RM) *.pathes
	$(RM) *.path_struc
	$(RM) *.net
	$(RM) *.id
	$(RM) *.prn
	$(RM) *_00.v
	$(RM) *.used
	$(RM) *.sdf
	$(RM) *.place
	$(RM) *.pin
	$(RM) *.cfg*
	$(RM) *.cdf
