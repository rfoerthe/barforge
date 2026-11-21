#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Roland Foerther
#
# Ported from Tagwerk's testdata/generate_testdata.py (MIT, same author): same
# algorithm, same seed handling, same data. Only the docstring, the comments
# and the report on stderr are English; the Markdown stays Tagwerk's German
# export format byte for byte (it is a data format that Barforge's import reads).
"""Generates test data for Barforge's Time Tracking as Markdown (the format of
"Tagwerk --export", which Barforge imports) and, with --db, as a ready database.

The period depends on today: it ends yesterday and starts on the first of the month
18 months before the current one - 18 full calendar months plus the days of the
current month up to yesterday. Today itself stays empty.

- Absences (table absences), planned per calendar year and entered within the period:
    Feiertag       the nationwide German public holidays on workdays
    Urlaub         30 days: Mon-Thu before Good Friday, the Friday after Ascension Day,
                   two or three weeks in summer (from a Monday in July or early
                   August), one week in autumn, the workdays from 27 to 30 December, and
                   Christmas Eve and New Year's Eve as half days (with about 4 h of work);
                   the rest single days, mostly Monday or Friday
    Zeitausgleich  6 days (time off in lieu), bridge days first (Friday after a holiday
                   on Thursday, Monday before one on Tuesday), otherwise Fridays
    Sonderurlaub   special leave, a whole day every 6 months: in the month 3, 9, 15 ...
                   months before the current one, on a workday without another absence
  So no workday stays without an entry - otherwise its target would count as minus.
- Saturday work: on the Saturday before the week with special leave 4 to 6 h in one go
  (at most with short locks under 15 min), as a free day with "record today"
  (correction "Erfassung": free day, counted). Time Tracking reports it as "work on the
  weekend"; it only enters the balance when the working-time rules say so (default: no).
- On the other workdays people work between 5 and 10 hours; the week total is
  39 h +/- 8 % (pro rata with absences and in the first and the current week). On top
  comes as much overtime as the time off in lieu uses up within the period (about
  15 min a day): the time account stays close to zero.
- Lunch breaks and other breaks of 15 min and more are locks; on top come short locks
  under 15 min, which count as working time.
- Work away from the Mac (database schema 3, table work_blocks) on about 25 % of the
  workdays, one kind per day:
    Meeting        Mac locked 45-90 min, entered afterwards as a meeting
    Telefonat      a break (20-35 min) counted as a call
    Sonstiges      Mac locked 30-75 min, without a note ("other")
    Networking     Mac locked 30-60 min, entered afterwards as networking
    back to back   a meeting and right after it a call in one lock: two adjoining
                   blocks (they are not merged)
    before start   a call before the first unlock
    after end      a call or meeting after the last lock
  Blocks entered afterwards (dialog or inspector) start and end on full minutes; only
  the break counted as a call keeps the seconds of the recorded lock.
- Built-in rule violations, repeated every six weeks. The six-week cycles count backwards
  from the current week: it is week 1 of a new cycle, before it lie weeks 6, 5, ... 1 of
  the previous one and so on back to the start of the period. If the wanted day is a
  holiday or within an absence, the violation moves to another day of the same week (in
  a vacation week it is dropped); the partial first week of the period has no built-in
  violation:
    Week 2  Tue until 21:2x, Wed from 07:0x     -> rest period under 11 h
    Week 3  Thu until 22:5x                     -> worked after 22:00
    Week 4  Mon from 06:1x                      -> worked before 07:00
    Week 5  Wed 7 h with a 20 min break         -> break too short (30 min needed)
            Fri 9:20 h with a 30 min break      -> break too short (45 min needed)
- More than 6 h without a break on about 10 % of the workdays, spread over the period:
  between 6:10 and 8:45 h of work in one go, interrupted at most by short locks under
  15 min (they count as working time) -> break too short (30 min needed). These days
  have no work away from the Mac and no other rule violation.
  All other days keep the Working Hours Act and the working-time frame; the script
  checks that itself (as Time Tracking does) and prints an overview on stderr.

Usage (from the project folder; Tools/time-tracking-testdb.sh does this):
    python3 Tools/time-tracking-testdata.py > build/testdata/testdata.md
    python3 Tools/time-tracking-testdata.py --today 2026-11-18   # another reference day
    python3 Tools/time-tracking-testdata.py --db build/testdata/timetracking.db > testdata.md

With --db PATH the script also writes a fresh database in Barforge's schema (Tagwerk's
schema 3, user_version 3, application_id "BFTT") with exactly the rows Barforge stores
after importing the same Markdown, plus the marker row settings('barforge_testdata', 1).
"""

import argparse
import datetime as dt
import os
import random
import sqlite3
import sys

