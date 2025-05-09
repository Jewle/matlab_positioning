function setupSearchPaths()
    addpath('libs');
    currentFolder = fileparts(mfilename('fullpath'));
    addpath(currentFolder);
end

function cleanupSearchPaths()
    rmpath('libs');
    currentFolder = fileparts(mfilename('fullpath'));
    rmpath(currentFolder);
end
