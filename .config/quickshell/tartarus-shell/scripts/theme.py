from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import cast

import tomllib

PROJECT_ROOT = Path(__file__).resolve().parent.parent
PALETTES_DIR = PROJECT_ROOT / "theme" / "palettes"
STATE_DIR = Path.home() / ".local" / "state" / "tartarus-shell"
ACTIVE_THEME_FILE = STATE_DIR / "active-theme.json"


REQUIRED_METADATA: set[str] = {
    "name",
    "slug",
    "mode",
}

REQUIRED_ROLES: set[str] = {
    "background",
    "background_alt",
    "surface",
    "surface_hover",
    "selection",
    "foreground",
    "foreground_muted",
    "foreground_subtle",
    "accent",
    "error",
    "warning",
    "success",
    "info",
}


def load_palette(slug: str) -> dict[str, object]:
    palette_file = PALETTES_DIR / slug / "colors.toml"

    if not palette_file.exists():
        raise FileNotFoundError(
            f"No existe la paleta '{slug}': {palette_file}"
        )

    with palette_file.open("rb") as file:
        return cast(dict[str, object], tomllib.load(file))


def discover_palettes() -> list[dict[str, object]]:
    palettes: list[dict[str, object]] = []

    if not PALETTES_DIR.exists():
        return palettes

    for palette_dir in sorted(PALETTES_DIR.iterdir()):
        if not palette_dir.is_dir():
            continue

        palette_file = palette_dir / "colors.toml"

        if not palette_file.exists():
            continue

        try:
            with palette_file.open("rb") as file:
                palette = cast(dict[str, object], tomllib.load(file))
            validate_palette(palette)
        except (FileNotFoundError, TypeError, ValueError):
            continue

        palettes.append(
            {
                "name": palette["name"],
                "slug": palette["slug"],
                "mode": palette["mode"],
                "preview": build_preview(palette),
            }
        )

    return palettes


def read_active_theme() -> dict[str, object]:
    if not ACTIVE_THEME_FILE.exists():
        raise FileNotFoundError("No hay ningún tema activo.")

    try:
        with ACTIVE_THEME_FILE.open("rb") as file:
            return cast(dict[str, object], json.load(file))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(
            f"El tema activo contiene JSON inválido: {error}"
        ) from error


def print_usage() -> None:
    print(
        "Uso:\n"
        "  python scripts/theme.py list [--json]\n"
        "  python scripts/theme.py current [--json]\n"
        "  python scripts/theme.py set <palette>"
    )


def validate_palette(palette: dict[str, object]) -> None:
    missing_metadata = REQUIRED_METADATA - palette.keys()

    if missing_metadata:
        missing = ", ".join(sorted(missing_metadata))
        raise ValueError(
            f"Faltan campos de metadata: {missing}"
        )

    colors = palette.get("colors")
    roles = palette.get("roles")

    if not isinstance(colors, dict):
        raise TypeError(
            "La paleta debe contener una tabla [colors]."
        )

    if not isinstance(roles, dict):
        raise TypeError(
            "La paleta debe contener una tabla [roles]."
        )

    typed_colors = cast(dict[str, str], colors)
    typed_roles = cast(dict[str, str], roles)

    missing_roles = REQUIRED_ROLES - typed_roles.keys()

    if missing_roles:
        missing = ", ".join(sorted(missing_roles))
        raise ValueError(
            f"Faltan roles requeridos: {missing}"
        )

    for role_name, color_name in typed_roles.items():
        if color_name not in typed_colors:
            raise ValueError(
                f"El rol '{role_name}' referencia el color '{color_name}', pero ese color no existe en [colors]."
            )


def resolve_roles(palette: dict[str, object]) -> dict[str, str]:
    colors = cast(dict[str, str], palette["colors"])
    roles = cast(dict[str, str], palette["roles"])

    return {
        role_name: colors[color_name]
        for role_name, color_name in roles.items()
    }


def build_preview(palette: dict[str, object]) -> list[str]:
    roles = resolve_roles(palette)

    preview_roles = [
        "accent",
        "info",
        "success",
        "warning",
        "error",
    ]

    return [
        roles[role]
        for role in preview_roles
    ]


def build_active_theme(palette: dict[str, object]) -> dict[str, object]:
    return {
        "name": palette["name"],
        "slug": palette["slug"],
        "mode": palette["mode"],
        "colors": palette["colors"],
        "roles": resolve_roles(palette),
    }


def write_active_theme(theme: dict[str, object]) -> None:
    STATE_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    _ = ACTIVE_THEME_FILE.write_text(
        json.dumps(
            theme,
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )


def set_theme(slug: str) -> None:
    palette = load_palette(slug)

    validate_palette(palette)

    active_theme = build_active_theme(palette)

    write_active_theme(active_theme)

    print(
        f"Tema activo: {active_theme['name']}"
    )
    print(
        f"Archivo generado: {ACTIVE_THEME_FILE}"
    )


def list_themes(as_json: bool = False) -> None:
    palettes = discover_palettes()

    if as_json:
        print(
            json.dumps(
                palettes,
                indent=2,
                ensure_ascii=False,
            )
        )
        return

    if not palettes:
        print("No hay paletas disponibles.")
        return

    for palette in palettes:
        print(
            f"{palette['slug']} "
            f"- {palette['name']} "
            f"({palette['mode']})"
        )


def show_current_theme(as_json: bool = False) -> None:
    theme = read_active_theme()

    current = {
        "name": theme.get("name", "Unknown"),
        "slug": theme.get("slug", "unknown"),
        "mode": theme.get("mode", "unknown"),
    }

    if as_json:
        print(
            json.dumps(
                current,
                indent=2,
                ensure_ascii=False,
            )
        )
        return

    print(f"Nombre: {current['name']}")
    print(f"Slug: {current['slug']}")
    print(f"Modo: {current['mode']}")


def main() -> None:
    try:
        if len(sys.argv) < 2:
            print_usage()
            raise SystemExit(1)

        command = sys.argv[1]

        if command == "list":
            if len(sys.argv) > 3:
                print_usage()
                raise SystemExit(1)

            as_json = len(sys.argv) == 3 and sys.argv[2] == "--json"

            if len(sys.argv) == 3 and not as_json:
                print_usage()
                raise SystemExit(1)

            list_themes(as_json)

        elif command == "current":
            if len(sys.argv) > 3:
                print_usage()
                raise SystemExit(1)

            as_json = len(sys.argv) == 3 and sys.argv[2] == "--json"

            if len(sys.argv) == 3 and not as_json:
                print_usage()
                raise SystemExit(1)

            show_current_theme(as_json)

        elif command == "set":
            if len(sys.argv) != 3:
                print_usage()
                raise SystemExit(1)

            slug = sys.argv[2]
            set_theme(slug)

        else:
            print_usage()
            raise SystemExit(1)

    except (FileNotFoundError, TypeError, ValueError) as error:
        print(
            f"Error: {error}",
            file=sys.stderr,
        )
        raise SystemExit(1)


if __name__ == "__main__":
    main()
