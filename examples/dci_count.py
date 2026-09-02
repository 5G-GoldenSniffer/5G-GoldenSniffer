#!/usr/bin/env python3
import argparse
import re
import sys
from collections import defaultdict

PDCCH_RE = re.compile(r"PDCCH:")
PDSCH_RE = re.compile(r"PDSCH:")
FIELD6_CLEAN_RE = re.compile(r"\.[0-9]*\]")
LEADING_NUM_RE = re.compile(r"\s*[+-]?(\d+\.?\d*([eE][+-]?\d+)?|\.\d+([eE][+-]?\d+)?)")


def parse_args():
    p = argparse.ArgumentParser(
        description="Python translation of the awk gNB log-parsing script."
    )
    p.add_argument(
        "-l", "--logfile",
        help="Log file to parse",
    )
    p.add_argument(
        "--sfnini", type=int,
        help="SFNini value, window start",
    )
    p.add_argument(
        "--sfnfin", type=int,
        help="SFNfin value, window end",
    )
    p.add_argument(
        "-r", "--rnti-regex",
        default=r"rnti=0x460[12]",
        help="Regular expression used to filter lines by rnti (default: %(default)s)",
    )
    return p.parse_args()


def awk_to_int(s: str) -> int:
    """Replicate awk's string-to-number conversion (takes the leading numeric
    prefix of the string, ignoring the rest; if there is no valid numeric
    prefix, returns 0)."""
    m = LEADING_NUM_RE.match(s)
    if not m:
        return 0
    try:
        return int(float(m.group(0)))
    except ValueError:
        return 0


def print_table(C, label_width=12, col_width=10, drop_last_window=False):
    # data[rnti][fmt][w] = count
    data = defaultdict(lambda: defaultdict(dict))
    windows_all = set()
    window_sums = defaultdict(int)
    for (w, rnti, fmt), cnt in C.items():
        data[rnti][fmt][w] = cnt
        windows_all.add(w)
        window_sums[w] += cnt
    windows_all = sorted(windows_all)

    if drop_last_window and windows_all:
        last_window = windows_all[-1]
        windows_all = windows_all[:-1]
        for rnti in data:
            for fmt in data[rnti]:
                data[rnti][fmt].pop(last_window, None)

    print(f"{'RNTI':<{label_width}}{'WINDOW':>{col_width}}")

    for rnti in sorted(data.keys()):
        fmts = data[rnti]

        header = f"{rnti:<{label_width}}" + "".join(f"{w:>{col_width}}" for w in windows_all)
        print(header)

        for fmt in sorted(fmts.keys()):
            row = f"{fmt:<{label_width}}" + "".join(
                f"{fmts[fmt].get(w, 0):>{col_width}}" for w in windows_all
            )
            print(row)
    
    if len(windows_all) > 1:
        print("The specified range is ambiguous in the specified log file. These are all the possible interpretations.\n")
    else:
        print("")


def main():
    print(*sys.argv)
    args = parse_args()

    logfile = args.logfile
    sfnini = args.sfnini
    sfnfin = args.sfnfin
    try:
        rnti_re = re.compile(args.rnti_regex)
    except re.error as e:
        sys.exit(f"Invalid regular expression for --rnti-regex: {e}")

    W = 0
    X = 0
    SFN = -1
    C = defaultdict(int)

    with open(logfile, "r", errors="replace") as f:
        for line in f:
            if not rnti_re.search(line):
                continue
            isPDCCH = PDCCH_RE.search(line)
            isPDSCH = PDSCH_RE.search(line)
            if not isPDCCH and not isPDSCH:
                continue

            fields = line.split()
            if len(fields) < 10:
                continue

            # $6 -> fields[5], $8 -> fields[7], $10 -> fields[9]
            f6 = FIELD6_CLEAN_RE.sub("", fields[5])

            SFNprev = SFN
            SFN = awk_to_int(f6)

            if SFNprev > SFN:
                SFNprev -= 1024

            if SFN >= sfnini and SFNprev < sfnini:
                W += 1
                X = 1
            elif SFN > sfnfin and SFNprev <= sfnfin:
                X = 0

            if X == 1:
                if isPDCCH:
                    rnti = fields[7].replace("rnti=", "")
                    fmt = fields[9].replace("format=", "")
                    if fmt == '1_0':
                        C[(W, rnti, fmt)] += 1
                    else:
                        C[(W, rnti, 'UNC')] += 1
                if isPDSCH:
                    rv = fields[15].replace("rv=", "")
                    if awk_to_int(rv) > 0:
                        C[(W, rnti, '1_0')] -= 1
                        C[(W, rnti, 'UNC')] += 1

    print_table(C, drop_last_window=(X == 1))


if __name__ == "__main__":
    main()
