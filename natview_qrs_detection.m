function [EEG,output_fileSET] = natview_qrs_detection(input_fileSET_EEG,outputDir,ECGChannel)
%% PURPOSE:	This script performs QRS detection on EEG data set and inserts QRS events into .set file (QRS detection function from EEGLAB FMRIB Toolbox)
%
% INPUT:
%           input_fileSET_EEG: Filename of EEG .set file or EEG struct
%
%           outputDir: Output directory specified by user
%                      [Default: current working directory]
%
%           ECGChannel: Specify ECG channel for QRS detection
%                       [Default: ECG (32)]
%           
%
% OUTPUT:
%           EEG: EEG struct with QRS events added to EEG struct
%
%           output_fileSET: .set output filename
%
% EXAMPLES:
%           EXAMPLE #1
%           INPUT:
%               input_fileSET_EEG = '/data/eeg/raw/sub-01_ses-01_task-rest_eeg_gradientANC.set';
%               outputDir = '/data/eeg/preprocess/';
%               ECGChannel = 12;
%               [EEG,output_fileSET] = eeglab_qrs_detection(input_fileSET_EEG,outputDir,ECGChannel);
%
%               This code detects QRS events in .set file
%               'sub-01_ses-01_task-rest_eeg_gradientANC.set' using channel
%               12 for QRS detection. File output is saved to /data/eeg/preprocess/
%
%           OUTPUT:
%               EEG: EEG struct with QRS events inserted into EEG data
%               output_fileSET: '/data/eeg/preprocess/sub-01_ses-01_task-rest_eeg_gradient_ANC_QRS.set'
%
%           EXAMPLE #2
%           INPUT:
%               input_fileSET_EEG = '/data/eeg/raw/sub-01_ses-01_task-rest_eeg_gradientANC.set';
%               outputDir = '/data/eeg/preprocess/';
%               [EEG,output_fileSET] = eeglab_qrs_detection(input_fileSET_EEG,outputDir);
%
%               This code detects QRS events in .set file
%               'sub-01_ses-01_task-rest_eeg_gradientANC.set' using channel
%               32 (default) for QRS detection. File output is saved to
%               /data/eeg/preprocess/
%
%
%           OUTPUT:
%               EEG: EEG struct with gradient artifact remove from EEG data
%               output_fileSET: '/data/eeg/preprocess/sub-01_ses-01_task-rest_eeg_gradient_ANC_QRS.set'
%
%
%--------------------------------------------------------------------------
%
%	Author: Qawi Telesford
%	Date: 2022-11-03
%
%--------------------------------------------------------------------------
%% Error Checking
% Checks for input file
if(nargin < 1 || isempty(input_fileSET_EEG))
    error('Missing input file (.set) or EEG struct, please enter filepath of set file or EEG struct.')
end

% Check for output directory, uses current directory if not included
if(nargin < 2 || isempty(outputDir))
    disp('No outputDir selected, using current directory.');
    outputDir = pwd;
end

% Creates output directory if it does not exist
if(~exist(outputDir,'dir'))
    mkdir(outputDir);
end

% EEG channel for QRS detection
if(nargin < 3 || isempty(ECGChannel))
    ECGChannel = 32;
end

%% Load Data
if(isstruct(input_fileSET_EEG))  % Check if input is STRUCT
    EEG = input_fileSET_EEG;
    [~,fileName] = fileparts(EEG.filename);
else
    input_fileSET = input_fileSET_EEG; % If not STRUCT, file assumed SET
    [fileDir,fileName,~] = fileparts(input_fileSET);
    input_fileSET = [fileName,'.set'];
    
    if(isempty(fileDir))
        fileDir = pwd;
    end
    EEG = pop_loadset('filename',input_fileSET,'filepath',fileDir); % Load SET file into MATLAB
end

%% Detect QRS events
output_fileSET = fullfile(outputDir,[fileName,'_QRS.set']); % Output filename for SET

EEG.data = double(EEG.data);
EEG = pop_fmrib_qrsdetect(EEG,ECGChannel,'QRS','no'); % QRS Detection
[~,EEG,~] = pop_newset([], EEG, 1,'setname',[EEG.setname,' | QRS Detection'],'savenew',output_fileSET,'gui','off'); % Edit SET name and save data
