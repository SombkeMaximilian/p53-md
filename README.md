# MD Simulations of the p53 protein

## Requirements

GNU Make, `python3` with `venv`, `curl`, and GROMACS with `gmx` on `PATH`.
Everything else bootstraps on first build.

## Usage

  ```bash
  make structure
  make CONSTRUCT=1-30 structure
  ```

First run downloads micromamba into `.mamba/` and creates `.venv/`; this
takes a few minutes and happens once. Output goes to `build/<construct>/`.
  
  ```bash
  make clean
  make distclean
  ```

# References

- UniProt ([p53alpha sequence](https://www.uniprot.org/uniprotkb/P04637/entry#sequences))
