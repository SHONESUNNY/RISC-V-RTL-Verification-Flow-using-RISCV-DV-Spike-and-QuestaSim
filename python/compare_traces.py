
#!/usr/bin/env python3

"""Compare RTL retirement records with Spike commit records."""

import argparse
import re
import sys
from pathlib import Path

START_PC = 0x80000000

SPIKE_RE = re.compile(
    r"^core\s+\d+:\s+3\s+0x([0-9a-fA-F]+)\s+"
    r"\(0x([0-9a-fA-F]+)\)(.*)$"
)

SPIKE_GPR_RE = re.compile( r"\bx(\d+)\s+0x([0-9a-fA-F]+)(?=\s|$)"
)

RTL_RE = re.compile(
    r"^RETIRE\s+PC=([0-9a-fA-F]+)\s+"
    r"INSTR=([0-9a-fA-F]+)\s+"
    r"RegWrite=([01])\s+Rd=(\d+)\s+"
    r"Result=([0-9a-fA-FxXzZ]+)"
)


def read_spike(path):
    records = []

    with path.open(errors="replace") as file:
        for line_number, line in enumerate(file, 1):
            match = SPIKE_RE.search(line.strip())
            if not match:
                continue

            pc = int(match.group(1), 16)
            instr = int(match.group(2), 16)

            # Ignore Spike's boot code below the test's load address.
            if pc < START_PC:
                continue

            tail = match.group(3)
            write = SPIKE_GPR_RE.search(tail)

            rd = None
            value = None
            if write:
                rd = int(write.group(1))
                value = int(write.group(2), 16) & 0xFFFFFFFF

                # x0 is hardwired to zero; it is not an architectural GPR write.
                if rd == 0:
                    rd = None
                    value = None

            records.append({
                "pc": pc,
                "instr": instr,
                "rd": rd,
                "value": value,
                "line": line_number,
            })

    return records


def read_rtl(path):
    records = []

    with path.open(errors="replace") as file:
        for line_number, line in enumerate(file, 1):
            match = RTL_RE.search(line.strip())
            if not match:
                continue

            pc = int(match.group(1), 16)
            instr = int(match.group(2), 16)
            regwrite = match.group(3) == "1"
            rd = int(match.group(4))
            result_text = match.group(5)

            if pc < START_PC:
                continue

            writes_gpr = regwrite and rd != 0
            value = None

            if writes_gpr and not re.search(r"[xXzZ]", result_text):
                value = int(result_text, 16) & 0xFFFFFFFF

            records.append({
                "pc": pc,
                "instr": instr,
                "rd": rd if writes_gpr else None,
                "value": value,
                "has_gpr_write": writes_gpr,
                "line": line_number,
            })

    return records


def hx(value, width=8):
    return f"0x{value:0{width}x}"


def main():
    parser = argparse.ArgumentParser(
        description="Compare RTL retirement trace against Spike commits."
    )
    parser.add_argument("--rtl", type=Path, required=True)
    parser.add_argument("--spike", type=Path, required=True)
    parser.add_argument("--max-errors", type=int, default=20)
    args = parser.parse_args()

    for path in (args.rtl, args.spike):
        if not path.is_file():
            print(f"ERROR: File not found: {path}", file=sys.stderr)
            return 2

    rtl = read_rtl(args.rtl)
    spike = read_spike(args.spike)

    print(f"RTL retirement records: {len(rtl)}")
    print(f"Spike commits from {START_PC:#010x}: {len(spike)}")

    if not rtl or not spike:
        print("ERROR: One or both traces contain no comparable records.")
        return 2

    compared = min(len(rtl), len(spike))
    errors = 0

    for index in range(compared):
        r = rtl[index]
        s = spike[index]
        differences = []

        if r["pc"] != s["pc"]:
            differences.append(
                f"PC RTL={hx(r['pc'])}, Spike={hx(s['pc'])}"
            )

        if r["instr"] != s["instr"]:
            differences.append(
                f"INSTR RTL={hx(r['instr'])}, Spike={hx(s['instr'])}"
            )

        # Only compare GPR effects when the instruction identity matches.
        if r["pc"] == s["pc"] and r["instr"] == s["instr"]:
            rtl_writes = r["has_gpr_write"]
            spike_writes = s["rd"] is not None

            if rtl_writes != spike_writes:
                differences.append(
                    f"GPR-write presence RTL={rtl_writes}, "
                    f"Spike={spike_writes}"
                )
            elif rtl_writes and spike_writes:
                if r["rd"] != s["rd"]:
                    differences.append(
                        f"RD RTL=x{r['rd']}, Spike=x{s['rd']}"
                    )

                if r["value"] is None:
                    differences.append(
                        f"RTL result is unknown: {r['value']}"
                    )
                elif r["value"] != s["value"]:
                    differences.append(
                        f"VALUE RTL={hx(r['value'])}, "
                        f"Spike={hx(s['value'])}"
                    )

        if differences:
            errors += 1
            if errors <= args.max_errors:
                print(f"\nMismatch at retirement index {index}:")
                print(
                    f"  RTL   line {r['line']}: "
                    f"PC={hx(r['pc'])} INSTR={hx(r['instr'])}"
                )
                print(
                    f"  Spike line {s['line']}: "
                    f"PC={hx(s['pc'])} INSTR={hx(s['instr'])}"
                )
                for difference in differences:
                    print(f"  - {difference}")

    print(f"\nCompared records: {compared}")
    print(f"Mismatch records: {errors}")

    if len(rtl) < len(spike):
        print(
            f"NOTE: RTL trace is shorter by {len(spike) - len(rtl)} "
            "records. The simulation may have stopped early."
        )
    elif len(spike) < len(rtl):
        print(
            f"NOTE: Spike trace is shorter by {len(rtl) - len(spike)} "
            "records. Check whether the Spike log is complete."
        )

    if errors > args.max_errors:
        print(f"Only the first {args.max_errors} mismatch records are shown.")

    if errors == 0:
        print(
            "\nNo mismatches found in the compared prefix. "
            "This is not proof of full-program correctness unless "
            "both traces cover the complete test."
        )
        return 0

    return 1


if __name__ == "__main__":
    sys.exit(main())
