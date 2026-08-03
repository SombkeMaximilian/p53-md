SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.DELETE_ON_ERROR:

VENV        := .venv
PYTHON_DEPS := deps/requirements.txt
PYTHON      ?= $(VENV)/bin/python3

P53FASTA := data/p53.fasta
CONSTRUCT ?= 1-5

FF    ?= a99SB-disp
WATER ?= TIP4P-D
BUILD := build/$(FF)/$(WATER)/$(CONSTRUCT)

REPS       ?= 8
INIT_CONFS := $(foreach r,$(shell seq 1 $(REPS)),$(BUILD)/rep$(r)/init_conf.pdb)

.PHONY: setup sequence conformers clean distclean

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

clean:
	rm -rf build

distclean: clean
	rm -rf $(VENV) $(MAMBA_ROOT)
