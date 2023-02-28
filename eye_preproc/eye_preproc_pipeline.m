%% Convert eyetracking data to BIDS format and compute quality control metrics

%% To-do 
% Download data
% Relative data paths
% Check data collection 

%% Packages 
% eyelink developers kit (for eyelink_edf2asc)

%% Set flags and variables for preprocessing
% Convert raw to BIDS (raw data is already provided in BIDS format, so this
% option probably will not be set true)
options.convert_to_bids = false;

% If raw data is in a single folder it should be organized in BIDS folder
% structure (only needed if the step above is true)
options.organize_raw = false;

% Plot quality control data
options.plot_qc = true;

% Download eyetracking data over the command line interface (tested only on Linux)
% Requires installation: https://duck.sh/
% If false download data manually and define options.raw_dir
% In addition, for alignment with EEG data, the preprocessed EEG data is
% necessary. Define the path in options.preproc_dir
options.download_data = false;

% Collect preprocessed data in a single folder (for easier data sharing)
options.collect_data = false;

% Preprocessing
% Interpolate blinks
options.blinkfilling = 'interp';

% Length of median filter in preprocessing [s]
options.filter_length_eye = 0.2;

% Buffer on each side of blinks to remove [ms]
options.buffer_ms = 100; 

% Alignment to videos
% Time in seconds monkey movies are presented
options.monkey_time = 300;

% Time in seconds for resting state condition 
options.rest_time = 600;

% Sampling rate for resting state data after downsampling
options.rest_fs = 30;

% Threshold for time difference between video and eyetracking data [s]
% Data with a larger difference will be corrected
options.time_diff_thresh = 0.1;

%% Options for data download
% Select subjects 'sub-01' to 'sub-22, or 'all' 
options.sub_select = {'all'};

% Select tasks specific task ('checker', 'checkeroff', 'dme_run-01', 'dme_run-02', 'monkey1_run-01', 'monkey1_run-02', 
% 'monkey2_run-01', 'monkey2_run-02', 'monkey5_run-01', 'monkey5_run-02', 'rest', 'tp_run-01', 'tp_run-02'), or 'all'
options.task_select = {'all'};

% Select modality 
options.mod_select = '_recording-eyetracking_physio';

% Define the path to the data
options.bucket_address = 's3:/fcp-indi/data/Projects/NATVIEW_EEGFMRI';

%% Define directories
% Code directory
options.code_dir = '/home/max/Documents/Code_colabs/NATVIEW_EEGFMRI/eye_preproc';

% Data directory
options.data_dir = '/media/max/RedPassport1/natview_eegfmri';

% If eyetracking data is present in a separate folder organize files in BIDS folder structure
options.eyelink_dir = '/home/max/Documents/Dropbox (City College)/EEG-fMRI_EyeLink';

% Directory to collect a copy of all data (if needed)
options.collect_dir = sprintf('%s/eye_preproc', options.data_dir);

% eeglab
options.eeglab_dir = '/home/max/Documents/Dropbox (City College)/Code/Master/eeglab2022.1';

% Raw eyetracking data
options.raw_dir = sprintf('%s/raw_data', options.data_dir);

% Preprocessed eyetracking data
options.preproc_dir = sprintf('%s/preproc_data', options.data_dir);

% Subfolder containing eyetracking data 
options.eye_dir = 'eeg';

% Subfolder containing EEG data
options.eeg_dir = 'eeg';

% Label for eyetracking files
options.eye_file_label = '_recording-eyetracking_physio';

% Results
options.res_dir = './Results/et_quality';
if exist(options.res_dir, 'dir') == 0, mkdir(options.res_dir), end

% Video alignment
options.align_dir = './Results/video_alignment';
if exist(options.align_dir, 'dir') == 0, mkdir(options.align_dir), end

% Figures
options.fig_dir = './Figures/et_quality';
if exist(options.fig_dir, 'dir') == 0, mkdir(options.fig_dir), end

options.fig_align_dir = './Figures/video_alignment';
if exist(options.fig_align_dir, 'dir') == 0, mkdir(options.fig_align_dir), end

% Video files
options.vid_dir = sprintf('%s/video_files', options.data_dir);

% Luminance files
options.lum_dir = sprintf('%s/vid_luminance', options.data_dir);

% Add functions and metadata
addpath(sprintf('%s/Functions', options.code_dir))
addpath(sprintf('%s/Organize', options.code_dir))

% Add eeglab
add_eeglab(options.eeglab_dir);

%% Compute video metadata
compute_vid_metadata(options)

%% Setup
% List subjects and sessions
[subs, sessions] = list_sub_ses(options.raw_dir);
   
for sub = 1:length(subs)
    for ses = 1:length(sessions{sub})

        % List all .edf files
        options.et_dir = sprintf('%s/%s/%s/%s', options.raw_dir, subs(sub).name, sessions{sub}{ses}, options.eye_dir);
        et_files = dir(options.et_dir);

        if options.convert_to_bids
            et_files = et_files(cellfun(@(C) contains(C, '.edf'), {et_files.name})); 
        else
            et_files = et_files(cellfun(@(C) contains(C, options.mod_select), {et_files.name})); 
            et_files = et_files(cellfun(@(C) contains(C, '.json'), {et_files.name}));
        end

        for f = 1:length(et_files)

            %% Convert the EDF files to BIDS format

            %% Convert the EDF files to .asc using the eyelink developers kit
            if options.convert_to_bids 
                edf_file = sprintf('%s/%s', options.et_dir, et_files(f).name);
                eyelink_edf2asc(edf_file)
            end

            %% Load the EEG triggers
            eeg_dir = sprintf('%s/%s/%s/%s', options.preproc_dir, subs(sub).name, sessions{sub}{ses}, options.eeg_dir);

            if options.convert_to_bids
                eeg_file = strrep(et_files(f).name, '_eyelink.edf', '_eeg.set');
            else
                eeg_file = strrep(et_files(f).name, sprintf('%s.json', options.eye_file_label), '_eeg.set');
            end

            eeg_file = sprintf('%s/%s', eeg_dir, eeg_file);
            eeg_trgs = read_eeg_trg(eeg_file, options);

            % Continue if EEG triggers are not available
            if isempty(eeg_trgs), continue, end

            %% Convert the asc file to BIDS format
            if options.convert_to_bids
                [et_data, metadata] = asc2bids(et_files(f).name, eeg_trgs, options);
            end

            %% Compute the quality control data
            % BIDS file name
            if options.convert_to_bids
                et_file_name = strrep(et_files(f).name, '_eyelink.edf', sprintf('%s.tsv.gz', options.eye_file_label));
            else
                et_file_name = strrep(et_files(f).name, '.json', '.tsv.gz');
            end

            qc_data(et_file_name, eeg_trgs, options)

            %% Double-check the files
            check_et(et_file_name, options);

            %% Preprocess the data
            % Define output file
            sub_prep_dir = sprintf('%s/%s/%s/%s', options.preproc_dir, subs(sub).name, sessions{sub}{ses}, options.eye_dir);
            et_prep_file = sprintf('%s/%s', sub_prep_dir, et_file_name);

            eye_prep(et_prep_file, options)

            %% Align the data to the videos
            align_vids(et_prep_file, options)

        end

    end
end

%% Quality control summary
if options.plot_qc    
    plot_qc(options)
end

%% Collect data in a single folder (for sharing)
if options.collect_data
    collect_data(options)
end