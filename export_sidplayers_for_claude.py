import re
from pathlib import Path
import tiktoken

# === CONFIGURATION ===
sidplayers_dir = "SIDPlayers"  # The main SIDPlayers directory
output_file = "claude_sidplayers.md"
file_extension = "*.asm"  # Looking for assembly files

# === COMMENT STRIPPING FOR ASM FILES ===
def strip_asm_comments(code):
    """Strip comments from assembly code while preserving important directives"""
    lines = []
    for line in code.splitlines():
        # Remove line comments (both ; and //)
        # But be careful with strings that might contain these characters
        in_string = False
        cleaned_line = []
        i = 0
        while i < len(line):
            if line[i] == '"' and (i == 0 or line[i-1] != '\\'):
                in_string = not in_string
                cleaned_line.append(line[i])
            elif not in_string:
                if line[i:i+2] == '//':
                    break  # Rest of line is comment
                elif line[i] == ';':
                    # Check if it's not part of a directive or label
                    if i == 0 or line[i-1].isspace():
                        break  # Rest of line is comment
                    else:
                        cleaned_line.append(line[i])
                else:
                    cleaned_line.append(line[i])
            else:
                cleaned_line.append(line[i])
            i += 1
        
        cleaned = ''.join(cleaned_line).rstrip()
        if cleaned:  # Only add non-empty lines
            lines.append(cleaned)
    
    # Remove block comments /* ... */
    result = '\n'.join(lines)
    result = re.sub(r"/\*.*?\*/", "", result, flags=re.DOTALL)
    
    return result.strip()

def remove_excessive_blank_lines(code):
    """Remove excessive blank lines but keep single blank lines for readability"""
    lines = code.splitlines()
    result = []
    prev_blank = False
    
    for line in lines:
        is_blank = not line.strip()
        if is_blank:
            if not prev_blank:  # Keep first blank line
                result.append(line)
            prev_blank = True
        else:
            result.append(line)
            prev_blank = False
    
    return '\n'.join(result)

def estimate_tokens(text):
    """Estimate token count for the text"""
    try:
        enc = tiktoken.encoding_for_model("gpt-4")
        return len(enc.encode(text))
    except:
        # Fallback: rough estimate of 1 token per 4 characters
        return len(text) // 4

def collect_asm_files():
    """Recursively collect all .asm files from SIDPlayers directory"""
    sidplayers_path = Path(sidplayers_dir)
    
    if not sidplayers_path.exists():
        print(f"Warning: {sidplayers_dir} directory not found!")
        return []
    
    all_files = []
    for asm_file in sidplayers_path.rglob(file_extension):
        # Sort files by their path for consistent ordering
        all_files.append(asm_file)
    
    # Sort files: first by subdirectory, then by filename
    all_files.sort(key=lambda x: (x.parent.name, x.name))
    return all_files

def generate_player_metadata(directory_path):
    """Generate metadata about a player directory"""
    metadata = []
    
    # Check for common player files
    player_name = directory_path.name
    metadata.append(f"Player: {player_name}")
    
    # Check for specific file types
    has_main = any(directory_path.glob(f"{player_name}.asm"))
    has_config = any(directory_path.glob("config.asm"))
    has_macros = any(directory_path.glob("macros.asm"))
    
    features = []
    if has_main:
        features.append("Main")
    if has_config:
        features.append("Config")
    if has_macros:
        features.append("Macros")
    
    if features:
        metadata.append(f"Components: {', '.join(features)}")
    
    return metadata

def generate_output():
    """Generate the output markdown file with all ASM files"""
    blocks = []
    current_player = None
    player_files = {}
    
    # Group files by player directory
    for path in collect_asm_files():
        player_dir = path.parent.name
        if player_dir not in player_files:
            player_files[player_dir] = []
        player_files[player_dir].append(path)
    
    # Add header
    blocks.append("# SIDPlayers Assembly Files\n")
    blocks.append(f"Total players found: {len(player_files)}\n")
    
    # Process each player's files
    for player_name in sorted(player_files.keys()):
        files = player_files[player_name]
        
        # Add player section header
        blocks.append(f"\n## Player: {player_name}")
        blocks.append(f"Files: {len(files)}")
        blocks.append("")
        
        # Process each file for this player
        for path in files:
            try:
                content = path.read_text(encoding="utf-8", errors="ignore")
                clean = strip_asm_comments(content)
                clean = remove_excessive_blank_lines(clean)
                
                if clean:
                    rel_path = path.relative_to(Path(sidplayers_dir)).as_posix()
                    file_size = len(content)
                    cleaned_size = len(clean)
                    reduction = 100 * (1 - cleaned_size / file_size) if file_size > 0 else 0
                    
                    blocks.append(f"### FILE: {sidplayers_dir}/{rel_path}")
                    blocks.append(f"*Original size: {file_size} bytes, Cleaned: {cleaned_size} bytes (reduced by {reduction:.1f}%)*")
                    blocks.append("```asm")
                    blocks.append(clean)
                    blocks.append("```\n")
            except Exception as e:
                print(f"Failed to read {path}: {e}")
    
    # Combine all blocks
    final_text = "\n".join(blocks)
    
    # Write output file
    Path(output_file).write_text(final_text, encoding="utf-8")
    
    # Print summary
    total_files = sum(len(files) for files in player_files.values())
    token_count = estimate_tokens(final_text)
    
    print(f"=" * 50)
    print(f"SIDPlayers Export Summary")
    print(f"=" * 50)
    print(f"Players found: {len(player_files)}")
    print(f"Total ASM files: {total_files}")
    print(f"Output file: {output_file}")
    print(f"Output size: {len(final_text):,} characters")
    print(f"Estimated tokens: {token_count:,}")
    
    if token_count > 100000:
        print(f"\nWARNING: Token count ({token_count:,}) may exceed Claude's context limit!")
        print("Consider splitting into multiple files or being selective about which players to include.")
    
    print(f"\nPlayers exported:")
    for player_name in sorted(player_files.keys()):
        print(f"  - {player_name}: {len(player_files[player_name])} files")

if __name__ == "__main__":
    generate_output()