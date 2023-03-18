function [fileNameTSVGZ,fileNameJSON] = natview_eye_edf2bids(fileNameSET,fileNameEDF,outputDir)
%% PURPOSE: This script converts EyeLink EDF files into the BIDS format
%
%           Eye tracking data collected with EyeLink 1000 Plus is saved in
%           the EDF format. Before conversion to BIDS format, this function
%           converted to ASCII format using EDF2ASC v3.1 software, which is
%           part of the EyeLink Developers Kit:
%
%               https://www.sr-research.com/support/thread-13.html
%
%           NOTE: User must signup for account on SR Research forum to get
%           access to download. Included with this code release is a ZIP
%           file containing EDF2ASC version 3.1 Win32. User should sign up
%           on the SR research for instructions to install the 64-bit
%           Windows version, Linux or macOS.
%
%           This script also utilizes the following toolbox:
%
%           EEGLAB (https://sccn.ucsd.edu/eeglab/index.php)
%
%           EEGLAB is used to import EEG data to extract event codes.
%
%           NOTE: This function uses the SET file format for file input 
%
% FINAL NOTE: Eye tracking data in this data release does not contain EDF
% files. This script here only serves to memorialize process of converting
% eye tracking data into BIDS format. Users are free to use code here, but
% modification required if using different event codes and triggers.
%
%--------------------------------------------------------------------------
% INPUT:
%       fileNameSET - Filename of SET file (EEG data)
%
%       fileNameEDF - Filename of EDF file (eye tracking data)
%
%         outputDir - Output directory for eye tracking data in BIDS format 
%
%--------------------------------------------------------------------------
% OUTPUT:
%     fileNameTSVGZ - Filename of TSV file for eye tracking data in BIDS format (zipped as GZ file)
%
%      fileNameJSON - Filename of JSON file for eye tracking data in BIDS format
%
%--------------------------------------------------------------------------
%% Error Checking
% SET Filename
if(nargin < 1 || isempty(fileNameSET))
    error('Missing SET file. Please enter filename of SET file.');
end

% EDF Filename
if(nargin < 2 || isempty(fileNameEDF))
    error('Missing eye tracking file. Please enter filename of eye tracking file (EDF or ASC).');
end

% Output directory (Default: current working directory)
if(nargin < 3 || isempty(outputDir))
    outputDir = pwd;
end

% If output directory does not exist, create directory
if(~exist(outputDir,'dir'))
    mkdir(outputDir);
end

%% Extract participant, session, and task information from filename
% This section assumes your input file is in BIDS format and will extract
% participant ID, session ID, task name, and run number (if applicable).
% NOTE: Must be in BIDS format (e.g., sub-01_ses-01_task-abc_run-01.tsv.gz)

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
task    = fileInfo{3}; % Task Name

if(length(fileInfo) > 3)
    runNum  = fileInfo{4}; % Run
    output_fileName = [subject,'_',session,'_',task,'_',runNum];
else
    output_fileName = [subject,'_',session,'_',task];
end

%% EEG event codes: EEG file
% In section you will find all the event codes and scanner triggers
% associated with simultaneous EEG-fMRI scanning. All tasks have a start
% code (S1), end code (S99), and trigger at the start of each TR (R128).
%
% NOTE: Data collected with the scanner off (i.e., 'checkeroff') do not
%       contain scanner triggers.
taskStart = 'S  1'; % Start of task
taskEnd   = 'S 99'; % End of task
triggerTR    = 'R128'; % TR trigger during fMRI scan

if(strcmp(task,'task-dme') || ...
        strcmp(task,'task-dmh') || ...
        strcmp(task,'task-inscapes') || ...
        strcmp(task,'task-monkey1') || ...
        strcmp(task,'task-monkey2') || ...
        strcmp(task,'task-monkey5') || ...
        strcmp(task,'task-rest') || ...
        strcmp(task,'task-tp'))

    % Video/Rest Task Event Code
    eventTimer  = 'S  5'; % 1-second time marker during video and rest task

elseif(strcmp(task,'task-checker') || strcmp(task,'task-checkeroff'))

    % Checkerboard Task Event Codes
    eventREST = 'S 10';    % Start Rest Block
    eventCHCK = 'S 25';    % Start Checkerboard Block
    eventREST_1s = 'S 11'; % 1-second time marker during rest block
    eventCHCK_1s = 'S 26'; % 1-second time marker during checkerboard block
    eventREST_2s = 'S 12'; % 2-second time marker during rest block
    eventCHCK_2s = 'S 27'; % 2-second time marker during checkerboard block

end

%% Eye tracking event codes: EyeLink EDF file
if(strcmp(task,'task-dme') || ...
   strcmp(task,'task-dmh') || ...
   strcmp(task,'task-inscapes') || ...
   strcmp(task,'task-monkey1') || ...
   strcmp(task,'task-monkey2') || ...
   strcmp(task,'task-monkey5') || ...
   strcmp(task,'task-tp'))
    msgStart = 'VIDEO START';   % Start of task
    msgEnd   = 'VIDEO END';     % End of task
    msgTimer = 'VIDEO MARKER';  % 1s marker
elseif(strcmp(task,'task-rest'))
    msgStart = 'REST START';    % Start of task
    msgEnd   = 'REST END';      % End of task
    msgTimer = 'REST MARKER';   % 1s marker
elseif(strcmp(task,'task-checker') || strcmp(task,'task-checkeroff'))
    msgStart = 'TASK START';    % Start of task
    msgEnd   = 'TASK END';      % End of task
    msgTimerREST_1s = 'REST BLOCK 1s';          % 1s marker during rest block
    msgTimerCHCK_1s = 'CHECKERBOARD BLOCK 1s';  % 1s marker during checkerboard block
    % msgTimerREST_2s = 'REST BLOCK 2s';          % 2s marker during rest block
    % msgTimerCHCK_2s = 'CHECKERBOARD BLOCK 2s';  % 2s marker during checkerboard block
end

%% Extract events from EEG file
EEG = pop_loadset(fileNameSET); % Load SET file into MATLAB
time_EEG = 0:1/EEG.srate:length(EEG.times)/EEG.srate; % Convert latency to seconds

latencyEEG = round([EEG.urevent.latency]); % Extract event code/trigger latency values
eventID = {EEG.urevent.type}; % Extract event code/trigger type

eventsEEG.start = latencyEEG(ismember(eventID,taskStart));
eventsEEG.end   = latencyEEG(ismember(eventID,taskEnd));

if(strcmp(task,'checkeroff'))
    disp('No scanner triggers');
    eventsEEG.TR = [];
else
    eventsEEG.TR = latencyEEG(ismember(eventID,triggerTR));
end

if(strcmp(task,'task-dme') || ...
   strcmp(task,'task-dmh') || ...
   strcmp(task,'task-inscapes') || ...
   strcmp(task,'task-monkey1') || ...
   strcmp(task,'task-monkey2') || ...
   strcmp(task,'task-monkey5') || ...
   strcmp(task,'task-rest') || ...
   strcmp(task,'task-tp'))
    eventsEEG.timer = latencyEEG(ismember(eventID,eventTimer));
elseif(strcmp(task,'task-checker') || strcmp(task,'task-checkeroff'))
    eventsEEG.rest      = latencyEEG(ismember(eventID,eventREST));
    eventsEEG.checker   = latencyEEG(ismember(eventID,eventCHCK));
    eventsEEG.rest1s    = latencyEEG(ismember(eventID,eventREST_1s));
    eventsEEG.checker1s = latencyEEG(ismember(eventID,eventCHCK_1s));
    eventsEEG.rest2s    = latencyEEG(ismember(eventID,eventREST_2s));
    eventsEEG.checker2s = latencyEEG(ismember(eventID,eventCHCK_2s));
    eventsEEG.timer     = sort([eventsEEG.rest1s, eventsEEG.checker1s]);
end

eventsEEG.startTime = time_EEG(eventsEEG.start); % Start time of task in seconds
eventsEEG.srate = EEG.srate; % sampling rate

%% Convert EDF to ASC
[~,~,fileExt] = fileparts(fileNameEDF);
if(strcmp(fileExt,'.edf'))
    fileNameASC = edf2asc(fileNameEDF);
elseif(strcmp(fileExt,'.asc'))
    fileNameASC = fileNameEDF;
end

%% Convert ASC to BIDS
opts = detectImportOptions(fileNameASC,'FileType','text');
opts.DataLines = [1, Inf];
opts.VariableTypes = repmat("string",1,length(opts.VariableTypes));

% Load the data from the .asc file
data_table = readtable(fileNameASC,opts);

% Time in ms
time_ASC = str2double(table2array(data_table(:,1)));

% Gaze position and pupil
x = str2double(table2array(data_table(:,2)));
y = str2double(table2array(data_table(:,3)));
pupil = str2double(table2array(data_table(:,4)));

% Resolution
res_x = str2double(table2array(data_table(:,5)));
res_y = str2double(table2array(data_table(:,6)));

% Remove messages
idx_nan = isnan(time_ASC); % Find NaNs in time vector

x(idx_nan) = [];
y(idx_nan) = [];
pupil(idx_nan) = [];
res_x(idx_nan) = [];
res_y(idx_nan) = [];
time_ASC(idx_nan) = [];

% Saccades, Fixations, Blinks
fixations = char(table2array(data_table(cellfun(@(C) contains(C, 'EFIX'), num2cell(table2array(data_table(:,1)))), [1,2])));
eventsEYE.fixation_time = cellfun(@(C) str2double(C(regexp(C, '\d'))), squeeze(num2cell(fixations, 2)));
eventsEYE.fixation_sample = round(interp1(time_ASC, 1:length(time_ASC), eventsEYE.fixation_time));

saccades = char(table2array(data_table(cellfun(@(C) contains(C, 'ESACC'), num2cell(table2array(data_table(:,1)))), [1,2])));
eventsEYE.saccade_time = cellfun(@(C) str2double(C(regexp(C, '\d'))), squeeze(num2cell(saccades, 2)));
eventsEYE.saccade_sample = round(interp1(time_ASC, 1:length(time_ASC), eventsEYE.saccade_time));

blinks = char(table2array(data_table(cellfun(@(C) contains(C, 'EBLINK'), num2cell(table2array(data_table(:,1)))), [1,2])));
eventsEYE.blink_time = cellfun(@(C) str2double(C(regexp(C, '\d'))), squeeze(num2cell(blinks, 2)));
eventsEYE.blink_sample = round(interp1(time_ASC, 1:length(time_ASC), eventsEYE.blink_time));

% Read the event codes
messages_ASC = data_table(strcmp(table2array(data_table(:,1)), 'MSG'), :);

[eventsEYE.start_time,eventsEYE.start_sample] = extract_triggers(messages_ASC,time_ASC,msgStart); % Start of task
[eventsEYE.end_time,eventsEYE.end_sample] = extract_triggers(messages_ASC,time_ASC,msgEnd); % End of task

if(strcmp(task,'task-checker') || strcmp(task,'task-checkeroff'))
    [timer_time_REST, timer_sample_REST] = extract_triggers(messages_ASC,time_ASC,msgTimerREST_1s,msgTimerREST_1s);
    [timer_time_CHCK, timer_sample_CHCK] = extract_triggers(messages_ASC,time_ASC,msgTimerCHCK_1s,msgTimerCHCK_1s);
    eventsEYE.timer_time = sort([timer_time_REST; timer_time_CHCK]);
    eventsEYE.timer_sample = sort([timer_sample_REST; timer_sample_CHCK]);
else
    [eventsEYE.timer_time, eventsEYE.timer_sample] = extract_triggers(messages_ASC,time_ASC,msgTimer,msgTimer);
end

% Align the data
time_ASC = time_ASC/1e3;

% Align EEG and fMRI
offsetTime = time_ASC(eventsEYE.start_sample) - eventsEEG.startTime;

% Set the task start to time zero
startTime = eventsEYE.start_time/1e3;

% Adjust time of events
eventsEYE.fixation_time = eventsEYE.fixation_time/1e3;
eventsEYE.saccade_time = eventsEYE.saccade_time/1e3;
eventsEYE.blink_time = eventsEYE.blink_time/1e3;

eventsEYE.fixation_time = eventsEYE.fixation_time - startTime;
eventsEYE.saccade_time = eventsEYE.saccade_time - startTime;
eventsEYE.blink_time = eventsEYE.blink_time - startTime;

% Adjust time of event codes
eventsEYE.start_time = eventsEYE.start_time/1e3;
eventsEYE.end_time = eventsEYE.end_time/1e3;
eventsEYE.timer_time = eventsEYE.timer_time/1e3;

eventsEYE.start_time =  eventsEYE.start_time - startTime;
eventsEYE.end_time =  eventsEYE.end_time - startTime;
eventsEYE.timer_time = eventsEYE.timer_time - startTime;

%% Collect metadata
% Sampling frequency
metadataEYE.SamplingFrequency = str2double(table2array(data_table(strcmp(table2array(data_table(:,5)), 'RATE'), 6)));

if diff(metadataEYE.SamplingFrequency) ~= 0
    error('Sampling frequency from left/right eye inconsistent')
else
    metadataEYE.SamplingFrequency = mean(metadataEYE.SamplingFrequency);
end

% Start time in relation to EEG
metadataEYE.StartTime = round(time_ASC(1) - offsetTime, 4);

% Organization of data table
metadataEYE.Columns = {'Time', 'Gaze_X', 'Gaze_Y', 'Pupil_Area', 'Resolution_X', 'Resolution_Y'};

% Device information
metadataEYE.Manufacturer = 'SR Research';

model_pattern = 'VERSION: ';
model_str = char(table2array(data_table(cellfun(@(C) contains(C, model_pattern), num2cell(table2array(data_table(:,1)))), 1)));
metadataEYE.ManufacturersModelName = model_str(regexp(model_str, model_pattern) + length(model_pattern) : end);

source_pattern = 'SOURCE: ';
idx_source = find(cellfun(@(C) contains(C, source_pattern), num2cell(table2array(data_table(:,1)))));
source_str = char(table2array(data_table(idx_source+1, 1)));
metadataEYE.SoftwareVersions = source_str(regexp(source_str, '** ') + length('** ') : end);

serial_pattern = 'SERIAL NUMBER: ';
serial_str = char(table2array(data_table(cellfun(@(C) contains(C, serial_pattern), num2cell(table2array(data_table(:,1)))), 1)));
metadataEYE.DeviceSerialNumber = serial_str(regexp(serial_str, serial_pattern) + length(serial_pattern) : end);

display_pattern = 'DISPLAY_COORDS';
display_str = char(table2array(data_table(cellfun(@(C) contains(C, display_pattern), num2cell(table2array(data_table(:,2)))), 2)));
display_str = display_str(regexp(display_str, display_pattern) + length(display_pattern) : end);

metadataEYE.DisplayCoordinates = cellfun(@(C) str2double(C), strsplit(display_str, ' '));
metadataEYE.DisplayCoordinates(isnan(metadataEYE.DisplayCoordinates)) = [];

%% Set start of time axis to zero
time_ASC = time_ASC - startTime;

%% Collect data
dataMAT = [time_ASC, x, y, pupil, res_x, res_y];

%% Interpolate fMRI triggers from EEG data
% The timer triggers can be used to interpolate triggers from the EEG to eye tracking data
eventsEYE.sample_fmri = round(interp1(eventsEEG.timer, eventsEYE.timer_sample, eventsEEG.TR))';
eventsEYE.sample_fmri(isnan(eventsEYE.sample_fmri)) = [];
eventsEYE.time_fmri = dataMAT(eventsEYE.sample_fmri, 1);

%% Add events and triggers to data array
fixationColumn = create_event_vector(eventsEYE,length(dataMAT),'fixation_sample');
saccadeColumn  = create_event_vector(eventsEYE,length(dataMAT),'saccade_sample');
blinkColumn    = create_event_vector(eventsEYE,length(dataMAT),'blink_sample');

taskStartEnd = zeros(length(dataMAT),1);
taskStartEnd(eventsEYE.start_sample) = 1;
taskStartEnd(eventsEYE.end_sample) = 1;

timerColumn = zeros(length(dataMAT),1);
timerColumn(eventsEYE.timer_sample) = 1;

TRColumn = zeros(length(dataMAT),1);
TRColumn(eventsEYE.sample_fmri) = 1;

dataMAT = [dataMAT, fixationColumn, saccadeColumn, blinkColumn, taskStartEnd, timerColumn, TRColumn];

metadataEYE.Columns = [metadataEYE.Columns, 'Fixations', ...
                                            'Saccades', ...
                                            'Blinks', ...
                                            'Task_Start_End_Trigger', ...
                                            'Timer_Trigger_1_second', ...
                                            'fMRI_Volume_Trigger'];

%% Add descriptions of the colums
metadataEYE.Time.Description = 'timestamps; time zero corresponds to the start of the task (movie, checkerboard, rest)';
metadataEYE.Time.Units = 'seconds';

metadataEYE.Gaze_X.Description = 'horizontal gaze position on the screen; Origin (0,0) at the top left)';
metadataEYE.Gaze_X.Units = 'pixels';

metadataEYE.Gaze_Y.Description = 'Vertical gaze position on the screen; Origin (0,0) at the top left)';
metadataEYE.Gaze_Y.Units = 'pixels';

metadataEYE.Pupil_Area.Description = 'pupil size reported as area (not calibrated)';
metadataEYE.Pupil_Area.Units = 'arbitrary units';

metadataEYE.Resolution_X.Description = 'instantaneous angular resolution in horizontal direction; defines the relationship between visual angle and gaze position';
metadataEYE.Resolution_X.Units = 'pixels per degreee visual angle';

metadataEYE.Resolution_Y.Description = 'instantaneous angular resolution in vertical direction; defines the relationship between visual angle and gaze position';
metadataEYE.Resolution_Y.Units = 'pixels per degreee visual angle';

metadataEYE.Fixations.Description = '1 indicates a fixation';

metadataEYE.Saccades.Description = '1 indicates a saccade';

metadataEYE.Blinks.Description = '1 indicates a blink';

metadataEYE.Task_Start_End_Trigger.Description = '1 indicates the start and end of the task, respectively; sent by the stimulus PC';

metadataEYE.Timer_Trigger_1_second.Description = '1 indicates time of a trigger sent every second by the stimulus PC';

metadataEYE.fMRI_Volume_Trigger.Description = '1 indicates time of a trigger sent by the fMRI scanner at the start of a volume';

%% Write the eyetracking data in BIDS format
% Save event code STRUCT
outputMAT = fullfile(outputDir,[output_fileName,'_recording-eyetracking_analysis-events_physio.mat']);
save(outputMAT,'eventsEEG','eventsEYE');

% Save JSON metadata
outputJSON = fullfile(outputDir,[output_fileName,'_recording-eyetracking_physio.json']);
fid = fopen(outputJSON,'w');
try
    fprintf(fid,'%s',jsonencode(metadataEYE,PrettyPrint=true));
catch
    fprintf(fid,'%s',jsonencode(metadataEYE));
end
fclose(fid);

% Save raw data file in BIDS format
outputTSV = fullfile(outputDir,[output_fileName,'_recording-eyetracking_physio.tsv']);
dlmwrite(outputTSV,dataMAT,'\t'); %#ok<DLMWT>
gzip(outputTSV); % Compress file

if(exist([outputTSV,'.gz'],'file'))
    delete(outputTSV);
end

fileNameTSVGZ = [outputTSV,'.gz'];
fileNameJSON = outputJSON;
disp('Eye tracking ASC file converted to BIDS format.');

end
%% Eye Tracking Subfunctions
%
% Contains subfunctions for converting and working with eye tracking data
%
%% Subfunction: Convert EDF files to ASC format
% PURPOSE:  Converts EyeLink EDF files to ASCII (text) files
%           EyeLink EDF file -> ASCII (text) file translator
%           EDF2ASC version 3.1 Win32 Feb 16 2010
% INPUT:
%       fileNameEDF - Filename of EDF file
%
%       getDirFlag - Flag to get directory containing EDF2ASC executable
%
% OUTPUT:
%       fileNameASC - Filename of ASC file
%
%--------------------------------------------------------------------------
function fileNameASC = edf2asc(fileNameEDF,getDirFlag)
    % If flag is used, user prompted to provide directory containing the
    % EDF2ASC executable. User can also hardcode the location of EDF2ASC if
    % they do not wish to used getDirFlag
    if(nargin < 2 || isempty(getDirFlag))
        getDirFlag = 0;
    end

    if(getDirFlag == 1)
        edf2ascDir = uigetdir('%s','Please select directory containing EDF2ASC executable');
        edf2ascExe = fullfile(edf2ascDir,'edf2asc.exe'); % EDF2ASC Executable File
    else
        edf2ascExe = 'C:\data\edf2asc\edf2asc.exe'; % EDF2ASC Executable File
    end

    fileNameASC = strrep(fileNameEDF,'.edf','.asc'); % Output filename of ASC file
    
    % Convert EDF to ASC
    if(~exist(fileNameASC,'file'))
        system([edf2ascExe,' -y -res ',fileNameEDF]);
        disp('Eye tracking EDF file converted to ASC.');
    else
        disp('Eye tracking EDF file already converted to ASC.');
    end
end

%% Subfunction: Extract Eye Track Event Codes/Triggers
function [trigger_time, trigger_sample] = extract_triggers(messages, time, trig_msg, varargin)

    % Optional variable of cutting end of message string
    cut_end = false;
    if nargin == 4
        end_pattern = varargin{1};
        cut_end = true;
    end
    
    % Find the entries of the specific message
    trigger_messages = num2cell(char(table2array(messages(cellfun(@(C) contains(C, trig_msg), table2cell(messages(:, 2))), 2))), 2);
    % Remove end of message with confounding numerical values
    if cut_end
        trigger_messages = cellfun(@(C) remove_string(C, end_pattern), trigger_messages, 'UniformOutput', false);
    end
    
    % Extract the time 
    trigger_time = cellfun(@(C) str2double(C(regexp(C, '\d'))), trigger_messages);
    % Find corresponding samples
    trigger_sample = round(interp1(time, 1:length(time), trigger_time));
    
end



%% Subfunction: Create a vector from event data
function event_vector = create_event_vector(event_data, n_sample, event_type)

    % Extract the tield from the struct
    event_idx = getfield(event_data, event_type); %#ok<GFLD> 

    % Create empty vectors
    event_vector = zeros(n_sample,1);

    % Fill with zeros at the time of events
    for i = 1:length(event_idx)
        event_vector(event_idx(i,1):event_idx(i,2)) = 1;
    end

end
