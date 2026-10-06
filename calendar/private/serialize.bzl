"""Stable serializers with explicit field and row order."""

def _json_string(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'

def _cell_json(cell):
    fields = [
        '"date":' + ("null" if cell.iso_date == None else _json_string(cell.iso_date)),
        '"year":' + ("null" if cell.year == None else str(cell.year)),
        '"month":' + ("null" if cell.month == None else str(cell.month)),
        '"day":' + ("null" if cell.day == None else str(cell.day)),
        '"weekday":' + ("null" if cell.weekday == None else _json_string(cell.weekday)),
        '"iso_week":' + ("null" if cell.iso_week == None else str(cell.iso_week)),
        '"iso_week_year":' + ("null" if cell.iso_week_year == None else str(cell.iso_week_year)),
        '"row":%d' % cell.row,
        '"column":%d' % cell.column,
        '"in_month":%s' % ("true" if cell.in_month else "false"),
        '"is_weekend":%s' % ("true" if cell.is_weekend else "false"),
        '"is_month_start":%s' % ("true" if cell.is_month_start else "false"),
        '"is_month_end":%s' % ("true" if cell.is_month_end else "false"),
        '"is_year_start":%s' % ("true" if cell.is_year_start else "false"),
        '"is_year_end":%s' % ("true" if cell.is_year_end else "false"),
    ]
    return "{" + ",".join(fields) + "}"

def _json(cells, year, month, week_start, layout, schema_kind = "month"):
    if schema_kind == "month":
        head = '{"schema":1,"year":%d,"month":%d,"week_start":%s,"layout":%s,"cells":[' % (year, month, _json_string(week_start), _json_string(layout))
        return head + ",".join([_cell_json(cell) for cell in cells]) + "]}\n"
    if schema_kind == "year":
        months = []
        offset = 0
        for month in range(1, 13):
            count = 0
            for cell in cells[offset:]:
                if count > 0 and cell.row == 1 and cell.column == 1:
                    break
                count += 1
            month_cells = cells[offset:offset + count]
            months.append('{"month":%d,"cells":[%s]}' % (month, ",".join([_cell_json(cell) for cell in month_cells])))
            offset += count
        head = '{"schema":1,"year":%d,"week_start":%s,"layout":%s,"months":[' % (year, _json_string(week_start), _json_string(layout))
        return head + ",".join(months) + "]}\n"
    if schema_kind == "range":
        head = '{"schema":1,"start_date":%s,"end_date":%s,"inclusive":true,"cells":[' % (_json_string(cells[0].iso_date), _json_string(cells[-1].iso_date))
        return head + ",".join([_cell_json(cell) for cell in cells]) + "]}\n"
    years = []
    for cell in cells:
        if cell.year not in years:
            years.append(cell.year)
    head = '{"schema":1,"years":[%s],"cases":[' % ",".join([str(value) for value in years])
    return head + ",".join([_cell_json(cell) for cell in cells]) + "]}\n"

def _csv_field(value):
    if value.find(",") != -1 or value.find('"') != -1 or value.find("\n") != -1 or value.find("\r") != -1:
        return '"' + value.replace('"', '""') + '"'
    return value

def _csv(cells):
    rows = ["date,year,month,day,weekday,iso_week,iso_week_year,row,column,in_month,is_weekend,is_month_start,is_month_end,is_year_start,is_year_end"]
    for cell in cells:
        rows.append(",".join([_csv_field(value) for value in [
            cell.iso_date or "",
            str(cell.year) if cell.year != None else "",
            str(cell.month) if cell.month != None else "",
            str(cell.day) if cell.day != None else "",
            cell.weekday or "",
            str(cell.iso_week) if cell.iso_week != None else "",
            str(cell.iso_week_year) if cell.iso_week_year != None else "",
            str(cell.row),
            str(cell.column),
            "true" if cell.in_month else "false",
            "true" if cell.is_weekend else "false",
            "true" if cell.is_month_start else "false",
            "true" if cell.is_month_end else "false",
            "true" if cell.is_year_start else "false",
            "true" if cell.is_year_end else "false",
        ]]))
    return "\n".join(rows) + "\n"

def _markdown(cells, week_start):
    headings = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    offset = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"].index(week_start)
    headings = headings[offset:] + headings[:offset]
    rows = ["| " + " | ".join(headings) + " |", "| " + " | ".join(["---"] * 7) + " |"]
    for row in range(len(cells) // 7):
        values = []
        for cell in cells[row * 7:(row + 1) * 7]:
            if cell.day == None:
                values.append("")
            elif cell.in_month:
                values.append(str(cell.day))
            else:
                values.append("(%d)" % cell.day)
        rows.append("| " + " | ".join(values) + " |")
    return "\n".join(rows) + "\n"

def _markdown_records(cells):
    rows = ["| Date | Weekday | ISO week | ISO week-year |", "| --- | --- | ---: | ---: |"]
    for cell in cells:
        rows.append("| %s | %s | %s | %s |" % (cell.iso_date, cell.weekday, cell.iso_week, cell.iso_week_year))
    return "\n".join(rows) + "\n"

def _markdown_year(cells, week_start, year):
    sections = []
    offset = 0
    for month in range(1, 13):
        count = 0
        for cell in cells[offset:]:
            if count > 0 and cell.row == 1 and cell.column == 1:
                break
            count += 1
        month_text = str(month)
        if month < 10:
            month_text = "0" + month_text
        year_text = str(year)
        for _ in range(4 - len(year_text)):
            year_text = "0" + year_text
        sections.append("## %s-%s\n\n%s" % (year_text, month_text, _markdown(cells[offset:offset + count], week_start)))
        offset += count
    return "\n".join(sections)

def serialize(format, cells, year, month, week_start, layout, schema_kind = "month"):
    """Serializes a cell sequence with stable JSON, CSV, or Markdown ordering.

    Args:
      format: json, csv, or markdown.
      cells: Ordered cell structs.
      year: Calendar year for month/year outputs.
      month: Calendar month for month output, or None.
      week_start: First weekday for grid output.
      layout: Grid layout for month/year output.
      schema_kind: month, year, range, or boundary metadata shape.

    Returns:
      Deterministic UTF-8 content ending in LF.
    """
    if format == "json":
        return _json(cells, year, month, week_start, layout, schema_kind)
    if format == "csv":
        return _csv(cells)
    if format == "markdown":
        if schema_kind == "year":
            return _markdown_year(cells, week_start, year)
        if schema_kind in ["range", "boundary"]:
            return _markdown_records(cells)
        return _markdown(cells, week_start)
    fail("format must be 'json', 'csv', or 'markdown'; got %r" % format)
