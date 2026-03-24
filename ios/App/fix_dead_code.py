import re

filepath = r"c:\Users\nsoli\Downloads\Proyectos\leanup-app\ios\App\App\NativeFoundation\LeanUpModels.swift"

with open(filepath, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
skip = False
brace_count = 0

for line in lines:
    if skip:
        brace_count += line.count('{') - line.count('}')
        if brace_count < 0:
            skip = False
            new_lines.append(line)
        continue
    
    match = re.search(r'^\s*return cachedPresentationState\.([a-zA-Z0-9_]+)\s*$', line)
    if match:
        indent = line[:line.index('return')]
        new_line = f"{indent}cachedPresentationState.{match.group(1)}\n"
        new_lines.append(new_line)
        skip = True
        brace_count = 0 
    else:
        new_lines.append(line)

with open(filepath, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print("Replacement complete. Dead code removed.")
