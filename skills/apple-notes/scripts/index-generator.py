#!/usr/bin/env python3
"""
Scan Apple Notes and generate an index note with tags and properties.
Supports:
- Frontmatter parsing (tags, status, owner, etc.)
- Tag grouping and categorization
- Hierarchical index structure

Usage:
    python3 index-generator.py [--output "索引笔记名称"] [--folder "文件夹路径"]
"""

import subprocess
import re
import sys
from collections import defaultdict
from datetime import datetime


def get_notes_from_apple_notes(folder=None):
    """Fetch all notes from Apple Notes using AppleScript"""
    script = """
    tell application "Notes"
        set allNotes to {}
        set accountName to "iCloud"

        try
            set notesList to every note of account accountName
            repeat with n in notesList
                set end of allNotes to {name:name of n, body:body of n, id:id of n}
            end repeat
        end try

        return allNotes
    end tell
    """
    try:
        result = subprocess.run(
            ['osascript', '-e', script],
            capture_output=True,
            text=True
        )
        # Parse the output (simplified - in production would need proper AppleEvent parsing)
        return []
    except Exception as e:
        print(f"Warning: Could not fetch notes from Apple Notes: {e}")
        return []


def scan_notes_in_directory(directory="~/Notes"):
    """Scan markdown files in a directory for notes"""
    import os
    from pathlib import Path

    notes = []
    notes_dir = Path(directory).expanduser()

    if not notes_dir.exists():
        return notes

    for md_file in notes_dir.glob("*.md"):
        with open(md_file, 'r', encoding='utf-8') as f:
            content = f.read()

        frontmatter = parse_frontmatter(content)
        notes.append({
            'title': md_file.stem,
            'file': str(md_file),
            'frontmatter': frontmatter,
            'tags': frontmatter.get('标签', []) if frontmatter else []
        })

    return notes


def parse_frontmatter(content):
    """Parse YAML frontmatter from markdown content"""
    if not content.startswith('---\n'):
        return None

    parts = content.split('\n---\n', 1)
    if len(parts) < 2:
        return None

    yaml_content = parts[0][4:]
    props = {}

    for line in yaml_content.strip().split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue

        # Handle tags array
        if line.startswith('标签：') or line.startswith('tags:'):
            tags_str = line.split(':', 1)[1].strip()
            # Parse [tag1, tag2, tag3] format
            if tags_str.startswith('[') and tags_str.endswith(']'):
                tags = [t.strip() for t in tags_str[1:-1].split(',')]
                props['标签'] = tags
            else:
                props['标签'] = [tags_str]
        elif ':' in line:
            key, value = line.split(':', 1)
            props[key.strip()] = value.strip()
        elif ':' in line:
            key, value = line.split(':', 1)
            props[key.strip()] = value.strip()

    return props if props else None


