# geosite2clash

Convert [v2fly/domain-list-community](https://github.com/v2fly/domain-list-community) **geosite lists** into [Clash](https://github.com/Dreamacro/clash)/[Meta](https://github.com/MetaCubeX/mihomo) compatible rule files.

---

## 🧭 Overview

`geosite2clash` flattens any **geosite** list (resolving all nested `include:` entries) and generates two clean, deduplicated rule files:

| Output file | Format | Purpose |
|--------------|---------|----------|
| `<prefix>-domain.txt` | domain wildcards (`+.` `*` `?`) | for `behavior: domain` rule-providers |
| `<prefix>-regex.txt`  | `DOMAIN-REGEX,<pattern>` | for `behavior: classical` rule-providers |

This makes it easy to integrate v2fly’s curated domain lists into Clash, or other rule-based proxy managers — without depending on third-party mirrors.

---

## ⚙️ Usage

```bash
# Basic usage
./build.sh <geosite> [output-prefix]

# Example: build the "geolocation-cn" list
./build.sh geolocation-cn

# Example: build with a custom output prefix
./build.sh geolocation-cn cn