SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.DELETE_ON_ERROR:

VENV        := .venv
PYTHON_DEPS := deps/requirements.txt
PYTHON      ?= $(VENV)/bin/python3

GMX ?= gmx

P53FASTA  := data/p53.fasta
CONSTRUCT ?= 1-5

FF    ?= amber99sb-disp
WATER ?= TIP4P-D
BUILD := build/$(FF)/$(WATER)/$(CONSTRUCT)

REPS        ?= 8
REP_IDS     := $(shell seq 1 $(REPS))
INIT_CONFS  := $(foreach r,$(REP_IDS),$(BUILD)/rep$(r)/init_conf.pdb)
TOPOLS      := $(foreach r,$(REP_IDS),$(BUILD)/rep$(r)/topol.top)
PDB2GMX_OUT := topol.top init_conf.gro posre.itp clean.pdb

.PHONY: setup sequence conformers topology clean distclean

setup: $(VENV)/.stamp

$(VENV)/.stamp: $(PYTHON_DEPS)
	test -d $(VENV) || python3 -m venv $(VENV)
	$(VENV)/bin/pip install --upgrade pip
	$(VENV)/bin/pip install -r $(PYTHON_DEPS)
	@touch $@

sequence: $(BUILD)/seq.fasta

$(BUILD)/seq.fasta: $(P53FASTA) src/extract_construct.py | $(VENV)/.stamp
	@mkdir -p $(@D)
	$(PYTHON) src/extract_construct.py --fasta $< --range $(CONSTRUCT) --out $@

conformers: $(INIT_CONFS)

$(BUILD)/rep%/init_conf.pdb: $(BUILD)/seq.fasta src/build_conformer.py | $(VENV)/.stamp
	@mkdir -p $(@D)
	$(PYTHON) src/build_conformer.py --seq $< --out $@ --seed $*

topology: $(TOPOLS)

$(addprefix $(BUILD)/rep%/,$(PDB2GMX_OUT)) &: $(BUILD)/rep%/init_conf.pdb
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

clean:
	rm -rf build

distclean: clean
	rm -rf $(VENV)
