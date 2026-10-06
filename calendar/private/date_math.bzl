"""Pure proleptic Gregorian date arithmetic, independent of host settings."""

_MONTH_LENGTHS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
_WEEKDAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]

def _is_leap_year(year):
    """Returns whether year is a Gregorian leap year."""
    return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)

def _days_in_month(year, month):
    """Returns the number of days in month, validating its range."""
    if month < 1 or month > 12:
        fail("month must be in 1..12; got %s" % month)
    if month == 2 and _is_leap_year(year):
        return 29
    return _MONTH_LENGTHS[month - 1]

def _day_of_year(year, month, day):
    """Returns the one-based ordinal day after validating the date."""
    if year < 1 or year > 9999:
        fail("year must be in 1..9999; got %s" % year)
    if day < 1 or day > _days_in_month(year, month):
        fail("day %s is invalid for %04d-%02d" % (day, year, month))
    total = day
    for prior_month in range(1, month):
        total += _days_in_month(year, prior_month)
    return total

def _ordinal(year, month, day):
    prior_year = year - 1
    return 365 * prior_year + prior_year // 4 - prior_year // 100 + prior_year // 400 + _day_of_year(year, month, day)

def _weekday(year, month, day):
    """Returns Monday=0 through Sunday=6 for a Gregorian date."""
    return (_ordinal(year, month, day) - 1) % 7

def _date_from_ordinal(ordinal):
    """Converts a one-based Gregorian ordinal to (year, month, day)."""
    maximum = 365 * 9999 + 9999 // 4 - 9999 // 100 + 9999 // 400
    if ordinal < 1 or ordinal > maximum:
        fail("date arithmetic would leave supported years 1..9999")
    low = 1
    high = 10000
    for _ in range(14):
        middle = (low + high) // 2
        if middle <= 9999 and _ordinal(middle, 1, 1) <= ordinal:
            low = middle
        else:
            high = middle
    year = low
    remaining = ordinal - _ordinal(year, 1, 1) + 1
    month = 1
    for _ in range(12):
        length = _days_in_month(year, month)
        if remaining <= length:
            return (year, month, remaining)
        remaining -= length
        month += 1
    fail("internal date conversion error")

def _add_days(year, month, day, delta):
    """Returns (year, month, day) after adding signed delta days."""
    return _date_from_ordinal(_ordinal(year, month, day) + delta)

def _days_between(start_year, start_month, start_day, end_year, end_month, end_day):
    """Returns end minus start in days; negative values are allowed."""
    return _ordinal(end_year, end_month, end_day) - _ordinal(start_year, start_month, start_day)

def _iso_date(year, month, day):
    """Returns an ISO 8601 date string."""
    _day_of_year(year, month, day)
    year_text = str(year)
    month_text = str(month)
    day_text = str(day)
    for _ in range(4 - len(year_text)):
        year_text = "0" + year_text
    for _ in range(2 - len(month_text)):
        month_text = "0" + month_text
    for _ in range(2 - len(day_text)):
        day_text = "0" + day_text
    return "%s-%s-%s" % (year_text, month_text, day_text)

def _iso_week(year, month, day):
    """Returns the ISO week number for a date."""
    ordinal = _ordinal(year, month, day)
    thursday = ordinal + (3 - _weekday(year, month, day))
    thursday_year, _, _ = _date_from_ordinal(thursday)
    jan4 = _ordinal(thursday_year, 1, 4)
    week1_monday = jan4 - _weekday(thursday_year, 1, 4)
    return ((thursday - week1_monday) // 7) + 1

def _iso_week_year(year, month, day):
    """Returns the ISO week-year for a date."""
    ordinal = _ordinal(year, month, day)
    thursday = ordinal + (3 - _weekday(year, month, day))
    thursday_year, _, _ = _date_from_ordinal(thursday)
    return thursday_year

WEEKDAYS = _WEEKDAYS
date_math = struct(
    add_days = _add_days,
    days_in_month = _days_in_month,
    day_of_year = _day_of_year,
    days_between = _days_between,
    iso_date = _iso_date,
    iso_week = _iso_week,
    iso_week_year = _iso_week_year,
    is_leap_year = _is_leap_year,
    ordinal = _ordinal,
    weekday = _weekday,
    weekdays = _WEEKDAYS,
)
