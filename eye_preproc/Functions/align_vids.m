%% Align eyetracking data to videos
function align_vids(et_file, options)

    % Load video metadata
    vid_meta_file = sprintf('%s/vid_metadata.mat', options.align_dir);
    load(vid_meta_file, 'vid_fr', 'vid_T', 'vid_names', 'vid_nfr')

    % Read file order table
    file_order = readtable('./Organize/file_order.xlsx');

    % Get the file_parts
    [prep_dir, et_file] = fileparts(et_file);

    % Output file
    vid_len_file = sprintf('%s/%s', options.align_dir, strrep(et_file, '.tsv', '_rec_length.mat'));
    if exist(vid_len_file, 'file') ~= 0, return, end

    fprintf('Aligning %s ...\n', et_file)
    
    % Load the data
    % Metadata
    metadata = load_et_bids_metadata(prep_dir, strrep(et_file, '.tsv', '.json'));
    
    % Data
    et_data = load_et_bids_data(prep_dir, sprintf('%s.gz', et_file));
    
    % Time axis
    et_time = table2array(et_data(:, ismember(metadata.Columns, 'Time')));
    
    % Task start and end triggers
    trigger_task = find(table2array(et_data(:, ismember(metadata.Columns, 'Task_Start_End_Trigger'))));
    trigger_task_on = trigger_task(1);
    trigger_task_off = trigger_task(2);
    
    % Total time of recording
    time_eye = et_time(trigger_task_off) - et_time(trigger_task_on);
    
    %% Downsample
    % Find the corresponding video
    vid_rec = file_order.vid_name{cellfun(@(C) contains(et_file, C), file_order.bids_name)};
    idx_vid = ismember(vid_names, vid_rec);
    
    if sum(idx_vid) == 0 && ~contains(et_file, 'rest')
        return
    end
    
    % Cut data at triggers
    et_data = et_data(trigger_task_on+1:trigger_task_off, :);
    
    % Compute difference between the time of the recording and the video to adjust for delays
    if sum(idx_vid) == 0 
        metadata.TimeDifferenceEyetrackingVideo = time_eye - options.rest_time;
    else
        if contains(vid_names{idx_vid}, 'Monkey')
            metadata.TimeDifferenceEyetrackingVideo = time_eye - options.monkey_time;
        else
            metadata.TimeDifferenceEyetrackingVideo = time_eye - vid_T(idx_vid);
        end
    end
    
    % In many recordings of incapes the videoplayback is delayed
    if contains(et_file, 'inscapes') && metadata.TimeDifferenceEyetrackingVideo > options.time_diff_thresh
        offset = height(et_data) - (vid_T(idx_vid) * metadata.SamplingFrequency);
        et_data = et_data(offset+1:end, :); 
    end
    
    % Split eyetracking and event data
    idx_time = ismember(metadata.Columns, 'Time');
    et_time = table2array(et_data(:, idx_time));
    col_time = metadata.Columns(:, idx_time);
    
    idx_events = ismember(metadata.Columns, {'Fixations', 'Saccades', 'Blinks', 'fMRI_Volume_Trigger', 'Interpolated_Samples'});
    et_events = table2array(et_data(:, idx_events));
    col_events = metadata.Columns(:, idx_events);
    
    idx_data = cellfun(@(C) contains(C, {'Gaze', 'Pupil', 'Resolution'}), metadata.Columns);
    et_data = table2array(et_data(:, idx_data));
    col_data = metadata.Columns(:, idx_data);
    
    metadata.Columns = col_data;
    
    % Get downsampling factor 
    if sum(idx_vid) == 0 
        dsf = options.rest_fs / metadata.SamplingFrequency;
    else
        if contains(vid_names{idx_vid}, 'Monkey')
            dsf = (options.monkey_time/vid_T(idx_vid) * vid_nfr(idx_vid)) / length(et_data);
        else
            dsf = vid_nfr(idx_vid) / length(et_data);
        end
    end
    
    % Downsample
    if dsf*1e10 < 2^31
        et_data = resample(et_data - et_data(1,:), round(1e5*dsf), 1e5) + et_data(1,:);
    else
        et_data = resample(et_data - et_data(1,:), round(1e5*dsf), 1e4) + et_data(1,:);
    end
    
    % Add time
    et_data = [linspace(et_time(1), et_time(end), length(et_data))', et_data];
    
    metadata.Columns = [col_time, metadata.Columns];
    
    %% Update metadata
    metadata.SamplingFrequency = vid_fr(idx_vid);
    
    % Interpolate time of triggers
    et_events_rs = zeros(length(et_data), length(col_events));
    
    for e = 1:length(col_events)
    
        idx_event = ismember(col_events, col_events{e});
    
        events = et_events(:, idx_event);
    
        if contains(col_events{e}, 'Trigger')
            et_events_rs(round(interp1(et_data(:,1), 1:length(et_data), et_time(events == 1))), ...
                idx_event) = 1;
        else
    
            [labeled_events] = bwlabel(events);
            props = regionprops(labeled_events, 'Area', 'PixelList');
    
            event_onset = cellfun(@(C) min(C(:,2)), {props.PixelList});
            event_offset = cellfun(@(C) max(C(:,2)), {props.PixelList});
    
            event_rs = round(interp1(et_data(:,1), 1:length(et_data), et_time([event_onset', event_offset'])));
    
            for i = 1:size(event_rs,1)
                et_events_rs(event_rs(i,1):event_rs(i,2), idx_event) = 1;
            end
    
        end
    
    end
    
    % Combine data
    et_data = [et_data, et_events_rs];
    metadata.Columns = [metadata.Columns, col_events];
    
    %% Save the data
    
    % Edit label 
    eye_file_parts = strsplit(options.eye_file_label, '_');
    eye_file_parts(cellfun(@(C) isempty(C), eye_file_parts)) = [];
    
    out_file_label = sprintf('_%s_video_aligned_%s', eye_file_parts{1}, eye_file_parts{2});
    out_file = strrep(et_file, options.eye_file_label, out_file_label);
    
    % Remove description for removed columns
    metadata = rmfield(metadata, 'Task_Start_End_Trigger');
    metadata = rmfield(metadata, 'Timer_Trigger_1_second');
      
    % Metadata
    save_et_bids_metadata(metadata, prep_dir, strrep(out_file, '.tsv', '.json'))
    
    % Data
    save_et_bids_data(et_data, prep_dir, out_file)

    % Save the recording length
    save(vid_len_file, 'time_eye')

end