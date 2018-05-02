function [aps, recall, precision] = evaluateTrackA(seqPath, resPath, gtPath, evalClassSet)

fullClassSet = {'ignored','pedestrian','person','bicycle','car','van','truck','tricycle','awning-tricyle','bus','motor', 'others'};

defaultIOUthr = 0.5;
pixelTolerance = 10;
defaultTrackThr = [0.25, 0.50, 0.75];

allSequences = findSeqList(seqPath); % find the sequence list
num_vids = length(allSequences);

gts = cell(1,num_vids);
gt_track_labels = cell(1,num_vids);
gt_track_bboxes = cell(1,num_vids);
gt_track_thr = cell(1,num_vids);
gt_track_img_ids = cell(1,num_vids);
gt_track_generated = cell(1,num_vids);
num_track_per_class = zeros(1,10);

fprintf('evaluating VisDrone2018 Task4a :: loading groundtruth\n');
for v = 1:num_vids
    sequenceName = char(allSequences(v));
    sequenceFolder = fullfile(seqPath, sequenceName, filesep);
    img_ids = dir(fullfile(sequenceFolder, '*.jpg'));
    num_imgs = length(img_ids);
    img = imread(fullfile(sequenceFolder, img_ids(1).name));
    [imgHeight, imgWidth, ~] = size(img);         
    % parse groudtruh
    gtFilename = fullfile(gtPath, [allSequences{v} '.txt']);
    if(~exist(gtFilename, 'file'))
        error('No annotation files is provided for evaluation.');
    end    
    clean_gtFilename = fullfile(gtPath, [allSequences{v} '_clean.txt']);
    if(~exist(clean_gtFilename, 'file'))   
        rec = load(gtFilename);
        rec = dropObjects(rec, rec, imgHeight, imgWidth);
        % break the groundtruth trajetory with multiple object categories
        rec = breakGts(rec);           
        dlmwrite(clean_gtFilename, rec);
    else
        rec = load(clean_gtFilename);
    end
    gts{v} = rec;
    
    tracks = [];
    num_tracks = 0;
    recs = cell(1,num_imgs);

    for i = 1:num_imgs
        idx = rec(:,1) == i;
        currec = rec(idx, :);
        recs{i} = currec;
        
        for j = 1:size(currec, 1)
            trackid = currec(j,2);
            c = currec(j,8);
            if(isempty(find(tracks == trackid, 1)))
                num_tracks = num_tracks + 1;
                tracks = cat(1, tracks, trackid);
                num_track_per_class(c) = num_track_per_class(c) + 1;
            end
        end
        if(num_tracks == 0)
            continue;
        end
    end
        
    gt_track_labels{v} = ones(1,num_tracks) * -1;
    gt_track_bboxes{v} = cell(1,num_tracks);
    gt_track_thr{v} = cell(1,num_tracks);
    gt_track_img_ids{v} = cell(1,num_tracks);
    gt_track_generated{v} = cell(1,num_tracks);
    count = 0;
    for i = 1:num_imgs
        count = count + 1;
        currec = recs{count};
        for j = 1:size(currec, 1)
            trackid = currec(j,2);
            c = currec(j,8);
            k = find(tracks == trackid);
            gt_track_img_ids{v}{k}(end+1) = i;
            if(gt_track_labels{v}(k) == -1)
                gt_track_labels{v}(k) = c;
            else
                if(gt_track_labels{v}(k) ~= c)
                    error('Find inconsistent label in a track!');
                end
            end
            bb = [currec(j,3), currec(j,4), currec(j,5)+currec(j,3)-1, currec(j,6)+currec(j,4)-1];
            gt_track_bboxes{v}{k}(:,end+1) = bb;
            gt_w = bb(4)-bb(2)+1;
            gt_h = bb(3)-bb(1)+1;
            thr = (gt_w*gt_h)/((gt_w+pixelTolerance)*(gt_h+pixelTolerance));
            gt_track_thr{v}{k}(end+1) = min(defaultIOUthr,thr);
        end
    end
end

