#!/usr/bin/env python3
"""Update Sparkle appcast.xml with idempotent entries and release notes."""

import os
import re
import sys
from datetime import datetime, timezone

if len(sys.argv) < 5:
    print("Usage: update-appcast.py <version> <build_number> <zip_path> <appcast_path> [signature]")
    sys.exit(1)

version = sys.argv[1]
build_number = sys.argv[2]
zip_path = sys.argv[3]
appcast_path = sys.argv[4]
signature = sys.argv[5] if len(sys.argv) > 5 else "PENDING"

file_size = os.path.getsize(zip_path)
pub_date = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S %z")

repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
notes_path = os.path.join(repo_root, "releases", f"{version}.html")
description_block = ""
if os.path.exists(notes_path):
    with open(notes_path, "r", encoding="utf-8") as handle:
        notes_html = handle.read().strip()
    indented = "\n".join("                " + line for line in notes_html.splitlines())
    description_block = f"""            <description><![CDATA[
{indented}
            ]]></description>
"""
else:
    print(
        f"WARNING: no release notes found at {notes_path}\n"
        f"         the appcast entry will publish without a <description> block.\n"
        f"         create the file (HTML body, no wrapper tags) before re-running.",
        file=sys.stderr,
    )

new_item = f"""        <item>
            <title>Version {version}</title>
            <sparkle:version>{build_number}</sparkle:version>
            <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
            <pubDate>{pub_date}</pubDate>
{description_block}            <enclosure url="https://github.com/hewigovens/ghosttile-cli/releases/download/v{version}/GhostTile-{version}.zip"
                       sparkle:edSignature="{signature}"
                       length="{file_size}"
                       type="application/octet-stream"/>
        </item>
"""

if os.path.exists(appcast_path) and os.path.getsize(appcast_path) > 0:
    with open(appcast_path, "r", encoding="utf-8") as handle:
        content = handle.read()

    pattern = re.compile(
        r"        <item>\n"
        r"            <title>Version " + re.escape(version) + r"</title>\n"
        r".*?</item>\n",
        re.DOTALL,
    )
    content = pattern.sub("", content)

    if "</language>" in content:
        content = content.replace("</language>\n", "</language>\n" + new_item, 1)
    else:
        content = content.replace("<channel>\n", "<channel>\n" + new_item, 1)

    with open(appcast_path, "w", encoding="utf-8") as handle:
        handle.write(content)
else:
    content = f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>GhostTile</title>
        <link>https://raw.githubusercontent.com/hewigovens/ghosttile-cli/main/docs/appcast.xml</link>
        <description>GhostTile updates</description>
        <language>en</language>
{new_item}    </channel>
</rss>
"""
    with open(appcast_path, "w", encoding="utf-8") as handle:
        handle.write(content)

print(f"Updated {appcast_path}")
print(f"  Version: {version} ({build_number})")
print(f"  Size: {file_size}")
print(f"  Signature: {signature}")
