PROJECT = teatimer
SRCS = teatimer.v teatimer_tb.v
SIMDIR = sim

# iverilog
IVC = iverilog
IVCFLAGS =

# vvp
VVP = vvp
VVPFLAGS =

# vvp dump type
DUMPTYPE = vcd

# wave form viewer
WAVEFORM_VIEWER = gtkwave
WAVEFORM_VIEWER_OPTIONS =

###############################################################################

all: compile simulate view

compile:
	mkdir -p $(SIMDIR)
	$(IVC) $(IVCFLAGS) -o $(SIMDIR)/$(PROJECT).vvp $(SRCS)

simulate:
	mkdir -p $(SIMDIR)
	$(VVP) $(VVPFLAGS) -N $(SIMDIR)/$(PROJECT).vvp -$(DUMPTYPE)
	mv dump.$(DUMPTYPE) $(SIMDIR)/$(PROJECT).$(DUMPTYPE)

view:
	$(WAVEFORM_VIEWER) $(WAVEFORM_VIEWER_OPTIONS) $(SIMDIR)/$(PROJECT).$(DUMPTYPE)

clean:
	rm -rf $(SIMDIR)

