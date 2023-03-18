function [taskLengthDiff,percentMissingSamples,percentOffSamples] = natview_eye_data_qc(fileNameSET,fileNameTSVGZ,fileNameJSON,outputDir,saveFlag)
% PURPOSE: This function calculates quality control (QC) metrics from eye
%          tracking data. Using the raw EEG file, function calculates the
%          difference between the timing for the EEG data and eye tracking
%          data. In addition, QC metrics include measurements of the
%          percentage of the scan session where the eye tracker lost track
%          of the eye (i.e., missing samples) and the perentage of the scan
%          session where the participant's gaze was off-screen.
%
% INPUT:
%         fileNameSET - Filename of SET file
%
%       fileNameTSVGZ - Filename of TSV.GZ file. User can also input TSV if
%                       files are not unzipped.
%                       NOTE: If using zipped file, function unzips GZ and
%                             deletes TSV/CSF files after data extracted
%
%        fileNameJSON - Filename of eye tracking JSON file
%
%           outputDir - Output directory for QC data (MAT file)
%       
%            saveFlag - Flag to save QC data (MAT file)
%                       (Default: 0)
%
%--------------------------------------------------------------------------
%% Error Checking
if(nargin < 1 || isempty(fileNameSET))
    error('Missing SET file. Please enter filename of SET file.');
end

if(nargin < 2 || isempty(fileNameTSVGZ))
    error('Missing TSV/TSV.GZ file. Please enter filename of TSV.GZ or TSV file.');
end

if(nargin < 3|| isempty(fileNameJSON))
    error('Missing JSON file. Please enter filename of JSON file.');
end

if(nargin < 4 || isempty(outputDir))
    outputDir = pwd;
end

if(~exist(outputDir,'dir'))
    mkdir(outputDir);
end

if(nargin < 5 || isempty(saveFlag))
    saveFlag = 0;
end

%% Get fileInfo
% This section assumes your input file is in BIDS format and will get the
% participant ID, session ID, task name, and run number (if applicable).
[~,fileName] = fileparts(fileNameSET);

underscore_idx = strfind(fileName,'_');
fileInfo = cell(length(underscore_idx),1);
for ii = 1:length(underscore_idx)
    if(ii==1)
        fileInfo{ii} = fileName(1:underscore_idx(1)-1);
    else
        fileInfo{ii} = fileName(underscore_idx(ii-1)+1:underscore_idx(ii)-1);
    end
end

subject = fileInfo{1}; % Participant ID
session = fileInfo{2}; % Session
task = fileInfo{3}; % Task Name

if(length(fileInfo) > 3)
    runNum  = fileInfo{4}; % Run
    output_fileName = [subject,'_',session,'_',task,'_',runNum];
else
    output_fileName = [subject,'_',session,'_',task];
end

%% Event Codes
% In section you will find all the event codes and scanner triggers
% associated with simultaneous EEG-fMRI scanning. All tasks have a start
% code (S1), end code (S99), and trigger at the start of each TR (R128).
%
% NOTE: Data collected with the scanner off (i.e., 'checkeroff') do not
%       contain scanner triggers.
eventStart = 'S  1'; % Start of task
eventEnd   = 'S 99'; % End of task
triggerTR    = 'R128'; % TR trigger during fMRI scan

if(strcmp(task,'task-dme') || ...
        strcmp(task,'task-dmh') || ...
        strcmp(task,'task-inscapes') || ...
        strcmp(task,'task-monkey1') || ...
        strcmp(task,'task-monkey2') || ...
        strcmp(task,'task-monkey5') || ...
        strcmp(task,'task-rest') || ...
        strcmp(task,'task-tp'))

    % Video/Rest Task Trigger
    eventTime  = 'S  5'; % 1-second time marker during video and rest task

elseif(strcmp(task,'task-checker') || strcmp(task,'task-checkeroff'))

    % Checkerboard Task Triggers
    eventREST = 'S 10';    % Start Rest Block
    eventCHCK = 'S 25';    % Start Checkerboard Block
    eventREST_1s = 'S 11'; % 1-second time marker during rest block
    eventREST_2s = 'S 12'; % 2-second time marker during rest block
    eventCHCK_1s = 'S 26'; % 1-second time marker during checkerboard block
    eventCHCK_2s = 'S 27'; % 2-second time marker during checkerboard block

end

%% Unzip TSV file and import table data into MATLAB
[fileDirGZ,fileNameGZ,fileExtGZ] = fileparts(fileNameTSVGZ);

% Check if file is GZ and unzip, else use TSV file for data import
if(strcmp(fileExtGZ,'.gz'))
    gunzip(fileNameTSVGZ);
    fileNameTSV = fullfile(fileDirGZ,fileNameGZ);
    deleteGZ = 1;
elseif(strcmp(fileExt,'.tsv'))
    fileNameTSV = fileNameTSVGZ;
    deleteGZ = 0;
