#!/usr/bin/env python3
"""Builds assets/ktmb_schedule.json from the official KTMB GTFS static feed.

The feed is published for free (no API key) by data.gov.my:
    https://api.data.gov.my/gtfs-static/ktmb/

Usage:
    python tool/build_ktmb_schedule.py                 # downloads the feed
    python tool/build_ktmb_schedule.py path/to/ktmb.zip  # or use a local zip

Re-run it whenever KTMB publishes a new timetable (see "validTo" in the
generated file) and commit the regenerated asset.

Output format (times are minutes since the start of the service day, so a
value >= 1440 means "after midnight"):
{
  "source": "...", "validFrom": "YYYY-MM-DD", "validTo": "YYYY-MM-DD",
  "stops":    ["KL SENTRAL", "IPOH", ...],
  "services": {"ets": [mon, tue, wed, thu, fri, sat, sun], ...},
  "exceptions": [["komuter_weekday", "2026-08-25", 2], ...],
  "trips": [ {"r": "ETS", "s": "ets", "t": [[stopIdx, arrMin, depMin], ...]} ]
}
"""
import csv
import io
import json
import sys
import urllib.request
import zipfile
from pathlib import Path

FEED_URL = "https://api.data.gov.my/gtfs-static/ktmb/"
OUT = Path(__file__).resolve().parent.parent / "assets" / "ktmb_schedule.json"


def load_zip(arg):
    if arg:
        return zipfile.ZipFile(arg)
    req = urllib.request.Request(FEED_URL, headers={"User-Agent": "TrekApp/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return zipfile.ZipFile(io.BytesIO(resp.read()))


def rows(z, name):
    with z.open(name) as f:
        return list(csv.DictReader(io.TextIOWrapper(f, encoding="utf-8-sig")))


def to_minutes(hhmmss):
    h, m, _ = hhmmss.split(":")
    return int(h) * 60 + int(m)


def iso(d):  # 20260818 -> 2026-08-18
    return f"{d[:4]}-{d[4:6]}-{d[6:]}"


def main():
    z = load_zip(sys.argv[1] if len(sys.argv) > 1 else None)

    stop_name = {r["stop_id"]: r["stop_name"].strip() for r in rows(z, "stops.txt")}
    names = sorted(set(stop_name.values()))
    name_idx = {n: i for i, n in enumerate(names)}

    calendar = rows(z, "calendar.txt")
    services = {
        r["service_id"]: [
            int(r[d])
            for d in ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")
        ]
        for r in calendar
    }
    exceptions = [
        [r["service_id"], iso(r["date"]), int(r["exception_type"])]
        for r in rows(z, "calendar_dates.txt")
    ]

    trips = {r["trip_id"]: r for r in rows(z, "trips.txt")}
    stop_times = {}
    for r in rows(z, "stop_times.txt"):
        stop_times.setdefault(r["trip_id"], []).append(r)

    out_trips = []
    for trip_id, trip in trips.items():
        seq = sorted(stop_times.get(trip_id, []), key=lambda r: int(r["stop_sequence"]))
        if len(seq) < 2:
            continue
        out_trips.append(
            {
                "r": trip["route_id"],
                "s": trip["service_id"],
                "t": [
                    [
                        name_idx[stop_name[r["stop_id"]]],
                        to_minutes(r["arrival_time"]),
                        to_minutes(r["departure_time"]),
                    ]
                    for r in seq
                ],
            }
        )

    # Only keep stop names that some trip actually uses.
    used = sorted({s[0] for t in out_trips for s in t["t"]})
    remap = {old: new for new, old in enumerate(used)}
    for t in out_trips:
        for s in t["t"]:
            s[0] = remap[s[0]]

    data = {
        "source": "KTMB GTFS static via data.gov.my (Government of Malaysia)",
        "validFrom": iso(min(r["start_date"] for r in calendar)),
        "validTo": iso(max(r["end_date"] for r in calendar)),
        "stops": [names[i] for i in used],
        "services": services,
        "exceptions": exceptions,
        "trips": out_trips,
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    print(f"Wrote {OUT} ({OUT.stat().st_size / 1024:.0f} KB): "
          f"{len(out_trips)} trips, {len(used)} stops, valid {data['validFrom']}..{data['validTo']}")


if __name__ == "__main__":
    main()
