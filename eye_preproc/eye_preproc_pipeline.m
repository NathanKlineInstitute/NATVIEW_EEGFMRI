%% Convert eyetracking data to BIDS format and compute quality control metrics

%% Set flags and variables for preprocessing
% If raw data is in a single folder it should be organized in BIDS folder structure
options.organize_raw = true;

% Plot quality control data
options.plot_qc = false;

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
options.eye_dir = 'func';

% Subfolder containing EEG data
options.eeg_dir = 'eeg';

% Label for eyetracking files
options.eye_file_label = '_eyetracking_physio';

% Results
options.res_dir = sprintf('%s/Results/et_quality', options.code_dir);
if exist(options.res_dir, 'dir') == 0, mkdir(options.res_dir), end

% Figures
options.fig_dir = sprintf('%s/Figures/et_quality', options.code_dir);
if exist(options.fig_dir, 'dir') == 0, mkdir(options.fig_dir), end

% Video files
options.vid_dir = sprintf('%s/video_files', options.data_dir);

% Luminance files
options.lum_dir = sprintf('%s/vid_luminance', options.data_dir);

% Add functions and metadata
addpath(sprintf('%s/Functions', options.code_dir))
addpath(sprintf('%s/Organize', options.code_dir))

% Add eeglab
add_eeglab(options.eeglab_dir);

%% Organize raw data
if options.organize_raw
    organize_raw_data(options)
end

%% Convert eyelink data to BIDS format and collect quality control data
eyelink2bids(options)

%% Preprocess the eyetracking data
eye_prep(options)

%% Align eyetracking data to videos
align_eye_videos(options)

%% Collect data in a single folder (for sharing)
if options.collect_data
    collect_data(options)
end