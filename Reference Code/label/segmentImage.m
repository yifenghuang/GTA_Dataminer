function segmentImage(dir, frame, egoMask)
%% creates the semantic segmentation of an image
%  INPUTS:
%   dir, frame as labelMTS
%   egoMask    mask depicting ego vehicle
%

    chkmkdir(fullfile(dir, 'segmentation'));
    segFile = fullfile(dir, 'segmentation', [frame, '__seg.png']);
    
    labelMap = LabelMap(dir, frame);
    labelMap.loadFileResources();
    
    [height,width,~] = size(labelMap.idMap);
    
    segmentation = ones(height,width);
    
    [uniqueIDs, ~, pos2uniqueIDs] = unique(reshape(labelMap.idMap, [height*width, 3]), 'rows');

    %% assign class id to every MTS
    for i = 1:size(uniqueIDs, 1),
        classID = labelMap.getLabel(uniqueIDs(i,:));
        if ~isnan(classID),        
            mtsMask = reshape(pos2uniqueIDs==i, [height, width]);
            segmentation(mtsMask) = classID;
        end
    end

    % fill holes in cars
    classID   = labelMap.c2id('car');
    classMask = imfill(segmentation == classID, 'holes');
    segmentation(classMask) = classID;
        
    % fill holes in trucks
    classID   = labelMap.c2id('truck');
    classMask = imfill(segmentation == classID, 'holes');
    segmentation(classMask) = classID;
    
    % fill holes in busses
    classID   = labelMap.c2id('bus');
    classMask = imfill(segmentation == classID, 'holes');
    segmentation(classMask) = classID;
    
    % fill holes in trains
    classID   = labelMap.c2id('train');
    classMask = imfill(segmentation == classID, 'holes');
    segmentation(classMask) = classID;
    
    if nargin > 2
        segmentation(egoMask) = labelMap.c2id('ego vehicle');
    end
    
    imwrite(segmentation, labelMap.colors./255, segFile);        
end