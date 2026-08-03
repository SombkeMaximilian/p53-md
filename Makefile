SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.DELETE_ON_ERROR:

P53FASTA := data/p53.fasta

VENV        := .venv
PYTHON_DEPS := deps/requirements.txt
PYTHON      ?= $(VENV)/bin/python3

MAMBA_ROOT := .mamba
MAMBA_ENV  := deps/env.yaml
AMBERTOOLS := $(MAMBA_ROOT)/envs/ambertools
MAMBA      := $(MAMBA_ROOT)/bin/micromamba
TLEAP      ?= $(MAMBA) run -r $(MAMBA_ROOT) -p $(AMBERTOOLS) tleap

CONSTRUCT ?= 1-5
BUILD     := build/$(CONSTRUCT)

.PHONY: setup structure clean distclean

setup: $(VENV)/.stamp $(AMBERTOOLS)/.stamp

$(MAMBA):
	@mkdir -p $(MAMBA_ROOT)
	curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest \
	  | tar -xj -C $(MAMBA_ROOT) bin/micromamba

$(AMBERTOOLS)/.stamp: $(MAMBA_ENV) | $(MAMBA)
	@rm -rf $(AMBERTOOLS)
	$(MAMBA) create -y -r $(MAMBA_ROOT) -p $(AMBERTOOLS) -f $(MAMBA_ENV)
	$(TLEAP) -h >/dev/null 2>&1 || { echo "tleap not runnable" >&2; exit 1; }
	@touch $@

$(VENV)/.stamp: $(PYTHON_DEPS)
	test -d $(VENV) || python3 -m venv $(VENV)
	$(VENV)/bin/pip install --upgrade pip
	$(VENV)/bin/pip install -r $(PYTHON_DEPS)
	@touch $@

structure: $(BUILD)/seq.fasta

$(BUILD)/seq.fasta: $(P53FASTA) src/extract_construct.py | $(VENV)/.stamp
	@mkdir -p $(@D)
	$(PYTHON) src/extract_construct.py --fasta $< --range $(CONSTRUCT) --out $@

clean:
	rm -rf build
distclean: clean
	rm -rf $(VENV) $(MAMBA_ROOT)
