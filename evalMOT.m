clc;
clear all;close all;
warning off all;

% add toolboxes
addpath('display');
addpath('eval');
addpath(genpath('utils'));

datasetPath = '..\VisDrone2018-MOT-test-challenge\'; % dataset path
detPath = '..\FasterRCNN-MOT-detections\test-challenge\'; % detection input path
resPath = '..\test-challenge_MOT_results\'; % result path
isSeqDisplay = false; % flag to display the detections 
isNMS = true; % flag to conduct NMS
nmsThre = 0.6; % threshold of NMS

evalTask = 'Task4b'; % the evaluated task, i.e, Task4a without detection input and Task4b with detection input
trackerName = 'GOG'; % the tracker name
evalClassSet = {'car','bus','truck','pedestrian','van'}; % the set of evaluated object category
threSet = [0.5, 0.5, 0.5, 0.5, 0.5]; % the detection score threshold

gtPath = fullfile(datasetPath, 'annotations'); % annotation path
seqPath = fullfile(datasetPath, 'sequences'); % sequence path

%% run the tracker
runTrackerAllClass(isSeqDisplay, isNMS, detPath, resPath, seqPath, evalClassSet, threSet, nmsThre, trackerName);

%% evaluate the tracker
if(strcmp(evalTask, 'Task4a'))
    [ap, recall, precision] = evaluateTrackA(seqPath, resPath, gtPath, evalClassSet);
elseif(strcmp(evalTask, 'Task4b'))
    [tendallMets, allresult] = evaluateTrackB(seqPath, resPath, gtPath, evalClassSet);
end
