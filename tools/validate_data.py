from __future__ import annotations

import csv
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"

KNOWN_EVENT_IDS = {"deposito", "pasillo", "enemigo"}
BUILTIN_LOOT_IDS = {"nothing", "gold_small", "gold_medium"}


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, message: str) -> None:
        self.errors.append(message)

    def warn(self, message: str) -> None:
        self.warnings.append(message)

    def print(self) -> None:
        if self.errors:
            print("ERRORS")
            for message in self.errors:
                print(f"- {message}")
        else:
            print("ERRORS: none")

        if self.warnings:
            print("\nWARNINGS")
            for message in self.warnings:
                print(f"- {message}")
        else:
            print("\nWARNINGS: none")


def read_csv(name: str, report: Report) -> list[dict[str, str]]:
    path = DATA_DIR / name
    if not path.exists():
        report.error(f"Missing data file: data/{name}")
        return []

    last_error: UnicodeDecodeError | None = None
    for encoding in ("utf-8-sig", "cp1252"):
        try:
            with path.open("r", encoding=encoding, newline="") as handle:
                reader = csv.DictReader(handle)
                rows: list[dict[str, str]] = []
                for row in reader:
                    clean_row = {
                        str(key).strip(): str(value or "").strip()
                        for key, value in row.items()
                        if key is not None
                    }
                    if any(clean_row.values()):
                        rows.append(clean_row)
                return rows
        except UnicodeDecodeError as exc:
            last_error = exc

    report.error(f"Could not decode data/{name}: {last_error}")
    return []


def require_columns(file_name: str, rows: list[dict[str, str]], columns: set[str], report: Report) -> None:
    if not rows:
        return
    found = set(rows[0].keys())
    missing = sorted(columns - found)
    if missing:
        report.error(f"data/{file_name} missing columns: {', '.join(missing)}")


def index_by_id(file_name: str, rows: list[dict[str, str]], report: Report) -> dict[str, dict[str, str]]:
    indexed: dict[str, dict[str, str]] = {}
    for line_number, row in enumerate(rows, start=2):
        item_id = row.get("id", "").strip()
        if not item_id:
            report.error(f"data/{file_name}:{line_number} has empty id")
            continue
        if item_id in indexed:
            report.error(f"data/{file_name}:{line_number} duplicates id '{item_id}'")
            continue
        if item_id != item_id.strip() or " " in item_id:
            report.warn(f"data/{file_name}:{line_number} id '{item_id}' contains whitespace")
        indexed[item_id] = row
    return indexed


def split_ids(value: str) -> list[str]:
    return [part.strip() for part in value.split(";") if part.strip()]


def validate() -> int:
    report = Report()

    enemies_rows = read_csv("enemies.csv", report)
    weapons_rows = read_csv("weapons.csv", report)
    armors_rows = read_csv("armors.csv", report)
    items_rows = read_csv("items.csv", report)
    locations_rows = read_csv("locations.csv", report)
    loot_rows = read_csv("loot_tables.csv", report)
    texts_rows = read_csv("texts.csv", report)

    require_columns("enemies.csv", enemies_rows, {"id", "name", "hp_min", "hp_max", "dmg_min", "dmg_max"}, report)
    require_columns("weapons.csv", weapons_rows, {"id", "name", "dmg_min", "dmg_max", "price", "kind"}, report)
    require_columns("armors.csv", armors_rows, {"id", "name", "armor", "price", "kind"}, report)
    require_columns("items.csv", items_rows, {"id", "name", "kind", "subkind", "stackable", "max_stack"}, report)
    require_columns("locations.csv", locations_rows, {"id", "name", "flavor_ids", "monster_ids", "loot_table_id", "event_ids"}, report)
    require_columns("loot_tables.csv", loot_rows, {"id", "item_id", "weight"}, report)
    require_columns("texts.csv", texts_rows, {"id", "text_es"}, report)

    enemies = index_by_id("enemies.csv", enemies_rows, report)
    weapons = index_by_id("weapons.csv", weapons_rows, report)
    armors = index_by_id("armors.csv", armors_rows, report)
    items = index_by_id("items.csv", items_rows, report)
    locations = index_by_id("locations.csv", locations_rows, report)
    texts = index_by_id("texts.csv", texts_rows, report)

    all_item_ids = set(items) | set(weapons) | set(armors) | BUILTIN_LOOT_IDS

    loot_table_ids: set[str] = set()
    for line_number, row in enumerate(loot_rows, start=2):
        table_id = row.get("id", "")
        item_id = row.get("item_id", "")
        weight_raw = row.get("weight", "")
        if not table_id:
            report.error(f"data/loot_tables.csv:{line_number} has empty table id")
        else:
            loot_table_ids.add(table_id)
        if item_id not in all_item_ids:
            report.error(f"data/loot_tables.csv:{line_number} references unknown item_id '{item_id}'")
        try:
            weight = int(weight_raw)
            if weight < 0:
                report.error(f"data/loot_tables.csv:{line_number} has negative weight")
        except ValueError:
            report.error(f"data/loot_tables.csv:{line_number} has non-integer weight '{weight_raw}'")

    for line_number, row in enumerate(locations_rows, start=2):
        location_id = row.get("id", f"line {line_number}")
        for text_id in split_ids(row.get("flavor_ids", "")):
            if text_id not in texts:
                report.error(f"location '{location_id}' references missing flavor text '{text_id}'")
        for enemy_id in split_ids(row.get("monster_ids", "")):
            if enemy_id not in enemies:
                report.error(f"location '{location_id}' references missing enemy '{enemy_id}'")
        loot_table_id = row.get("loot_table_id", "")
        if loot_table_id and loot_table_id not in loot_table_ids:
            report.error(f"location '{location_id}' references missing loot table '{loot_table_id}'")
        for event_id in split_ids(row.get("event_ids", "")):
            if event_id not in KNOWN_EVENT_IDS:
                report.warn(f"location '{location_id}' references unknown event id '{event_id}'")

    for file_name, rows, expected_kind in (
        ("weapons.csv", weapons_rows, "weapon"),
        ("armors.csv", armors_rows, "armor"),
    ):
        for line_number, row in enumerate(rows, start=2):
            kind = row.get("kind", "")
            if kind and kind != expected_kind:
                report.warn(f"data/{file_name}:{line_number} has kind '{kind}', expected '{expected_kind}'")

    report.print()
    return 1 if report.errors else 0


if __name__ == "__main__":
    sys.exit(validate())
