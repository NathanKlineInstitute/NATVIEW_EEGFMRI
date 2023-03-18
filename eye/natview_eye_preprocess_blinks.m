function [fileNameTSVGZ_blink,fileNameJSON_blink] = natview_eye_preprocess_blinks(fileNameTSVGZ,fileNameJSON,outputDir)
%% PURPOSE: This script converts EyeLink EDF files into the BIDS format
%
%           Raw eye tracking data contains column with NaN entries during
%           periods when participant is blinking or their eyes are closed or eyes are closed during
%           scan. This code finds all these instances and use a linear
%           interpolation between the 
%           before and after the blinks 
%           the EDF format. Before conversion to BIDS format, this function
%           converted to ASCII format using EDF2ASC v3.1 software, which is
%           part of the EyeLink Developers Kit:
%
%--------------------------------------------------------------------------
% INPUT:
%      fileNameTSVGZ - Filename of TSV file for raw eye tracking data
%
%      fileNameJSON - Filename of JSON file for raw eye tracking data
%
%         outputDir - Output directory for processed eye tracking data
%
%--------------------------------------------------------------------------
% OUTPUT:
%     fileNameTSVGZ_blink - Filename of TSV file for processed eye tracking data (zipped as GZ file)
%
%      fileNameJSON_blink - Filename of JSON file for processed eye tracking data
%
%--------------------------------------------------------------------------
%% Error Checking

% TSV Filename
if(nargin < 1 || isempty(fileNameTSVGZ))
    error('Missing TSV/TSV.GZ file. Please enter filename of TSV.GZ or TSV file.');
end

% JSON filename
if(nargin < 2 || isempty(fileNameJSON))
    error('Missing JSON file. Please enter filename of JSON file.');
end

% Output directory to save preprocessed eye tracking file
% (Default: current working directory)
if(nargin < 3 || isempty(outputDir))
    outputDir = pwd;
end

% If output directory does not exist, create directory
if(~exist(outputDir,'dir'))
    mkdir(outputDir);
end

%% Extract participant, session, and task information from filename
% NOTE: Must be in BIDS format (e.g., sub-01_ses-01_task-abc_run-01.tsv.gz)

[~,fileName] = fileparts(fileNameTSVGZ);

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
task = fileInfo{3};    % Task Name

if(length(fileInfo) > 3 && strcmp(fileInfo{4}(1:4),'run-'))
    runNum  = fileInfo{4}; % Run
    output_fileName = [subject,'_',session,'_',task,'_',runNum];
else
    output_fileName = [subject,'_',session,'_',task];
end

outputJSON = fullfile(outputDir,[output_fileName,'_recording-eyetracking_preprocess-blinkinterp_physio.json']);
outputTSV = fullfile(outputDir,[output_fileName,'_recording-eyetracking_preprocess-blinkinterp_physio.tsv']);

%% Blink data processing parameter
% Interpolate blinks
blinkfilling = 'interp';

% Length of median filter in preprocessing [s]
filter_length_eye = 0.2;

% Buffer on each side of blinks to remove [ms]
buffer_ms = 100; 

%% Unzip TSV file and import table data into MATLAB
[fileDirGZ,fileNameGZ,fileExtGZ] = fileparts(fileNameTSVGZ);

% Check if file is GZ and unzip, else use TSV file for data import
if(strcmp(fileExtGZ,'.gz'))
    gunzip(fileNameTSVGZ);
    fileNameTSV = fullfile(fileDirGZ,fileNameGZ);
    deleteTSV = 1;
elseif(strcmp(fileExt,'.tsv'))
    fileNameTSV = fileNameTSVGZ;
    deleteTSV = 0;
end

fileNameCSV = strrep(fileNameTSV,'.tsv','.csv'); % CSV filename
copyfile(fileNameTSV,fileNameCSV); % Copy TSV to CSV file format

if(deleteTSV == 1)
    delete(fileNameTSV); % Only deletes TSV file if input is GZ zip file
end

dataCSV = readtable(fileNameCSV); % Reads in table data from CSV
dataMAT = table2array(dataCSV); % Converts table to array
delete(fileNameCSV); % Delete CSV file

