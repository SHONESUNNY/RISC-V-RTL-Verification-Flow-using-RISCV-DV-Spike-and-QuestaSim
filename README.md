# RISC-V Core Verification — RISCV-DV + Spike + Questa

A practical verification environment for a custom 5-stage pipelined RV32 RISC-V processor using:

- **RISCV-DV** for randomized RISC-V instruction/test generation
- **RISC-V GCC/binutils** for assembling/linking and binary conversion
- **Spike** as the architectural instruction-set simulator (ISS) reference model
- **QuestaSim** for RTL simulation
- A custom **RTL instruction memory / testbench** that loads RISCV-DV-generated HEX images
- **Trace parsing and architectural comparison** between Spike and the RTL

The verification flow is designed around one principle:

> The same generated program must be executed by the Spike reference model and by the RTL implementation, and their architectural behavior must be compared.

---

## 1. Project Status

This README documents the current working setup and the intended end-to-end verification flow.

### Currently working

- RISCV-DV installation and Python virtual environment
- RISCV-DV test generation
- Questa as the RISCV-DV simulator
- GCC RISC-V toolchain
- Clean 64-bit Spike build
- Direct Spike execution with commit logging
- `.bin` generation
- `.bin -> HEX` conversion
- RTL compilation with Questa
- RTL `work` library located under `rtl/work/`
- RTL instruction memory loading from `rtl/tb/hexfile.txt`
- RTL execution of a RISCV-DV-generated non-compressed RV32 test
- Spike and RTL fetching the same first instruction words

### In progress

- Robust RTL architectural commit trace
- Spike trace parser
- RTL trace parser
- Event-by-event architectural comparator
- Automated regression driver
- PASS/FAIL mailbox integration
- Large randomized regressions

---

# 2. Verification Architecture

The complete flow is:

```text
                         RISCV-DV
                            |
                            | generated assembly
                            v
                           .S
                            |
                            | GCC / assembler / linker
                            v
                           ELF
                         /     \
                        /       \
                       v         v
                    Spike      objcopy
                      |           |
                      |           v
                      |          BIN
                      |           |
                      |           | bin_to_hex.py
                      |           v
                      |          HEX
                      |           |
                      |           v
                      |        RTL / Questa
                      |           |
                      v           v
                  Spike log   RTL trace
                       \         /
                        \       /
                         v     v
                         Comparator
                             |
                             v
                       PASS / FAIL
```

### What each component does

| Component | Role |
|---|---|
| RISCV-DV | Generates RISC-V instruction streams and test programs |
| GCC/binutils | Builds the generated source into executable binary form |
| Spike | Executes the program as the architectural reference model |
| `objcopy` / BIN | Produces the raw instruction/data image used by RTL |
| `bin_to_hex.py` | Converts binary bytes into 32-bit HEX words for the RTL memory |
| RTL | Design under verification |
| Questa | Compiles and simulates the RTL/testbench |
| Trace parser | Converts Spike/RTL log formats into a common representation |
| Comparator | Detects the first architectural divergence |

---

# 3. Workspace

The current workspace is:

```text
~/riscv_spike_clean/
```

Current high-level structure:

```text
riscv_spike_clean/
├── riscv-dv/                         # RISCV-DV repository
│   ├── run.py
│   ├── target/
│   ├── yaml/
│   ├── scripts/
│   ├── .venv/
│   └── out_*/                        # Generated tests and logs
│
├── riscv-isa-sim/                    # Spike source/build tree
│   └── build/
│       └── spike
│
├── rtl/                              # Custom processor RTL
│   ├── src/
│   │   ├── ALU.sv
│   │   ├── branch.sv
│   │   ├── branch_target.sv
│   │   ├── control_unit.sv
│   │   ├── csr_file.sv
│   │   ├── EX_MEM.sv
│   │   ├── Extend_unit.sv
│   │   ├── forwarding_mux.sv
│   │   ├── hazard_unit.sv
│   │   ├── ID_EX.sv
│   │   ├── IF_ID.sv
│   │   ├── load_control_unit.sv
│   │   ├── MEM_WB.sv
│   │   ├── pc_logic.sv
│   │   ├── result_mux.sv
│   │   ├── riscv_top.sv
│   │   └── ...
│   │
│   ├── tb/
│   │   ├── riscv_tb.sv
│   │   └── hexfile.txt
│   │
│   └── work/                         # Questa compiled library
│
├── bin/ or utility scripts as needed
├── setup_env.sh
├── spike_2026-09-23.log
└── compare_trace.py                  # planned/current comparison utility
```

## Important working-directory rule

The Questa `work` library is intentionally kept **inside `rtl/`**.

