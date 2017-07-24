function chkmkdir(dir)
%% creates a directory if not already present.

    if ~exist(dir, 'dir'),
        mkdir(dir);
    end
end