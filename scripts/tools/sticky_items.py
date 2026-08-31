"""Shared authoring contract for one immovable item per shelf layer."""

from __future__ import annotations

from typing import Any


def validate_sticky_items(shelf: dict[str, Any]) -> list[str]:
    entries = shelf.get("sticky_items", [])
    if not isinstance(entries, list):
        return ["sticky_items must be an array"]
    if entries and shelf.get("type", "standard") == "dispenser":
        return ["dispenser shelves cannot contain sticky items"]
    errors: list[str] = []
    layers = shelf.get("layers", [])
    seen: set[int] = set()
    for entry in entries:
        if not isinstance(entry, dict) or set(entry) != {"layer", "slot"}:
            errors.append("each sticky_items entry must contain exactly layer and slot")
            continue
        layer, slot = entry["layer"], entry["slot"]
        if type(layer) is not int or type(slot) is not int or layer < 0 or slot < 0:
            errors.append("sticky layer and slot must be non-negative integers")
            continue
        if layer in seen:
            errors.append("only one sticky item is allowed per shelf layer")
        seen.add(layer)
        if (not isinstance(layers, list) or layer >= len(layers)
                or not isinstance(layers[layer], list) or slot >= len(layers[layer])):
            errors.append("sticky item coordinates are out of range")
        elif not isinstance(layers[layer][slot], str) or not layers[layer][slot]:
            errors.append("sticky item must reference an occupied slot")
    return errors