Therefore run Questa commands from:

```bash
cd ~/riscv_spike_clean/rtl
```

Do not create `work` in the workspace root unless you intentionally change the flow.

---

# 4. Required Tools

The environment uses:

- Python 3.9+
- `git`
- `make`
- RISC-V GCC toolchain
- RISC-V `objcopy` / `objdump`
- RISCV-DV
- Spike
- QuestaSim 64-bit

The current RISC-V toolchain is installed under:

```text
/opt/riscv
```

Expected tools include:

```text
/opt/riscv/bin/riscv32-unknown-elf-gcc
/opt/riscv/bin/riscv32-unknown-elf-objcopy
/opt/riscv/bin/riscv32-unknown-elf-objdump
```

The current GCC toolchain target is `riscv32-unknown-elf`.

---

# 5. Environment Setup

The workspace contains an environment script:

```text
~/riscv_spike_clean/setup_env.sh
```

The current environment configuration is conceptually:

```bash
export DV_WS=$HOME/riscv_spike_clean
export RISCV_DV_ROOT=$DV_WS/riscv-dv
export RISCV=/opt/riscv
export RISCV_GCC=/opt/riscv/bin/riscv32-unknown-elf-gcc
export RISCV_OBJCOPY=/opt/riscv/bin/riscv32-unknown-elf-objcopy
export SPIKE_PATH=$DV_WS/riscv-isa-sim/build
export SPIKE=$SPIKE_PATH/spike
export QUESTA_HOME=$HOME/Downloads/questasim
export MTI_VCO_MODE=64
export PATH=$RISCV/bin:$QUESTA_HOME/bin:$PATH
```

Load it with:

```bash
cd ~/riscv_spike_clean
source setup_env.sh
```

Check the important variables:

```bash
echo "$RISCV_DV_ROOT"
echo "$RISCV_GCC"
echo "$RISCV_OBJCOPY"
echo "$SPIKE_PATH"
echo "$SPIKE"
echo "$QUESTA_HOME"
echo "$MTI_VCO_MODE"
```

Also verify that `RISCV_GCC` is actually exported:

```bash
env | grep RISCV_GCC
```

---

# 6. Questa 64-bit Setup

The Questa installation contains both 32-bit and 64-bit binaries.

The current machine is `x86_64`, so use the 64-bit simulator.

Set:

```bash
export MTI_VCO_MODE=64
export QUESTA_HOME=$HOME/Downloads/questasim
export PATH=$QUESTA_HOME/bin:$PATH
```

Verify:

```bash
vsim -version
vlog -version
```

If Questa attempts to use the wrong architecture, check:

```bash
uname -m
echo "$MTI_VCO_MODE"
```

Expected architecture:

```text
x86_64
```

---

# 7. RISCV-DV Setup

Enter the RISCV-DV repository:

```bash
cd ~/riscv_spike_clean/riscv-dv
```

Activate the Python environment:

```bash
source .venv/bin/activate
```

Check:

```bash
python3 --version
python3 run.py --help
```

The RISCV-DV command supports simulator selection. The current Questa simulator identifier is:

```text
questa
```

The default RISCV-DV simulator may be VCS, so explicitly specify Questa.

---

# 8. Spike Setup

Spike was built from source in:

```text
~/riscv_spike_clean/riscv-isa-sim/
```

The executable is:

```text
~/riscv_spike_clean/riscv-isa-sim/build/spike
```

Verify:

```bash
$SPIKE --help
```

A direct version/help check can also be performed with:

```bash
$SPIKE --help | head
```

## Important Spike option compatibility note

This Spike build does **not** support the RISCV-DV `--misaligned` option.

Do not use:

```text
--misaligned
```

with the current Spike binary.

The RISCV-DV Spike command configuration was adjusted accordingly. The original configuration should be kept as a backup if needed.

---

# 9. ISA Strategy

The custom RTL currently fetches 32-bit instructions and is being brought up using a **non-compressed instruction test**.

This matters because an `rv32imc` program can contain compressed 16-bit instructions. A 32-bit-only fetch path cannot simply assume:

```text
PC + 4
```

for every instruction.

For initial verification, use:

```text
riscv_non_compressed_instr_test
```

with the appropriate target configuration.

Avoid using a test containing compressed instructions until the RTL's C-extension/fetch support is explicitly verified.

## Why this distinction matters

A compressed instruction can produce addresses such as:

```text
0x80000000
0x80000004
0x80000006
0x8000000A
```

whereas a 32-bit-only stream advances as:

```text
0x80000000
0x80000004
0x80000008
0x8000000C
```

A mismatch caused by compressed instructions must not be confused with a datapath or control bug.

---

