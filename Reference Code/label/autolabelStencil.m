function autolabelStencil(dir, frame, stencilMask, className)
%% uses class mask (like stencil buffer) to annotate MTS
%  Stencil buffers may be used for automatically labeling some classes.
%  In order to do that, name the file containing the stencil buffer 
%  <frame>__stencil.png, specify an
%
%  INPUTS:
%    dir, file    directory containing files, frame to be labeled 
%    stencilMask  class mask (potentially from stencil buffer)
%    className    class for all MTS covered by the stencilMask
%

    labelMap = LabelMap(dir, frame);
    labelMap.loadFileResources();
    classID = labelMap.c2id(className);
    
    [height, width, ~] = size(labelMap.idMap);
    mtsVector = reshape(labelMap.idMap, [height*width, 3]);
    
    stencilLabels = zeros(height,width);
    sl = bwlabeln(stencilMask);
    stencilLabels(sl~=0) = sl(sl ~= 0);
    
    [potIds, ~, ~] = unique(mtsVector(stencilMask, :), 'rows');    
    
    %% filter hashes that are within mask
    hu = potIds; k = 0;
    for j = 1:size(potIds,1)
        m = labelMap.maskHash(potIds(j,:));
        if any(m(:) & ~stencilMask(:))
            continue;
        end
        k = k + 1;
        hu(k,:) = potIds(j,:);
    end               
    hu = hu(1:k,:);    
    
    i = 1;
    while(i < size(hu,1))
        
        he = hu(i,:);

        % do we have a label already?
        label = labelMap.getLabel(he);
        if ~isnan(label)
            i = i+1;
            continue;            
        end

        % get all blobs in the stencil mask with this hash
        mask = labelMap.maskHash(hu(i,:));
        potStencils = unique(stencilLabels(mask));
        stencilMask = false(height,width);
        for j = 1:length(potStencils)
            if potStencils(j) ~= 0
                stencilMask = stencilMask | (stencilLabels == potStencils(j));
            end
        end
        
        % take only those hashes that are completly within a stencil blob
        mask = stencilMask;
        hep = unique(mtsVector(mask, :), 'rows');        
        he = [];
        for j = 1:size(hep,1)
            m = labelMap.maskHash(hep(j,:));
            if any(m(:) & ~stencilMask(:))
                continue;
            end
            he = [he; hep(j,:);];
        end                        
        
        % assign class to all of them
        for j = 1:size(he,1)
            labelMap.setLabel(he(j,:), classID);
        end 

        i = i + 1;        
    end
    labelMap.save();
end