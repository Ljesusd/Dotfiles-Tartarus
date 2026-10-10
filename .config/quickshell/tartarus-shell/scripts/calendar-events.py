#!/usr/bin/env python3
"""Fetch private iCalendar feeds and expose a small shell-friendly JSON model."""

from __future__ import annotations

import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo


def unfold(text: str) -> list[str]:
    lines: list[str] = []
    for line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if line.startswith((" ", "\t")) and lines:
            lines[-1] += line[1:]
        else:
            lines.append(line)
    return lines


def unescape(value: str) -> str:
    return (value.replace("\\n", "\n").replace("\\N", "\n")
            .replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\"))


def property_value(line: str) -> tuple[str, dict[str, str], str]:
    name, _, value = line.partition(":")
    chunks = name.split(";")
    key = chunks[0].upper()
    params: dict[str, str] = {}
    for chunk in chunks[1:]:
        param, _, param_value = chunk.partition("=")
        params[param.upper()] = param_value.strip('"')
    return key, params, value


def parse_datetime(value: str, params: dict[str, str], zone: ZoneInfo) -> tuple[datetime, bool]:
    value = value.strip()
    if len(value) == 8:
        return datetime.strptime(value, "%Y%m%d").replace(tzinfo=zone), True
    if value.endswith("Z"):
        return datetime.strptime(value[:-1], "%Y%m%dT%H%M%S").replace(tzinfo=timezone.utc).astimezone(zone), False
    parsed = datetime.strptime(value, "%Y%m%dT%H%M%S")
    if params.get("TZID"):
        try:
            parsed = parsed.replace(tzinfo=ZoneInfo(params["TZID"]))
        except Exception:
            parsed = parsed.replace(tzinfo=zone)
    else:
        parsed = parsed.replace(tzinfo=zone)
    return parsed, False


def event_from_lines(lines: list[str], zone: ZoneInfo, calendar_name: str) -> dict | None:
    values: dict[str, tuple[dict[str, str], str]] = {}
    for line in lines:
        key, params, value = property_value(line)
        values[key] = (params, unescape(value))
    if "DTSTART" not in values:
        return None
    try:
        start_params, start_value = values["DTSTART"]
        start, all_day = parse_datetime(start_value, start_params, zone)
        if "DTEND" in values:
            end_params, end_value = values["DTEND"]
            end = parse_datetime(end_value, end_params, zone)[0]
        else:
            end = start + (timedelta(days=1) if all_day else timedelta(hours=1))
    except (TypeError, ValueError):
        return None
    return {
        "id": values.get("UID", ({}, ""))[1] or f"{start.isoformat()}:{values.get('SUMMARY', ({}, ''))[1]}",
        "title": values.get("SUMMARY", ({}, "Sin título"))[1] or "Sin título",
        "start": start.isoformat(),
        "end": end.isoformat(),
        "dateKey": start.date().isoformat(),
        "allDay": all_day,
        "location": values.get("LOCATION", ({}, ""))[1],
        "description": values.get("DESCRIPTION", ({}, ""))[1],
        "url": values.get("URL", ({}, ""))[1],
        "calendar": calendar_name,
    }


def fetch(feed: dict, zone: ZoneInfo) -> list[dict]:
    url = str(feed.get("url", feed.get("icalUrl", ""))).strip()
    if not url.startswith("https://"):
        return []
    request = Request(url, headers={"User-Agent": "Tartarus Calendar/1.0"})
    with urlopen(request, timeout=15) as response:
        text = response.read().decode("utf-8", errors="replace")
    events: list[dict] = []
    block: list[str] = []
    inside = False
    for line in unfold(text):
        if line == "BEGIN:VEVENT":
            inside, block = True, []
        elif line == "END:VEVENT":
            if inside:
                event = event_from_lines(block, zone, str(feed.get("name", "Calendario")))
                if event:
                    events.append(event)
            inside = False
        elif inside:
            block.append(line)
    return events


def main() -> int:
    config_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / ".local/state/tartarus-shell/calendar.json"
    try:
        config = json.loads(config_path.read_text(encoding="utf-8")) if config_path.exists() else {}
        zone = ZoneInfo(str(config.get("timezone", "Europe/Madrid")))
        now = datetime.now(zone)
        lower = now - timedelta(days=1)
        upper = now + timedelta(days=60)
        events: list[dict] = []
        errors: list[str] = []
        feeds = config.get("feeds", [])
        if isinstance(config.get("icalUrl"), str) and config["icalUrl"].strip():
            feeds = [{"url": config["icalUrl"], "name": "Calendario"}]
        for feed in feeds if isinstance(feeds, list) else []:
            try:
                events.extend(fetch(feed, zone))
            except Exception as error:
                errors.append(str(feed.get("name", "Calendario")) + ": " + str(error))
        unique: dict[tuple[str, str], dict] = {}
        for event in events:
            start = datetime.fromisoformat(event["start"])
            if start < lower or start > upper:
                continue
            unique[(event["id"], event["dateKey"])] = event
        events = sorted(unique.values(), key=lambda event: event["start"])
        print(json.dumps({"ok": True, "events": events, "errors": errors, "syncedAt": now.isoformat()}, ensure_ascii=False))
    except Exception as error:
        print(json.dumps({"ok": False, "events": [], "error": str(error)}))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
