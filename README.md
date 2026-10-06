# Beta Calendars Calendar Fixtures for Bazel

Generate calendar grids and temporal boundary datasets as deterministic Bazel outputs. The public rules are implemented in pure Starlark and write declared files with `ctx.actions.write`; they do not execute a runtime program.

## Why this exists

Snapshot tests, date-boundary regression tests, static documentation, generated website data, and application test assets often need known calendar input checked into the build graph. This module makes those fixtures explicit Bazel targets so their configuration participates in dependency analysis and cache keys.

## Design and installation

Add the module with Bzlmod:

```starlark
bazel_dep(name = "betacalendars_calendar_fixtures", version = "1.0.0")
```

Load supported APIs from `@betacalendars_calendar_fixtures//calendar:defs.bzl`. The module has no runtime dependencies. Development tools are declared as Bzlmod dev dependencies.

## `calendar_month`

```starlark
load("@betacalendars_calendar_fixtures//calendar:defs.bzl", "calendar_month")

calendar_month(
    name = "january_2027",
    year = 2027,
    month = 1,
    week_start = "monday",
    layout = "fixed",
    overflow = "adjacent",
    format = "json",
)
```

The generated target is `:january_2027.json`. Fixed grids have exactly 42 cells. Compact grids contain the minimum 4, 5, or 6 rows required by the selected first weekday. The seven accepted week starts are Monday through Sunday. `overflow = "adjacent"` includes real neighboring dates; `overflow = "blank"` encodes outside cells with null date fields.

## `calendar_year`

`calendar_year` takes `year`, `week_start`, `layout`, `overflow`, and `format` and emits January through December in order. Its month grids use the same calculation as `calendar_month`.

## `calendar_range`

`calendar_range` takes zero-padded `start_date` and `end_date` attributes in `YYYY-MM-DD` format. Both endpoints are included. The end must not precede the start. Dates crossing month and year boundaries remain consecutive.

## Boundary matrices and fixture suite

`calendar_boundary_matrix` accepts any list of years in 1..9999. For each year it emits February 28, February 29 when valid, March 1, December 31, and January 1 of the next year when representable. Its default year list covers leap-century and year-turn cases, but does not limit supported years.

`calendar_fixture_suite` creates a `calendar_year` target and a boundary target for each requested year and output format, using stable target names derived from its `name` prefix.

## Output formats and schema

All formats use LF line endings and deterministic field/column order.

* JSON uses schema version `1`. Month objects include schema, year, month, week start, layout, and ordered cells. Each cell includes its ISO date, calendar and ISO-week metadata, coordinates, and boundary flags. Empty overflow cells use `null` for date-derived fields.
* CSV uses a fixed header and one record per cell. Blank overflow cells have empty date and date-derived fields.
* Markdown renders weekday headings in the requested order. Adjacent-month days are parenthesized; blank overflow cells are empty.

Generated fixtures contain only application data and no promotional text. `CalendarGridInfo` provides the computed year/month, week start, layout, cell structs, and output `File` to downstream Starlark rules, without parsing JSON again.

## Examples and tests

`examples/year_turn` covers November 2026 through February 2027 and the 2027–2028 leap-year transition. `examples/bcr` is a separate Bzlmod consumer used by registry presubmit.

The Starlark unit tests cover Gregorian leap years, weekday arithmetic, date addition, month lengths, fixed-grid cardinality, blank overflow, compact rows, and inclusive cross-year ranges. CI runs these tests and the standalone consumer.

## Hermeticity and caching

Every year, month, date range, week start, layout, overflow policy, and format is an explicit target attribute. Generation does not consult a system clock, locale, timezone, environment variable, network, shell, or language runtime. Identical attributes and module source produce identical output bytes, making outputs suitable for local and remote action caches.

## Supported Bazel versions

The declared minimum is Bazel 7.2.1. CI and the BCR presubmit matrix exercise Bazel 7.x, 8.x, and 9.x on Linux, macOS, macOS ARM, and Windows.

## Documentation and security

Public rule and provider docstrings are extracted by Bazel's built-in `starlark_doc_extract` targets. The resulting `.binaryproto` files can be bundled into the release docs archive consumed by the BCR frontend. No extensions, repository rules, telemetry, credentials, or network operations are included.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Report vulnerabilities using [SECURITY.md](SECURITY.md).

## License

Apache-2.0. See [LICENSE](LICENSE).

## Project

This module is maintained as part of the [Beta Calendars](https://www.betacalendars.com/) developer tooling project.