# 10. Generate a Test with RISCV-DV

The current known-good example uses the non-compressed test:

```bash
cd ~/riscv_spike_clean/riscv-dv
source .venv/bin/activate
source ~/riscv_spike_clean/setup_env.sh

python3 run.py \
  --target rv32imc \
  --test riscv_non_compressed_instr_test \
  --iterations 1 \
  --simulator questa \
  --iss spike
```

The generated files appear under a directory such as:

```text
riscv-dv/out_2026-09-23/asm_test/
```

Example:

```text
riscv_non_compressed_instr_test_0.o
riscv_non_compressed_instr_test_0.bin
```

## Note about the `.o` file

In the current flow, the generated `.o` file can be an executable ELF image even though its filename ends in `.o`.

For example:

```bash
file riscv_non_compressed_instr_test_0.o
```

can report an ELF 32-bit RISC-V executable.

Therefore do not assume that a missing `.elf` filename means the executable image does not exist.

---

# 11. Inspect the Generated Test

Before running the RTL, inspect the exact program.

Set:

```bash
TEST_O=~/riscv_spike_clean/riscv-dv/out_2026-09-23/asm_test/riscv_non_compressed_instr_test_0.o
TEST_BIN=~/riscv_spike_clean/riscv-dv/out_2026-09-23/asm_test/riscv_non_compressed_instr_test_0.bin
```

Check the executable type:

```bash
file "$TEST_O"
```

Disassemble it:

```bash
/opt/riscv/bin/riscv32-unknown-elf-objdump -d "$TEST_O" | head -80
```

The known-good September 23 test begins with:

```text
80000000: f14022f3   csrr   t0,mhartid
80000004: 00000313   li     t1,0
80000008: 00628263   beq    t0,t1,...
8000000c: 00000497   auipc  s1,0x0
80000010: 00c48493   addi   s1,s1,12
80000014: 00048067   jr     s1
```

These addresses and instruction words are useful sanity checks.

---

# 12. BIN → HEX Conversion

The converter is located at:

```text
~/riscv_spike_clean/rtl/bin_to_hex.py
```

The output HEX is:

```text
~/riscv_spike_clean/rtl/tb/hexfile.txt
```

Run:

```bash
cd ~/riscv_spike_clean

python3 ~/riscv_spike_clean/rtl/bin_to_hex.py \
  "$TEST_BIN" \
  ~/riscv_spike_clean/rtl/tb/hexfile.txt
```

Verify:

```bash
head -12 ~/riscv_spike_clean/rtl/tb/hexfile.txt
```

For the known-good test, the beginning is:

```text
f14022f3
00000313
00628263
00000497
00c48493
00048067
40001ab7
104a8a93
301a9073
0002c797
cc078793
00011a97
```

---

# 13. Validate BIN ↔ HEX Consistency

Use `xxd` on the binary:

```bash
xxd -g 4 -l 32 "$TEST_BIN"
```

The binary is little-endian, so for example:

```text
f32240f1  -> f14022f3
13030000  -> 00000313
63826200  -> 00628263
97040000  -> 00000497
9384c400  -> 00c48493
67800400  -> 00048067
```

This is a critical check because it proves that the instruction image passed to the RTL corresponds to the generated executable.

---

# 14. RTL Testbench

The RTL testbench is:

```text
rtl/tb/riscv_tb.sv
```

The custom core top-level is instantiated as `riscv`.

The testbench supplies signals including:

```text
clk
rst
instr_addr
instr_data
Valid_W
PCW
InstrW
RegWriteW
RdW
ResultW
MemWriteW
ALUResultW
WriteDataW
```

The instruction memory used by the testbench is populated from:

```text
rtl/tb/hexfile.txt
```

The current working-directory convention is important.

Because Questa is run from:

```text
~/riscv_spike_clean/rtl
```

the testbench should use:

```systemverilog
$readmemh("tb/hexfile.txt", imem);
```

not:

```systemverilog
$readmemh("rtl/tb/hexfile.txt", imem);
```

---

# 15. Questa `work` Library

The compiled Questa library is intentionally located at:

```text
~/riscv_spike_clean/rtl/work
```

Do the complete RTL compile/run flow from `rtl/`:

```bash
cd ~/riscv_spike_clean/rtl
```

Recreate the library when necessary:

```bash
rm -rf work
vlib work
```

Compile the RTL and testbench:

```bash
vlog src/*.sv tb/riscv_tb.sv
```

Run the testbench:

```bash
vsim work.riscv_tb
```

This distinction is important:

```text
riscv_spike_clean/rtl/work
```

is the correct library location for the current project layout.

---

# 16. RTL Instruction Memory Check

When the RTL simulation starts, the testbench should report values such as:

