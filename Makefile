SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.DELETE_ON_ERROR:
.SECONDARY:

VENV        := .venv
PYTHON_DEPS := deps/requirements.txt
PYTHON      ?= $(VENV)/bin/python3

GMX                  ?= gmx
GMX_NT_OMP           ?= 2
GMX_NT_MPI           ?= 1
MDRUN_FLAGS          ?=
export GMX_MAXBACKUP := -1

GMX_PIN     ?= on
PIN_BASE    ?= 0
PIN_STRIDE  ?= 1
NT_PER_REP  := $(shell expr $(GMX_NT_MPI) \* $(GMX_NT_OMP))
PINOFFSET    = $$(( $(PIN_BASE) + ($* - 1) * $(NT_PER_REP) * $(PIN_STRIDE) ))

ifeq ($(GMX_PIN),on)
MDRUN_PIN = -ntmpi $(GMX_NT_MPI) -ntomp $(GMX_NT_OMP) \
            -pin on -pinstride $(PIN_STRIDE) -pinoffset $(PINOFFSET)
else
MDRUN_PIN = -ntmpi $(GMX_NT_MPI) -ntomp $(GMX_NT_OMP)
endif

LOCAL_FF      ?= ff
FF_STAMP      ?= $(LOCAL_FF)/.stamp
export GMXLIB := $(CURDIR)/$(LOCAL_FF)

P53FASTA  := data/p53.fasta
CONSTRUCT ?= 1-5
FF        ?= a99SBdisp
WATER     ?= a99SBdisp_water
BUILD     := build/$(FF)/$(WATER)/$(CONSTRUCT)

FF_DIR   := $(FF).ff
WATERBOX := $(LOCAL_FF)/$(FF_DIR)/$(WATER).gro

REPS        ?= 2
REP_IDS     := $(shell seq 1 $(REPS))
PDB2GMX_OUT := topol.top init_conf.gro posre.itp clean.pdb

BOXD        ?= 1.2
BOXTYPE     ?= dodecahedron
BOXVEC      ?=
BOX_DAT     := $(BUILD)/box.dat

ifeq ($(strip $(BOXVEC)),)
BOX_L   = $$(cat $(BOX_DAT))
BOX_DEP = $(BOX_DAT)
else
BOX_L   = $(BOXVEC)
BOX_DEP =
endif

CONC        ?= 0.15
PNAME       ?= NA
NNAME       ?= CL
EM_MDP      := mdp/em.mdp
NVT_MDP     := mdp/nvt.mdp
NPT_MDP     := mdp/npt.mdp
PROD_MDP    := mdp/prod.mdp

ANALYSIS_SKIP ?= 0
RVDW          ?= 1.0
PLOT_FMT      ?= svg
ANALYSIS_OUT  := gyrate.xvg polystat.xvg mindist.xvg energy.xvg dssp.dat
PLOTS         := rg e2e mindist temp dens pres
RESULTS       := $(addsuffix .$(PLOT_FMT),$(PLOTS)) summary.txt

.PHONY: setup \
	topology \
	solvate \
	minimize \
	equilibrate \
	produce \
	analyse \
	analyze \
    clean \
    distclean

%/.dir:
	@mkdir -p $(@D)
	@touch $@

setup: $(VENV)/.stamp $(FF_STAMP)

$(VENV)/.stamp: $(PYTHON_DEPS)
	test -d $(VENV) || python3 -m venv $(VENV)
	$(VENV)/bin/pip install --upgrade pip
	$(VENV)/bin/pip install -r $(PYTHON_DEPS)
	@touch $@

$(FF_STAMP): $(LOCAL_FF)/download.sh
	cd $(LOCAL_FF) && ./download.sh
	@for f in forcefield.itp $(WATER).itp $(WATER).gro ions.itp; do \
	  test -f $(LOCAL_FF)/$(FF_DIR)/$$f \
	    || { echo "missing $$f after download" >&2; exit 1; }; \
	done
	@touch $@

topology: $(foreach r,$(REP_IDS),$(BUILD)/rep$(r)/topol.top)

$(BUILD)/seq.fasta: $(P53FASTA) src/extract_construct.py | $(BUILD)/.dir $(VENV)/.stamp
	$(PYTHON) src/extract_construct.py --fasta $< --range $(CONSTRUCT) --out $@

$(BUILD)/rep%/init_conf.pdb: $(BUILD)/seq.fasta src/build_conformer.py | $(BUILD)/rep%/.dir $(VENV)/.stamp
	$(PYTHON) src/build_conformer.py --seq $< --out $@ --seed $*

