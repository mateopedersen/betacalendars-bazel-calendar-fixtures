"""Analysis tests for calendar model invariants and public rule providers."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//calendar:defs.bzl", "calendar_month", "calendar_range")
load("//calendar:providers.bzl", "CalendarGridInfo")

def _month_test_impl(ctx):
    env = analysistest.begin(ctx)
    info = analysistest.target_under_test(env)[CalendarGridInfo]
    asserts.equals(env, 42, len(info.cells))
    month_days = [cell.day for cell in info.cells if cell.in_month]
    asserts.equals(env, 31, len(month_days))
    asserts.equals(env, list(range(1, 32)), month_days)
    dates = [cell.iso_date for cell in info.cells]
    asserts.equals(env, len(dates), len({date: True for date in dates}.keys()))
    return analysistest.end(env)

month_test = analysistest.make(_month_test_impl)

def _february_test_impl(ctx):
    env = analysistest.begin(ctx)
    info = analysistest.target_under_test(env)[CalendarGridInfo]
    days = [cell.day for cell in info.cells if cell.in_month]
    asserts.equals(env, ctx.attr.expected_days, len(days))
    asserts.equals(env, info.year, [cell.year for cell in info.cells if cell.in_month][0])
    return analysistest.end(env)

february_test = analysistest.make(
    _february_test_impl,
    attrs = {"expected_days": attr.int(mandatory = True)},
)

def _compact_test_impl(ctx):
    env = analysistest.begin(ctx)
    info = analysistest.target_under_test(env)[CalendarGridInfo]
    asserts.equals(env, 0, len(info.cells) % 7)
    asserts.equals(env, ctx.attr.expected_cells, len(info.cells))
    return analysistest.end(env)

compact_test = analysistest.make(
    _compact_test_impl,
    attrs = {"expected_cells": attr.int(mandatory = True)},
)

def _week_start_test_impl(ctx):
    env = analysistest.begin(ctx)
    info = analysistest.target_under_test(env)[CalendarGridInfo]
    asserts.equals(env, ctx.attr.expected_weekday, info.cells[0].weekday)
    return analysistest.end(env)

week_start_test = analysistest.make(
    _week_start_test_impl,
    attrs = {"expected_weekday": attr.string(mandatory = True)},
)

def _iso_week_test_impl(ctx):
    env = analysistest.begin(ctx)
    info = analysistest.target_under_test(env)[CalendarGridInfo]
    jan1 = [cell for cell in info.cells if cell.in_month and cell.day == 1][0]
    asserts.equals(env, 53, jan1.iso_week)
    asserts.equals(env, 2020, jan1.iso_week_year)
    return analysistest.end(env)

iso_week_test = analysistest.make(_iso_week_test_impl)

def _range_test_impl(ctx):
    env = analysistest.begin(ctx)
    info = analysistest.target_under_test(env)[CalendarGridInfo]
    dates = [cell.iso_date for cell in info.cells]
    asserts.equals(env, ["2026-12-29", "2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02", "2027-01-03", "2027-01-04"], dates)
    return analysistest.end(env)

range_test = analysistest.make(_range_test_impl)

def _blank_test_impl(ctx):
    env = analysistest.begin(ctx)
    info = analysistest.target_under_test(env)[CalendarGridInfo]
    blanks = [cell for cell in info.cells if not cell.in_month]
    asserts.true(env, len(blanks) > 0)
    asserts.equals(env, None, blanks[0].iso_date)
    asserts.equals(env, None, blanks[0].day)
    return analysistest.end(env)

blank_test = analysistest.make(_blank_test_impl)

def calendar_test_suite(name):
    """Defines fixture-producing targets and their analysis test suite.

    Args:
      name: Name of the resulting native test_suite target.
    """
    calendar_month(name = "test_january_2027", year = 2027, month = 1, layout = "fixed")
    calendar_month(name = "test_january_2021", year = 2021, month = 1)
    calendar_month(name = "test_february_1900", year = 1900, month = 2)
    calendar_month(name = "test_february_2000", year = 2000, month = 2)
    calendar_month(name = "test_february_2024", year = 2024, month = 2)
    calendar_month(name = "test_february_2027", year = 2027, month = 2)
    calendar_month(name = "test_february_2028", year = 2028, month = 2)
    calendar_month(name = "test_february_2100", year = 2100, month = 2)
    calendar_month(name = "test_february_2400", year = 2400, month = 2)
    calendar_month(name = "test_compact_4_rows", year = 2027, month = 2, layout = "compact")
    calendar_month(name = "test_compact_5_rows", year = 2027, month = 3, layout = "compact")
    calendar_month(name = "test_compact_6_rows", year = 2026, month = 8, layout = "compact")
    calendar_month(name = "test_blank", year = 2027, month = 2, overflow = "blank")
    calendar_range(name = "test_range", start_date = "2026-12-29", end_date = "2027-01-04")
    calendar_test_cases = [
        (month_test, ":test_january_2027", {}),
        (iso_week_test, ":test_january_2021", {}),
        (february_test, ":test_february_1900", {"expected_days": 28}),
        (february_test, ":test_february_2000", {"expected_days": 29}),
        (february_test, ":test_february_2024", {"expected_days": 29}),
        (february_test, ":test_february_2027", {"expected_days": 28}),
        (february_test, ":test_february_2028", {"expected_days": 29}),
        (february_test, ":test_february_2100", {"expected_days": 28}),
        (february_test, ":test_february_2400", {"expected_days": 29}),
        (compact_test, ":test_compact_4_rows", {"expected_cells": 28}),
        (compact_test, ":test_compact_5_rows", {"expected_cells": 35}),
        (compact_test, ":test_compact_6_rows", {"expected_cells": 42}),
        (blank_test, ":test_blank", {}),
        (range_test, ":test_range", {}),
    ]
    for week_start, expected_weekday in [
        ("monday", "monday"),
        ("tuesday", "tuesday"),
        ("wednesday", "wednesday"),
        ("thursday", "thursday"),
        ("friday", "friday"),
        ("saturday", "saturday"),
        ("sunday", "sunday"),
    ]:
        target = "week_start_%s" % week_start
        calendar_month(name = target, year = 2027, month = 1, week_start = week_start)
        calendar_test_cases.append((week_start_test, ":%s" % target, {"expected_weekday": expected_weekday}))
    for index, (test_rule, target, extra) in enumerate(calendar_test_cases):
        test_rule(name = "calendar_case_%d" % index, target_under_test = target, **extra)
    native.test_suite(name = name, tests = [":calendar_case_%d" % i for i in range(len(calendar_test_cases))])
