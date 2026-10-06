"""Public providers returned by Beta Calendars calendar fixture rules."""

CalendarGridInfo = provider(
    doc = "Analysis-time calendar structure for downstream Starlark rules.",
    fields = {
        "year": "Calendar year represented by this target.",
        "month": "Month number (1–12), or None for multi-month targets.",
        "week_start": "Weekday at the first grid column.",
        "layout": "Grid layout; fixed grids contain 42 cells.",
        "cells": "Immutable sequence of cell structs; blank overflow cells have day=None.",
        "output": "Generated fixture File available to downstream rules.",
    },
)
