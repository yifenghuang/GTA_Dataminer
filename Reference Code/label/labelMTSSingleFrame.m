function labelMTSSingleFrame(dir, frame)
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
    
    %% load class info
    data = load('label.mat');
    colors = data.colors./255;
    classes = data.classes;
    labelClasses = data.labelClasses;
    class2id = containers.Map(classes, 1:length(classes));
    
    %% load frame-specific annotations
    specialHashFile = fullfile(dir, [frame, '__hash2cid.mat']);
    if exist(specialHashFile, 'file')
        data2 = load(specialHashFile, 'hk', 'hv');
        hashMap2 = containers.Map(data2.hk, data2.hv);
    else
        hashMap2 = containers.Map({'0.0.0'}, {class2id('sky')});
    end
    
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
    
    imshow(0.5*img + 0.5*cat(3, o1, o2, o3), 'Parent', handles.imaxes);
    set(handles.dispname,'String',classes{1});
    
    handles.buttons = cell(length(labelClasses),1);
    for c = 1:length(labelClasses),
        handles.buttons{c} = uicontrol('Style','pushbutton','String',classes{labelClasses(c)},...
            'pos', [0, (c-1)*30, 100, 30], 'parent',f,'Callback', @(a,b)(setCurrentClass(a,b,classes{labelClasses(c)})));
    end
        
    handles.select = uicontrol('Style','pushbutton','String', 'STOP',...
            'pos', [0, (length(labelClasses))*30, 100, 30], 'parent',f,'Callback', @stop);
    
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
%             continue
        end
        
        if 0 > x 
            continue;
        end
        
        currentMTS = mts(y,x,:);        
        [h1, h2, h3] = labelMap.resource2hashes(currentMTS); 
        key = sprintf('%s.%s.%s', h1, h2, h3);
        hashMap2(key) = currentClass;
        
        mtsMask = mts(:,:,1) == currentMTS(1) & ...
                  mts(:,:,2) == currentMTS(2) & ...
                  mts(:,:,3) == currentMTS(3);        
        o1(mtsMask) = colors(currentClass,1);
        o2(mtsMask) = colors(currentClass,2);
        o3(mtsMask) = colors(currentClass,3);
       
        imshow(0.5*img + 0.5*cat(3, o1, o2, o3), 'Parent', handles.imaxes);        
    end   
    
    function setCurrentClass(source,eventdata, class)
        currentClass = class2id(class); 
        handles = guidata(source);
        set(handles.dispname,'String',class);
        guidata(source, handles);
    end    

    function stop(source, eventdata)
        hk = hashMap2.keys;
        hv = hashMap2.values;
        save(specialHashFile, 'hk', 'hv');   
        dontStop = false;
        close(f);
    end
end