```text
mem[0]=f14022f3
mem[1]=00000313
mem[2]=00628263
mem[3]=00000497
mem[4]=00c48493
mem[5]=00048067
```

These should match the generated program.

If they do not match, stop debugging the core and fix the image-loading path first.

---

# 17. Extra Instruction-Memory Warning

The current RTL also contains an internal `instruction_memory.sv` path that attempts to load:

```text
hexfile.txt
```

When the simulation is launched from `rtl/`, this can generate:

```text
Failed to open readmem file "hexfile.txt"
```

while the external testbench memory still successfully loads:

```text
tb/hexfile.txt
```

This indicates that two instruction-memory mechanisms are currently present.

The long-term fix is to have one authoritative instruction-memory mechanism and one clear path convention. Until then, distinguish the warning from an actual failure of the testbench memory shown by the `mem[0]`, `mem[1]`, etc. messages.

---

# 18. Run Spike on the Exact Same Test

After the BIN/HEX path has been validated, run Spike on the exact executable that produced the BIN.

```bash
cd ~/riscv_spike_clean
source setup_env.sh

TEST_O=~/riscv_spike_clean/riscv-dv/out_2026-09-23/asm_test/riscv_non_compressed_instr_test_0.o

$SPIKE \
  --log-commits \
  --isa=rv32imc_zicsr_zifencei \
  --priv=m \
  "$TEST_O" > spike_2026-09-23.log 2>&1
```

Check:

```bash
head -40 spike_2026-09-23.log
```

For the known-good non-compressed run, the common instruction stream starts as:

```text
core   0: 3 0x80000000 (0xf14022f3) x5  0x00000000
core   0: 3 0x80000004 (0x00000313) x6  0x00000000
core   0: 3 0x80000008 (0x00628263)
core   0: 3 0x8000000c (0x00000497) x9  0x8000000c
core   0: 3 0x80000010 (0x00c48493) x9  0x80000018
core   0: 3 0x80000014 (0x00048067)
```

---

# 19. Why the Spike Log Has Two Formats

Spike can print both disassembly and commit information.

A disassembly line looks like:

```text
core 0: 0x8000000c (0x00000497) auipc s1,0x0
```

A commit line looks like:

```text
core 0: 3 0x8000000c (0x00000497) x9 0x8000000c
```

The RTL monitor may look like:

```text
T=115000 PC=8000000c INSTR=00000497 Rd=9 RegWrite=1 Result=8000000c
```

These are not supposed to be textually identical.

The verification flow therefore needs **parsing and normalization**, not raw string comparison.

---

# 20. Architectural Comparison Strategy

The correct comparison level is the **architectural commit/retirement event**, not the simulator clock cycle.

The reason is that the custom processor is pipelined while Spike is an instruction-set simulator. They have fundamentally different timing models.

Do not compare:

```text
Spike cycle 10 == RTL cycle 10
```

Instead compare events such as:

```text
PC
Instruction
Register write
Register value
Memory read
Memory write
```

For example, a common normalized format can be:

```text
PC=80000000 INSTR=f14022f3 RD=x5 VALUE=00000000
PC=80000004 INSTR=00000313 RD=x6 VALUE=00000000
PC=80000008 INSTR=00628263
PC=8000000c INSTR=00000497 RD=x9 VALUE=8000000c
```

Spike and RTL parsers should both produce this representation.

---

# 21. Spike Trace Parsing

The Spike commit format to extract is approximately:

```text
core 0: 3 0x<PC> (0x<INSTR>) x<RD> 0x<VALUE>
```

or, for an instruction with no register write:

```text
core 0: 3 0x<PC> (0x<INSTR>)
```

Loads can include memory information, for example:

```text
core 0: 3 0x0000100c (0x0182a283) x5  0x80000000 mem 0x00001018
```

The parser should preserve memory information when present.

Spike startup instructions in the `0x00001000` region should be treated separately from the core execution region if the RTL starts directly at `0x80000000`.

For the current bring-up, the comparison window starts at the first common PC:

```text
0x80000000
```

---

# 22. RTL Trace Strategy

The current RTL monitor prints pipeline signals every clock cycle. That is useful for debugging, but it is not yet an ideal architectural trace.

A better trace should be emitted when an instruction is valid at the writeback/retirement point.

The intended signal set is:

```text
Valid_W
PCW
InstrW
RegWriteW
RdW
ResultW
MemWriteW
ALUResultW
WriteDataW
```

A basic trace block can be:

