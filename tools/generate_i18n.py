"""One-shot generator for the UI translation catalog.

Reads the Russian source column from assets/i18n/ui.csv and fills the requested
locale columns through the same public Google web translation endpoint supported
by YOUR_ID_HERE. It is kept in the repository so catalog updates are repeatable.
"""
from __future__ import annotations

import csv
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "assets" / "i18n" / "ui.csv"
# Only punctuation and digits: machine translation must never alter the marker.
SEPARATOR = "\n§§§123456789§§§\n"
LOCALES = ("fr", "it", "de", "es", "pt-BR", "uk", "ja", "ko", "zh-TW", "ar", "nl", "id", "hi", "tr", "zh-CN", "th", "vi", "pl")


def translate_batch(texts: list[str], locale: str) -> list[str]:
    query = SEPARATOR.join(texts)
    url = "https://translate.googleapis.com/translate_a/single?" + urllib.parse.urlencode(
        {"client": "gtx", "sl": "ru", "tl": locale, "dt": "t", "q": query}
    )
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=30) as response:
                payload = json.load(response)
            translated = "".join(part[0] for part in payload[0])
            result = translated.split(SEPARATOR)
            if len(result) == len(texts):
                return result
        except (OSError, ValueError, IndexError):
            pass
        time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"Could not translate {locale}: {texts[0][:40]!r}")


def batches(texts: list[str], max_characters: int = 3500):
    current: list[str] = []
    length = 0
    for text in texts:
        extra = len(text) + (len(SEPARATOR) if current else 0)
        if current and length + extra > max_characters:
            yield current
            current, length = [], 0
        current.append(text)
        length += extra
    if current:
        yield current


def main() -> None:
    with CATALOG.open("r", encoding="utf-8", newline="") as source:
        rows = list(csv.DictReader(source))
    keys = [row["keys"] for row in rows]
    translations: dict[str, list[str]] = {"ru": [row["ru"] for row in rows], "en": [row["en"] for row in rows]}
    for locale in LOCALES:
        values: list[str] = []
        for group in batches(keys):
            print(f"{locale}: {len(values) + 1}/{len(keys)}", flush=True)
            values.extend(translate_batch(group, locale))
            time.sleep(0.2)
        translations[locale.replace("-", "_").lower()] = values
    columns = ["keys", "ru", "en", *translations.keys() - {"ru", "en"}]
    # Preserve a stable language order matching Locale.gd rather than dict order.
    columns = ["keys", "ru", "en", "fr", "it", "de", "es", "pt_br", "uk", "ja", "ko", "zh_tw", "ar", "nl", "id", "hi", "tr", "zh_cn", "th", "vi", "pl"]
    with CATALOG.open("w", encoding="utf-8", newline="") as target:
        writer = csv.DictWriter(target, fieldnames=columns)
        writer.writeheader()
        for index, key in enumerate(keys):
            writer.writerow({"keys": key, **{locale: values[index] for locale, values in translations.items()}})


if __name__ == "__main__":
    main()
