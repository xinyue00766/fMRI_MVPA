function mvpaRunSearchlightWithinSubjects(nameIdx,groupLabel1,groupLabel2,nameCont,runID,subjID,dirFeatures,dirHdr,dirSave,strSave)

disp('Running MVPA Searhlight Within Subjects');
disp(['Subject ID: ' subjID]);
disp(['Group 1: ' nameCont{groupLabel1}]);
disp(['Group 2: ' nameCont{groupLabel2}]);
disp(['Neighbor name: ' nameIdx])

%get GM indices
fidIdx = fopen(nameIdx, 'r'); 
len = fread(fidIdx, 1, 'int32');
idxGM = fread(fidIdx, len, 'int32');

% read features from files (this is generated by mvpaLoadFeatures)
features = cell(2, 1);
[features{1}, features{2}] = mvpaLoadFeatures(dirFeatures,subjID,groupLabel1,groupLabel2,runID); % load feature data 
nRun = length(runID);
casePerRun = size(features{1}, 1)/nRun;

% spotlight search
count = 0;
dim = [53 63 46]; % dimension of the searchlight image file
accuracy = zeros(1, dim(1)* dim(2)* dim(3));
groupTrain = [zeros(casePerRun*(nRun-1), 1); ones(casePerRun*(nRun-1),1)]; % binary labels for training data points
groupTest = [zeros(casePerRun,1); ones(casePerRun,1)]; % binary labels for test data points
while true
    [len, c] = fread(fidIdx, 1, 'int32');
    if c < 1
        break;
    end
    count = count + 1;
    
    % read in neighbor data
    centerId = fread(fidIdx, 1, 'int32');
    idx1 = fread(fidIdx, len, 'int32');
    
    % for normal analysis   
    F1 = features{1}(:, idx1);
    F2 = features{2}(:, idx1);
    
    % eliminate all 0 vectors in T map
    idx0 = find(sum(abs(F1)) > 0); 
    if length(idx0) ~= length(idx1)
        F1 = F1(:, idx0);
        F2 = F2(:, idx0);
    end
    
    % run searchlight
    if ~isempty(F1)
        cv = []; %0;
        classAll = [];
        
        % divide runs into training & test data set
        for i = 1 : nRun
            training1 = [];
            training2 = [];
            for j = 1 : nRun
                %divides data into runs (if casePerRun = 1, run j is the test data set)
                x1 = F1(j * casePerRun - casePerRun + 1 : j * casePerRun, :);
                x2 = F2(j * casePerRun - casePerRun + 1 : j * casePerRun, :);
                if i == j
                    test1 = x1; % class 0
                    test2 = x2; % class 1
                else
                    training1 = [training1; x1]; % class 0
                    training2 = [training2; x2]; % class 1
                end
            end
            
            %train the classifier using training samples. group is a vector of indices of 0 and 1
            %SVMStruct = svmtrain([training1; training2], groupTrain, 'Method', 'LS', 'BoxConstraint', 1, 'Autoscale', false);
            SVMStruct = svmtrain([training1; training2], groupTrain, 'Method', 'LS', 'BoxConstraint', 1);
            
            %get classification accuracy
            tAccuracy1 = svmclassify(SVMStruct, [test1; test2]); % returns the predicted class (group; 0 or 1)
            cv = [cv; tAccuracy1]; % classifier prediction
            classAll = [classAll; groupTest]; % the actual Y 
            %tAccuracy1 = AccuracyTest(SVMStruct, test1, test2);
            %cv = cv + tAccuracy1;
        end
        accuracy(idxGM(centerId)) = mean(cv==classAll); %cv / nRun;
    end
    
    if mod(count, 500) == 1
        disp(sprintf('%d voxels searched, max accuracy %f', count, max(accuracy)));
    end
end
fclose(fidIdx);

% generate accuracy map
saveName = fullfile(dirSave, sprintf('cv%s.img', strSave));
fid = fopen(saveName, 'w');
fwrite(fid, accuracy, 'float32');
fclose(fid);

% copy header file
system(['copy ' dirHdr ' ' saveName(1:end - 4) '.hdr']);

