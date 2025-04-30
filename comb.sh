# Output file where all contents will be stored
output_file="../combined_output.txt"

# Clear the output file if it exists
> "$output_file"

# Loop through all files in the current directory
for file in *; do
    # Check if it's a file (not a directory)
    if [ -f "$file" ]; then
        # Write the file name and a separator to the output file
        echo "$file:" >> "$output_file"
        # Append the file's contents to the output file
        cat "$file" >> "$output_file"
        # Add a newline for separation
        echo "" >> "$output_file"
    fi
done

echo "All file contents have been combined into $output_file"
