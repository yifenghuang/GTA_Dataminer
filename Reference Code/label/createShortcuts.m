function createShortcuts(minOccurence, minPercentage)
%% create shortcut rules, e.g. shader ID => class
%  INPUTS:
%    minOccurrence    minimum number of hash to class annotations
%    minPercentage    minimum percentage of hash to same class annotations

    fprintf('loading files...'); tic;
    data = load(fullfile('hash2cid.mat'), 'hk', 'hv');
    hk = data.hk;
    hv = data.hv;
    
    mts2classID = zeros(length(hv), 7, 'uint64'); 
    for i = 1:length(hk)
        if ~strcmp(hk{i}, '0.0.0') % skip sky
            s = strsplit(hk{i},'.');
            for j = 1:6 % mts
                mts2classID(i,j) = sscanf(s{j}, '%lx');
                end
            mts2classID(i,7) = hv{i}; % class
        end
    end
    fprintf('%.2fs.\n', toc);
    
    names = {'tex', 'mesh', 'shader'};
    for j = 1:3
        
        fprintf('processing %s\n', names{j});
        shortcutFilename = fullfile([names{j}, 'Hash2class.mat']);
        if ~exist(shortcutFilename, 'file')
            hashMap = containers.Map('KeyType', 'char', 'ValueType', 'double');
        else
            data = load(shortcutFilename, 'hk', 'hv');
            hashMap = containers.Map(data.hk, data.hv);
        end
    
        hashVector = mts2classID(:,2*(j-1)+1:2*j);
        [uniqueHashes] = unique(hashVector, 'rows');

        for i = 1:size(uniqueHashes,1)
            mtsMask = hashVector(:,1) == uniqueHashes(i,1) & ...
                hashVector(:,2) == uniqueHashes(i,2);
            if sum(mtsMask) > minOccurence
                classID = double(mts2classID(mtsMask,7));
                annotations = unique(classID);
                [N,X] = hist(classID,annotations);
                N = N./sum(N);

                targetClassID = X(N > minPercentage);
                if ~isempty(targetClassID)
                    key = sprintf('%lx.%lx', uniqueHashes(i,1), uniqueHashes(i,2));
                    if hashMap.isKey(key)
                        if hashMap(key) ~= targetClassID
                            warning('would modify key %d -> %d', hashMap(key), targetClassID);
                        end
                    else
                        hashMap(key) = targetClassID;
                        fprintf('%s: %s => %d @ %.2f (%d)\n', names{j}, key, targetClassID, N(N>minPercentage), sum(mtsMask));
                    end
                end
            end
        end
        
        hk = hashMap.keys;
        hv = hashMap.values;
        
        if ~isempty(hk)
            save(shortcutFilename, 'hk', 'hv');
        end
    end
end