def generate_index_html(notes):
    """Generate HTML index for Apple Notes"""

    # Group notes by tags
    tags_map = defaultdict(list)
    untagged = []

    for note in notes:
        if note.get('tags'):
            for tag in note['tags']:
                tags_map[tag].append(note)
        else:
            untagged.append(note)

    # Build HTML
    html_parts = []

    # Header
    html_parts.append('''
<div style="padding:20px;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);margin:-20px -20px 20px -20px;border-radius:12px 12px 0 0;">
    <h1 style="margin:0;color:white;font-size:24px;">📚 笔记索引</h1>
    <p style="margin:8px 0 0 0;color:rgba(255,255,255,0.9);font-size:14px;">
        最后更新：''' + datetime.now().strftime('%Y-%m-%d %H:%M') + '''
    </p>
</div>
''')

    # Tag cloud
    if tags_map:
        html_parts.append('<h2 style="margin:20px 0 12px 0;">🏷️ 标签云</h2>')
        tag_cloud = []
        for tag, tag_notes in sorted(tags_map.items()):
            tag_cloud.append(
                f'<span style="display:inline-block;padding:6px 12px;margin:4px;background:#667eea10;color:#667eea;'
                f'border-radius:16px;font-size:13px;border:1px solid #667eea30;">{tag} ({len(tag_notes)})</span>'
            )
        html_parts.append('<div style="margin:16px 0;">' + ' '.join(tag_cloud) + '</div>')

    # Notes by tag
    for tag, tag_notes in sorted(tags_map.items()):
        html_parts.append(f'''
<div style="margin:24px 0;padding:16px;background:#f8fafc;border-radius:8px;border-left:4px solid #667eea;">
    <h3 style="margin:0 0 12px 0;color:#667eea;">🏷️ {tag}</h3>
    <ul style="margin:0;padding-left:20px;">
''')
        for note in tag_notes:
            note_title = note.get('frontmatter', {}).get('标题', note['title']) if note.get('frontmatter') else note['title']
            status = note.get('frontmatter', {}).get('状态', '') if note.get('frontmatter') else ''
            status_color = {'已完成': '#10b981', '进行中': '#3b82f6', '待开始': '#6b7280'}.get(status, '#6b7280')

            html_parts.append(f'''
        <li style="margin:8px 0;">
            <span style="font-weight:500;color:#1f2937;">{note_title}</span>
            {f'<span style="margin-left:8px;padding:2px 8px;background:{status_color}20;color:{status_color};'
             f'border-radius:4px;font-size:11px;">{status}</span>' if status else ''}
        </li>
''')
        html_parts.append('    </ul>\n</div>\n')

    # Untagged notes
    if untagged:
        html_parts.append('''
<div style="margin:24px 0;padding:16px;background:#fef3c7;border-radius:8px;border-left:4px solid #f59e0b;">
    <h3 style="margin:0 0 12px 0;color:#f59e0b;">📝 未分类笔记</h3>
    <ul style="margin:0;padding-left:20px;">
''')
        for note in untagged:
            html_parts.append(f'        <li style="margin:8px 0;"><span style="font-weight:500;color:#1f2937;">{note["title"]}</span></li>\n')
        html_parts.append('    </ul>\n</div>\n')

    return ''.join(html_parts)


def create_index_in_apple_notes(html_content, output_name="笔记索引", folder="Notes"):
    """Create or update the index note in Apple Notes"""

    # Escape HTML for AppleScript
    escaped_html = html_content.replace('"', '\\"').replace('\n', '\\n')

    script = f'''
    tell application "Notes"
        set folderName to "{folder}"
        set noteName to "{output_name}"
        set noteBody to "{escaped_html}"

        try
            set existingNote to note noteName of folder folderName
            set body of existingNote to noteBody
            log "Index updated: " & noteName
        on error
            set newNote to make new note at folder folderName with properties {{name:noteName, body:noteBody}}
            log "Index created: " & (name of newNote)
        end try
    end tell
    '''

    try:
        subprocess.run(['osascript', '-e', script], check=True)
        print(f"✓ 索引笔记已更新：{output_name}")
    except Exception as e:
        print(f"Error creating index note: {e}")
        sys.exit(1)


def main():
    output_name = "笔记索引"
    folder = "Notes"
    scan_dir = "~/Documents/Notes"

    i = 1
    while i < len(sys.argv):
        if sys.argv[i] == '--output' and i + 1 < len(sys.argv):
            output_name = sys.argv[i + 1]
            i += 2
        elif sys.argv[i] == '--folder' and i + 1 < len(sys.argv):
            folder = sys.argv[i + 1]
            i += 2
        elif sys.argv[i] == '--scan-dir' and i + 1 < len(sys.argv):
            scan_dir = sys.argv[i + 1]
            i += 2
        else:
            i += 1

    print("📖 扫描笔记文件...")
    notes = scan_notes_in_directory(scan_dir)

    if not notes:
        print("⚠️  未找到笔记文件")
        sys.exit(0)

    print(f"✓ 找到 {len(notes)} 篇笔记")

    print("📊 生成索引...")
    html = generate_index_html(notes)

    print("📝 创建索引笔记...")
    create_index_in_apple_notes(html, output_name, folder)

    print("✓ 完成!")


if __name__ == '__main__':
    main()
