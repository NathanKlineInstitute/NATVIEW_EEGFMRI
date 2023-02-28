
function [et_data, metadata] = asc2bids(et_file, eeg_trgs, options)

    % Define csv file for event data (last file created)
    tsv_name = strrep(et_file, '_eyelink.edf', sprintf('%s.tsv.gz', options.eye_file_label));
    data_file = sprintf('%s/%s', options.et_dir, tsv_name);
    
    % Just load the data if the file was already converted
    if exist(strrep(data_file, '.csv', '.tsv'), 'file') ~= 0
        metadata = load_et_bids_metadata(options.et_dir, strrep(tsv_name, '.tsv.gz', '.json'));
        et_data = table2array(load_et_bids_data(options.et_dir, tsv_name));
        return
    end
        
    %% PEER data is missing triggers (skip)
    if contains(et_file, 'PEER', 'IgnoreCase', true) 
        et_data = [];
        metadata = [];
        return
    end

    trigger_table = readtable('./Organize/trigger_ids.xlsx');  
    trigger_table = trigger_table(cellfun(@(C) contains(et_file, C, 'IgnoreCase', true), trigger_table.bids_name), :);

    %% Load ET data
    [et_data, metadata, et_events, et_trgs] = load_asc(options.et_dir, strrep(et_file, '.edf', '.asc'), trigger_table, eeg_trgs.eeg_trg_on_time);

    %% Interpolate fMRI triggers from EEG data
    % The timer trigers can be used to interpolate triggers from the EEG to the eyetracking data
    et_trgs.sample_fmri = round(interp1(eeg_trgs.eeg_trg_timer, et_trgs.sample_timer, eeg_trgs.eeg_trg_fmri))';
    et_trgs.sample_fmri(isnan(et_trgs.sample_fmri)) = [];
    et_trgs.time_fmri = et_data(et_trgs.sample_fmri, 1);

    %% Add events and triggers to data array
    fixations = create_event_vector(et_events, length(et_data), 'fix_sample');
    saccades = create_event_vector(et_events,  length(et_data), 'sac_sample');
    blinks = create_event_vector(et_events,  length(et_data), 'bl_sample');

    trg_on_off = zeros(length(et_data),1);
    trg_on_off(et_trgs.sample_on) = 1;
    trg_on_off(et_trgs.sample_off) = 1;

    trg_timer = zeros(length(et_data),1);
    trg_timer(et_trgs.sample_timer) = 1;

    trg_fmri = zeros(length(et_data),1);
    trg_fmri(et_trgs.sample_fmri) = 1;

    et_data = [et_data, fixations, saccades, blinks, trg_on_off, trg_timer, trg_fmri];

    metadata.Columns = [metadata.Columns, 'Fixations', 'Saccades', 'Blinks', ...
        'Task_Start_End_Trigger', 'Timer_Trigger_1_second', 'fMRI_Volume_Trigger'];

    %% Add descriptions of the colums 
    metadata.Time.Description = 'timestamps; time zero corresponds to the start of the task (movie, checkerboard, rest)';
    metadata.Time.Units = 'seconds';

    metadata.Gaze_X.Description = 'horizontal gaze position on the screen; Origin (0,0) at the top left)';
    metadata.Gaze_X.Units = 'pixels';

    metadata.Gaze_Y.Description = 'Vertical gaze position on the screen; Origin (0,0) at the top left)';
    metadata.Gaze_Y.Units = 'pixels';

    metadata.Pupil_Area.Description = 'pupil size reported as area (not calibrated)';
    metadata.Pupil_Area.Units = 'arbitrary units';

    metadata.Resolution_X.Description = 'instantaneous angular resolution in horizontal direction; defines the relationship between visual angle and gaze position';
    metadata.Resolution_X.Units = 'pixels per degreee visual angle';

    metadata.Resolution_Y.Description = 'instantaneous angular resolution in vertical direction; defines the relationship between visual angle and gaze position';
    metadata.Resolution_Y.Units = 'pixels per degreee visual angle';

    metadata.Fixations.Description = '1 indicates a fixation';

    metadata.Saccades.Description = '1 indicates a saccade';

    metadata.Blinks.Description = '1 indicates a blink';

    metadata.Task_Start_End_Trigger.Description = '1 indicates the start and end of the task, respectively; sent by the stimulus PC';

    metadata.Timer_Trigger_1_second.Description = '1 indicates time of a trigger sent every second by the stimulus PC';

    metadata.fMRI_Volume_Trigger.Description = '1 indicates time of a trigger sent by the fMRI scanner at the start of a volume';

    %% Write the eyetracking data in BIDS format
    % Jason file for metadata
    save_et_bids_metadata(metadata, options.et_dir, strrep(et_file, '_eyelink.edf', sprintf('%s.json', options.eye_file_label)))
    
    % Data file 
    save_et_bids_data(et_data, options.et_dir, strrep(et_file, '_eyelink.edf', sprintf('%s.tsv', options.eye_file_label)))
    
end