SEED = 20261117
MONTHS = 18  # full calendar months before the current month
CYCLE = 6  # weeks after which the rule violations repeat
FRAME = (7 * 3600, 22 * 3600)
MIN_PAUSE = 15 * 60
MIN_REST = 11 * 3600
MAX_WORK = 10 * 3600
WEEK_TARGET = 39 * 3600
VACATION_DAYS = 30  # vacation days per year (half days count half)
TIME_OFF_DAYS = 6  # days of time off in lieu per year
SPECIAL_LEAVE_EVERY = 6  # months between two days of special leave
SPECIAL_LEAVE_OFFSET = 3  # months before the current one: the most recent special leave
SATURDAY_WORK = (4 * 3600, 6 * 3600 - 60)  # work on the Saturday before the special leave
DAY_TARGET = WEEK_TARGET // 5
HALF_DAY_WORK = (3 * 3600 + 35 * 60, 4 * 3600 + 15 * 60)  # work on a half vacation day
WORK_SHARE = 0.25  # share of workdays with work away from the Mac
NO_BREAK_SHARE = 0.10  # share of workdays with more than 6 h of work without a break
H = 3600
M = 60
DAY = 24 * H
EARLIEST = 7 * H + 5 * M  # earliest start of normal days
LATEST_END = 20 * H  # latest end of normal days (rest period until 07:00)
WORK_RANGE = (5 * H + 15 * M, 9 * H + 45 * M)  # working time of normal days
# Working time of the days without a break: over 6 h, but under 9 h (else 45 min were needed)
NO_BREAK_RANGE = (6 * H + 10 * M, 8 * H + 45 * M)
NO_BREAK = "no_break"
# Markdown values (Tagwerk's German export format, read by Barforge's import)
WEEKDAYS = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
KIND_WORK = "Arbeit ohne Mac"
KIND_ABSENCE = "Abwesenheit"
KIND_COUNTING = "Erfassung"
COUNTED_FREE_DAY = "freier Tag, gezählt"
HOLIDAY, VACATION, TIME_OFF, SPECIAL_LEAVE = "Feiertag", "Urlaub", "Zeitausgleich", "Sonderurlaub"
SATURDAY = "saturday"

# Rule violations: (week in the six-week cycle from 0, kinds on consecutive days,
# wanted weekdays 0=Mon)
SPECIALS = [
    (1, ("late_end", "early_start"), [1, 0, 2, 3]),
    (2, ("after_22",), [3, 2, 1, 0, 4]),
    (3, ("before_7",), [0, 1, 2, 3, 4]),
    (4, ("pause_20",), [2, 1, 3, 0, 4]),
    (4, ("pause_30_long",), [4, 3, 2, 1, 0]),
]
# Warnings (as Time Tracking reports them) the script checks for
REST = "rest period under 11 h"
OUTSIDE = "outside the working-time frame"
BREAK_30 = "break under 30 min"
BREAK_45 = "break under 45 min"
OVER_10 = "over 10 h"
WEEKEND = "work on the weekend"
# Expected warnings per kind
EXPECTED = {
    "early_start": {REST},
    "after_22": {OUTSIDE},
    "before_7": {OUTSIDE},
    "pause_20": {BREAK_30},
    "pause_30_long": {BREAK_45},
    NO_BREAK: {BREAK_30},
    SATURDAY: {WEEKEND},
}
VARIANTS = ["meeting", "call_pause", "other", "networking", "back_to_back", "call_morning", "call_evening"]
# Kinds entered afterwards in a lock: (duration in min from-to, note)
LOCKED = {
    "meeting": ((45, 90), "Meeting"),
    "other": ((30, 75), ""),
    "networking": ((30, 60), "Networking"),
    "back_to_back": ((50, 90), "Meeting"),  # split into meeting + call
}
VARIANT_NAMES = {
    "meeting": "meeting (locked)",
    "call_pause": "break as a call",
    "other": "other (locked)",
    "networking": "networking (locked)",
    "back_to_back": "back to back",
    "call_morning": "before the start",
    "call_evening": "after the end",
}


# ---------- Calendar ------------------------------------------------------------


def easter(year):
    """Easter Sunday (Gregorian, anonymous algorithm)."""
    a, b, c = year % 19, year // 100, year % 100
    d, e = b // 4, b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = c // 4, c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    month = (h + l - 7 * m + 114) // 31
    day = (h + l - 7 * m + 114) % 31 + 1
    return dt.date(year, month, day)


def holidays(year):
    """Nationwide German public holidays."""
    e = easter(year)
    return {
        dt.date(year, 1, 1),
        e - dt.timedelta(days=2),
        e + dt.timedelta(days=1),
        dt.date(year, 5, 1),
        e + dt.timedelta(days=39),
        e + dt.timedelta(days=50),
        dt.date(year, 10, 3),
        dt.date(year, 12, 25),
        dt.date(year, 12, 26),
    }


def workday_of(hol):
    return lambda d: d.weekday() < 5 and d not in hol


def monday_on_or_after(d):
    return d + dt.timedelta(days=-d.weekday() % 7)


def vacation_plan(year, hol, rng):
    """Vacation of a year: date -> half day? (VACATION_DAYS days in all)."""
    workday, plan = workday_of(hol), {}

    def take(days, half=False):
        for d in days:
            if workday(d) and d not in plan and used() + (0.5 if half else 1) <= VACATION_DAYS:
                plan[d] = half

    def used():
        return sum(0.5 if h else 1 for h in plan.values())

    def week(monday, days):
        return [monday + dt.timedelta(days=i) for i in range(days)]

    e = easter(year)
    take([dt.date(year, 12, 24), dt.date(year, 12, 31)], half=True)  # Christmas Eve, New Year's Eve
    take(dt.date(year, 12, d) for d in range(27, 31))
    take(e - dt.timedelta(days=k) for k in range(6, 2, -1))  # Holy Week up to Maundy Thursday
    take([e + dt.timedelta(days=40)])  # bridge day after Ascension Day
    summer = monday_on_or_after(dt.date(year, 7, 1)) + dt.timedelta(weeks=rng.randint(0, 5))
    take(week(summer, 7 * rng.choice([2, 3])))
    autumn = monday_on_or_after(dt.date(year, 10, 5)) + dt.timedelta(weeks=rng.randint(0, 3))
    take(week(autumn, 5))
    # The rest as single days, mostly on a Monday or Friday (long weekend).
    days = [dt.date(year, 1, 1) + dt.timedelta(days=i) for i in range(365 + (year % 4 == 0))]
    singles = [d for d in days if workday(d) and d not in plan]
    while used() < VACATION_DAYS and singles:
        d = rng.choice(singles)
        if d.weekday() in (0, 4) or rng.random() < 0.3:
            take([d])
        singles.remove(d)
    return plan


