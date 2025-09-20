import re
from pathlib import Path
import tiktoken

# === CONFIGURATION ===
public_dir = "public"  # main folder to scan
output_file = "claude_public.md"
extensions = ("*.html", "*.css", "*.js")
TOKEN_MODEL = "gpt-4"  # tiktoken proxy for Claude-ish length

# === COMMENT STRIPPING ===
def strip_comments(code, ext):
    if ext == ".html":
        # Remove <!-- ... -->
        code = re.sub(r"<!--.*?-->", "", code, flags=re.DOTALL)
    elif ext == ".css":
        # Remove /* ... */
        code = re.sub(r"/\*.*?\*/", "", code, flags=re.DOTALL)
    elif ext == ".js":
        # Remove /* ... */ and // ...
        code = re.sub(r"/\*.*?\*/", "", code, flags=re.DOTALL)
        code = re.sub(r"//.*?$", "", code, flags=re.MULTILINE)
    return code.strip()

def remove_excessive_blank_lines(code):
    lines = code.splitlines()
    result = []
    prev_blank = False
    for line in lines:
        if not line.strip():
            if not prev_blank:
                result.append(line)
            prev_blank = True
        else:
            result.append(line)
            prev_blank = False
    return "\n".join(result)

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
def collect_files():
    all_files = []
    base = Path(public_dir)
    if not base.exists():
        print(f"Warning: {public_dir} directory not found!")
        return []
    for ext in extensions:
        for file in base.rglob(ext):
            all_files.append(file)
    return all_files

def generate_output():
    blocks = []
    for path in collect_files():
        try:
            content = path.read_text(encoding="utf-8", errors="ignore")
            clean = strip_comments(content, path.suffix.lower())
            clean = remove_excessive_blank_lines(clean)
            if clean:
                rel = path.relative_to(public_dir).as_posix()
                blocks.append(f"### FILE: {public_dir}/{rel}\n```{path.suffix[1:]}\n{clean}\n```\n")
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
