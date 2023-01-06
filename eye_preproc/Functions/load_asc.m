%% Load the eyetracking asc file into matlab
function [et_data, metadata, events, triggers] = load_asc(file_dir, file_name, trigger_table, eeg_start_time)

	% Define options for data import
	opts = detectImportOptions(sprintf('%s/%s', file_dir, file_name), 'FileType', 'text');
	opts.DataLines = [1, Inf];
	opts.VariableTypes = repmat("string", 1, length(opts.VariableTypes));

    % Load the data from the .asc file
	data_table = readtable(sprintf('%s/%s', file_dir, file_name), opts);

	% Time in ms
	time = str2double(table2array(data_table(:,1)));

    % Gaze position and pupil
	x = str2double(table2array(data_table(:,2)));
	y = str2double(table2array(data_table(:,3)));
	pupil = str2double(table2array(data_table(:,4)));

    % Resolution 
    res_x = str2double(table2array(data_table(:,5)));
    res_y = str2double(table2array(data_table(:,6)));

	% Remove messages
	idx_nan = isnan(time);

	x(idx_nan) = [];
	y(idx_nan) = [];
	pupil(idx_nan) = [];
    res_x(idx_nan) = [];
    res_y(idx_nan) = [];
	time(idx_nan) = [];

    %% Saccades, Fixations, Blinks
    fixations = char(table2array(data_table(cellfun(@(C) contains(C, 'EFIX'), num2cell(table2array(data_table(:,1)))), [1,2])));
    events.fix_time = cellfun(@(C) str2double(C(regexp(C, '\d'))), squeeze(num2cell(fixations, 2)));
    events.fix_sample = round(interp1(time, 1:length(time), events.fix_time));
    
    saccades = char(table2array(data_table(cellfun(@(C) contains(C, 'ESACC'), num2cell(table2array(data_table(:,1)))), [1,2])));
    events.sac_time = cellfun(@(C) str2double(C(regexp(C, '\d'))), squeeze(num2cell(saccades, 2)));
    events.sac_sample = round(interp1(time, 1:length(time), events.sac_time));
    
    blinks = char(table2array(data_table(cellfun(@(C) contains(C, 'EBLINK'), num2cell(table2array(data_table(:,1)))), [1,2])));
    events.bl_time = cellfun(@(C) str2double(C(regexp(C, '\d'))), squeeze(num2cell(blinks, 2)));
    events.bl_sample = round(interp1(time, 1:length(time), events.bl_time));

	%% Read the triggers
	messages = data_table(strcmp(table2array(data_table(:,1)), 'MSG'), :);

    %% Eyetracking triggers
    idx_et = cellfun(@(C) contains('et', C), trigger_table.data_type); 

    [triggers.time_on, triggers.sample_on] = extract_triggers(messages, time, trigger_table.task_start{idx_et});
    [triggers.time_off, triggers.sample_off] = extract_triggers(messages, time, trigger_table.task_end{idx_et});
    [triggers.time_timer, triggers.sample_timer] = extract_triggers(messages, time, trigger_table.timer_1{idx_et}, trigger_table.timer_1{idx_et});

    %% Align the data
    time = time/1e3;

    % Align EEG and fMRI
    time_offset = time(triggers.sample_on) - eeg_start_time;
    
    % Set the task start to time zero
    time_start = triggers.time_on/1e3;

    % Adjust time of events
    events.fix_time = events.fix_time/1e3;
    events.sac_time = events.sac_time/1e3;
    events.bl_time = events.bl_time/1e3;

    events.fix_time = events.fix_time - time_start;
    events.sac_time = events.sac_time - time_start;
    events.bl_time = events.bl_time - time_start;

    % Adjust time of triggers
    triggers.time_on = triggers.time_on/1e3;
    triggers.time_off = triggers.time_off/1e3;
    triggers.time_timer = triggers.time_timer/1e3;

    triggers.time_on =  triggers.time_on - time_start;
    triggers.time_off =  triggers.time_off - time_start;
    triggers.time_timer = triggers.time_timer - time_start;

    %% Collect metadata 
    % Sampling frequency
    metadata.SamplingFrequency = str2double(table2array(data_table(strcmp(table2array(data_table(:,5)), 'RATE'), 6)));
    
    if diff(metadata.SamplingFrequency) ~= 0 
        error('Sampling frequency from left/right eye inconsistent')
    else
        metadata.SamplingFrequency = mean(metadata.SamplingFrequency);
    end

    % Start time in relation to EEG
    metadata.StartTime = round(time(1) - time_offset, 4);

    % Organization of data table
    metadata.Columns = {'Time', 'Gaze_X', 'Gaze_Y', 'Pupil_Area', 'Resolution_X', 'Resolution_Y'};
    
    % Device information
    metadata.Manufacturer = 'SR Research';
    
    model_pattern = 'VERSION: ';
    model_str = char(table2array(data_table(cellfun(@(C) contains(C, model_pattern), num2cell(table2array(data_table(:,1)))), 1)));
    metadata.ManufacturersModelName = model_str(regexp(model_str, model_pattern) + length(model_pattern) : end);
    
    source_pattern = 'SOURCE: ';
    idx_source = find(cellfun(@(C) contains(C, source_pattern), num2cell(table2array(data_table(:,1)))));
    source_str = char(table2array(data_table(idx_source+1, 1)));
    metadata.SoftwareVersions = source_str(regexp(source_str, '** ') + length('** ') : end);
    
    serial_pattern = 'SERIAL NUMBER: ';
    serial_str = char(table2array(data_table(cellfun(@(C) contains(C, serial_pattern), num2cell(table2array(data_table(:,1)))), 1)));
    metadata.DeviceSerialNumber = serial_str(regexp(serial_str, serial_pattern) + length(serial_pattern) : end);

    display_pattern = 'DISPLAY_COORDS';
    display_str = char(table2array(data_table(cellfun(@(C) contains(C, display_pattern), num2cell(table2array(data_table(:,2)))), 2)));
    display_str = display_str(regexp(display_str, display_pattern) + length(display_pattern) : end);

    metadata.DisplayCoordinates = cellfun(@(C) str2double(C), strsplit(display_str, ' '));
    metadata.DisplayCoordinates(isnan(metadata.DisplayCoordinates)) = [];

    %% Set start of time axis to zero
    time = time - time_start;

    %% Collect data
    et_data = [time, x, y, pupil, res_x, res_y];

end
