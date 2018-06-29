function runTrackerAllClass(isSeqDisplay, isNMS, detPath, resPath, seqPath, evalClassSet, threSet, nmsThre, trackerName)

createPath(resPath); % create the saving path of the tracking results
nameSeqs = findSeqList(seqPath); % find the sequence list
speed = 0;
numfrs = 0;

% evaluate each sequence
for idSeq = 1:length(nameSeqs)
    disp(['tracking the sequence ' num2str(idSeq) '/' num2str(length(nameSeqs)) '...']);
    % load detections and sequence
    det = load(fullfile(detPath, [nameSeqs{idSeq} '.txt']));
    sequence.dataset = dir(fullfile(seqPath, [nameSeqs{idSeq} '/*.jpg']));
    sequence.seqPath = fullfile(seqPath, nameSeqs{idSeq});
    sequence.seqName = nameSeqs{idSeq};
    img = imread(fullfile(seqPath, nameSeqs{idSeq}, sequence.dataset(1).name));
    [sequence.imgHeight, sequence.imgWidth, ~] = size(img);
    % nms processing
    detections = nmsProcess(det, isNMS, nmsThre);  
    % evaluate each object category
    allRes = cell(1, length(evalClassSet));
    for idClass = 1:length(evalClassSet)
        classID = getClassID(evalClassSet{idClass});
        idx = detections(:, 8) == classID & detections(:, 7) >= threSet(idClass);
        curdetections = detections(idx,:);
        if(size(curdetections,1)>=4) % at least 4 detections
            try
                % add the tracker path
                cd(['./trackers/' trackerName]);
                addpath(genpath('.'));
                % run the tracker
                [resClass, runTime] = run_tracker(sequence, curdetections);
                % save tracking result
                resClass(:,8) = classID;
                allRes{idClass} = resClass;
                speed = speed + runTime;                  
                % remove the toolbox path
                rmpath(genpath('.'));
                cd('../../');                 
            catch err
                % remove the toolbox path
                rmpath(genpath('./'));
                cd('../../');
                error('error in running the tracker!');
            end       
        end
    end
    % combine tracks of multiple object categories
    res = combineTrks(evalClassSet, allRes);
    % calculate the length of all the sequences
    numfrs = numfrs + length(sequence.dataset);
    % show the tracking results
    dlmwrite(fullfile(resPath, [nameSeqs{idSeq} '.txt']), res);
    % show the tracking results
    showResults(isSeqDisplay, res, sequence);
end

% calculate the speed
speed = numfrs/speed;
disp(['Tracking completed. The runing speed of ' trackerName ' tracker is ' num2str(roundn(speed,-2)) 'fps.']);
