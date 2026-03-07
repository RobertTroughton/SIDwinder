import re
from pathlib import Path
import tiktoken

# === CONFIGURATION ===
source_dirs = ["src", "include"]  # adjust as needed
exclude_dirs = ["test", "third_party", "build"]
output_file = "claude_input.md"
TOKEN_MODEL = "gpt-4"  # tiktoken proxy for Claude-ish length

# === COMMENT STRIPPING ===
def strip_comments(code):
    code = re.sub(r"/\*.*?\*/", "", code, flags=re.DOTALL)
    code = re.sub(r"//.*?$", "", code, flags=re.MULTILINE)
    return code.strip()

def remove_blank_lines(code):
    return "\n".join(line for line in code.splitlines() if line.strip())

def estimate_tokens(text: str, model: str = TOKEN_MODEL) -> int:
    """
    Best-effort token estimate:
    1) Try model-specific encoding
    2) Fallback to cl100k_base
    3) Fallback to ~1 token per 4 chars
    """
    try:
        enc = tiktoken.encoding_for_model(model)
    except Exception:
        try:
            enc = tiktoken.get_encoding("cl100k_base")
        except Exception:
            return max(1, len(text) // 4)
    try:
        return len(enc.encode(text))
    except Exception:
        return max(1, len(text) // 4)
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

    token_count = estimate_tokens(final_text)
    Path(output_file).write_text(final_text, encoding="utf-8")
    print(f"Estimated tokens: {token_count:,}")
    print(f"Wrote: {output_file}")

    if token_count > 100000:
        print(f"\nWARNING: Token count ({token_count:,}) may exceed Claude's context limit!")
        print("Consider splitting into multiple files or being selective about which players to include.")


if __name__ == "__main__":
    generate_output()
