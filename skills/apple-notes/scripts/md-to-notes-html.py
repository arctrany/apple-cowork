#!/usr/bin/env python3
"""
Convert Markdown to Apple Notes compatible HTML.
Supports: Notion-style callouts, STAR framework, page properties, checkboxes.

Usage: echo "# Title" | python3 md-to-notes-html.py
       python3 md-to-notes-html.py < input.md

## Notion-style callouts:
    > [!NOTE] Note content
    > [!WARNING] Warning content
    > [!TIP] Tip content
    > [!KEY] Key insight content

## STAR framework:
    ::: star
    Situation: xxx
    Task: xxx
    Action: xxx
    Result: xxx
    :::

## Page properties (YAML frontmatter):
    ---
    状态：进行中
    负责人：张三
    模块：后端
    截止：2024-12-31
    ---
"""
import sys
import re
import markdown


def parse_frontmatter(md_text):
    """Extract YAML frontmatter and return (properties_dict, remaining_text)"""
    if not md_text.startswith('---\n'):
        return None, md_text

    parts = md_text.split('\n---\n', 1)
    if len(parts) < 2:
        return None, md_text

    yaml_content = parts[0][4:]  # Skip '---\n'

    # Parse simple key: value pairs (handles Chinese keys and Chinese colon)
    props = {}
    for line in yaml_content.strip().split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        # Support both English colon (:) and Chinese colon (：)
        if ':' in line:
            key, value = line.split(':', 1)
            props[key.strip()] = value.strip()
        elif '：' in line:  # Chinese colon (U+FF1A)
            key, value = line.split('：', 1)
            props[key.strip()] = value.strip()

    return props if props else None, parts[1] if len(parts) > 1 else ''


def render_properties(props):
    """Render Notion-style properties grid"""
    if not props:
        return ''

    items = []
    for key, value in props.items():
        items.append(f'''<div style="display:flex;flex-direction:column;gap:4px;min-width:120px;">
            <span style="font-size:11px;color:#6b7280;text-transform:uppercase;letter-spacing:0.05em;">{key}</span>
            <span style="font-size:13px;font-weight:500;color:#1f2937;">{value}</span>
        </div>''')

    return f'''<div style="display:flex;flex-wrap:wrap;gap:16px;padding:12px 0;margin-bottom:20px;border-bottom:1px solid #e5e7eb;">
        {''.join(items)}
    </div>'''


def convert_callouts(md_text):
    """Convert Notion-style callouts to Apple Notes HTML"""
    callout_types = {
        'NOTE': ('📌', '3b82f6', '注记'),
        'WARNING': ('⚠️', 'f59e0b', '警告'),
        'TIP': ('💡', '10b981', '提示'),
        'KEY': ('🎯', '6b7280', '核心'),
        'TODO': ('📝', '8b5cf6', '待办'),
        'SUCCESS': ('✅', '10b981', '成功'),
        'ERROR': ('❌', 'ef4444', '错误'),
        'QUESTION': ('❓', 'f97316', '问题'),
    }

    # Handle multi-line callouts with > prefix
    def replace_callout_block(m):
        callout_type = m.group(1).upper()
        raw_content = m.group(2).strip()
        # Remove leading > from continuation lines
        content_lines = []
        for line in raw_content.split('\n'):
            cleaned = re.sub(r'^>\s*', '', line).strip()
            if cleaned:
                content_lines.append(cleaned)
        content = ' '.join(content_lines)

        if callout_type in callout_types:
            icon, color, label = callout_types[callout_type]
            r, g, b = int(color[0:2], 16), int(color[2:4], 16), int(color[4:6], 16)
            return f'''<div style="border-left:4px solid #{color};background:linear-gradient(to right, rgba({r}, {g}, {b}, 0.08), transparent);padding:16px;margin:16px 0;border-radius:0 8px 8px 0;">
                <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px;">
                    <span style="font-size:16px;">{icon}</span>
                    <span style="font-size:13px;font-weight:600;color:#{color};">{label}</span>
                </div>
                <div style="font-size:14px;line-height:1.6;color:#374151;">{content}</div>
            </div>'''
        return m.group(0)

    # Match > [!TYPE] followed by content lines (each may start with >)
    pattern = r'^>\s*\[!([A-Z]+)\]\s*(.*?)(?=\n\n|\n#|\n##|\n###|\n- |\n\*\ |\n\d\.|\Z)'
    md_text = re.sub(pattern, replace_callout_block, md_text, flags=re.MULTILINE | re.DOTALL)

    # Also handle single-line: > [!TYPE] content
    for callout_type, (icon, color, label) in callout_types.items():
        pattern = r'^>\s*\[!' + callout_type + r'\]\s*(.+)$'
        r, g, b = int(color[0:2], 16), int(color[2:4], 16), int(color[4:6], 16)
        replacement = f'''<div style="border-left:4px solid #{color};background:linear-gradient(to right, rgba({r}, {g}, {b}, 0.08), transparent);padding:16px;margin:16px 0;border-radius:0 8px 8px 0;">
            <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px;">
                <span style="font-size:16px;">{icon}</span>
                <span style="font-size:13px;font-weight:600;color:#{color};">{label}</span>
            </div>
            <div style="font-size:14px;line-height:1.6;color:#374151;">\\1</div>
        </div>'''
        md_text = re.sub(pattern, replacement, md_text, flags=re.MULTILINE)

    return md_text