```systemverilog
integer trace_fd;

initial begin
    trace_fd = $fopen("rtl_trace.log", "w");
    if (trace_fd == 0) begin
        $display("ERROR: cannot open rtl_trace.log");
        $finish;
    end
end

always @(posedge clk) begin
    if (!rst && Valid_W) begin
        $fdisplay(trace_fd,
                  "PC=%08h INSTR=%08h REGWRITE=%b RD=%0d RESULT=%08h",
                  PCW, InstrW, RegWriteW, RdW, ResultW);
    end
end

final begin
    $fclose(trace_fd);
end
```

### Important timing note

SystemVerilog nonblocking assignments update at the end of the current time step. Therefore a debug monitor placed on the same clock edge can observe pipeline signals before their intended updated values appear.

If the displayed `PC/INSTR` and `Rd/Result` appear to belong to different instructions, the monitor timing must be adjusted or signals must be tapped at a well-defined retirement point.

Do not interpret a badly synchronized debug print as proof that the RTL datapath is wrong.

---

# 23. Initial Comparison: PC + Instruction

Before adding all register and memory semantics, the simplest first parser should compare:

```text
PC
INSTR
```

Example:

```text
Spike:
PC=8000000c INSTR=00000497

RTL:
PC=8000000c INSTR=00000497
```

This checks the instruction stream and control-flow alignment.

Once PC/instruction alignment is stable, extend the comparator to:

```text
Register writes
Register values
Memory reads
Memory writes
```

---

# 24. Why `Rd` Must Be Conditioned on `RegWrite`

A branch or store can contain an encoded register field even though it does not write a register.

For example, RTL may print:

```text
INSTR=00628263 Rd=4 RegWrite=0
```

The `Rd=4` field is not an architectural register write in this case.

The comparator should only compare `Rd` and `Result` when:

```text
RegWrite == 1
```

and normally ignore writes to `x0` because RISC-V defines `x0` as hardwired zero.

---

# 25. Same-Test Rule

One of the most important rules in the flow is:

> Spike and RTL must be driven by the exact same generated test image.

A common failure mode is comparing:

```text
Spike log from riscv_arithmetic_basic_test
```

against:

```text
HEX from riscv_non_compressed_instr_test
```

That makes the traces appear inconsistent even when the tools are working correctly.

For every comparison, record:

```text
Test name
Iteration number
RISCV-DV output directory
Executable image
BIN file
HEX file
Spike log
RTL log
Seed, when applicable
```

---

# 26. Recommended Test Artifact Naming

For reproducibility, use a consistent naming scheme such as:

```text
regressions/
└── debug/
    └── 2026-09-23_non_compressed_000/
        ├── test.o
        ├── test.bin
        ├── test.hex
        ├── test.dump
        ├── spike.log
        ├── rtl.log
        ├── rtl_trace.log
        └── compare.log
```

This makes a failed test independently reproducible.

---

# 27. End-to-End Manual Smoke Test

The current manual procedure is:

## Step 1 — Load environment

```bash
cd ~/riscv_spike_clean
source setup_env.sh
```

## Step 2 — Activate RISCV-DV environment

```bash
cd ~/riscv_spike_clean/riscv-dv
source .venv/bin/activate
```

## Step 3 — Generate one test

```bash
python3 run.py \
  --target rv32imc \
  --test riscv_non_compressed_instr_test \
  --iterations 1 \
  --simulator questa \
  --iss spike
```

## Step 4 — Identify the exact BIN

```bash
find out_* -type f -name 'riscv_non_compressed_instr_test_0.bin' | sort
```

## Step 5 — Convert BIN to HEX

```bash
cd ~/riscv_spike_clean

python3 rtl/bin_to_hex.py \
  riscv-dv/out_2026-09-23/asm_test/riscv_non_compressed_instr_test_0.bin \
  rtl/tb/hexfile.txt
```

## Step 6 — Verify HEX

```bash
head -12 rtl/tb/hexfile.txt
```

## Step 7 — Rebuild RTL simulation

```bash
cd ~/riscv_spike_clean/rtl
rm -rf work
vlib work
vlog src/*.sv tb/riscv_tb.sv
```

## Step 8 — Run RTL

```bash
vsim work.riscv_tb
```

Then in the Questa console:

```text
run 1000ns
```

or use the required simulation time for the current testbench.

## Step 9 — Run Spike

```bash
cd ~/riscv_spike_clean
source setup_env.sh

TEST_O=~/riscv_spike_clean/riscv-dv/out_2026-09-23/asm_test/riscv_non_compressed_instr_test_0.o

$SPIKE \
  --log-commits \
  --isa=rv32imc_zicsr_zifencei \
  --priv=m \
  "$TEST_O" > spike_2026-09-23.log 2>&1
```

## Step 10 — Compare

First compare instruction stream:

