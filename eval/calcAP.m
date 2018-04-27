function [aps, recall, precision] = calcAP(track_confs, track_labels, tp_cell, fp_cell, num_vids, num_track_per_class, num_track_thr, defaultTrackThr, evalClassSet)

fprintf('evaluating VisDrone2018 Task4a :: computing ap\n');
recall = cell(1,num_track_thr);
precision = cell(1,num_track_thr);
aps = cell(1,num_track_thr);
confs = [track_confs{:}];
[~, ind] = sort(confs,'descend');
for o = 1:num_track_thr
    tp_all = [];
    fp_all = [];
    for v = 1:num_vids
        tp_all = [tp_all(:); tp_cell{v}{o}'];
        fp_all = [fp_all(:); fp_cell{v}{o}'];
    end
    
    tp_all = tp_all(ind)';
    fp_all = fp_all(ind)';
    obj_labels = [track_labels{:}];
    obj_labels = obj_labels(ind);
    
    for c = 1:10
        % compute precision/recall
        if(num_track_per_class(c))
            tp = cumsum(tp_all(obj_labels==c));
            fp = cumsum(fp_all(obj_labels==c));
            recall{o}{c} = (tp/num_track_per_class(c))';
            precision{o}{c} = (tp./(fp+tp))';
            aps{o}(c) = VOCap(recall{o}{c},precision{o}{c})*100;
        end
    end
end

fprintf('-------------\n');
fprintf('Category\tAP\n');
if(length(aps) ~= length(defaultTrackThr))
    error('Inconsistent number of APs.');
end
ap = aps{1};
for t = 2:length(aps)
    ap = ap + aps{t};
end
ap = ap ./ length(aps);
eval_ap_ind = [];
for i = 1:length(evalClassSet)
    s = evalClassSet{i};
    ind = getClassID(evalClassSet{i});
    if(length(s) < 5)
        fprintf('%s\t\t\t%0.2f%%\n',s,ap(ind));
    elseif(length(s) < 8)
        fprintf('%s\t\t%0.2f%%\n',s,ap(ind));        
    else
        fprintf('%s\t%0.2f%%\n',s,ap(ind));
    end
    eval_ap_ind = cat(1, eval_ap_ind, ind);
end
fprintf(' - - - - - - - - \n');
fprintf('Mean AP:\t\t %0.2f%%\n',mean(ap(eval_ap_ind)));
fprintf(' = = = = = = = = \n');
for t = 1:length(aps)
    ap = aps{t};
    fprintf('Mean AP@%0.2f:\t %0.2f%%\n',defaultTrackThr(t),mean(ap(eval_ap_ind)));
end
fprintf(' = = = = = = = = \n');