end

fileNameCSV = strrep(fileNameTSV,'.tsv','.csv'); % CSV filename
copyfile(fileNameTSV,fileNameCSV); % Copy TSV to CSV file format

if(deleteGZ == 1)
    delete(fileNameTSV); % Only deletes TSV file if input is zip file
end

dataCSV = readtable(fileNameCSV); % Reads in table data from CSV
dataMAT = table2array(dataCSV); % Converts table to array
delete(fileNameCSV);

%% Extract JSON Metadata
file_id = fopen(fileNameJSON);
contentJSON = char(fread(file_id, inf)');
fclose(file_id);

metadataJSON = jsondecode(contentJSON);

%% Extract trigger/event codes from EEG file
EEG = pop_loadset(fileNameSET); % Load SET file into MATLAB
t = 0:1/EEG.srate:length(EEG.times)/EEG.srate; % Convert latency to seconds

triggerLatency = round([EEG.urevent.latency]); % Extract trigger latency values
triggerID = {EEG.urevent.type}; % Extract trigger type

triggerEEG.start     = triggerLatency(ismember(triggerID,eventStart));
triggerEEG.end       = triggerLatency(ismember(triggerID,eventEnd));

if(strcmp(task,'checkeroff'))
    disp('No scanner triggers');
    triggerEEG.TR = [];
else
    triggerEEG.TR = triggerLatency(ismember(triggerID,triggerTR));
end
if(strcmp(task,'task-dme') || ...
        strcmp(task,'task-dmh') || ...
        strcmp(task,'task-inscapes') || ...
        strcmp(task,'task-monkey1') || ...
        strcmp(task,'task-monkey2') || ...
        strcmp(task,'task-monkey5') || ...
        strcmp(task,'task-rest') || ...
        strcmp(task,'task-tp'))

    triggerEEG.time = triggerLatency(ismember(triggerID,eventTime));

elseif(strcmp(task,'task-checker') || strcmp(task,'task-checkeroff'))

    triggerEEG.rest      = triggerLatency(ismember(triggerID,eventREST));
    triggerEEG.checker   = triggerLatency(ismember(triggerID,eventCHCK));
    triggerEEG.rest1s    = triggerLatency(ismember(triggerID,eventREST_1s));
    triggerEEG.checker1s = triggerLatency(ismember(triggerID,eventCHCK_1s));
    triggerEEG.rest2s    = triggerLatency(ismember(triggerID,eventREST_2s));
    triggerEEG.checker2s = triggerLatency(ismember(triggerID,eventCHCK_2s));
end

triggerEEG.srate = EEG.srate;

%% Check alignment of time stamps for EEG data and eye tracker
timeTable = dataMAT(:,ismember(metadataJSON.Columns,'Time'));

timeStartEnd = timeTable(dataMAT(:,ismember(metadataJSON.Columns,'Task_Start_End_Trigger')) == 1);

triggerEEG.timeStartEEG = t(triggerEEG.start); % Time start in EEG
triggerEEG.timeEndEEG = t(triggerEEG.end); % Time end in EEG
triggerEEG.timeStartEYE = timeStartEnd(1); % Time start in eye tracking TSV
triggerEEG.timeEndEYE = timeStartEnd(2); % Time end in eye tracking TSV

% Calculate length of task as recorded by EEG system and eye tracker
taskLengthEEG = triggerEEG.timeEndEEG - triggerEEG.timeStartEEG; % Task length by EEG system (in seconds)
taskLengthEYE = triggerEEG.timeEndEYE - triggerEEG.timeStartEYE; % Task length by eye tracker (in seconds)

% Time difference between EEG system and eye tracker
taskLengthDiff = taskLengthEEG - taskLengthEYE;

%% Calculate eye tracking quality metrics
% Samples without data
percentMissingSamples = sum(dataMAT(:,ismember(metadataJSON.Columns,'Interpolated_Samples'))) / length(dataMAT);

% Samples with gaze position outside of the screen
offScreenX = sum(dataMAT(:,ismember(metadataJSON.Columns,'Gaze_X')) < metadataJSON.DisplayCoordinates(2) | ...
    dataMAT(:,ismember(metadataJSON.Columns,'Gaze_X')) > metadataJSON.DisplayCoordinates(4));
offScreenY = sum(dataMAT(:,ismember(metadataJSON.Columns,'Gaze_Y')) < metadataJSON.DisplayCoordinates(1) | ...
    dataMAT(:,ismember(metadataJSON.Columns,'Gaze_Y')) > metadataJSON.DisplayCoordinates(3));

percentOffSamples = (offScreenX + offScreenY) / length(dataMAT);

if(saveFlag == 1)
    save_fileName = fullfile(outputDir,[output_fileName,'_recording-eyetracking_analysis-qc_physio.mat']);
    save(save_fileName,'taskLengthDiff','percentMissingSamples','percentOffSamples');
end