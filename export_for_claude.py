import re
from pathlib import Path
import tiktoken

# === CONFIGURATION ===
source_dirs = ["src", "include"]  # adjust as needed
exclude_dirs = ["test", "third_party", "build"]
output_file = "claude_input.md"

# === COMMENT STRIPPING ===
def strip_comments(code):
    code = re.sub(r"/\*.*?\*/", "", code, flags=re.DOTALL)
    code = re.sub(r"//.*?$", "", code, flags=re.MULTILINE)
    return code.strip()

def remove_blank_lines(code):
    return "\n".join(line for line in code.splitlines() if line.strip())

def estimate_tokens(text):
    enc = tiktoken.encoding_for_model("gpt-4")
    return len(enc.encode(text))

def should_exclude(path):
    return any(part in exclude_dirs for part in path.parts)

def collect_files():
    all_files = []
    for folder in source_dirs:
        for ext in ("*.cpp", "*.hpp", "*.h"):
            for file in Path(folder).rglob(ext):
                if not should_exclude(file):
                    all_files.append(file)
    return all_files

def generate_output():
    blocks = []
    for path in collect_files():
        try:
            content = path.read_text(encoding="utf-8")
            clean = strip_comments(content)
            clean = remove_blank_lines(clean)
            if clean:
                rel = path.as_posix()
                blocks.append(f"### FILE: {rel}\n```cpp\n{clean}\n```\n")
        except Exception as e:
            print(f"Failed to read {path}: {e}")

    final_text = "\n\n".join(blocks)
    Path(output_file).write_text(final_text, encoding="utf-8")
    print(f"Estimated tokens: {estimate_tokens(final_text)}")
    print(f"Wrote: {output_file}")

if __name__ == "__main__":
    generate_output()
