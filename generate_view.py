import re
import os

def generate_interleaved_view(asm_path, target_filename, start_line, end_line):
    # Regex patterns to parse the assembly directives
    file_pattern = re.compile(r'^\s*\.file\s+(\d+)\s+"[^"]+"\s+"([^"]+)"')
    loc_pattern = re.compile(r'^\s*\.loc\s+(\d+)\s+(\d+)')
    
    file_map = {}  # ID -> short filename (e.g., "ubsan_rt.zig")
    asm_by_line = {} # (filename, line_no) -> list of asm instructions
    
    current_file_id = None
    current_line = None

    # Step 1: Parse the assembly file
    with open(asm_path, 'r') as f:
        for line in f:
            line_stripped = line.strip()
            
            # Match .file directives
            file_match = file_pattern.match(line)
            if file_match:
                f_id, f_name = file_match.groups()
                file_map[f_id] = f_name
                continue
                
            # Match .loc directives
            loc_match = loc_pattern.match(line)
            if loc_match:
                f_id, l_num = loc_match.groups()
                current_file_id = f_id
                current_line = int(l_num)
                continue
            
            # If we have an active file/line, and it's an instruction (indented), record it
            if current_file_id in file_map and current_line is not None:
                # Skip labels, macro directives, and empty lines to keep it clean
                if line.startswith('\t') and not line_stripped.startswith('.'):
                    filename = file_map[current_file_id]
                    key = (filename, current_line)
                    if key not in asm_by_line:
                        asm_by_line[key] = []
                    asm_by_line[key].append(line_stripped)

    # Step 2: Try to locate and read the original source file
    # (In a production script, you might pass the absolute path from the .file directive)
    try:
        # Assuming the source file is accessible locally or in the same directory
        with open(target_filename, 'r') as f:
            source_lines = f.readlines()
    except FileNotFoundError:
        print(f"Error: Could not open source file '{target_filename}' to interleave.")
        return

    # Step 3: Print the interleaved view for the requested range
    print(f"\n=== Interleaved Source & Assembly: {target_filename} (Lines {start_line}-{end_line}) ===\n")
    
    # Target filename for matching against our map
    short_target_name = os.path.basename(target_filename)

    for line_no in range(start_line, end_line + 1):
        if line_no - 1 < len(source_lines):
            src_line = source_lines[line_no - 1].rstrip()
            # Print the source line in bold or colored if your terminal supports it
            print(f"\033[1;36m{line_no:4d} | {src_line}\033[0m")
            
            # Check if there is assembly for this line
            asm_key = (short_target_name, line_no)
            if asm_key in asm_by_line:
                for asm_ins in asm_by_line[asm_key]:
                    print(f"         └─>  {asm_ins}")
            else:
                print("         └─>  (No instructions / optimized away)")
        print()


generate_interleaved_view("main.s", "src/main.zig", 140, 151)