```text
Spike PC/INSTR
        vs
RTL PC/INSTR
```

Then compare architectural state:

```text
register writes
memory operations
```

---

# 28. Automated Comparison Flow

The intended automated flow is:

```bash
python3 run_verification.py --test riscv_non_compressed_instr_test --iterations 1
```

Conceptually this script should:

```text
1. Select RISCV-DV output
2. Record the test/seed/image
3. Convert BIN → HEX
4. Build RTL work library
5. Run RTL
6. Run Spike
7. Parse Spike trace
8. Parse RTL trace
9. Normalize events
10. Compare events
11. Print first mismatch
12. Store logs and artifacts
```

The desired failure message is not merely:

```text
FAIL
```

It should identify the first divergence, for example:

```text
FIRST MISMATCH
Instruction index : 142
Spike:
  PC      = 0x80000238
  INSTR   = 0x00a585b3
  RD      = x11
  VALUE   = 0x0000002f

RTL:
  PC      = 0x80000238
  INSTR   = 0x00a585b3
  RD      = x11
  VALUE   = 0x0000002b
```

That immediately narrows the debugging target.

---

# 29. Register State Comparison

For instructions that write a register, compare:

```text
PC
instruction
RD
value written
```

Example:

```text
Spike: x9 = 0x80000018
RTL:   x9 = 0x80000018
```

For instructions with no register write:

```text
RegWrite = 0
```

do not compare an irrelevant `Rd`/`Result` field from the RTL monitor.

---

# 30. Memory Comparison

The comparator should eventually support:

### Load

```text
PC
instruction
destination register
loaded value
memory address
```

### Store

```text
PC
instruction
memory address
stored value
store width
```

The RTL signals available for stores include:

```text
MemWriteW
ALUResultW
WriteDataW
```

These should be normalized against Spike's memory annotations.

---

# 31. CSR and Privileged Execution

The generated tests can contain privileged/CSR instructions, particularly during startup and initialization.

Examples already observed include:

```text
csrr t0,mhartid
csrw misa,s5
csrw mtvec,s5
csrw mepc,s5
csrw mstatus,s5
mret
```

For initial functional bring-up, separate:

```text
startup / privileged setup
```

from:

```text
main test instruction stream
```

The RTL must ultimately model the required CSRs and privileged behavior for the selected test configuration.

---

# 32. Boot / Address Map Consistency

The linker address and RTL reset/instruction-memory address must agree.

The current RISCV-DV-generated test places `_start` at:

```text
0x80000000
```

The RTL testbench therefore uses an instruction-memory address translation conceptually equivalent to:

```systemverilog
imem[(instr_addr - 32'h80000000) >> 2]
```

This means:

```text
PC 0x80000000 -> imem[0]
PC 0x80000004 -> imem[1]
PC 0x80000008 -> imem[2]
```

This relationship must stay consistent between:

```text
linker
RISCV-DV configuration
Spike execution image
RTL reset PC
RTL instruction memory
```

---

# 33. Startup Code at `0x1000`

Spike may execute a small machine-mode startup sequence near:

```text
0x00001000
```

before jumping into the generated image at:

```text
0x80000000
```

Example observed sequence:

```text
0x1000  auipc
0x1004  addi
0x1008  csrr
0x100c  lw
0x1010  jr
```

For the current RTL bring-up, the core is starting directly from:

```text
0x80000000
```

Therefore the first meaningful common comparison point is the first common PC rather than blindly comparing line 1 of each log.

A production verification environment should eventually decide whether startup code is modeled identically on both sides or explicitly excluded from the comparison window.

---

# 34. PASS / FAIL Mechanism

A robust regression environment should not rely on a simulation simply ending by timeout.

A recommended mechanism is a memory-mapped mailbox:

```text
MAILBOX_ADDR = implementation-defined
PASS_CODE    = implementation-defined
FAIL_CODE    = implementation-defined
```

Firmware writes a pass/fail code to the mailbox.

The RTL testbench monitors that address and:

```text
PASS -> print PASS and stop
FAIL -> print FAIL and stop
TIMEOUT -> print TIMEOUT and stop
```

A typical future testbench structure is:

```text
reset
  |
  v
start core
  |
  v
execute test
  |
  +---- mailbox PASS ----> PASS
  |
  +---- mailbox FAIL ----> FAIL
  |
  +---- timeout ----------> TIMEOUT
```

---

# 35. Timeout Handling

Every automated RTL simulation should have a finite timeout.

For example:

```systemverilog
initial begin
    #10_000_000;
    $display("TIMEOUT");
    $finish;
end
```

Use a timeout long enough for the generated test but finite enough to detect an infinite loop or deadlock.

