import csv
import re

def main():
    input_filename = "resultsall.txt"
    output_filename = "results.csv"

    # Regex patterns
    # Matches section header, e.g. --- Random Tree, Successful Search ---
    header_pat = re.compile(r"^---\s*(Random|Balanced)\s*Tree,\s*(Successful|Unsuccessful)\s*Search\s*---")
    # Matches data line, e.g. Standard  Search: Mean =    91.44 ns/op, StdDev =   3.90 ns/op (4.3%)
    data_pat = re.compile(r"^\s*([\w\-]+)\s+Search:\s*Mean\s*=\s*([\d.]+)\s*ns/op,\s*StdDev\s*=\s*([\d.]+)\s*ns/op")

    rows = []
    current_cpu = None
    current_tree_type = None
    current_search_type = None

    with open(input_filename, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            # Check if line is a section header
            header_match = header_pat.match(line)
            if header_match:
                current_tree_type = header_match.group(1).lower()
                current_search_type = header_match.group(2)
                continue

            # Check if line is a benchmark data line
            data_match = data_pat.match(line)
            if data_match:
                test_name = data_match.group(1)
                mean_val = float(data_match.group(2))
                std_dev_val = float(data_match.group(3))
                rows.append([
                    current_cpu,
                    current_tree_type,
                    current_search_type,
                    test_name,
                    mean_val,
                    std_dev_val
                ])
                continue

            # If it's not empty, not a header, and not a data line, it is CPU name
            # Normalize multiple spaces in CPU name to a single space
            current_cpu = re.sub(r"\s+", " ", line)

    # Write output to CSV
    headers = ["CPU", "Tree Type", "Search Type", "Test", "Mean (ns/op)", "Std Dev (ns/op)"]
    with open(output_filename, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)

    print(f"Successfully wrote {len(rows)} results to {output_filename}")

if __name__ == "__main__":
    main()
