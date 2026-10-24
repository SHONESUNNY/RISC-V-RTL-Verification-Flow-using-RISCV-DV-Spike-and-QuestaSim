#!/bin/bash

# Workspace
export DV_WS=$HOME/riscv_spike_clean
export RISCV_DV_ROOT=$DV_WS/riscv-dv

# RV32 GCC toolchain
export RISCV=/opt/riscv
export RISCV_GCC=/opt/riscv/bin/riscv32-unknown-elf-gcc
export RISCV_OBJCOPY=/opt/riscv/bin/riscv32-unknown-elf-objcopy

# Spike
export SPIKE_PATH=$DV_WS/riscv-isa-sim/build
export SPIKE=$SPIKE_PATH/spike

# Questa
export QUESTA_HOME=$HOME/Downloads/questasim
export MTI_VCO_MODE=64

# PATH
export PATH=$RISCV/bin:$QUESTA_HOME/bin:$PATH
