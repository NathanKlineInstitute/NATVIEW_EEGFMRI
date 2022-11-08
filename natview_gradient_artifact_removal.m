function [EEG,output_fileSET] = natview_gradient_artifact_removal(input_fileSET_EEG,outputDir,ANCFlag,electrodeExclude)
%% PURPOSE:	This script removes the gradient artifact from simultaneous EEG-fMRI data using the EEGLAB FMRIB Toolbox
%
% INPUT:
%           input_fileSET_EEG: Filename of EEG .set file or EEG struct

%           outputDir: Output directory specified by user
%                      [Default: current working directory]
%
%           ANCFlag: Adaptive noise cancellation flag
%                    [Default: 1 (use adaptive noise cancellation)]
%           
%           electrodeExclude: Channels to exclude from residual artifact
%                             principle component fitting (OBS), specify
%                             non-EEG channels (e.g., ECG, EOG, EMG, etc.)
%                             [Default: ECG (32), EOGL (63), EOGU (64)]
%
%           NOTE: MRI cap for this data release was customized to include
%                 EOG electrodes. If using your own data set, be sure check
%                 non-EEG channels for this parameter.
%
% OUTPUT:
%           EEG: EEG struct with gradient artifact remove from EEG data
%
%           output_fileSET: .set output filename
%
% EXAMPLES:
%           EXAMPLE #1
%           INPUT:
%               input_fileSET_EEG = '/data/eeg/raw/sub-01_ses-01_task-rest_eeg.set';
%               outputDir = '/data/eeg/preprocess/';
%               ANCFlag = 0;
%               electrodeExclude = 10;
%               [EEG,output_fileSET] = eeglab_gradient_artifact_removal(input_fileSET_EEG,outputDir,ANCFlag,electrodeExclude);
%
%               This code will perform gradient artifact removal on .set
%               file 'sub-01_ses-01_task-rest_eeg.set' and save output to
%               /data/eeg/preprocess/. Adaptive noise cancellation is not
%               used and electrode 10 is excluded from residual artifact
%               principle component fitting
%
%           OUTPUT:
%               EEG: EEG struct with gradient artifact remove from EEG data
%               output_fileSET: '/data/eeg/preprocess/sub-01_ses-01_task-rest_eeg_gradient_noANC.set'
%
%           EXAMPLE #2
%           INPUT:
%               input_fileSET_EEG = '/data/eeg/raw/sub-01_ses-01_task-rest_eeg.set';
%               outputDir = '/data/eeg/preprocess/';
%               [EEG,output_fileSET] = eeglab_gradient_artifact_removal(input_fileSET_EEG,outputDir);
%
%               This code will perform gradient artifact removal on .set
%               file 'sub-01_ses-01_task-rest_eeg.set' and save output to
%               /data/eeg/preprocess/. Following defaults, adaptive noise
%               cancellation is used and electrodes 32, 63 and 64 are
%               excluded from residual artifact principle component fitting
%
%           OUTPUT:
%               EEG: EEG struct with gradient artifact remove from EEG data
%               output_fileSET: '/data/eeg/preprocess/sub-01_ses-01_task-rest_eeg_gradient_ANC.set'
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

% Default is to use adaptive noise cancellation (ANC)
if(nargin < 3 || isempty(ANCFlag))
    ANCFlag = 1;
end

% Check what electrodes to be excluded from residual artifact principle component fitting
if(nargin < 4 || isempty(electrodeExclude))
    electrodeExclude = [32,63,64];
end

%% Load Data
if(isstruct(input_fileSET_EEG)) % Check if input is STRUCT
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

%% Gradient Artifact Removal
EEG.data = double(EEG.data);

% Gradient artifact without adaptive noise cancellation
if(ANCFlag == 0)
    output_fileSET = fullfile(outputDir,[fileName,'_gradient_noANC','.set']); % Output filename for SET
    EEG = pop_fmrib_fastr(EEG,[],[],[],'R128',1,0,[],[],[],[],electrodeExclude,'auto'); % Remove gradient artifact
    [~,EEG,~] = pop_newset([], EEG, 1,'setname',[EEG.setname,' | GA Removed (no ANC)'],'savenew',output_fileSET,'gui','off'); % Edit SET name and save data
    
% Gradient artifact with adaptive noise cancellation
elseif(ANCFlag == 1)
    output_fileSET = fullfile(outputDir,[fileName,'_gradient_ANC','.set']); % Output filename for SET
    EEG = pop_fmrib_fastr(EEG,[],[],[],'R128',1,1,[],[],[],[],electrodeExclude,'auto'); % Remove gradient artifact
    [~,EEG,~] = pop_newset([], EEG, 1,'setname',[EEG.setname,' | GA Removed (ANC)'],'savenew',output_fileSET,'gui','off'); % Edit SET name and save data
end
