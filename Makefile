## tools
YOSYS = yosys
PR = p_r
OFL = openFPGALoader

TOP = serdes_lb
PRFLAGS  = -ccf src/$(TOP).ccf -cCP
OFLFLAGS = --index-chain 0

## target sources
VLOG_SRC = $(shell find ./src/verilog/ -type f \( -iname \*.v -o -iname \*.sv \))
VHDL_SRC = $(shell find ./src/vhdl/ -type f \( -iname \*.vhd -o -iname \*.vhdl \))

synth: $(VLOG_SRC)
	$(YOSYS) -ql log/synth.log -p 'read_verilog -sv $^; synth_gatemate -top $(TOP) $(YSFLAGS) -vlog net/$(TOP)_synth.v'

synth_vhdl: $(VHDL_SRC)
	$(YOSYS) -m ghdl -ql log/synth.log -p 'ghdl --std=08 --warn-no-binding --ieee=synopsys -C $^ -e $(TOP); synth_gatemate -top $(TOP) $(YSFLAGS) -vlog net/$(TOP)_synth.v'

impl:
	$(PR) -i net/$(TOP)_synth.v -o $(TOP) $(PRFLAGS) > log/$@.log

jtag:
	$(OFL) $(OFLFLAGS) -b gatemate_evb_jtag $(TOP)_00.cfg

clean:
	$(RM) rm log/*.log
#	$(RM) net/*_synth.v
	$(RM) work-obj93.cf
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