$(addprefix $(BUILD)/rep%/,$(PDB2GMX_OUT)) &: $(BUILD)/rep%/init_conf.pdb $(FF_STAMP)
	cd $(@D) && $(GMX) pdb2gmx \
	    -f init_conf.pdb \
	    -o init_conf.gro \
	    -p topol.top \
	    -i posre.itp \
	    -q clean.pdb \
	    -ff $(FF) \
	    -water none \
	    -ignh \
	    -norenum \
	    -chainsep id \
	    2>&1 | tee pdb2gmx.log
	@grep -q 'Opening force field file' $(@D)/pdb2gmx.log

solvate: $(foreach r,$(REP_IDS),$(BUILD)/rep$(r)/ions.gro)

$(BOX_DAT): $(foreach r,$(REP_IDS),$(BUILD)/rep$(r)/init_conf.gro) | $(BUILD)/.dir
	@for g in $^; do \
	  $(GMX) editconf -f $$g -o $(BUILD)/probe.gro \
	      -bt $(BOXTYPE) -d $(BOXD) -c >/dev/null 2>&1; \
	  tail -n 1 $(BUILD)/probe.gro | awk '{print $$1}'; \
	done | sort -g | tail -n 1 > $@
	@rm -f $(BUILD)/probe.gro
	@echo "common box vector: $$(cat $@) nm ($(BOXTYPE))"

$(BUILD)/rep%/box.gro: $(BUILD)/rep%/init_conf.gro $(BOX_DEP)
	L=$(BOX_L); \
	$(GMX) editconf \
	    -f $< \
	    -o $@ \
	    -bt $(BOXTYPE) \
	    -d $$L $$L $$L \
	    -c

$(BUILD)/rep%/solv.gro $(BUILD)/rep%/solv.top &: $(BUILD)/rep%/box.gro $(BUILD)/rep%/topol.top $(FF_STAMP)
	cp $(@D)/topol.top $(@D)/solv.top
	sed -i '/^\[ system \]/i #include "$(FF_DIR)/$(WATER).itp"\n#include "$(FF_DIR)/ions.itp"' $(@D)/solv.top
	$(GMX) solvate \
	    -cp $(@D)/box.gro \
	    -cs $(WATERBOX) \
	    -o $(@D)/solv.gro \
	    -p $(@D)/solv.top

$(BUILD)/rep%/ions.tpr: $(BUILD)/rep%/solv.gro $(BUILD)/rep%/solv.top $(EM_MDP)
	$(GMX) grompp \
	    -f $(EM_MDP) \
	    -c $< \
	    -p $(@D)/solv.top \
	    -o $@ \
	    -po $(@D)/mdout_ions.mdp \
	    -maxwarn 1

$(BUILD)/rep%/ions.gro $(BUILD)/rep%/ions.top &: $(BUILD)/rep%/ions.tpr $(BUILD)/rep%/solv.top
	cp $(@D)/solv.top $(@D)/ions.top
	echo SOL | $(GMX) genion \
	    -s $(@D)/ions.tpr \
	    -o $(@D)/ions.gro \
	    -p $(@D)/ions.top \
	    -pname $(PNAME) \
	    -nname $(NNAME) \
	    -neutral \
	    -conc $(CONC)

minimize: $(foreach r,$(REP_IDS),$(BUILD)/rep$(r)/em.gro)

$(BUILD)/rep%/em.tpr: $(BUILD)/rep%/ions.gro $(BUILD)/rep%/ions.top $(EM_MDP)
	$(GMX) grompp \
	    -f $(EM_MDP) \
	    -c $< \
	    -p $(@D)/ions.top \
	    -o $@ \
	    -po $(@D)/mdout_em.mdp

$(BUILD)/rep%/em.gro: $(BUILD)/rep%/em.tpr
	cd $(@D) && $(GMX) mdrun \
	    -s em.tpr \
	    -deffnm em \
	    $(MDRUN_PIN) \
	    $(MDRUN_FLAGS)

equilibrate: $(foreach r,$(REP_IDS),$(BUILD)/rep$(r)/npt.gro)

$(BUILD)/rep%/nvt.mdp: $(NVT_MDP) | $(BUILD)/rep%/.dir
	sed 's/@SEED@/$*/' $< > $@

$(BUILD)/rep%/nvt.tpr: $(BUILD)/rep%/em.gro $(BUILD)/rep%/ions.top $(BUILD)/rep%/nvt.mdp
	$(GMX) grompp \
	    -f $(@D)/nvt.mdp \
	    -c $< \
	    -r $< \
	    -p $(@D)/ions.top \
	    -o $@ \
	    -po $(@D)/mdout_nvt.mdp

