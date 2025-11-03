# geosite2clash

Convert [v2fly/domain-list-community](https://github.com/v2fly/domain-list-community) geosite lists into Clash-compatible rule files.

---

## 🧭 Overview

`geosite2clash` flattens any geosite list (resolving all nested `include:` entries) and generates two output files:

| Output file         | Format                                | Description                          |
|---------------------|----------------------------------------|--------------------------------------|
| `<prefix>-domain.txt` | wildcard domain rules (`+.` `*` `?`)    | For `behavior: domain` rule-sets     |
| `<prefix>-regex.txt`  | `DOMAIN-REGEX,<pattern>`              | For `behavior: classical` rule-sets  |

The output is clean, deduplicated, and ready to use in any Clash-compatible client.

---

## ⚙️ Usage

```bash
./build.sh <geosite> [output_prefix] [-o output_prefix] [-r repo_path]
