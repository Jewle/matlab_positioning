#!/bin/bash

# Функция для отображения дерева директорий
print_tree() {
    local dir="$1"
    local prefix="$2"

    # Получаем список файлов и папок, исключая .git
    local items=$(ls -A "$dir" | grep -v '^.git$')

    # Преобразуем список в массив
    local IFS=$'\n'
    local items_array=($items)
    local count=${#items_array[@]}
    local i=0

    for item in "${items_array[@]}"; do
        ((i++))
        local path="$dir/$item"
        # Определяем символ для соединения (последний элемент или нет)
        if [ $i -eq $count ]; then
            echo "${prefix}└── $item"
            local new_prefix="${prefix}    "
        else
            echo "${prefix}├── $item"
            local new_prefix="${prefix}│   "
        fi

        # Если это директория, рекурсивно вызываем функцию
        if [ -d "$path" ]; then
            print_tree "$path" "$new_prefix"
        fi
    done
}

# Проверяем, указана ли директория, иначе используем текущую
if [ $# -eq 0 ]; then
    target_dir="."
else
    target_dir="$1"
fi

# Проверяем, существует ли директория
if [ ! -d "$target_dir" ]; then
    echo "Ошибка: Директория '$target_dir' не существует."
    exit 1
fi

# Выводим название корневой директории
echo "$target_dir"
# Запускаем функцию для отображения дерева
print_tree "$target_dir" ""
