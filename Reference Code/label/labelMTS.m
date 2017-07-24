function labelMTS(dir, frame)
%% GUI for labeling images.
%  INPUT
%  dir      directory containing
%            <frame>__final.png      rgb image
%            <frame>__mts.mat        id buffers stored as 'texID', 'meshID',
%                                    'shaderID'
%  frame    frame prefix for finding rgb image and mts file

    %% load image and MTS
    finalFile = fullfile(dir, [frame, '__final.png']);
    if ~exist(finalFile, 'file')
        fprintf('Could not find %s\n', finalFile);
        return;
    end
    
    idFile    = fullfile(dir, [frame, '__id.mat']);
    if ~exist(idFile, 'file')
        fprintf('Could not find %s\n', idFile);
        return;
    end
    
    img  = im2double(imread(finalFile));
    data = load(idFile, 'texID', 'meshID', 'shaderID');
    mts  = cat(3, data.texID, data.meshID, data.shaderID);
    
    [height, width] = size(data.texID);
    [uniqueMTS, ~, pos2uniqueMTS] = unique(reshape(mts, [height*width, 3]), 'rows');
    
    if size(img, 1) ~= height
        img = imresize(img, [height,width]);
    end
    
    %% load labelmap
    labelMap = LabelMap(dir, frame);
    labelMap.loadFileResources();
    
    %% create GUI
    f = figure('Visible', 'on', 'Position', [10, 10, 1593, 870]);
    handles.dispname = uicontrol('Style','text','String','',...
           'Position',[700,810,100,20]);
    handles.imaxes = axes('Parent', f, 'Units', 'pixels', 'Position', [100, 0, 1493, 840]);    
    
    %% make overlay from previously labeled MTS
    o1 = zeros(height,width);
    o2 = zeros(height,width);
    o3 = zeros(height,width);
    for i = 1:size(uniqueMTS, 1)     
        classID = labelMap.getLabel(uniqueMTS(i,:));
        if ~isnan(classID)      
            mtsMask = pos2uniqueMTS==i;
            o1(mtsMask) = labelMap.colors(classID,1)./255;
            o2(mtsMask) = labelMap.colors(classID,2)./255;
            o3(mtsMask) = labelMap.colors(classID,3)./255;
        end
    end
    overlay = cat(3, o1, o2, o3);
    
    %% display it
    imshow(0.6*img + 0.6*overlay, 'Parent', handles.imaxes);
    set(handles.dispname,'String', labelMap.classes{1});
    
    %% create buttons for classes
    handles.buttons = cell(length(labelMap.labelClasses),1);
    for c = 1:length(labelMap.labelClasses)
        handles.buttons{c} = uicontrol('Style','pushbutton','String',labelMap.classes{labelMap.labelClasses(c)},...
            'pos', [0, (c-1)*30, 100, 30], 'parent',f,'Callback', @(a,b)(setCurrentClass(a,b,labelMap.classes{labelMap.labelClasses(c)})));
    end
        
    handles.select = uicontrol('Style','pushbutton','String', 'STOP',...
            'pos', [0, (length(labelMap.labelClasses))*30, 100, 30], 'parent',f,'Callback', @stop);
    
    movegui(f, 'center');
    guidata(f, handles);
    
    currentClass = 1;   
    
    dontStop = true;
    
    while(dontStop)    
        try
            [x,y] = ginput(1);
            x = round(x);
            y = round(y);
        catch
            break;
        end
        
        if 0 >= x 
            continue;
        end
        
        currentMTS = mts(y,x,:);        
        labelMap.setLabel(currentMTS, currentClass);
        
        mtsMask = labelMap.maskHash(currentMTS);
        o1(mtsMask) = labelMap.colors(currentClass,1)./255;
        o2(mtsMask) = labelMap.colors(currentClass,2)./255;
        o3(mtsMask) = labelMap.colors(currentClass,3)./255;
        overlay = cat(3, o1, o2, o3);
    
        imshow(0.6*img + 0.6*overlay, 'Parent', handles.imaxes);        
    end  
    
    function setCurrentClass(source,eventdata, class)
        currentClass = labelMap.c2id(class); 
        set(handles.dispname,'String',class);
    end    

    function stop(source, eventdata)
        labelMap.save();
        dontStop = false;
        close(f);
    end
end