"""Hermetic Bazel rules for deterministic calendar fixtures.

All fixture bytes are derived from explicit rule attributes. Generation uses
Starlark analysis and ctx.actions.write, with no runtime program or host data.
"""

load("//calendar:providers.bzl", "CalendarGridInfo")
load("//calendar/private:grid.bzl", "boundary_cells", "month_cells", "range_cells", "year_cells")
load("//calendar/private:serialize.bzl", "serialize")

_FORMATS = ["json", "csv", "markdown"]
_WEEK_STARTS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]

def _emit(ctx, cells, year, month, week_start, layout, schema_kind = "month"):
    if ctx.attr.format not in _FORMATS:
        fail("format must be one of %s; got %r" % (", ".join(_FORMATS), ctx.attr.format))
    output = ctx.actions.declare_file(ctx.label.name + "." + ctx.attr.format)
    ctx.actions.write(
        output = output,
        content = serialize(ctx.attr.format, cells, year, month, week_start, layout, schema_kind),
        is_executable = False,
    )
    return [
        DefaultInfo(files = depset([output])),
        CalendarGridInfo(
            year = year,
            month = month,
            week_start = week_start,
            layout = layout,
            cells = cells,
            output = output,
        ),
    ]

def _month_impl(ctx):
    cells = month_cells(ctx.attr.year, ctx.attr.month, ctx.attr.week_start, ctx.attr.layout, ctx.attr.overflow)
    return _emit(ctx, cells, ctx.attr.year, ctx.attr.month, ctx.attr.week_start, ctx.attr.layout)

_COMMON_GRID_ATTRS = {
    "year": attr.int(mandatory = True, doc = "Explicit Gregorian year in 1..9999."),
    "week_start": attr.string(default = "monday", values = _WEEK_STARTS, doc = "Weekday at the first column."),
    "layout": attr.string(default = "fixed", values = ["fixed", "compact"], doc = "fixed creates six rows; compact creates the minimum number."),
    "overflow": attr.string(default = "adjacent", values = ["adjacent", "blank"], doc = "Use neighboring dates or null-valued outside cells."),
    "format": attr.string(default = "json", values = _FORMATS, doc = "Output encoding: json, csv, or markdown."),
}

calendar_month = rule(
    implementation = _month_impl,
    doc = "Generates one deterministic Gregorian month fixture. Fixed layout has exactly 42 cells. Returns CalendarGridInfo for analysis-time consumers.",
    attrs = {
        "year": attr.int(mandatory = True, doc = "Explicit Gregorian year in 1..9999."),
        "week_start": attr.string(default = "monday", values = _WEEK_STARTS, doc = "Weekday at the first column."),
        "layout": attr.string(default = "fixed", values = ["fixed", "compact"], doc = "fixed creates six rows; compact creates the minimum number."),
        "overflow": attr.string(default = "adjacent", values = ["adjacent", "blank"], doc = "Use neighboring dates or null-valued outside cells."),
        "format": attr.string(default = "json", values = _FORMATS, doc = "Output encoding: json, csv, or markdown."),
        "month": attr.int(mandatory = True, doc = "Gregorian month number in 1..12."),
    },
)

def _year_impl(ctx):
    months = year_cells(ctx.attr.year, ctx.attr.week_start, ctx.attr.layout, ctx.attr.overflow)
    cells = []
    for month_cells in months:
        cells.extend(month_cells)
    return _emit(ctx, cells, ctx.attr.year, None, ctx.attr.week_start, ctx.attr.layout, "year")

calendar_year = rule(
    implementation = _year_impl,
    doc = "Generates January through December for an explicit year using the same grid calculation as calendar_month.",
    attrs = dict(_COMMON_GRID_ATTRS),
)

def _range_impl(ctx):
    cells = range_cells(ctx.attr.start_date, ctx.attr.end_date)
    return _emit(ctx, cells, cells[0].year, None, "monday", "range", "range")

calendar_range = rule(
    implementation = _range_impl,
    doc = "Generates consecutive Gregorian dates from start_date through end_date, inclusive, in YYYY-MM-DD form.",
    attrs = {
        "start_date": attr.string(mandatory = True, doc = "Inclusive first date in zero-padded YYYY-MM-DD form."),
        "end_date": attr.string(mandatory = True, doc = "Inclusive final date in zero-padded YYYY-MM-DD form."),
        "format": attr.string(default = "json", values = _FORMATS, doc = "Output encoding: json, csv, or markdown."),
    },
)

def _boundary_impl(ctx):
    cells = boundary_cells(ctx.attr.years)
    year = ctx.attr.years[0] if ctx.attr.years else 1
    return _emit(ctx, cells, year, None, "monday", "boundary", "boundary")

calendar_boundary_matrix = rule(
    implementation = _boundary_impl,
    doc = "Generates leap-day, March-start, year-end, and following-year-start regression dates for each requested year.",
    attrs = {
        "years": attr.int_list(default = [1900, 2000, 2024, 2027, 2028, 2100, 2400], doc = "Years to cover; any integer in 1..9999 is supported."),
        "format": attr.string(default = "json", values = _FORMATS, doc = "Output encoding: json, csv, or markdown."),
    },
)

def calendar_fixture_suite(name, years, formats = ["json"], week_start = "monday", layout = "fixed", overflow = "adjacent", **kwargs):
    """Creates predictable annual fixtures and boundary matrices.

    Args:
      name: Prefix for generated targets.
      years: Explicit Gregorian years to include.
      formats: Output formats for each target; values are json, csv, markdown.
      week_start: First weekday for calendar grids.
      layout: fixed or compact grid layout.
      overflow: adjacent or blank outside-month representation.
      **kwargs: Additional common rule attributes, such as tags or visibility.
    """
    for format in formats:
        if format not in _FORMATS:
            fail("formats must contain only %s; got %r" % (", ".join(_FORMATS), format))
        for year in years:
            calendar_year(
                name = "%s_%s_%s" % (name, year, format),
                year = year,
                week_start = week_start,
                layout = layout,
                overflow = overflow,
                format = format,
                **kwargs
            )
            calendar_boundary_matrix(
                name = "%s_%s_boundaries_%s" % (name, year, format),
                years = [year],
                format = format,
                **kwargs
            )