%% Extract JSON Metadata
file_id = fopen(fileNameJSON);
contentJSON = char(fread(file_id, inf)');
fclose(file_id);

metadataJSON = jsondecode(contentJSON);

%% Extract blink data
blinkTable = dataMAT(:,ismember(metadataJSON.Columns,'Blinks')); % Blink data
LabelEvents = logical(blinkTable);
props = regionprops(LabelEvents, 'Area', 'PixelList');

blink_onset = cellfun(@(C) min(C(:,2)), {props.PixelList});
blink_offset = cellfun(@(C) max(C(:,2)), {props.PixelList});

% Start and end sample needed
blinkData = [blink_onset', blink_offset'];

buffer_samples = round((buffer_ms/1000)*metadataJSON.SamplingFrequency); %buffer in samples

idx_blinks = false(length(dataMAT),1);

idx_eyes = find(contains(metadataJSON.Columns, 'Gaze'));
idx_pupil = find(contains(metadataJSON.Columns, 'Pupil'));
idx_res = find(contains(metadataJSON.Columns, 'Resolution'));


%% Find blinks and set them to NaN
for ii = 1:length(blinkData)
    
    % Get index for start and end of blink
    idx_blink_start = blinkData(ii,1);
    idx_blink_end = blinkData(ii,2);
    
    % Extend with buffer_samples on each side of blink
    idx_blink_start = max(1,idx_blink_start-buffer_samples);
    idx_blink_end = min(length(dataMAT),idx_blink_end+buffer_samples);
    
    % Fill in with NaN
    dataMAT(idx_blink_start:idx_blink_end,[idx_eyes' idx_pupil' idx_res']) = NaN;
    idx_blinks(idx_blink_start:idx_blink_end) = true;
end

%% Fill in NaNs with linearly interpolated data
if strcmpi(blinkfilling,'interpolation') || strcmpi(blinkfilling,'interp')
    % take all the NaNs and use interpolation to fill in to values
    dataMAT = fillmissing(dataMAT,'linear','EndValues','nearest');
end


%% Filter eye tracking data to remove spurious blinks
no_taps = round(metadataJSON.SamplingFrequency*filter_length_eye);

if no_taps>0
    dataMAT(:,[idx_eyes' idx_pupil' idx_res']) = medfilt1(dataMAT(:,[idx_eyes' idx_pupil' idx_res'])-dataMAT(1,[idx_eyes' idx_pupil' idx_res']),no_taps) ...
        + dataMAT(1,[idx_eyes' idx_pupil' idx_res']);
end

%% Remove initial sample offsets in data
if dataMAT(1,1)~=mean(round(dataMAT(metadataJSON.SamplingFrequency*0.1,1)))
    dataMAT(1:5,:) = NaN;
    dataMAT = fillmissing(dataMAT,'linear','EndValues','extrap');
end

%% Check if NaN processing successful
if any(isnan(dataMAT(:)))
    error('NaNs not cleaned')
end

%% Add blink indices to data
dataMAT_blinks = [dataMAT, idx_blinks];

%% Save eye tracking data
% Edit metadata
metadataJSON.Columns = [metadataJSON.Columns; 'Interpolated_Samples'];

% Add description of column
metadataJSON.Interpolated_Samples.Description = sprintf('1 indicates interpolated samples based on blinks detected by eyelink; includes %i ms before and after blinks',buffer_ms);

% Save JSON Metadata
fid = fopen(outputJSON,'w');
try
    fprintf(fid,'%s',jsonencode(metadataJSON,PrettyPrint=true));
catch
    fprintf(fid,'%s',jsonencode(metadataJSON));
end
fclose(fid);


% Save preprocess eye tracking data
dlmwrite(outputTSV,dataMAT_blinks,'\t'); %#ok<DLMWT> 
gzip(outputTSV); % Compress file

if(exist([outputTSV,'.gz'],'file'))
    delete(outputTSV);
end

fileNameTSVGZ_blink = [outputTSV,'.gz'];
fileNameJSON_blink = outputJSON;