fprintf('evaluating VisDrone2018 Task4a :: loading predictions\n');
track_img_ids = cell(1,num_vids);
track_labels = cell(1,num_vids);
track_confs = cell(1,num_vids);
track_bboxes = cell(1,num_vids);
for v = 1:num_vids
    % retrieve results for current video.
    resFilename = fullfile(resPath, [allSequences{v} '.txt']);
    resdata = dlmread(resFilename);
    resdata = dropObjects(resdata, gts{v}, imgHeight, imgWidth);

    vid_img_ids = resdata(:,1);
    vid_obj_labels = resdata(:,8);
    vid_track_ids = resdata(:,2);
    vid_obj_confs = resdata(:,7);
    vid_obj_bboxes = [resdata(:,3), resdata(:,4), resdata(:,5)+resdata(:,3)-1, resdata(:,6)+resdata(:,4)-1]';

    % get result for each tracklet in a video.
    track_ids = unique(vid_track_ids);
    num_tracks = length(track_ids);
    track_img_ids{v} = cell(1,num_tracks);
    track_labels{v} = ones(1,num_tracks) * -1;
    track_confs{v} = zeros(1,num_tracks);
    track_bboxes{v} = cell(1,num_tracks);
    count = 0;
    for k = track_ids'
        ind = vid_track_ids == k;
        count = count + 1;
        track_img_ids{v}{count} = vid_img_ids(ind);
        track_label = unique(vid_obj_labels(ind));
        if(numel(track_label) > 1)
            error('Find multiple labels in a tracklet.');
        end        
        track_labels{v}(count) = track_label;
        % use the mean score as a score for a tracklet.
        track_confs{v}(count) = mean(vid_obj_confs(ind));
        track_bboxes{v}{count} = vid_obj_bboxes(:,ind);
    end
end

for v = 1:num_vids
    [track_confs{v}, ind] = sort(track_confs{v},'descend');
    track_img_ids{v} = track_img_ids{v}(ind);
    track_labels{v} = track_labels{v}(ind);
    track_bboxes{v} = track_bboxes{v}(:,ind);
end
tp_cell = cell(1,num_vids);
fp_cell = cell(1,num_vids);

fprintf('evaluating VisDrone2018 Task4a :: accumulating\n');
num_track_thr = length(defaultTrackThr);
% iterate over videos
for v = 1:num_vids    
    num_tracks = length(track_labels{v});
    num_gt_tracks = length(gt_track_labels{v});

    tp = cell(1,num_track_thr);
    fp = cell(1,num_track_thr);
    gt_detected = cell(1,num_track_thr);
    for o = 1:num_track_thr
        tp{o} = zeros(1,num_tracks);
        fp{o} = zeros(1,num_tracks);
        gt_detected{o} = zeros(1,num_gt_tracks);
    end

    for m = 1:num_tracks
        img_ids = track_img_ids{v}{m};
        label = track_labels{v}(m);
        bboxes = track_bboxes{v}{m};
        num_obj = length(img_ids);

        ovmax = ones(1,num_track_thr) * -inf;
        kmax = ones(1,num_track_thr) * -1;
        for n = 1:num_gt_tracks
            gt_label = gt_track_labels{v}(n);
            if(label ~= gt_label)
                continue;
            end
            gt_img_ids = gt_track_img_ids{v}{n};
            gt_bboxes = gt_track_bboxes{v}{n};
            gt_thr = gt_track_thr{v}{n};

            num_matched = 0;
            num_total = length(union(img_ids, gt_img_ids));
            for j = 1:num_obj
                id = img_ids(j);
                k = find(gt_img_ids == id);
                if(isempty(k) || ~ismember(fullClassSet{label+1}, evalClassSet))
                    continue; % just ignore this detection if it does not belong to the evaluated object category
                end
                bb = bboxes(:,j);
                bbgt = gt_bboxes(:,k);
                bi = [max(bb(1),bbgt(1)) ; max(bb(2),bbgt(2)) ; min(bb(3),bbgt(3)) ; min(bb(4),bbgt(4))];
                iw = bi(3)-bi(1)+1;
                ih = bi(4)-bi(2)+1;
                if(iw>0 && ih>0)
                    % compute overlap as area of intersection / area of union
                    ua=(bb(3)-bb(1)+1)*(bb(4)-bb(2)+1)+(bbgt(3)-bbgt(1)+1)*(bbgt(4)-bbgt(2)+1)-iw*ih;
                    % makes sure that this object is detected according to its individual threshold
                    ov = iw*ih/ua;
                    if(ov >= gt_thr(k))
                        num_matched = num_matched + 1;
                    end
                end
            end
            ov = num_matched / num_total;
            for o = 1:num_track_thr
                if(gt_detected{o}(n))
                    continue;
                end
                if(ov >= defaultTrackThr(o) && ov > ovmax(o))
                    ovmax(o) = ov;
                    kmax(o) = n;
                end
            end
        end
        for o = 1:num_track_thr
            if(kmax(o) > 0)
                tp{o}(m) = 1;
                gt_detected{o}(kmax(o)) = 1;
            else
                fp{o}(m) = 1;
            end
        end
    end
    % put back into global vector
    tp_cell{v} = tp;
    fp_cell{v} = fp;
end

% calculate APs
[aps, recall, precision] = calcAP(track_confs, track_labels, tp_cell, fp_cell, num_vids, num_track_per_class, num_track_thr, defaultTrackThr, evalClassSet);
