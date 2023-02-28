%% Compute quality control data
function qc_data(et_file, eeg_trgs, options)

    % Define output file names
    sample_diff_file = sprintf('%s/%s', options.res_dir, strrep(et_file, '.tsv.gz', '_et_sample_diff.mat'));
    missing_samples_file = sprintf('%s/%s', options.res_dir, strrep(et_file, '.tsv.gz', '_percent_missing_samples.mat'));
    out_samples_file = sprintf('%s/%s', options.res_dir, strrep(et_file, '.tsv.gz', '_percent_out_samples.mat'));

    % Skip if all output files exist
    if exist(sample_diff_file, 'file') ~= 0 || exist(missing_samples_file, 'file') ~= 0 || exist(out_samples_file, 'file') ~= 0
        return
    end

    % Jason file for metadata
    metadata = load_et_bids_metadata(options.et_dir, strrep(et_file, '.tsv.gz', '.json'));
    
    % Data file 
    et_data = table2array(load_et_bids_data(options.et_dir, et_file));

    % Triggers
    time = et_data(:, ismember(metadata.Columns, 'Time'));
    start_end_trg = time(et_data(:, ismember(metadata.Columns, 'Task_Start_End_Trigger')) == 1);
    
    et_trgs.time_on = start_end_trg(1);
    et_trgs.time_off = start_end_trg(2);
    
    %% Check time alignment
    % Get time of task
    eeg_time_task = (eeg_trgs.eeg_trg_off - eeg_trgs.eeg_trg_on) / eeg_trgs.eeg_srate;
    et_time_task = et_trgs.time_off - et_trgs.time_on;  
    
    % Time difference
    if ~isempty(eeg_time_task) && ~isempty(et_time_task)
        eeg_et_sample_diff = (eeg_time_task - et_time_task) * eeg_trgs.eeg_srate;
    else
        eeg_et_sample_diff = [];
    end
    
    %% Quality metrics
    % Samples without data
    if options.convert_to_bids
        percent_missing_samples = sum(isnan(et_data(:,ismember(metadata.Columns, 'Gaze_X')))) / length(et_data);
    else
        percent_missing_samples = sum(et_data(:,ismember(metadata.Columns, 'Interpolated_Samples'))) / length(et_data);
    end
    
    % Samples with gaze position outside of the screen
    out_of_screen_x = sum(et_data(:,ismember(metadata.Columns, 'Gaze_X')) < metadata.DisplayCoordinates(2) | ...
        et_data(:,ismember(metadata.Columns, 'Gaze_X')) > metadata.DisplayCoordinates(4));
    out_of_screen_y = sum(et_data(:,ismember(metadata.Columns, 'Gaze_Y')) < metadata.DisplayCoordinates(1) | ...
        et_data(:,ismember(metadata.Columns, 'Gaze_Y')) > metadata.DisplayCoordinates(3));
    
    percent_out_samples = (out_of_screen_x + out_of_screen_y) / length(et_data);
    
    % Save the quality control data
    save(sample_diff_file, 'eeg_et_sample_diff', 'et_file')
    save(missing_samples_file, 'percent_missing_samples', 'et_file')
    save(out_samples_file, 'percent_out_samples', 'et_file')

end