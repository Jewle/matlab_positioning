#!/bin/bash

# Указываем имя выходного файла
OUTPUT_FILE="output.txt"

# Очищаем или создаем выходной файл
> "$OUTPUT_FILE"

# Функция для обработки файлов и папок
process_directory() {
    local dir="$1"
    
    # Проходим по всем файлам и папкам в текущей директории
    for item in "$dir"/*; do
        # Пропускаем output.txt
        if [[ "$(basename "$item")" == "$OUTPUT_FILE" ]]; then
            continue
        fi
        
        if [[ -f "$item" ]]; then
            # Если это файл, записываем его путь и содержимое
            echo "$item" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            cat "$item" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        elif [[ -d "$item" ]]; then
            # Если это папка, рекурсивно вызываем функцию
            process_directory "$item"
        fi
    done
}

# Начинаем обработку с текущей директории
process_directory "."

echo "Processing complete. Results written to $OUTPUT_FILE"
