"""Calendar model construction."""

load(":date_math.bzl", "date_math")

def _validate_week_start(week_start):
    if week_start not in date_math.weekdays:
        fail("week_start must be one of %s; got %r" % (", ".join(date_math.weekdays), week_start))
    return date_math.weekdays.index(week_start)

def _cell(year, month, day, row, column, in_month):
    blank = day == None
    if blank:
        return struct(
            year = None,
            month = None,
            day = None,
            iso_date = None,
            weekday = None,
            iso_week = None,
            iso_week_year = None,
            row = row,
            column = column,
            in_month = False,
            is_weekend = False,
            is_month_start = False,
            is_month_end = False,
            is_year_start = False,
            is_year_end = False,
        )
    return struct(
        year = year,
        month = month,
        day = day,
        iso_date = date_math.iso_date(year, month, day),
        weekday = date_math.weekdays[date_math.weekday(year, month, day)],
        iso_week = date_math.iso_week(year, month, day),
        iso_week_year = date_math.iso_week_year(year, month, day),
        row = row,
        column = column,
        in_month = in_month,
        is_weekend = date_math.weekday(year, month, day) >= 5,
        is_month_start = in_month and day == 1,
        is_month_end = in_month and day == date_math.days_in_month(year, month),
        is_year_start = month == 1 and day == 1,
        is_year_end = month == 12 and day == 31,
    )

def month_cells(year, month, week_start, layout, overflow):
    """Constructs a month grid from validated Gregorian attributes.

    Args:
      year: Gregorian year in 1..9999.
      month: Gregorian month number in 1..12.
      week_start: First weekday name.
      layout: fixed or compact row layout.
      overflow: adjacent or blank outside-month policy.

    Returns:
      Ordered calendar cell structs, row-major.
    """
    if year < 1 or year > 9999:
        fail("year must be in 1..9999; got %s" % year)
    if month < 1 or month > 12:
        fail("month must be in 1..12; got %s" % month)
    if layout not in ["fixed", "compact"]:
        fail("layout must be 'fixed' or 'compact'; got %r" % layout)
    if overflow not in ["adjacent", "blank"]:
        fail("overflow must be 'adjacent' or 'blank'; got %r" % overflow)
    start = _validate_week_start(week_start)
    leading = (date_math.weekday(year, month, 1) - start) % 7
    count = date_math.days_in_month(year, month)
    rows = 6 if layout == "fixed" else (leading + count + 6) // 7
    cells = []
    for index in range(rows * 7):
        offset = index - leading + 1
        in_month = offset >= 1 and offset <= count
        if not in_month and overflow == "blank":
            cells.append(_cell(None, None, None, index // 7 + 1, index % 7 + 1, False))
        else:
            date = date_math.add_days(year, month, 1, offset - 1)
            cells.append(_cell(date[0], date[1], date[2], index // 7 + 1, index % 7 + 1, in_month))
    return cells

def range_cells(start_date, end_date):
    """Constructs consecutive cells for an inclusive ISO date range.

    Args:
      start_date: Inclusive YYYY-MM-DD start.
      end_date: Inclusive YYYY-MM-DD end.

    Returns:
      One cell per consecutive date, including both endpoints.
    """
    start = _parse_date(start_date, "start_date")
    end = _parse_date(end_date, "end_date")
    first = date_math.ordinal(start[0], start[1], start[2])
    last = date_math.ordinal(end[0], end[1], end[2])
    if last < first:
        fail("end_date must be on or after start_date (both endpoints are inclusive)")
    cells = []
    for ordinal in range(first, last + 1):
        date = date_math.add_days(start[0], start[1], start[2], ordinal - first)
        cells.append(_cell(date[0], date[1], date[2], len(cells) + 1, 1, True))
    return cells

def _parse_date(value, attribute):
    if len(value) != 10 or value[4] != "-" or value[7] != "-":
        fail("%s must use YYYY-MM-DD; got %r" % (attribute, value))
    year = int(value[0:4])
    month = int(value[5:7])
    day = int(value[8:10])
    date_math.day_of_year(year, month, day)
    if date_math.iso_date(year, month, day) != value:
        fail("%s must use zero-padded YYYY-MM-DD; got %r" % (attribute, value))
    return (year, month, day)

def year_cells(year, week_start, layout, overflow):
    """Constructs twelve month grids in January through December order.

    Args:
      year: Gregorian year in 1..9999.
      week_start: First weekday name.
      layout: fixed or compact row layout.
      overflow: adjacent or blank outside-month policy.

    Returns:
      A list containing twelve row-major cell lists.
    """
    months = []
    for month in range(1, 13):
        months.append(month_cells(year, month, week_start, layout, overflow))
    return months

def boundary_cells(years):
    """Constructs leap-day and year-turn regression dates.

    Args:
      years: Gregorian years in 1..9999.

    Returns:
      Ordered cells for February, March, and year boundary cases.
    """
    cells = []
    for year in years:
        if year < 1 or year > 9999:
            fail("years must be in 1..9999; got %s" % year)
        dates = [(year, 2, 28), (year, 3, 1), (year, 12, 31)]
        if date_math.days_in_month(year, 2) == 29:
            dates.insert(1, (year, 2, 29))
        if year < 9999:
            dates.append((year + 1, 1, 1))
        for date in dates:
            cells.append(_cell(date[0], date[1], date[2], len(cells) + 1, 1, True))
    return cells
