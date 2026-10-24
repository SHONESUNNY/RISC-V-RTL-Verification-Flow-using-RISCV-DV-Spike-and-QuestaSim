# RISC-V Core Verification

A verification environment for a custom **5-stage, 32-bit RISC-V  processor** using SystemVerilog, QuestaSim, Spike, and RISCV-DV. The goal is to execute the same program on the RTL and Spike, then compare their architectural results.

## Current Status

- Implemented the initial RV32I instruction execution and retirement tracing.
- Achieved **85 matching retirement events with zero mismatches** against Spike. This is an initial verification checkpoint, not proof of complete RV32I compliance.
- Set up RISCV-DV, the RISC-V GCC toolchain, Spike, and QuestaSim.
- Built a trace comparator for RTL-versus-Spike verification.
- Future work: expand RV32I testing, implement RV32M, and add privileged architecture support.

## Verification Flow

```text
RISCV-DV → Assembly → GCC / binutils
                         |
                    Executable
                    /         \
                 Spike        BIN
                  |            |
              Spike log    BIN → HEX
                               |
                           RTL / Questa
                               |
                           RTL trace
                               |
                     Trace comparison
                               |
                          PASS / FAIL
```

RISCV-DV generates instruction tests, GCC/binutils builds them, and Spike serves as the architectural reference. QuestaSim executes the processor RTL. The comparator checks architectural retirement events rather than clock cycles because Spike and a pipelined processor have different timing models.

## Project Structure

```text
riscv_spike_clean/
├── setup_env.sh
├── riscv-dv/             # Test generation
├── riscv-isa-sim/        # Spike
├── rtl/
│   ├── src/              # Processor RTL
│   ├── tb/               # Testbench and HEX image
│   ├── bin_to_hex.py     # Binary-to-HEX converter
│   └── work/             # Questa library
└── compare/
    ├── rtl_trace.log
    └── compare_traces.py
```

## Environment Setup

Load the common environment script in each new terminal:

```bash
cd ~/riscv_spike_clean
source setup_env.sh
```

Activate the RISCV-DV Python environment:

```bash
cd ~/riscv_spike_clean/riscv-dv
source .venv/bin/activate
```

The setup script configures the RISC-V toolchain, Spike, and Questa paths. The virtual environment provides the Python packages required by RISCV-DV.

## Generate a Randomized Test

```bash
cd ~/riscv_spike_clean/riscv-dv
source .venv/bin/activate
source ~/riscv_spike_clean/setup_env.sh

python3 run.py \
  --simulator pyflow \
  --target rv32i \
  --test riscv_rand_instr_test \
  --iterations 1 \
  --steps gen,gcc_compile,iss_sim \
  --output out_rv32i_300_nosubprog
```

The current experiment uses 300 requested instructions, zero subprograms, and disabled directed-instruction streams. These settings are configured in `yaml/base_testlist.yaml`.

**Note:** Selecting `rv32i` does not necessarily remove all privileged startup and termination code. Inspect the generated program before running it on a core that does not yet support privileged instructions.

## Convert the Binary To HEX for RTL Simulation

```bash
cd ~/riscv_spike_clean

TEST_BIN=~/riscv_spike_clean/riscv-dv/out_rv32i_300_nosubprog/asm_test/riscv_rand_instr_test_0.bin

python3 rtl/bin_to_hex.py \
  "$TEST_BIN" rtl/tb/hexfile.txt

head -12 rtl/tb/hexfile.txt
```

Verify the HEX words against the generated binary and disassembly. If the testbench loads different instructions, check the file path and conversion before debugging the processor.

## Run the RTL in QuestaSim

Run Questa from the `rtl/` directory so its library and relative file paths resolve correctly.

```bash
cd ~/riscv_spike_clean/rtl

vlog src/*.sv tb/riscv_tb.sv

vsim -c work.riscv_tb \
  +DATA_HEX=tb/hexfile.txt \
  -do "run 5000ns; quit -f" > rtl_run.log 2>&1
```

The `+DATA_HEX` argument supplies the data-memory image when supported by the testbench. The retirement trace is written to `../compare/rtl_trace.log`.

## Run Spike and Compare

Run Spike on the executable corresponding to the exact BIN/HEX image used by the RTL.

```bash
cd ~/riscv_spike_clean
source setup_env.sh

TEST_O=~/riscv_spike_clean/riscv-dv/out_rv32i_300_nosubprog/asm_test/riscv_rand_instr_test_0.o

"$SPIKE" --log-commits --isa=rv32i \
  "$TEST_O" > spike.log 2>&1
```

Compare the traces:

```bash
python3 compare/compare_traces.py \
  --rtl compare/rtl_trace.log \
  --spike spike.log
```

Use ISA options compatible with the selected program and the Spike build. The current generated test still contains privileged framework code, so it has **not yet been validated end-to-end against the RTL**.

The comparator should check:

- Program counter and instruction
- Register destination and written value
- Memory addresses and store data

Compare register results only when an instruction actually writes a register. Branches and stores may contain encoded register fields without performing a register write.

## Current Limitations

- **Compressed instructions (C):** The current fetch path expects 32-bit instructions.
- **RV32M:** Multiply, divide, and remainder instructions are not yet supported by the current RV32I-only core.
- **Privileged architecture:** Machine-mode CSRs, trap handling, `mret`, and related functionality are not yet complete for the current verification flow.
- **Randomized testing:** The newly generated test still needs integration with the RTL before its results can be compared.

## Next Steps

1. Preserve and reproduce the 85-event, zero-mismatch baseline.
2. Improve randomized RV32I verification.
3. Implement and verify RV32M.
4. Add machine-mode CSRs, traps, and privileged instructions.
5. Expand regression coverage and automate trace comparison.

## Core Verification Principle

**One test image, two executions, one architectural comparison.**

Keep the executable, BIN, HEX, Spike log, RTL trace, and test seed together so every mismatch can be reproduced.