def convert_star_framework(md_text):
    """Convert STAR framework blocks to 2x2 grid cards"""
    pattern = r':::\s*star\s*\n(.*?)\n:::'

    def replace_star(m):
        content = m.group(1)
        star_parts = {
            'Situation': '',
            'Task': '',
            'Action': '',
            'Result': ''
        }

        for line in content.split('\n'):
            line = line.strip()
            if line.startswith('Situation:'):
                star_parts['Situation'] = line.replace('Situation:', '').strip()
            elif line.startswith('Task:'):
                star_parts['Task'] = line.replace('Task:', '').strip()
            elif line.startswith('Action:'):
                star_parts['Action'] = line.replace('Action:', '').strip()
            elif line.startswith('Result:'):
                star_parts['Result'] = line.replace('Result:', '').strip()

        star_styles = {
            'Situation': ('#3b82f6', '#dbeafe', '背景情境'),
            'Task': ('#f97316', '#ffedd5', '目标任务'),
            'Action': ('#10b981', '#d1fae5', '行动措施'),
            'Result': ('#a855f7', '#f3e8ff', '结果产出')
        }

        cards = []
        for key, (bg, border, label) in star_styles.items():
            if star_parts[key]:
                cards.append(f'''<div style="flex:1;min-width:200px;padding:16px;background:{bg}08;border:1px solid {border};border-radius:8px;">
                    <div style="font-size:11px;color:{bg};text-transform:uppercase;font-weight:700;margin-bottom:8px;">{label}</div>
                    <div style="font-size:14px;line-height:1.6;color:#1f2937;">{star_parts[key]}</div>
                </div>''')

        return f'''<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:16px;margin:20px 0;">
            {''.join(cards)}
        </div>'''

    return re.sub(pattern, replace_star, md_text, flags=re.DOTALL)


def convert(md_text):
    # Step 1: Parse frontmatter
    properties, md_text = parse_frontmatter(md_text)

    # Step 2: Convert checkboxes
    def replace_checkbox(m):
        checked = m.group(1).lower() == 'x'
        text = m.group(2).strip()
        state = 'true' if checked else 'false'
        return f'<ul class="Apple-checked-list"><li data-checked="{state}">{text}</li></ul>'

    lines = md_text.split('\n')
    processed_lines = []
    checkbox_pattern = re.compile(r'^[-*]\s+\[([xX ])\]\s+(.*)')
    for line in lines:
        m = checkbox_pattern.match(line)
        if m:
            processed_lines.append(replace_checkbox(m))
        else:
            processed_lines.append(line)
    md_text = '\n'.join(processed_lines)

    # Step 3: Convert callouts (before markdown conversion)
    md_text = convert_callouts(md_text)

    # Step 4: Convert STAR framework
    md_text = convert_star_framework(md_text)

    # Step 5: Convert with Python-Markdown
    html = markdown.markdown(
        md_text,
        extensions=['extra', 'nl2br'],
        output_format='html'
    )

    # Step 6: Clean up
    html = re.sub(r'<p>(<ul class="Apple-checked-list">.*?</ul>)</p>', r'\1', html, flags=re.DOTALL)

    # Step 7: Prepend properties if present
    if properties:
        props_html = render_properties(properties)
        html = props_html + html

    return html


if __name__ == '__main__':
    md_text = sys.stdin.read()
    print(convert(md_text), end='')