The timeout should be reported explicitly rather than allowing an unattended regression to run forever.

---

# 36. Waveform Debugging

When a trace mismatch is found, use Questa waveform inspection to determine whether the first divergence originates in:

```text
IF / PC generation
instruction fetch
decode/control
operand read
ALU
branch target
hazard/forwarding
memory access
CSR
writeback
```

Useful signals include:

```text
PC
instruction
pipeline valid bits
RS1 / RS2
RD
ALU control
ALU result
branch decision
branch target
memory address
memory write data
memory write enable
writeback result
register write enable
CSR controls
```

The first architectural mismatch should be treated as the primary debug point.

---

# 37. Common Failure Modes

## `vcs: not found`

RISCV-DV defaults to VCS in some configurations.

Use:

```bash
--simulator questa
```

---

## `work` library not found

Cause: `vsim` was started from a directory that does not contain the compiled `work` library.

Current project rule:

```bash
cd ~/riscv_spike_clean/rtl
vlib work
vlog src/*.sv tb/riscv_tb.sv
vsim work.riscv_tb
```

---

## `Failed to open readmem file`

Check the testbench path relative to the Questa working directory.

From `rtl/`, use:

```systemverilog
$readmemh("tb/hexfile.txt", imem);
```

---

## RTL loads `xxxxxxxx`

Check:

```text
hexfile path
HEX file contents
$readmemh timing
instruction address
reset PC
memory index calculation
```

A quick check is:

```text
mem[0]
mem[1]
mem[2]
```

---

## Spike command becomes `/spike`

If:

```bash
echo "$SPIKE_PATH"
```

is empty, then:

```bash
source ~/riscv_spike_clean/setup_env.sh
```

and verify:

```bash
echo "$SPIKE"
```

---

## `--misaligned` is rejected

The current Spike build does not support this option.

Remove it from the RISCV-DV Spike invocation/configuration.

---

## Spike and RTL instruction streams differ

First check that they were generated from the same test.

Then verify:

```text
same executable
same BIN
same HEX
same reset/link address
same ISA assumptions
```

---

## Spike contains compressed instructions but RTL does not

Use the non-compressed RISCV-DV test until the RTL supports compressed fetch/decode.

Do not treat this as a random datapath failure.

---

## RTL `Rd/Result` appears wrong even though `PC/INSTR` is correct

Likely cause:

```text
pipeline signals sampled on the wrong simulation phase
```

Move the trace to a well-defined retirement point or use delayed sampling so that all reported fields correspond to the same instruction.

---

## Spike runs but RTL fails

Check in this order:

```text
1. Same test/image?
2. HEX correct?
3. RTL loaded correct words?
4. Reset PC correct?
5. ISA supported?
6. CSR/privileged instructions supported?
7. Branch target correct?
8. Hazard/forwarding correct?
9. Memory model correct?
10. PASS/FAIL mechanism correct?
```

---

# 38. Regression Strategy

Use three classes of tests.

## Smoke regression

Small number of deterministic tests:

```text
1–5 iterations
```

Purpose:

```text
basic connectivity
instruction fetch
ALU
branch
load/store
CSR
termination
```

## Random regression

More iterations of randomized RISCV-DV tests.

Record:

```text
test name
seed
iteration
ISA
configuration
```

## Debug regression

A failing test reproduced using a fixed seed.

Example concept:

```bash
python3 run.py \
  --test riscv_rand_instr_test \
  --iterations 1 \
  --seed 12345 \
  --simulator questa \
  --iss spike
```

The exact supported CLI options depend on the installed RISCV-DV revision.

---

# 39. Recommended Debug Order

When a test fails, debug from the outside inward:

```text
1. Test identity
2. Generated executable
3. Disassembly
4. BIN
5. HEX
6. RTL memory contents
7. PC / instruction stream
8. Commit trace
9. Register values
10. Memory behavior
11. Pipeline internals
```

This prevents spending time debugging RTL logic when the actual problem is a stale or mismatched test image.

---

# 40. Reproducibility Checklist

Every regression result should be reproducible from:

```text
RISCV-DV revision
Spike revision/build
GCC version
Questa version
RTL git revision
RISCV-DV test
seed
iteration
ISA
MABI
program image
HEX
```

For a failing test, preserve:

```text
*.o / executable image
*.bin
*.hex
Spike log
RTL log
normalized traces
waveform, if available
comparison report
```

---

# 41. Current Verified Example

The following exact chain has been validated during bring-up:

```text
RISCV-DV:
  riscv_non_compressed_instr_test_0.o
             |
             v
  riscv_non_compressed_instr_test_0.bin
             |
             v
  rtl/tb/hexfile.txt
             |
             v
  Questa RTL simulation
```

