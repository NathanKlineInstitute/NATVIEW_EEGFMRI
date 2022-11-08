function [EEG,output_fileSET] = natview_remove_PA(input_fileSET_EEG,outputDir,PAType,nPC)
%% PURPOSE:	This removes pulse artifact signal from EEG data using a function from the EEGLAB FMRIB Toolbox
%
% INPUT:
%           input_fileSET_EEG: Filename of EEG .set file or EEG struct
%
%           outputDir: Output directory specified by user
%                      [Default: current working directory]
%
%           PAType: Artifact template formation method
%                   * 'obs' | Optimal Basis Set: Does a PCA on a martix of
%                     all the heart artifacts then fits the first N
%                     components to each artifact. The default number of
%                     components is 4.  
%   
%                   * 'mean' | Simple Mean: Simply averages successive
%                     pulse artifacts
%
%                   * 'gmean' | Gaussian-Weighted Mean: Averages artifacts
%                     after multiplying by a Gaussian window weights to
%                     emphasize current artifact shape and reduce effect of
%                     further artifacts.
%
%                   * 'median' | Median: Uses a median filter of artifacts
%                     to form template.
%
%                   [Default: 'median']
%
%           nPC: Number of components for OBS template option
%                [Default: 4]
%
% OUTPUT:
%           EEG: EEG struct with pulse artifact removed
%
%           output_fileSET: .set output filename
%
% EXAMPLES:
%           EXAMPLE #1
%           INPUT:
%               input_fileSET_EEG = '/data/eeg/raw/sub-01_ses-01_task-rest_eeg_gradientANC_QRS.set';
%               outputDir = '/data/eeg/preprocess/';
%               PAType = 'obs';
%               nPC = 3;
%               [EEG,output_fileSET] = eeglab_remove_PA(input_fileSET_EEG,outputDir,PAType,nPC)
%
%               This code removes the pulse artifact from .set file
%               'sub-01_ses-01_task-rest_eeg_gradientANC_QRS.set' using
%               'obs' method for artifact template formation (3 components)
%               File output is saved to /data/eeg/preprocess/
%
%           OUTPUT:
%               EEG: EEG struct with pulse artifact removed from EEG data
%               output_fileSET: '/data/eeg/preprocess/sub-01_ses-01_task-rest_eeg_gradient_ANC_QRS_PA_obs3.set'
%
%           EXAMPLE #2
%           INPUT:
%               input_fileSET_EEG = '/data/eeg/raw/sub-01_ses-01_task-rest_eeg_gradientANC_QRS.set';
%               outputDir = '/data/eeg/preprocess/';
%               [EEG,output_fileSET] = eeglab_remove_PA(input_fileSET_EEG,outputDir);
%
%               This code removes the pulse artifact from .set file
%               'sub-01_ses-01_task-rest_eeg_gradientANC_QRS.set' using
%               'median' (default) method.
%               File output is saved to /data/eeg/preprocess/
%
%
%           OUTPUT:
%               EEG: EEG struct with pulse artifact removed from EEG data
%               output_fileSET: '/data/eeg/preprocess/sub-01_ses-01_task-rest_eeg_gradient_ANC_QRS_PA_median.set'
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

% Artifact template formation method (Default: 'median')
if(nargin < 3 || isempty(PAType))
   PAType = 'median';
end

% Number of components for OBS (Default: 4)
if(nargin < 4 || isempty(nPC))
   nPC = 4;
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

%% Remove Pulse Artifact
output_fileSET = fullfile(outputDir,[fileName,'_PA_',PAType,'.set']); % Output filename for SET

% Edit SET name
if(strcmp(PAType,'median'))
    output_setName = [EEG.setname,' | PA Removal (Median)'];
elseif(strcmp(PAType,'mean'))
    output_setName = [EEG.setname,' | PA Removal (Mean)'];
elseif(strcmp(PAType,'gmean'))
    output_setName = [EEG.setname,' | PA Removal (Gaussian Mean)'];
elseif(strcmp(PAType,'obs'))
    output_setName = [EEG.setname,' | PA Removal (OBS, PC = ',sprintf('%1.1d',nPC),')'];
    output_fileSET = strrep(output_fileSET,PAType,[PAType,sprintf('%1.1d',nPC)]);
end

EEG.data = double(EEG.data);
EEG = pop_fmrib_pas(EEG,'QRS',PAType,nPC); % Pulse Artifact removal

[~,EEG,~] = pop_newset([], EEG, 1,'setname',output_setName,'savenew',output_fileSET,'gui','off'); % Edit SET name and save data
