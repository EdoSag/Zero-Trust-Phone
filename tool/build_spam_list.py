#!/usr/bin/env python3
"""Builds ZT Phone's spam list (P24) for the weekly "Spam list" workflow.

Usage: build_spam_list.py <out.txt> [--reported spam/reported.tsv]
                          [--days 30] [--min-reports 3] [--csv-dir DIR]

Sources, both public:
  * Complaints to the US National Do Not Call Registry, published daily by
    the FTC as public-domain CSV files ("Do Not Call reported calls data").
    A number is listed when at least --min-reports complaints in the last
    --days days name it.
  * spam/reported.tsv in this repository: numbers reported to ZT Phone and
    checked by hand (any country), one per line: +E.164, tab, note.

--csv-dir reads the FTC files from a folder instead of downloading them
(for tests). The output format is what SpamList.kt reads:
  # ZT Phone spam list, format 1.
  # list-date: yyyy-mm-ddThh:mm   (UTC)
  +12025550123<TAB>reports
"""
import argparse
import csv
import datetime as dt
import io
import os
import re
import sys
import urllib.request

HEADER = '# ZT Phone spam list, format 1.'
FTC_URL = 'https://www.ftc.gov/sites/default/files/DNC_Complaint_Numbers_{date}.csv'
MAX_ENTRIES = 300_000


def us_number(raw):
    digits = re.sub(r'\D', '', raw or '')
    if len(digits) == 11 and digits.startswith('1'):
        digits = digits[1:]
    # NANP: area code and exchange never start with 0 or 1.
    if len(digits) != 10 or digits[0] in '01' or digits[3] in '01':
        return None
    return '+1' + digits


def phone_column(header):
    for i, name in enumerate(header):
        n = name.strip().lower()
        if n in ('company_phone_number', 'company phone number'):
            return i
    for i, name in enumerate(header):
        n = name.strip().lower()
        if 'phone' in n and 'number' in n and 'consumer' not in n:
            return i
    return None


def count_csv(text, counts):
    rows = csv.reader(io.StringIO(text))
    header = next(rows, None)
    if not header:
        return 0
    col = phone_column(header)
    if col is None:
        return 0
    seen = 0
    for row in rows:
        if col < len(row):
            n = us_number(row[col])
            if n:
                counts[n] = counts.get(n, 0) + 1
                seen += 1
    return seen


def ftc_files(days, csv_dir):
    today = dt.datetime.now(dt.timezone.utc).date()
    for back in range(1, days + 1):
        date = (today - dt.timedelta(days=back)).isoformat()
        if csv_dir:
            path = os.path.join(csv_dir, f'DNC_Complaint_Numbers_{date}.csv')
            if os.path.exists(path):
                with open(path, encoding='utf-8', errors='replace') as f:
                    yield date, f.read()
            continue
        req = urllib.request.Request(FTC_URL.format(date=date),
                                     headers={'User-Agent': 'ZT-Phone-spam-list'})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                if r.status == 200:
                    yield date, r.read(64 * 1024 * 1024).decode('utf-8', 'replace')
        except Exception as e:  # A missing day (weekend, holiday) is normal.
            print(f'  {date}: {e}', file=sys.stderr)


def reported(path):
    out = {}
    if not path or not os.path.exists(path):
        return out
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            number = line.split('\t')[0].strip()
            if re.fullmatch(r'\+[1-9]\d{6,14}', number):
                out[number] = max(out.get(number, 0), 1)
            else:
                print(f'  skipped "{number}": not +E.164', file=sys.stderr)
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument('out')
    p.add_argument('--reported', default='spam/reported.tsv')
    p.add_argument('--days', type=int, default=30)
    p.add_argument('--min-reports', type=int, default=3)
    p.add_argument('--csv-dir')
    a = p.parse_args()

    counts = {}
    days = 0
    for date, text in ftc_files(a.days, a.csv_dir):
        if count_csv(text, counts):
            days += 1
    listed = {n: c for n, c in counts.items() if c >= a.min_reports}
    for n, c in reported(a.reported).items():
        listed[n] = max(listed.get(n, 0), c)
    if not listed:
        print('::error::No numbers: the FTC files were not found and spam/reported.tsv is empty.')
        return 1
    if days == 0:
        print('::warning::No FTC files this week; the list has only spam/reported.tsv.')
    top = sorted(listed.items(), key=lambda kv: (-kv[1], kv[0]))[:MAX_ENTRIES]
    now = dt.datetime.now(dt.timezone.utc).strftime('%Y-%m-%dT%H:%M')
    with open(a.out, 'w', encoding='utf-8', newline='\n') as f:
        f.write(HEADER + '\n')
        f.write(f'# list-date: {now}\n')
        f.write(f'# sources: FTC Do Not Call complaints ({days} days, '
                f'{a.min_reports}+ reports), spam/reported.tsv\n')
        for n, c in sorted(top):
            f.write(f'{n}\t{c}\n')
    print(f'{len(top)} numbers from {days} FTC days')
    return 0


if __name__ == '__main__':
    sys.exit(main())
