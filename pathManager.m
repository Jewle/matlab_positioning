function setupSearchPaths()
    addpath('libs');
    currentFolder = fileparts(mfilename('fullpath'));
    addpath(currentFolder);
    addpath(fullfile(currentFolder, 'src')); % Добавляем папку с декомпозированными файлами
end

function cleanupSearchPaths()
    rmpath('libs');
    currentFolder = fileparts(mfilename('fullpath'));
    rmpath(currentFolder);
    rmpath(fullfile(currentFolder, 'src')); % Удаляем папку
end