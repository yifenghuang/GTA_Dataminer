classdef LabelMap < matlab.mixin.Copyable
    
    properties
        hashMaps;
        fileClassIds;   % classes that are labeled per file
        colors;
        classes;
        labelClasses;
        c2id;    
        needsSave;
        dir;
        hash2Class;
        
        %% frame-specific
        file;        
        idMap;
        res2hash;        
    end
    
    methods(Access = private)
        function addHashes(self, resourceIdMap, lines)
            resourceIdMap = unique(uint64(resourceIdMap(:)));
            for i = 1:length(lines)
                split = strsplit(lines{i}, ',');
                resourceId = sscanf(split{1}, '%lu');
                if any(resourceIdMap == resourceId)
                    if self.res2hash.isKey(resourceId)
                        assert(strcmp(self.res2hash(resourceId),split{2}));
                    end
                    self.res2hash(resourceId) = split{2};
                end
            end
        end
    end
    
    methods
        function self = LabelMap(dir, file)
            self.dir = dir;

            %% load class names, ids, colors
            data = load('label.mat');
            self.colors = data.colors;
            self.classes = data.classes;
            self.labelClasses = data.labelClasses;
            self.c2id = containers.Map(self.classes, 1:length(self.classes));

            hash2ClassFile = 'hash2cid.mat';
            if ~exist(hash2ClassFile, 'file')
                self.hash2Class = containers.Map({'0.0.0'}, {self.c2id('sky')});
            else            
                data = load(hash2ClassFile, 'hk', 'hv');
                self.hash2Class = containers.Map(data.hk, data.hv);
            end
            
            %% load shortcuts
            shaderHashFile = fullfile('shaderHash2class.mat');
            if ~exist(shaderHashFile, 'file')
                self.hashMaps.shader = containers.Map('KeyType', 'char', 'ValueType', 'double');
            else            
                data = load(shaderHashFile, 'hk', 'hv');
                self.hashMaps.shader = containers.Map(data.hk, data.hv);
            end

            meshHashFile = fullfile('meshHash2class.mat');
            if ~exist(meshHashFile, 'file')
                self.hashMaps.mesh = containers.Map('KeyType', 'char', 'ValueType', 'double');
            else            
                data = load(meshHashFile, 'hk', 'hv');
                self.hashMaps.mesh = containers.Map(data.hk, data.hv);
            end

            texHashFile = fullfile('texHash2class.mat');
            if ~exist(texHashFile, 'file')
                self.hashMaps.tex = containers.Map('KeyType', 'char', 'ValueType', 'double');
            else            
                data = load(texHashFile, 'hk', 'hv');
                self.hashMaps.tex = containers.Map(data.hk, data.hv);
            end
            
            self.setFile(file);
            
            c = {'rider'};
            self.fileClassIds = zeros(length(c),1);
            for i = 1:length(c)
                self.fileClassIds(i) = self.c2id(c{i});
            end
            
            self.needsSave = false;
        end
        
        function setFile(self, file)
            self.file = file;
        end
        
        function loadFileResources(self)
            
            %% load resource ID map
            idFile = fullfile(self.dir, [self.file, '__id.mat']);            
            data = load(idFile);
            self.idMap = cat(3, data.texID, data.meshID, data.shaderID);
            
            %% load resource ID to hash for this frame
            res2hashFile = fullfile(self.dir, [self.file, '__res2hash.mat']);
            if ~exist(res2hashFile, 'file'),            
                texIdTranslateFile = fullfile(self.dir, [self.file, '__tex.txt']);            
                lines = readListFile(texIdTranslateFile);

                self.res2hash = containers.Map('KeyType', 'uint64', 'ValueType', 'char');
                self.addHashes(self.idMap(:,:,1)-1, lines); % bug in extraction code added 1 to texture id

                texIdTranslateFile = fullfile(self.dir, [self.file, '__mesh.txt']);            
                lines = readListFile(texIdTranslateFile);
                self.addHashes(self.idMap(:,:,2), lines);
                
                texIdTranslateFile = fullfile(self.dir, [self.file, '__shader.txt']);            
                lines = readListFile(texIdTranslateFile);
                self.addHashes(self.idMap(:,:,3), lines);
                
                % save cache
                hk = self.res2hash.keys;
                hv = self.res2hash.values;
                save(res2hashFile, 'hk', 'hv');
            else
                % read from cache
                data = load(res2hashFile, 'hk', 'hv');
                self.res2hash = containers.Map(data.hk, data.hv);                
            end  
            
            %% frame-specific annotations
            specialHashFile = fullfile(self.dir, [self.file, '__hash2cid.mat']);
            if exist(specialHashFile, 'file'),
                data2 = load(specialHashFile, 'hk', 'hv');
                if isempty(data2.hk),
                    self.hashMaps.file = containers.Map('KeyType', 'char', 'ValueType', 'double');
                else
                    self.hashMaps.file = containers.Map(data2.hk, data2.hv);
                end
            else
                self.hashMaps.file = containers.Map('KeyType', 'char', 'ValueType', 'double');
            end           
        end
        
        function uniqueResourceIDTuples = uniqueResourceIds(self)
            [height,width,~] = size(self.idMap);
            idVec = reshape(self.idMap, [height*width, 3]);
            uniqueResourceIDTuples = unique(idVec, 'rows');
        end
        
        function mask = maskHash(self, hash)
            mask = self.idMap(:,:,1) == hash(1) & self.idMap(:,:,2) == hash(2) & self.idMap(:,:,3) == hash(3);
        end
        
        function [texHash, meshHash, shaderHash] = resource2hashes(self, resourceId)
            %% translates resource ID tuple to hash tuple
            
            resourceId = uint64(resourceId);  
            texHash    = [];
            meshHash   = [];
            shaderHash = [];
            
            if self.res2hash.isKey(resourceId(1)-1)
                texHash = self.res2hash(resourceId(1)-1);            
                if self.res2hash.isKey(resourceId(2))
                    meshHash = self.res2hash(resourceId(2));
                    if self.res2hash.isKey(resourceId(3))
                        shaderHash = self.res2hash(resourceId(3));
                    end
                end
            end
        end
        
        function classID = getLabel(self, resourceId)                      
            classID = nan;                        
            [texHash, meshHash, shaderHash] = self.resource2hashes(resourceId); 
            if ~isempty(shaderHash)
                mtsHash = [texHash, '.', meshHash, '.', shaderHash];                          
                
                if self.hashMaps.file.isKey(mtsHash)
                    % frame-specific
                    classID = self.hashMaps.file(mtsHash);
                elseif self.hash2Class.isKey(mtsHash)
                    % global
                    classID = self.hash2Class(mtsHash);
                elseif self.hashMaps.tex.isKey(texHash)
                    % shortcut for texture
                    classID = self.hashMaps.tex(texHash);                    
                elseif self.hashMaps.mesh.isKey(meshHash)
                    % shortcut for mesh
                    classID = self.hashMaps.mesh(meshHash);
                elseif self.hashMaps.shader.isKey(shaderHash)
                    % shortcut for shader
                    classID = self.hashMaps.shader(shaderHash);     
                end                
                
            elseif all(resourceId == 0)
                % special case as sky is rendered earlier and gets 0,0,0
                classID = self.c2id('sky');
            end
        end
        
        function val = hasShortcutLabel(self, resourceId)
            %% checks if we have a shortcut, e.g. certain shader determines class
            
            val = false;                        
            [texHash, meshHash, shaderHash] = self.resource2hashes(resourceId); 
            if ~isempty(shaderHash)
                if self.hashMaps.tex.isKey(texHash) || ...
                   self.hashMaps.mesh.isKey(meshHash) || ...
                   self.hashMaps.shader.isKey(shaderHash)
                    val = true;
                end                
            elseif all(resourceId == 0)
                val = true;
            end
        end
        
        function hashes = getResourceIds(self,class)
            hash2res = containers.Map(self.res2hash.values, self.res2hash.keys);
            
            cid = self.c2id(class);
            %% collect all hashes that map to this class
            hv = self.hash2Class.values;
            m = [hv{:}] == cid;
            ids = find(m);
            numHashes = sum(m);
            hashes.all = zeros(numHashes, 3);
            hk = self.hash2Class.keys;
            k = 0;
            for i = 1:numHashes,   
                h1 = hk{ids(i)}(1:33);
                h2 = hk{ids(i)}(35:67);
                h3 = hk{ids(i)}(69:101);
                if hash2res.isKey(h1) && hash2res.isKey(h2) && hash2res.isKey(h3)
                    k = k+1;
                    hashes.all(k,:) = [hash2res(h1), hash2res(h2), hash2res(h3)];
                end
            end
            hashes.all = hashes.all(1:k,:);
            
            hv = self.hashMaps.tex.values;
            m = [hv{:}] == cid;
            ids = find(m);
            numHashes = sum(m);
            hashes.tex = zeros(numHashes, 1);
            hk = self.hashMaps.tex.keys;k = 0;
            for i = 1:numHashes, 
                if hash2res.isKey(hk{ids(i)})
                    k = k+1;
                    hashes.tex(k) = hash2res(hk{ids(i)});
                end
            end
            hashes.tex = hashes.tex(1:k);
            
            hv = self.hashMaps.mesh.values;
            m = [hv{:}] == cid;
            ids = find(m);
            numHashes = sum(m);
            hashes.mesh = zeros(numHashes, 1);
            hk = self.hashMaps.mesh.keys; k = 0;
            for i = 1:numHashes,
                if hash2res.isKey(hk{ids(i)})
                    k = k+1;
                    hashes.mesh(k) = hash2res(hk{ids(i)});
                end
            end
            hashes.mesh = hashes.mesh(1:k);
            
            hv = self.hashMaps.shader.values;
            m = [hv{:}] == cid;
            ids = find(m);
            numHashes = sum(m);
            hashes.shader = zeros(numHashes, 1);
            hk = self.hashMaps.shader.keys; k = 0;
            for i = 1:numHashes,
                if hash2res.isKey(hk{ids(i)})
                    k = k+1;
                    hashes.shader(k) = hash2res(hk{ids(i)});
                end
            end
            hashes.shader = hashes.shader(1:k);            
        end
        
        function setLabel(self, resourceId, cid)
            [h1, h2, h3] = self.resource2hashes(resourceId); 
            if ~isempty(h3),                        
                key = [h1, '.', h2, '.', h3];                   
                if any(cid == self.fileClassIds),
                    self.hashMaps.file(key) = cid;
                else
                    self.hash2Class(key) = cid;
                end
                self.needsSave = true;
            end
        end
        
        function save(self)
            
            %% save frame-specific mts to class labels
            hk = self.hashMaps.file.keys;
            hv = self.hashMaps.file.values;
            save(fullfile(self.dir, [self.file, '__hash2cid.mat']), 'hk', 'hv');
            
%             hk = self.hashMaps.all.keys;
%             hv = self.hashMaps.all.values;
%             save(fullfile('hash2class.mat'), 'hk', 'hv');
            
            hash2ClassFile = 'hash2cid.mat';
            hk = self.hash2Class.keys;
            hv = self.hash2Class.values;
            save(hash2ClassFile, 'hk', 'hv');
        end
    end
end