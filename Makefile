PROJECT_TITLE = eth_40gb
QUARTUS_DIR = ./quartus/
SIM_DIR = ./sim/
RTL_DIR = ./RTL/
PROJECT = $(QUARTUS_DIR)$(PROJECT_TITLE)

# utilities
RM     = rm -rf
MKDIR  = @mkdir -p $(@D) #creates folders if not present
#QUARTUS_PATH = 
SYNTH  = quartus_syn
P&R    = quartus_fit
ASM    = quartus_asm
TIMING = quartus_sta
PROG   = quartus_pgm

# build files
SOF = $(PROJECT).sof
CDF = $(PROJECT).cdf
SRC_FILES := $(wildcard $(RTL_DIR)*.sv)



#############
### BUILD ###
#############
all: $(SOF)

program: $(SOF)
	$(PROG) $(CDF)

timing: #$(SOF)
	$(TIMING) $(PROJECT) -c $(PROJECT)

$(SOF): $(SRC_FILES)
	$(SYNTH) --read_settings_files=on --write_settings_files=off $(PROJECT) -c $(PROJECT)
	$(P&R) --read_settings_files=on --write_settings_files=off $(PROJECT) -c $(PROJECT_TITLE)
	$(ASM) --read_settings_files=on --write_settings_files=off $(PROJECT) -c $(PROJECT)

clean:
	$(RM) $(SOF)
	cd $(QUARTUS_DIR) && $(RM) *.sof *.pof *.srf *.cdl *.vcs *.rpt *.log
	$(RM) *.sof *.pof *.srf *.cdl *.vcs *.rpt *.log

##################
### SIMULATION ###
##################

# TODO full regression
#sim:
#	$(MAKE) -C sim -f Makefile