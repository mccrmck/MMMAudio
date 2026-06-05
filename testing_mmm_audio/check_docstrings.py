import sys
import re
import subprocess
import os

def check_directory_for_docstrings(dir: str) -> list[str]:
    print("🔍 Interactive Docstring Checker")
    print("-" * 40)

    tmpjson = "tmp.json"
    full_command = ["mojo", "doc", "--diagnose-missing-doc-strings", dir, "-o", tmpjson]
    
    print(f"\n🚀 Running: {' '.join(full_command)}\n")
    
    result = subprocess.run(
        full_command,
        capture_output=True,
        text=True,
    )

    os.remove(tmpjson)

    # Combine stdout and stderr to ensure we don't miss anything
    all_output = result.stdout + result.stderr
    lines = all_output.splitlines(keepends=True)
    
    # 4. Filter the output
    ansi_escape = re.compile(r'\x1b\[[0-9;]*m')
    function_warnings = []
    i = 0
    
    while i < len(lines):
        original_line = lines[i]
        clean_line = ansi_escape.sub('', original_line)
        
        if "warning: function" in clean_line:
            warning_block = [original_line.strip()]
            
            if i + 1 < len(lines):
                warning_block.append(lines[i+1].rstrip())
            if i + 2 < len(lines):
                warning_block.append(lines[i+2].rstrip())
            
            function_warnings.append("\n".join(warning_block))
            i += 3 
        else:
            i += 1
            
    if result.returncode != 0:
        print(f"⚠️ Command exited with code {result.returncode}, but no function docstring warnings were found.")
        print("Here is the raw output in case of syntax errors:\n")
        print(all_output)
        sys.exit(1)
    else:
        return function_warnings

if __name__ == "__main__":
    function_warnings = []
    function_warnings.extend(check_directory_for_docstrings("mmm_audio"))

    if function_warnings:
        for warn in function_warnings:
            print(warn, file=sys.stderr)
            print("-" * 60, file=sys.stderr)

        print(f"❌ Failed: Found {len(function_warnings)} function docstring warning(s).\n", file=sys.stderr)
            
        sys.exit(1)
    else:
        print("🎉 All function docstrings are complete.")
        sys.exit(0)