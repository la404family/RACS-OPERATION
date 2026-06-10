import os
import re

def strip_sqf_comments(filepath):
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()

    # Remove block comments
    content = re.sub(r'/\*[\s\S]*?\*/', '', content)
    # Remove line comments
    content = re.sub(r'//.*', '', content)
    
    # Clean up empty lines
    content = re.sub(r'^[ \t]+$', '', content, flags=re.MULTILINE)
    content = re.sub(r'\n{3,}', '\n\n', content)
    content = content.strip() + '\n'

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'Stripped: {filepath}')

for root, dirs, files in os.walk('.'):
    for name in files:
        if name.endswith('.sqf'):
            strip_sqf_comments(os.path.join(root, name))
