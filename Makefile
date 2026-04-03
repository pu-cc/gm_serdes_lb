## tools
YOSYS = yosys
PR = p_r
NEXTPNR = nextpnr-himbaechel
PACK = gmpack
OFL = openFPGALoader

TOP = serdes_lb
NEXTPNRFLAGS =
OFLFLAGS = --index-chain 0
PACKFLAGS =

## target sources
VLOG_SRC = $(shell find ./src/verilog/ -type f \( -iname \*.v -o -iname \*.sv \))
VHDL_SRC = $(shell find ./src/vhdl/ -type f \( -iname \*.vhd -o -iname \*.vhdl \))

net/$(TOP)_synth.json: $(VLOG_SRC)
	$(YOSYS) -ql log/synth.log -p 'read_verilog -sv $^; synth_gatemate -top $(TOP) -luttree $(YSFLAGS) -vlog net/$(TOP)_synth.v -json net/$(TOP)_synth.json'

$(TOP).txt: net/$(TOP)_synth.json src/$(TOP).ccf
	$(NEXTPNR) -l log/impl.log --device CCGM1A1 --json net/$(TOP)_synth.json -o ccf=src/$(TOP).ccf $(NEXTPNRFLAGS) -o out=$(TOP).txt --router router2 --sdf=$(TOP).sdf --write $(TOP)_impl.json
	$(YOSYS) -q -p 'read_json $(TOP)_impl.json; write_verilog $(TOP)_impl.v'

$(TOP).bit: $(TOP).txt
	$(PACK) $(PACKFLAGS) $(TOP).txt $(TOP).bit

jtag: $(TOP).bit
	$(OFL) $(OFLFLAGS) -b gatemate_evb_jtag $(TOP).bit

jtag-flash: $(TOP).bit
	$(OFL) $(OFLFLAGS) -b gatemate_evb_jtag -f --verify $(TOP).bit

spi: $(TOP).bit
	$(OFL) $(OFLFLAGS) -b gatemate_evb_spi -m $(TOP).bit

spi-flash: $(TOP).bit
	$(OFL) $(OFLFLAGS) -b gatemate_evb_spi -f --verify $(TOP).bit

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