def time_off_plan(year, hol, taken, rng):
    """Time off in lieu of a year: bridge days first, then Fridays (without vacation `taken`)."""
    workday = workday_of(hol)
    days = [dt.date(year, 1, 1) + dt.timedelta(days=i) for i in range(365 + (year % 4 == 0))]
    free = [d for d in days if workday(d) and d not in taken]
    bridges = [
        d for d in free
        if (d.weekday() == 4 and d - dt.timedelta(days=1) in hol)
        or (d.weekday() == 0 and d + dt.timedelta(days=1) in hol)
    ]
    fridays = [d for d in free if d.weekday() == 4 and d not in bridges]
    rng.shuffle(bridges)
    rng.shuffle(fridays)
    return set((bridges + fridays)[:TIME_OFF_DAYS])


def plan_absences(first, last, hol, rng):
    """Absences within the period: date -> (kind, half day?). Only workdays (Mon-Fri)."""
    out = {}
    for year in range(first.year, last.year + 1):
        vacation = vacation_plan(year, hol, rng)
        time_off = time_off_plan(year, hol, vacation, rng)
        for d, half in vacation.items():
            out[d] = (VACATION, half)
        for d in time_off:
            out[d] = (TIME_OFF, False)
        for d in holidays(year):
            if d.weekday() < 5:
                out[d] = (HOLIDAY, False)
    return {d: a for d, a in out.items() if first <= d <= last}


def special_leave_plan(first, last, hol, absences, rng):
    """Special leave every SPECIAL_LEAVE_EVERY months: date of the special leave -> the
    Saturday before it (in the week before), on which 4 to 6 h are worked.

    The months count backwards from the current month (that of `last + 1`): 3, 9, 15 ...
    months before it. Picked is a workday without a holiday and without another absence
    whose Saturday of the week before lies within the period and is no holiday."""
    today = last + dt.timedelta(days=1)
    current = today.year * 12 + today.month - 1
    out = {}
    back = SPECIAL_LEAVE_OFFSET
    while True:
        year, month0 = divmod(current - back, 12)
        start = dt.date(year, month0 + 1, 1)
        if start < first.replace(day=1):
            break
        end = dt.date(year + (month0 == 11), (month0 + 1) % 12 + 1, 1) - dt.timedelta(days=1)
        days = [start + dt.timedelta(days=i) for i in range((end - start).days + 1)]
        saturday = lambda d: d - dt.timedelta(days=d.weekday() + 2)
        candidates = [
            d for d in days
            if first <= saturday(d) and d <= last and d.weekday() < 5
            and d not in hol and d not in absences and saturday(d) not in hol
        ]
        if candidates:
            d = rng.choice(candidates)
            out[d] = saturday(d)
        back += SPECIAL_LEAVE_EVERY
    return out


def absence_label(kind, half):
    return f"{kind} (halber Tag)" if half else kind


