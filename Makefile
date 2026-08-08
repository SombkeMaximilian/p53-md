SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.DELETE_ON_ERROR:
.SECONDARY:

VENV        := .venv
PYTHON_DEPS := deps/requirements.txt
PYTHON      ?= $(VENV)/bin/python3

GMX ?= gmx
export GMX_MAXBACKUP := -1

LOCAL_FF ?= ff
FF_STAMP ?= $(LOCAL_FF)/.stamp
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

BOXD     ?= 1.2
BOXTYPE  ?= dodecahedron
CONC     ?= 0.15
PNAME    ?= NA
NNAME    ?= CL
EM_MDP   := mdp/em.mdp
NVT_MDP  := mdp/nvt.mdp
NPT_MDP  := mdp/npt.mdp
PROD_MDP := mdp/prod.mdp

.PHONY: setup topology solvate minimize clean distclean

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

$(BUILD)/seq.fasta: $(P53FASTA) src/extract_construct.py | $(VENV)/.stamp
	@mkdir -p $(@D)
	$(PYTHON) src/extract_construct.py --fasta $< --range $(CONSTRUCT) --out $@

$(BUILD)/rep%/init_conf.pdb: $(BUILD)/seq.fasta src/build_conformer.py | $(VENV)/.stamp
	@mkdir -p $(@D)
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

$(BUILD)/rep%/box.gro: $(BUILD)/rep%/init_conf.gro
	$(GMX) editconf \
	    -f $< \
		-o $@ \
		-bt $(BOXTYPE) \
		-d $(BOXD) \
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
	$(GMX) grompp -f $(EM_MDP) -c $< -p $(@D)/ions.top -o $@ -po $(@D)/mdout_em.mdp

$(BUILD)/rep%/em.gro: $(BUILD)/rep%/em.tpr
	cd $(@D) && $(GMX) mdrun -s em.tpr -deffnm em

clean:
	rm -rf build

distclean: clean
	rm -rf $(VENV) $(LOCAL_FF)/$(FF_DIR) $(FF_STAMP)