The beginning of the HEX image is:

```text
f14022f3
00000313
00628263
00000497
00c48493
00048067
```

The same instruction words are present in the executable disassembly and in the binary image.

Spike's corresponding commit stream begins:

```text
80000000  f14022f3
80000004  00000313
80000008  00628263
8000000c  00000497
80000010  00c48493
80000014  00048067
```

The RTL instruction fetch path has also been observed fetching these same words.

This establishes that the basic image-delivery path is working:

```text
RISCV-DV -> BIN -> HEX -> RTL instruction memory
```

---

# 42. Definition of Done

The verification environment should ultimately satisfy all of the following.

### Tool/setup acceptance

- `python3 run.py --help` works
- `spike --help` works
- RISC-V GCC version command works
- Questa 64-bit starts
- RISCV-DV generates a test

### Image-flow acceptance

- Generated executable can be inspected/disassembled
- executable → BIN works
- BIN → HEX works
- RTL testbench loads HEX correctly
- RTL fetches expected instruction words

### Execution acceptance

- Spike executes the selected test
- RTL executes the same test
- RTL has PASS/FAIL/timeout termination
- No uncontrolled simulator hang

### Comparison acceptance

- Spike commit log is parsed
- RTL commit trace is parsed
- Both are normalized to a common event format
- PC/instruction stream is compared
- Register writes are compared
- Memory operations are compared
- First mismatch is reported with enough context to debug

### Regression acceptance

- Tests can be run from a repeatable command
- seeds are recorded
- logs are archived
- failing tests can be reproduced

---

# 43. Useful Command Reference

## Environment

```bash
cd ~/riscv_spike_clean
source setup_env.sh
```

## RISCV-DV

```bash
cd ~/riscv_spike_clean/riscv-dv
source .venv/bin/activate
python3 run.py --help
```

## Generate known-good non-compressed test

```bash
python3 run.py \
  --target rv32imc \
  --test riscv_non_compressed_instr_test \
  --iterations 1 \
  --simulator questa \
  --iss spike
```

## Inspect test

```bash
file <test>
/opt/riscv/bin/riscv32-unknown-elf-objdump -d <test> | head -80
```

## BIN → HEX

```bash
python3 ~/riscv_spike_clean/rtl/bin_to_hex.py \
  <test.bin> \
  ~/riscv_spike_clean/rtl/tb/hexfile.txt
```

## Check HEX

```bash
head -20 ~/riscv_spike_clean/rtl/tb/hexfile.txt
```

## Check binary words

```bash
xxd -g 4 -l 64 <test.bin>
```

## Rebuild RTL

```bash
cd ~/riscv_spike_clean/rtl
rm -rf work
vlib work
vlog src/*.sv tb/riscv_tb.sv
```

## Run RTL

```bash
vsim work.riscv_tb
```

## Run Spike

```bash
cd ~/riscv_spike_clean
source setup_env.sh

$SPIKE \
  --log-commits \
  --isa=rv32imc_zicsr_zifencei \
  --priv=m \
  <test.o> > spike.log 2>&1
```

## Read Spike commits

```bash
head -40 spike.log
```

---

# 44. Notes for Future Development

The next useful implementation steps are:

1. Make RTL retirement tracing authoritative and timing-safe.
2. Write a Spike commit parser.
3. Write an RTL commit parser.
4. Normalize both traces into a common event schema.
5. Compare PC/instruction first.
6. Add register-write comparison.
7. Add memory-operation comparison.
8. Add first-mismatch context windows.
9. Add fixed-seed reproducibility.
10. Add one-command regression automation.
11. Add mailbox PASS/FAIL handling.
12. Add waveform capture only on failures.
13. Expand from directed/non-compressed tests to larger RISCV-DV regressions.
14. Enable compressed instructions only after the RTL fetch/decode path explicitly supports them.

---

# 45. Core Verification Principle

The verification environment should always preserve this chain:

```text
ONE GENERATED TEST
       |
       +--------------------+
       |                    |
       v                    v
     Spike                   RTL
       |                    |
       v                    v
Reference events       RTL events
       |                    |
       +---------+----------+
                 |
                 v
             COMPARATOR
                 |
           +-----+-----+
           |           |
         PASS         FAIL
```

A mismatch is meaningful only when the two sides are executing the **same instruction image under compatible ISA and memory-map assumptions**.

That is the foundation of the entire project.

---

## Reference

The workspace procedure and acceptance criteria in this README were aligned with the project setup/run guide provided for the RISCV-DV + Spike flow, while the paths, commands, RTL structure, and current bring-up details reflect the actual `~/riscv_spike_clean` environment used for this project.
