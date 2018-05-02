function [tendallMets, allresult] = evaluateTrackB(seqPath, resPath, gtPath, evalClassSet)
% Input:
% - seqPath
% Sequence path is the path of all sequences to be evaluated in a single run.
%
% - resPath
% The folder containing the tracking results. Each one should be saved in a
% separate .txt file with the name of the respective sequence
%
% - gtPath
% The folder containing the groundtruth files.
%
% - evalClassSet
% The set of evaluated object category
%
% Output:
% - tendallMets
% Scores for each sequence on the evaluated object category
% 
% - allresult
% Aggregate score over all sequences

% benchmark specific properties
world = 0;

% read sequence list
allSequences = findSeqList(seqPath); % find the sequence list

fprintf('Sequences: \n');
disp(allSequences');
numSeqs = length(allSequences);
gtMat = cell(1, numSeqs);
resMat = cell(1, numSeqs);

%% evaluate sequences individually
allMets = [];
tendallMets = [];
allresult = [];

for ind = 1:numSeqs
    % parse groundtruth
    sequenceName = char(allSequences(ind));
    sequenceFolder = fullfile(seqPath, sequenceName, filesep);
    dataset = dir(fullfile(sequenceFolder, '*.jpg'));
    img = imread(fullfile(sequenceFolder, dataset(1).name));
    [imgHeight, imgWidth, ~] = size(img);       
    fprintf('\t... %s\n',sequenceName);
    assert(isdir(sequenceFolder), 'Sequence folder %s missing.\n', sequenceFolder);
    gtFilename = fullfile(gtPath, [allSequences{ind} '.txt']);
    if(~exist(gtFilename, 'file'))
        error('No annotation files is provided for evaluation.');
    end
    gtdata = dlmread(gtFilename);
    % process groudtruth    
    clean_gtFilename = fullfile(gtPath, [allSequences{ind} '_clean.txt']);
    if(~exist(clean_gtFilename, 'file'))   
        gtdata = dropObjects(gtdata, gtdata, imgHeight, imgWidth);
        dlmwrite(clean_gtFilename, gtdata);
    else
        gtdata = dlmread(clean_gtFilename);
    end
    % break the groundtruth trajetory with multiple object categories
    gtdata = breakGts(gtdata);   
    gtMat{ind} = gtdata;
    % split the groundtruth for each object category
    gtsortdata = classSplit(gtdata);        
    
    % parse result
    resFilename = fullfile(resPath, [allSequences{ind} '.txt']);
    % read result file
    if(exist(resFilename,'file'))
        s = dir(resFilename);
        if(s.bytes ~= 0)
            resdata = dlmread(resFilename);
        else
            resdata = zeros(0,9);
        end
    else
        error('Invalid submission. Result file for sequence %s is missing or invalid\n', resFilename);
    end  
    % process result
    resdata = dropObjects(resdata, gtdata, imgHeight, imgWidth);
    resdata(resdata(:,1) > max(gtMat{ind}(:,1)),:) = []; % clip result to gtMaxFrame 
    resMat{ind} = resdata;
    % split the result for each object category    
    ressortdata = classSplit(resdata);
    % evaluate sequence
    tendMets = classEval(gtsortdata, ressortdata, allMets, ind, evalClassSet, sequenceName);
    tendallMets = [tendallMets,tendMets];
    tendmetsBenchmark = evaluateBenchmark(tendMets, world);
    fprintf(' ********************* Sequence %s Results *********************\n', sequenceName);
    printMetrics(tendmetsBenchmark);
    allresult = cat(1, allresult, tendmetsBenchmark);
end

%% calculate overall scores
metsBenchmark = evaluateBenchmark(tendallMets, world);
allresult = cat(1, allresult, metsBenchmark);
fprintf('\n');
fprintf(' ********************* Your VisDrone2018 Results *********************\n');
printMetrics(metsBenchmark);
fprintf('\n');

%% calculate overall scores for each object category
for k = 1:length(evalClassSet)
    className = evalClassSet{k};
    cateallMets = [];
    curInd = k:length(evalClassSet):length(tendallMets);
    for i = 1:length(curInd)
        cateallMets = [cateallMets, tendallMets(curInd(i))];
    end
    metsCategory = evaluateBenchmark(cateallMets, world);
    metsCategory(isnan(metsCategory)) = 0;
    fprintf('evaluating tracking %s:\n', className); 
    printMetrics(metsCategory); 
    fprintf('\n');
end