$(BUILD)/rep%/nvt.gro $(BUILD)/rep%/nvt.cpt &: $(BUILD)/rep%/nvt.tpr
	cd $(@D) && $(GMX) mdrun \
	    -s nvt.tpr \
	    -deffnm nvt \
	    $(MDRUN_PIN) \
	    $(MDRUN_FLAGS)

$(BUILD)/rep%/npt.tpr: $(BUILD)/rep%/nvt.gro $(BUILD)/rep%/nvt.cpt $(BUILD)/rep%/ions.top $(NPT_MDP)
	$(GMX) grompp \
	    -f $(NPT_MDP) \
	    -c $< \
	    -r $< \
	    -t $(@D)/nvt.cpt \
	    -p $(@D)/ions.top \
	    -o $@ \
	    -po $(@D)/mdout_npt.mdp

$(BUILD)/rep%/npt.gro $(BUILD)/rep%/npt.cpt &: $(BUILD)/rep%/npt.tpr
	cd $(@D) && $(GMX) mdrun \
	    -s npt.tpr \
	    -deffnm npt \
	    $(MDRUN_PIN) \
	    $(MDRUN_FLAGS)

produce: $(foreach r,$(REP_IDS),$(BUILD)/rep$(r)/production.gro)

$(BUILD)/rep%/production.tpr: $(BUILD)/rep%/npt.gro $(BUILD)/rep%/npt.cpt $(BUILD)/rep%/ions.top $(PROD_MDP)
	$(GMX) grompp \
	    -f $(PROD_MDP) \
	    -c $< \
	    -t $(@D)/npt.cpt \
	    -p $(@D)/ions.top \
	    -o $@ \
	    -po $(@D)/mdout_production.mdp

$(addprefix $(BUILD)/rep%/production., gro xtc edr cpt) &: $(BUILD)/rep%/production.tpr
	cd $(@D) && $(GMX) mdrun \
	    -s production.tpr \
	    -deffnm production \
	    $(MDRUN_PIN) \
	    $(MDRUN_FLAGS)

analyse: $(foreach r,$(REP_IDS),$(BUILD)/rep$(r)/analysis/summary.txt)

analyze: analyse

$(BUILD)/rep%/analysis/whole.xtc: $(BUILD)/rep%/production.xtc $(BUILD)/rep%/production.tpr | $(BUILD)/rep%/analysis/.dir
	printf 'Protein\nSystem\n' | $(GMX) trjconv \
	    -f $< \
	    -s $(BUILD)/rep$*/production.tpr \
	    -o $@ \
	    -pbc mol \
	    -center \
	    -b $(ANALYSIS_SKIP)

$(addprefix $(BUILD)/rep%/analysis/,$(ANALYSIS_OUT)) &: $(BUILD)/rep%/analysis/whole.xtc $(addprefix $(BUILD)/rep%/production., xtc edr tpr)
	echo Protein | $(GMX) gyrate \
	    -f $< \
	    -s $(BUILD)/rep$*/production.tpr \
	    -o $(@D)/gyrate.xvg
	echo Protein | $(GMX) polystat \
	    -f $< \
	    -s $(BUILD)/rep$*/production.tpr \
	    -o $(@D)/polystat.xvg
	echo Protein | $(GMX) mindist \
	    -f $(BUILD)/rep$*/production.xtc \
	    -s $(BUILD)/rep$*/production.tpr \
	    -pi \
	    -od $(@D)/mindist.xvg \
	    -b $(ANALYSIS_SKIP)
	printf 'Temperature\nPressure\nVolume\nDensity\n\n' | $(GMX) energy \
	    -f $(BUILD)/rep$*/production.edr \
	    -o $(@D)/energy.xvg \
	    -b $(ANALYSIS_SKIP)
	$(GMX) dssp \
	    -f $< \
	    -s $(BUILD)/rep$*/production.tpr \
	    -o $(@D)/dssp.dat

$(addprefix $(BUILD)/rep%/analysis/,$(RESULTS)) &: \
		$(addprefix $(BUILD)/rep%/analysis/,$(ANALYSIS_OUT)) \
		src/analyze.py | $(VENV)/.stamp
	$(PYTHON) src/analyze.py \
	    --dir $(@D) \
	    --outdir $(@D) \
	    --title "p53 $(CONSTRUCT) rep$*" \
	    --rvdw $(RVDW) \
	    --format $(PLOT_FMT)

clean:
	rm -rf build

distclean: clean
	rm -rf $(VENV) $(LOCAL_FF)/$(FF_DIR) $(FF_STAMP)