def period_for(today):
    """(first day, last day): the first of the month 18 months before the current one up to yesterday."""
    months = today.year * 12 + today.month - 1 - MONTHS
    return dt.date(months // 12, months % 12 + 1, 1), today - dt.timedelta(days=1)


# ---------- Time Tracking's rules rebuilt (Tagwerk src/day.rs, src/rules.rs) ---------


def union(spans):
    out = []
    for f, t in sorted(spans):
        if out and f <= out[-1][1]:
            out[-1] = (out[-1][0], max(out[-1][1], t))
        else:
            out.append((f, t))
    return out


def fill_gaps(spans):
    out = []
    for f, t in union(spans):
        if out and f - out[-1][1] < MIN_PAUSE:
            out[-1] = (out[-1][0], max(out[-1][1], t))
        else:
            out.append((f, t))
    return out


def clip(spans, lo, hi):
    return [(max(f, lo), min(t, hi)) for f, t in spans if min(t, hi) > max(f, lo)]


class Day:
    def __init__(self, periods, blocks=(), kind=None):
        self.periods = list(periods)
        self.blocks = list(blocks)  # (from, to, note) - work away from the Mac
        self.kind = kind  # rule violation or kind of work away from the Mac

    def shift(self, by):
        self.periods = [(f + by, t + by) for f, t in self.periods]
        self.blocks = [(f + by, t + by, n) for f, t, n in self.blocks]

    def first(self):
        return min([f for f, _ in self.periods] + [f for f, _, _ in self.blocks])

    def last(self):
        return max([t for _, t in self.periods] + [t for _, t, _ in self.blocks])

    def unframed(self):
        """Blocks of work without the frame: short gaps filled, work away from the Mac added."""
        return fill_gaps(self.periods + [(f, t) for f, t, _ in self.blocks])

    def spans(self):
        return clip(self.unframed(), *FRAME)

    def work(self):
        return sum(t - f for f, t in self.spans())

    def outside(self):
        all_ = self.unframed()
        out = clip(all_, 0, FRAME[0]) + clip(all_, FRAME[1], DAY)
        return [s for s in out if s[1] - s[0] >= 60]


def warnings(days):
    """Warnings per day like rules::day_warnings."""
    out, prev = {}, None
    for d in sorted(days):
        day, found = days[d], set()
        spans, work = day.spans(), day.work()
        pause = sum(b[0] - a[1] for a, b in zip(spans, spans[1:]) if b[0] - a[1] >= 15 * M)
        if work > 9 * H and pause < 45 * M:
            found.add(BREAK_45)
        elif work > 6 * H and pause < 30 * M:
            found.add(BREAK_30)
        if work > MAX_WORK:
            found.add(OVER_10)
        if spans and prev is not None:
            rest = (d - prev[0]).days * DAY + spans[0][0] - prev[1]
            if rest < MIN_REST:
                found.add(REST)
        if day.outside():
            found.add(OUTSIDE)
        if work > 0 and d.weekday() >= 5:
            found.add(WEEKEND)
        if found:
            out[d] = found
        if work > 0:
            prev = (d, spans[-1][1])
    return out


# ---------- Building days -------------------------------------------------------


def counts(lock):
    """Does a lock count as working time? (short, or entered as work away from the Mac)"""
    _, dur, note = lock
    return note is not None or dur < MIN_PAUSE


def build_day(start, work, locks):
    """Periods (unlocked) and work away from the Mac for one day.

    `work` is the counted working time of the periods including the locks that count.
    `locks` are (position in counted working time, duration, note): note None = a normal
    lock (from 15 min a break), otherwise entered afterwards as work away from the Mac."""
    periods, blocks, t, elapsed = [], [], start, 0
    for lock in sorted(locks, key=lambda l: l[0]):
        pos, dur, note = lock
        run = pos - elapsed
        assert run > 0, (start, work, locks)
        periods.append((t, t + run))
        if note is not None:
            blocks.append((t + run, t + run + dur, note))
        t += run + dur
        elapsed = pos + (dur if counts(lock) else 0)
    assert work > elapsed, (start, work, locks)
    periods.append((t, t + (work - elapsed)))
    return periods, blocks


def free_pos(rng, lo, hi, dur, note, taken, gap=30 * M):
    """Position for a lock at a distance from the others (or None)."""
    if hi < lo:
        return None
    own = dur if counts((0, dur, note)) else 0
    for _ in range(50):
        pos = rng.randint(lo, hi)
        if all(
            pos > p + (d if counts((p, d, n)) else 0) + gap or pos + own + gap < p
            for p, d, n in taken
        ):
            return pos
    return None


def short_locks(rng, work, taken):
    """0-3 short locks (3-12 min) spread over the day, not close to other locks."""
    out = []
    for _ in range(rng.randint(0, 3)):
        dur = rng.randint(3 * M, 12 * M) + rng.randint(0, 59)
        pos = free_pos(rng, 45 * M, work - 45 * M, dur, None, taken + out)
        if pos is not None:
            out.append((pos, dur, None))
    return out


def normal_day(rng, work, variant, min_start):
    """A day with `work` counted working time; `variant` is the kind of work away from the
    Mac, NO_BREAK (worked through: no lock of 15 min or more - the day's only rule
    violation) or None. Returns None when the kind does not fit into the day."""
    call = rng.randint(15, 40) * M + rng.randint(0, 59) if variant in ("call_morning", "call_evening") else 0
    pwork = work - call  # working time of the periods
    start = int(min(max(rng.gauss(8 * H, 35 * M), EARLIEST), 9 * H + 30 * M)) + rng.randint(0, 59)
    locks = []
    if variant == NO_BREAK:
        pass  # no lunch break and no coffee break, only short locks
    elif work > 6 * H or rng.random() < 0.5:
        # Lunch break around 12-13 h; from 9 h of work at least 45 min
        lunch = rng.randint(45, 60) if work > 9 * H else rng.randint(30, 55)
        pos = min(max(12 * H + rng.randint(0, 50) * M - start, 3 * H), pwork - 2 * H)
        locks.append((pos, lunch * M + rng.randint(0, 59), None))
    if variant != NO_BREAK and work > 6 * H and rng.random() < 0.3:
        # Coffee break in the afternoon (counts as a break)
        locks.append((int(pwork * 0.8), rng.randint(15, 22) * M + rng.randint(0, 59), None))
    if variant == "call_pause" or variant in LOCKED:
        if variant == "call_pause":
            dur, note = rng.randint(20, 35) * M + rng.randint(0, 59), "Telefonat"
        else:
            (lo, hi), note = LOCKED[variant]
            dur = rng.randint(lo, hi) * M
        pos = free_pos(rng, 75 * M, pwork - dur - 60 * M, dur, note, locks)
        if pos is None:
            return None
        locks.append((pos, dur, note))
    locks += short_locks(rng, pwork, locks)
    day = Day(*build_day(start, pwork, locks), kind=variant)
    if variant == "back_to_back":
        # A meeting and right after it a call (at least 15 and 20 min)
        (f, t, _), = day.blocks
        cut = f + rng.randint(30 * M, t - f - 20 * M)
        day.blocks = [(f, cut, "Meeting"), (cut, t, "Telefonat")]
    if variant == "call_morning":
        gap = rng.randint(20, 45) * M + rng.randint(0, 59)
        first = day.first()
        day.blocks.insert(0, (first - gap - call, first - gap, "Telefonat"))
    elif variant == "call_evening":
        gap = rng.randint(30, 75) * M + rng.randint(0, 59)
        last = day.last()
        day.blocks.append((last + gap, last + gap + call, rng.choice(["Telefonat", "Telefonat", "Meeting"])))
    # move into the allowed time: not before 07:00 or before the end of the rest period,
    # done by 20:00 at the latest
    lower = max(EARLIEST, min_start)
    if day.first() < lower:
        day.shift(lower - day.first() + rng.randint(0, 15 * M))
    if day.last() > LATEST_END:
        day.shift(-min(day.last() - LATEST_END, day.first() - lower))
    if day.last() > LATEST_END:
        return None
    if variant != "call_pause":
        # Entered afterwards: the time fields take only full minutes. The gap under a
        # minute to the recorded period counts as working time, like a short lock.
        day.blocks = [(f // M * M, t // M * M, n) for f, t, n in day.blocks]
    return day


def saturday_day(rng, min_start):
    """Work on the Saturday before the special leave: 4 to 6 h in one go from 9-10:30 h
    (after the rest period), interrupted at most by short locks under 15 min."""
    work = rng.randint(*SATURDAY_WORK) // M * M + rng.randint(0, 59)
    start = max(rng.randint(9 * H, 10 * H + 30 * M), min_start) + rng.randint(0, 59)
    locks = short_locks(rng, work, [])
    return Day(*build_day(start, work, locks), kind=SATURDAY)


def special_day(rng, kind):
    """Days with a rule violation."""
    s = rng.randint(0, 59)
    if kind == "late_end":  # ends 21:2x - with "early_start" on the next day < 11 h of rest
        p = build_day(11 * H + 40 * M + s, 9 * H, [(4 * H, 45 * M + 13, None), (7 * H, 6 * M + 40, None)])
    elif kind == "early_start":
        p = build_day(7 * H + 4 * M + s, 8 * H, [(5 * H, 40 * M + 7, None)])
    elif kind == "after_22":
        p = build_day(13 * H + 40 * M + s, 8 * H + 30 * M, [(4 * H + 30 * M, 45 * M + 21, None)])
    elif kind == "before_7":
        p = build_day(6 * H + 12 * M + s, 8 * H + 40 * M, [(6 * H, 40 * M + 30, None)])
    elif kind == "pause_20":
        p = build_day(8 * H + 2 * M + s, 7 * H, [(4 * H, 20 * M + 15, None)])
    elif kind == "pause_30_long":
        p = build_day(7 * H + 30 * M + s, 9 * H + 20 * M, [(4 * H + 30 * M, 30 * M + 40, None), (2 * H, 8 * M, None)])
    else:
        raise ValueError(kind)
    return Day(*p, kind=kind)


# ---------- Planning the period -------------------------------------------------


class NoFit(Exception):
    """A day cannot be built within the rules with this seed."""


def place_specials(mondays, workdays, current):
    """Date -> kind of rule violation (the wanted day, otherwise another day of the week).

    `current` is the Monday of the current week; from it the six-week cycles in which
    the violations repeat count backwards."""
    out = {}
    for monday in mondays:
        position = (monday - current).days // 7 % CYCLE
        for week, kinds, candidates in SPECIALS:
            if week != position:
                continue
            for wd in candidates:
                dates = [monday + dt.timedelta(days=wd + i) for i in range(len(kinds))]
                if all(d in workdays and d not in out and d.weekday() < 5 for d in dates):
                    out.update(zip(dates, kinds))
                    break
    return out


def generate(first, last, seed):
    rng = random.Random(seed)
    hol = set().union(*(holidays(y) for y in range(first.year, last.year + 1)))
    absences = plan_absences(first, last, hol, rng)
    special_leave = special_leave_plan(first, last, hol, absences, rng)
    for d in special_leave:
        absences[d] = (SPECIAL_LEAVE, False)
    saturdays = set(special_leave.values())
    half_days = {d for d, (_, half) in absences.items() if half}
    all_days = [first + dt.timedelta(days=i) for i in range((last - first).days + 1)]
    # Workdays with full work (without holidays and absences)
    workdays = [d for d in all_days if d.weekday() < 5 and d not in absences]
    mondays = sorted({d - dt.timedelta(days=d.weekday()) for d in all_days})
    # Overtime for the time off in lieu: its target, spread over the full workdays
    time_off = sum(1 for kind, _ in absences.values() if kind == TIME_OFF)
    extra = time_off * DAY_TARGET / max(len(workdays), 1)
    today = last + dt.timedelta(days=1)
    # without the partial first week: a single day with a fixed working time could
    # push the week total out of range there
    specials = place_specials(
        [m for m in mondays if m >= first], set(workdays), today - dt.timedelta(days=today.weekday())
    )

    # Work away from the Mac: about 25 % of the workdays, each kind about equally often
    free = [d for d in workdays if d not in specials]
    count = min(len(free), round(len(workdays) * WORK_SHARE))
    variants = VARIANTS[:]
    rng.shuffle(variants)
    # spread evenly over the period: one day from each section
    picks = [rng.choice(free[i * len(free) // count:(i + 1) * len(free) // count]) for i in range(count)]
    away = dict(zip(picks, (variants * count)[:count]))

    # More than 6 h without a break: about 10 % of the workdays, also spread evenly
    free = [d for d in free if d not in away]
    count = min(len(free), round(len(workdays) * NO_BREAK_SHARE))
    no_break = {rng.choice(free[i * len(free) // count:(i + 1) * len(free) // count]) for i in range(count)}

    # Working time per day: the week target pro rata (less with absences) plus overtime
    # for the time off in lieu, +/- 8 % at random; about 4 h on half vacation days
    plan, fixed = {}, {}
    for d, kind in specials.items():
        fixed[d] = special_day(rng, kind)
    for d in sorted(half_days):  # fixed order: the same data on every run
        plan[d] = rng.randint(*HALF_DAY_WORK)
    # State of the time account while planning: whoever is in the minus works a little
    # more in the next weeks (and the other way round) - so it swings around zero
    # instead of running away.
    account = 0
    for monday in mondays:
        in_week = lambda d: 0 <= (d - monday).days < 7
        account -= DAY_TARGET * sum(1 for d, (k, _) in absences.items() if k == TIME_OFF and in_week(d))
        account += sum(plan[d] - DAY_TARGET // 2 for d in half_days if in_week(d))
        week = [d for d in workdays if in_week(d)]
        open_days = [d for d in week if d not in fixed]
        if not open_days:
            account += sum(fixed[d].work() - DAY_TARGET for d in week)
            continue
        target = (DAY_TARGET + extra) * len(week) * rng.uniform(0.92, 1.08) - 0.3 * account
        rest = target - sum(fixed[d].work() for d in week if d in fixed)
        bounds = [NO_BREAK_RANGE if d in no_break else WORK_RANGE for d in open_days]
        work = [min(max(rest / len(open_days) + rng.uniform(-1.9, 1.9) * H, lo), hi) for lo, hi in bounds]
        # match the sum without leaving the bounds
        for _ in range(50):
            diff = rest - sum(work)
            if abs(diff) < M:
                break
            work = [min(max(w + diff / len(work), lo), hi) for w, (lo, hi) in zip(work, bounds)]
        for d, w in zip(open_days, work):
            plan[d] = int(w) // 60 * 60 + rng.randint(0, 59)
        account += sum(plan[d] for d in open_days) + sum(fixed[d].work() for d in week if d in fixed)
        account -= DAY_TARGET * len(week)

    # Build the days in order - so each day knows the end of the day before (rest period)
    days, prev = {}, None
    for d in sorted(set(workdays) | half_days | saturdays):
        min_start = 0
        if prev is not None:
            min_start = prev[1] + MIN_REST - (d - prev[0]).days * DAY + rng.randint(5, 25) * M
        if d in fixed:
            day = fixed[d]
        elif d in saturdays:
            day = saturday_day(rng, min_start)
        else:
            variant = NO_BREAK if d in no_break else away.get(d)
            day = normal_day(rng, plan[d], variant, min_start)
            for fallback in () if variant == NO_BREAK else ("meeting", "call_pause", None):
                if day is not None:
                    break
                day = normal_day(rng, plan[d], fallback, min_start)
            if day is None:
                raise NoFit(f"{d}: no fitting course of the day")
        days[d] = day
        prev = (d, min(day.last(), FRAME[1]))
    # No workday without an entry: its target would count as minus otherwise.
    assert all(d.weekday() >= 5 or d in days or d in absences for d in all_days)
    return days, hol, absences, special_leave


def expected_warnings(days):
    out = {}
    for d, day in days.items():
        if day.kind in EXPECTED:
            out[d] = EXPECTED[day.kind]
    return out


def no_break_days(days):
    return [d for d in sorted(days) if days[d].kind == NO_BREAK]


def no_break_ok(days):
    """Days without a break: a single block of work of more than 6 h."""
    return all(len(days[d].spans()) == 1 and days[d].work() > 6 * H for d in no_break_days(days))


# ---------- Output --------------------------------------------------------------


def clock(s):
    return f"{s // 3600:02d}:{s % 3600 // 60:02d}:{s % 60:02d}"


def date_cell(d):
    return f"{WEEKDAYS[d.weekday()]}, {d:%d.%m.%Y}"


def write_markdown(out, days, absences, first, last, seed):
    # The header names Tagwerk's script: the fixtures in Tests/Fixtures/TimeTracking were
    # made with it, and the output stays byte-identical to Tagwerk's.
    out.write(f"# Tagwerk – Testdaten {first:%d.%m.%Y} bis {last:%d.%m.%Y}\n\n")
    out.write(f"Erzeugt mit testdata/generate_testdata.py (Startwert {seed}).\n\n")
    out.write("## Korrekturen\n\n")
    out.write(f"Art: {KIND_WORK} (z. B. Telefonat oder Meeting), {KIND_ABSENCE} bzw. {KIND_COUNTING}.\n\n")
    out.write("| Datum | Art | Von | Bis | Notiz |\n|:------|:----|:---:|:---:|:------|\n")
    for d in sorted(set(days) | set(absences)):
        if d in absences:
            out.write(f"| {date_cell(d)} | {KIND_ABSENCE} | – | – | {absence_label(*absences[d])} |\n")
        for f, t, note in days[d].blocks if d in days else ():
            out.write(f"| {date_cell(d)} | {KIND_WORK} | {clock(f)} | {clock(t)} | {note} |\n")
        if d in days and d.weekday() >= 5:
            # Free day: "record today" chosen, the recorded time counts.
            out.write(f"| {date_cell(d)} | {KIND_COUNTING} | – | – | {COUNTED_FREE_DAY} |\n")
    out.write("\n## Erfasste Perioden\n\n| Datum | Von | Bis |\n|:------|:---:|:---:|\n")
    for d in sorted(days):
        for f, t in days[d].periods:
            out.write(f"| {date_cell(d)} | {clock(f)} | {clock(t)} |\n")


# ---------- Database (Barforge's TimeTrackingDatabase) ----------------------------

SCHEMA_VERSION = 3
APPLICATION_ID = 0x42465454  # "BFTT", TimeTrackingDatabase.applicationID
TESTDATA_KEY = "barforge_testdata"  # marker row in `settings`: the database holds test data
DAY_END = 86_400  # TTLimits.dayEnd
# TTAbsenceKind.id and TTFreeDay.id
ABSENCE_IDS = {VACATION: 1, HOLIDAY: 3, TIME_OFF: 4, SPECIAL_LEAVE: 5}
FREE_DAY_COUNTED = 1

# The statements of TimeTrackingDatabase.initSchema, in its order for a new file.
SCHEMA_ABSENCES = """CREATE TABLE IF NOT EXISTS absences (
    date TEXT PRIMARY KEY,
    kind INTEGER NOT NULL,
    half INTEGER NOT NULL DEFAULT 0
) WITHOUT ROWID;"""
SCHEMA_FREE_DAYS = """CREATE TABLE IF NOT EXISTS auto_counting (
    date TEXT PRIMARY KEY,
    counts INTEGER NOT NULL
) WITHOUT ROWID;"""
SCHEMA_WORK_RULES = """CREATE TABLE IF NOT EXISTS work_rules (
    valid_from TEXT PRIMARY KEY,
    min_pause_s INTEGER NOT NULL,
    weekly_target_s INTEGER NOT NULL,
    frame_from_s INTEGER NOT NULL,
    frame_to_s INTEGER NOT NULL,
    workdays INTEGER NOT NULL,
    free_days_count INTEGER NOT NULL DEFAULT 0
) WITHOUT ROWID;"""
SCHEMA_SETTINGS = """CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value INTEGER NOT NULL
) WITHOUT ROWID;"""
SCHEMA_WORK = """CREATE TABLE IF NOT EXISTS work_blocks (
    date TEXT NOT NULL,
    idx INTEGER NOT NULL,
    from_s INTEGER NOT NULL,
    to_s INTEGER NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (date, idx)
) WITHOUT ROWID;"""
SCHEMA_BASE = ("""CREATE TABLE periods (
    date TEXT NOT NULL,
    idx INTEGER NOT NULL,
    from_s INTEGER NOT NULL,
    to_s INTEGER NOT NULL,
    PRIMARY KEY (date, idx)
) WITHOUT ROWID;""", """CREATE TABLE breaks (
    date TEXT NOT NULL,
    idx INTEGER NOT NULL,
    from_s INTEGER NOT NULL,
    to_s INTEGER,
    PRIMARY KEY (date, idx)
) WITHOUT ROWID;""", """CREATE TABLE day_marks (
    date TEXT PRIMARY KEY,
    start_s INTEGER,
    end_s INTEGER
) WITHOUT ROWID;""")


def add_period(periods, f, t):
    """TTDay.addPeriod: clamped to the day, overlapping and touching periods merge."""
    if t < f:
        return periods
    return union(periods + [(min(max(f, 0), DAY_END), min(max(t, 0), DAY_END))])


def add_work(work, f, t, note):
    """TTDay.addWork: older work in that time is cut away, adjoining blocks stay apart,
    sorted by (from, to) and stable."""
    f, t = min(max(f, 0), DAY_END), min(max(t, 0), DAY_END)
    if t <= f:
        return work
    out = []
    for a, b, n in work:  # TTSpan.subtract of (f, t)
        if a < f:
            out.append((a, min(b, f), n))
        if b > t:
            out.append((max(a, t), b, n))
    out = [(a, b, n) for a, b, n in out if b > a]
    out.append((f, t, note.strip()))
    return sorted(out, key=lambda w: (w[0], w[1]))


def day_rows(days, absences):
    """The rows per date as Barforge stores them after importing the Markdown of
    write_markdown (TTImport.parseFile, then TimeTrackingDatabase.writeDay)."""
    out = {}
    for d in sorted(set(days) | set(absences)):
        periods, work = [], []
        if d in days:
            for f, t, note in days[d].blocks:
                work = add_work(work, f, t, note)
            for f, t in days[d].periods:
                periods = add_period(periods, f, t)
        absence = None
        if d in absences:
            kind, half = absences[d]
            absence = (ABSENCE_IDS[kind], 1 if half else 0)
        free_day = FREE_DAY_COUNTED if d in days and d.weekday() >= 5 else None
        out[d] = (periods, work, absence, free_day)
    return out


def write_database(path, days, absences):
    """Writes a fresh database in Barforge's schema to `path` (replacing a file there):
    the schema as TimeTrackingDatabase.initSchema creates it, the days as writeDay stores
    them, and the marker row. Journal mode DELETE (Barforge switches to WAL itself),
    owner-only."""
    path = os.path.abspath(path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = f"{path}.tmp-{os.getpid()}"
    for p in (tmp, tmp + "-journal"):
        if os.path.exists(p):
            os.remove(p)
    os.close(os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600))
    try:
        db = sqlite3.connect(tmp, isolation_level=None)
        try:
            db.execute("PRAGMA journal_mode = DELETE")
            db.execute("BEGIN")
            for statement in (SCHEMA_ABSENCES, SCHEMA_FREE_DAYS, SCHEMA_WORK_RULES, SCHEMA_SETTINGS, SCHEMA_WORK):
                db.execute(statement)
            db.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
            for statement in SCHEMA_BASE:
                db.execute(statement)
            db.execute(f"PRAGMA application_id = {APPLICATION_ID}")
            for d, (periods, work, absence, free_day) in day_rows(days, absences).items():
                key = d.isoformat()
                for i, (f, t) in enumerate(periods):
                    db.execute("INSERT INTO periods (date, idx, from_s, to_s) VALUES (?, ?, ?, ?)", (key, i, f, t))
                for i, (f, t, note) in enumerate(work):
                    db.execute("INSERT INTO work_blocks (date, idx, from_s, to_s, note) VALUES (?, ?, ?, ?, ?)",
                               (key, i, f, t, note))
                if absence is not None:
                    db.execute("INSERT INTO absences (date, kind, half) VALUES (?, ?, ?)", (key, *absence))
                if free_day is not None:
                    db.execute("INSERT INTO auto_counting (date, counts) VALUES (?, ?)", (key, free_day))
            db.execute("INSERT INTO settings (key, value) VALUES (?, 1)", (TESTDATA_KEY,))
            db.execute("COMMIT")
            check = db.execute("PRAGMA integrity_check").fetchone()[0]
            if check != "ok":
                raise RuntimeError(f"integrity check of {tmp} failed: {check}")
        finally:
            db.close()
    except BaseException:
        os.remove(tmp)
        raise
    # A stale -wal next to the new file would be replayed into it on the next open.
    for suffix in ("-wal", "-shm", "-journal"):
        if os.path.exists(path + suffix):
            os.remove(path + suffix)
    os.replace(tmp, path)


# ---------- Report --------------------------------------------------------------

REPORT_WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
REPORT_KINDS = {
    HOLIDAY: "holiday", VACATION: "vacation", TIME_OFF: "time off in lieu", SPECIAL_LEAVE: "special leave",
}


def report_date(d):
    return f"{REPORT_WEEKDAYS[d.weekday()]} {d:%d.%m.%Y}"


def report_absence(kind, half):
    return f"{REPORT_KINDS[kind]} (half day)" if half else REPORT_KINDS[kind]


def report(days, hol, absences, special_leave, first, last, seed, found):
    """Check on stderr: week totals, absences, special leave with Saturday work, work
    away from the Mac, rule violations."""
    err = sys.stderr
    print(f"Period {first:%d.%m.%Y} to {last:%d.%m.%Y}, seed {seed}", file=err)
    weeks = {}
    for d, day in days.items():
        if d.weekday() >= 5:
            continue  # Saturday work is listed below with the special leave
        # Target of the day: half of it on a half vacation day
        target = DAY_TARGET / 2 if absences.get(d, (None, False))[1] else DAY_TARGET
        weeks.setdefault(d.isocalendar()[:2], []).append((day.work(), target))
    for (year, kw), ws in sorted(weeks.items()):
        total, target = sum(w for w, _ in ws), sum(t for _, t in ws)
        print(
            f"  W{kw:02d}/{year}: {len(ws)} days, {total / H:5.2f} h "
            f"({(total / target - 1) * 100:+.1f} %), "
            f"days {min(w for w, _ in ws) / H:.2f}-{max(w for w, _ in ws) / H:.2f} h",
            file=err,
        )
    print("Absences:", file=err)
    for year in range(first.year, last.year + 1):
        of_year = [(d, a) for d, a in absences.items() if d.year == year]
        vacation = sum(0.5 if half else 1 for _, (kind, half) in of_year if kind == VACATION)
        print(
            f"  {year}: vacation {vacation:g} days, time off in lieu "
            f"{sum(1 for _, (k, _) in of_year if k == TIME_OFF)} days, special leave "
            f"{sum(1 for _, (k, _) in of_year if k == SPECIAL_LEAVE)} days, holidays "
            f"{sum(1 for _, (k, _) in of_year if k == HOLIDAY)} (workdays within the period)",
            file=err,
        )
    for d in sorted(absences):
        print(f"  {report_date(d)}  {report_absence(*absences[d])}", file=err)
    print("Special leave with Saturday work in the week before:", file=err)
    for d, sat in sorted(special_leave.items()):
        (f, _), (_, t) = days[sat].spans()[0], days[sat].spans()[-1]
        print(
            f"  {report_date(d)}  special leave; {report_date(sat)} {clock(f)[:5]}-{clock(t)[:5]}, "
            f"{days[sat].work() / H:.2f} h",
            file=err,
        )
    # Balance as Time Tracking computes it with the default rules: the target of all
    # workdays up to yesterday minus the absences; work on the weekend does not count.
    work = sum(day.work() for d, day in days.items() if d.weekday() < 5)
    target = sum(
        0 if absences.get(d, (None, False))[0] in (VACATION, HOLIDAY, SPECIAL_LEAVE) and not absences[d][1]
        else DAY_TARGET / 2 if absences.get(d, (None, False))[1]
        else DAY_TARGET
        for d in (first + dt.timedelta(days=i) for i in range((last - first).days + 1))
        if d.weekday() < 5
    )
    print(f"Time account at the end (without rounding to minutes): {(work - target) / H:+.2f} h", file=err)
    weekdays = [d for d in days if d.weekday() < 5]
    away = [d for d in sorted(days) if days[d].blocks]
    print(f"Work away from the Mac on {len(away)} of {len(weekdays)} workdays:", file=err)
    for d in away:
        blocks = ", ".join(f"{clock(f)[:5]}-{clock(t)[:5]} {n or 'other'}" for f, t, n in days[d].blocks)
        print(f"  {report_date(d)}  {VARIANT_NAMES[days[d].kind]:22s} {blocks}", file=err)
    through = no_break_days(days)
    print(
        f"More than 6 h without a break on {len(through)} of {len(weekdays)} workdays "
        f"({len(through) / len(weekdays) * 100:.0f} %):",
        file=err,
    )
    for d in through:
        (f, t), = days[d].spans()
        print(f"  {report_date(d)}  {clock(f)[:5]}-{clock(t)[:5]}  {(t - f) / H:.2f} h", file=err)
    print("Rule violations:", file=err)
    for d in sorted(found):
        print(f"  {report_date(d)}  {', '.join(sorted(found[d]))}", file=err)
    in_range = sorted(h for h in hol if first <= h <= last)
    print(f"Holidays within the period (nationwide): {', '.join(f'{h:%d.%m.%Y}' for h in in_range) or 'none'}",
          file=err)


def main():
    ap = argparse.ArgumentParser(
        description="Generate test data for Barforge's Time Tracking (Markdown on stdout, report on stderr).")
    ap.add_argument("--today", type=dt.date.fromisoformat, default=dt.date.today(),
                    help="reference day YYYY-MM-DD (default: today); the data ends the day before")
    ap.add_argument("--seed", type=int, default=SEED, help=f"seed of the random generator (default: {SEED})")
    ap.add_argument("--db", metavar="PATH",
                    help="also write a fresh database in Barforge's schema to PATH (replaces a file there)")
    ap.add_argument("--no-markdown", action="store_true", help="do not write the Markdown to stdout")
    args = ap.parse_args()
    first, last = period_for(args.today)

    # Should a day break a rule unintentionally or not be buildable (say a long day
    # after a late end the day before), roll again with the next seed.
    for seed in range(args.seed, args.seed + 100):
        try:
            days, hol, absences, special_leave = generate(first, last, seed)
        except NoFit:
            continue
        found = warnings(days)
        if found == expected_warnings(days) and no_break_ok(days):
            break
    else:
        sys.exit("No test data without unintended rule violations found.")
    if not args.no_markdown:
        write_markdown(sys.stdout, days, absences, first, last, seed)
    if args.db:
        write_database(args.db, days, absences)
    report(days, hol, absences, special_leave, first, last, seed, found)


if __name__ == "__main__":
    main()
