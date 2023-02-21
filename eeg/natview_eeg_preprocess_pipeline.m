function EEG = natview_eeg_preprocess_pipeline(fileNameSET,outputDir,saveIntermediates,options)
%% PURPOSE: This script preprocesses EEG data using EEGLAB functions
%           Simultaneously EEG and fMRI data was collected for the
%           NATVIEW_EEGFMRI dataset in a Siemens TrioTim 3T MRI scanner and
%           with Brain Products BrainCap MR at the Nathan Kline Institute
%           in Orangeburg, NY.
%
%           This script utilizes the following toolboxes/plugins:
%
%           EEGLAB (https://sccn.ucsd.edu/eeglab/index.php)
%           FMRIB Plug-In (https://fsl.fmrib.ox.ac.uk/eeglab/fmribplugin/)
%
%           The toolbox and plugins above remove various artificats
%           (gradient artifact, pulse artifact, etc.) and performs other
%           preprocessing steps to prepare EEG data for secondary analysis.
%
%           NOTE: This function uses the SET file format for file input 
%
%--------------------------------------------------------------------------
% INPUT:
%       fileNameSET - Filename of SET file
%
%         outputDir - Output directory for preprocessed EEG file(s)
%
% saveIntermediates - Flag to save intermediate preprocessing steps
%                     (Default: 0)
%
%           options - Input STRUCT for saving specific intermediate steps
%                     (Default: options.final = 1)
%
%--------------------------------------------------------------------------
%% Error Checking
% Output directory (Default: current working directory)
if(nargin < 2 || isempty(outputDir))
    outputDir = pwd;
end

% Save intermediate preprocessing files (Default: [])
if(nargin < 3 || isempty(saveIntermediates))
    saveIntermediates = [];
end

% Options STRUCT (Default: Only save final output)
% NOTE: User can edit default flags here to save specific intermediate steps
if(nargin < 4 || isempty(options))
    options.step1_gradient   = 0;
    options.step2a_qrs       = 0;
    options.step2b_pulse     = 0;
    options.step3_downsample = 0;
    options.step4_nonEEG     = 0;
    options.step5_bandpass   = 0;
    options.step6_bad        = 0;
    options.step7_asr        = 0;
    options.step8_reference  = 0;
    options.step9_ica        = 0;
    options.final            = 1;
end

if(~isfield(options,'final'))
    options.final = 1;
end
%% STEP 0: Load data into EEGLAB
[~,fileName] = fileparts(fileNameSET);
EEG = pop_loadset(fileNameSET); % Load SET file into MATLAB

underscore_idx = strfind(fileName,'_');
fileInfo = cell(length(underscore_idx),1);
for ii = 1:length(underscore_idx)
    if(ii==1)
        fileInfo{ii} = fileName(1:underscore_idx(1)-1);
    else
        fileInfo{ii} = fileName(underscore_idx(ii-1)+1:underscore_idx(ii)-1);
    end
end

% subject = fileInfo{1}; % Participant ID
% session = fileInfo{2}; % Session
task = fileInfo{3}(6:end); % Task Name

%% Non-EEG Channel specification
ECGChan = find(strcmp({EEG.chanlocs.labels},'ECG'));
EOGLChan = find(strcmp({EEG.chanlocs.labels},'EOGL'));
EOGUChan = find(strcmp({EEG.chanlocs.labels},'EOGU'));
electrodeExclude = [ECGChan,EOGLChan,EOGUChan];

%% STEP 1: Gradient Artifact Removal
% This step performs gradient artifact removal using FMRIB Toolbox
% Link: https://fsl.fmrib.ox.ac.uk/eeglab/fmribplugin/
if(strcmp(task,'checker') || ...
   strcmp(task,'dme') || ...
   strcmp(task,'dmh') || ...
   strcmp(task,'inscapes') || ...
   strcmp(task,'monkey1') || ...
   strcmp(task,'monkey2') || ...
   strcmp(task,'monkey5') || ...
   strcmp(task,'peer') || ...
   strcmp(task,'rest') || ...
   strcmp(task,'tp'))
    EEG = pop_fmrib_fastr(EEG,[],[],[],'R128',1,0,[],[],[],[],electrodeExclude,'auto'); % Remove gradient artifact
end

% Save intermediate
if(saveIntermediates == 1 && isfield(options, 'step1_gradient'))
    if(options.step1_gradient == 1)
        pop_saveset(EEG,'filename',[fileName,'_preprocess-1gradient'],'filepath',outputDir);
    end
end

%% STEP 2a: QRS Detection
% This step detects QRS complexes in the ECG channel. If the function fails
% to find QRS complex, QRS detection is performed on every EEG channel; the
% channel chosen for QRS detection equals the mode of the QRS counts
try
    EEG = pop_fmrib_qrsdetect(EEG,ECGChan,'QRS','no'); % FMRIB Toolbox QRS Detection
catch
    nChannels = EEG.nbchan;
    channelEEG = 1:nChannels;

    QRSCount = zeros(nChannels,1);
    channelError = zeros(nChannels,1);

    for nn = 1:nChannels
        try
            EEG_QRS = pop_fmrib_qrsdetect(EEG,channelEEG(nn),'QRS','no');
            eventLatency = extract_eventLatency(EEG_QRS,'QRS');

            if(length(eventLatency) > (EEG.xmax - 50) || nn ~= 32)
                QRSCount(nn) = length(eventLatency);
            end
        catch
            channelError(nn) = 1;
        end
    end

    channelEEG(QRSCount == 0) = [];
    QRSCount(QRSCount == 0) = [];

    [QRSCount_mode, QRSCount_modeNum] = mode(QRSCount);
    [QRSCount_sort, QRSCount_sort_idx] = sort(QRSCount);

    % Select mode of QRS counts if there are 3 or more else select the median
    % QRS number
    if(QRSCount_modeNum >= 3)
        QRSCount_mode_idx = find(QRSCount == QRSCount_mode);
    else
        if(length(QRSCount) == 1)
            QRSCount_mode_idx = 1;
        else
            QRSCount_mode_idx = QRSCount_sort_idx(find(diff(QRSCount_sort > median(QRSCount)))); %#ok<FNDSB>
        end
    end

    QRS_channel = channelEEG(QRSCount_mode_idx);

    EEG = pop_fmrib_qrsdetect(EEG,QRS_channel(1),'QRS','no'); % FMRIB Toolbox QRS Detection
    % disp(find(channelError==1));
end

% Save intermediate
if(saveIntermediates == 1 && isfield(options, 'step2a_qrs'))
    if(options.step2a_qrs == 1)
        pop_saveset(EEG,'filename',[fileName,'_preprocess-2aqrs'],'filepath',outputDir);
    end
end

%% STEP 2b: Pulse Artifact Removal
PAType = 'median'; % Template for pulse artifact (Default: median)

EEG = pop_fmrib_pas(EEG,'QRS',PAType); % Pulse Artifact removal

% Save intermediate
if(saveIntermediates == 1 && isfield(options, 'step2b_pulse'))
    if(options.step2b_pulse == 1)
        pop_saveset(EEG,'filename',[fileName,'_preprocess-2bpulse'],'filepath',outputDir);
    end
end

%% STEP 3: Downsample EEG data to 250Hz
resample_freq = 250;
EEG = pop_resample(EEG,resample_freq);
      
% Save intermediate
if(saveIntermediates == 1 && isfield(options, 'step3_downsample'))
    if(options.step3_downsample == 1)
        pop_saveset(EEG,'filename',[fileName,'_preprocess-3downsample'],'filepath',outputDir);
    end
end

%% STEP 4: Remove non-EEG channels (i.e., EOG and ECG)
EEG  = pop_select(EEG,'nochannel',electrodeExclude);

% Save intermediate
if(saveIntermediates == 1 && isfield(options, 'step4_nonEEG'))
    if(options.step4_nonEEG == 1)
        pop_saveset(EEG,'filename',[fileName,'_preprocess-4nonEEG'],'filepath',outputDir);
    end
end

%% STEP 5: Bandpass filter data
freq_lo = 0.3;
freq_hi = 50;
EEG = pop_eegfiltnew(EEG,'locutoff',freq_lo,'hicutoff',freq_hi);

% Save intermediate
if(saveIntermediates == 1 && isfield(options, 'step5_bandpass'))
    if(options.step5_bandpass == 1)
        pop_saveset(EEG,'filename',[fileName,'_preprocess-5bandpass'],'filepath',outputDir);
    end
end

%% STEP 6: Remove bad channels
EEG = pop_clean_rawdata(EEG,'FlatlineCriterion',5,...
                            'ChannelCriterion',0.8,...
                            'LineNoiseCriterion',4,...
                            'Highpass',[0.75 1.25],...
                            'BurstCriterion','off',...
                            'WindowCriterion','off',...
                            'BurstRejection','off',...
                            'Distance','Euclidian',...
                            'WindowCriterionTolerances','off');
  
% Save intermediate
if(saveIntermediates == 1 && isfield(options, 'step6_bad'))
    if(options.step6_bad == 1)
        pop_saveset(EEG,'filename',[fileName,'_preprocess-6bad'],'filepath',outputDir);
    end
end

%% STEP 7: Clear data using ASR
EEG = pop_clean_rawdata(EEG,'FlatlineCriterion','off',...
                            'ChannelCriterion','off',...
                            'LineNoiseCriterion','off', ...
                            'Highpass','off', ...
                            'BurstCriterion',20,...
                            'WindowCriterion',0.25, ...
                            'BurstRejection','on', ...
                            'Distance','Euclidian',...
                            'WindowCriterionTolerances',[-inf 7]);
                    
% Save intermediate
if(saveIntermediates == 1 && isfield(options, 'step7_asr'))
    if(options.step7_asr == 1)
        pop_saveset(EEG,'filename',[fileName,'_preprocess-7asr'],'filepath',outputDir);
    end
end

%% STEP 8: Rereference data using average reference
EEG = pop_reref(EEG,[]);
                    
% Save intermediate
if(saveIntermediates == 1 && isfield(options, 'step8_reference'))
    if(options.step8_reference == 1)
        pop_saveset(EEG,'filename',[fileName,'_preprocess-8reference'],'filepath',outputDir);
    end
end

%% STEP 9: computing ICA, flat IC using ICLabel, and removing the highly correlated ICs with muscle and eye artifacts
EEG = pop_runica(EEG,'icatype','runica','concatcond','on','options',{'pca',-1});
EEG = pop_iclabel(EEG,'default');
EEG = pop_icflag(EEG,[NaN NaN; 0.8 1; 0.8 1; NaN NaN; NaN NaN; NaN NaN; NaN NaN]);
EEG = pop_subcomp(EEG,[]);
            
% Save intermediate
if(saveIntermediates == 1 && isfield(options, 'step9_ica'))
    if(options.step9_ica == 1)
        pop_saveset(EEG,'filename',[fileName,'_preprocess-9ica'],'filepath',outputDir);
    end
end

%% STEP 10: Saving preprocessing data into output directory
if(isempty(saveIntermediates) || options.final == 1)
    pop_saveset(EEG,'filename',[fileName,'_preprocess'],'filepath',outputDir);
end

end
%% Subfunction: Extract Event Latency
function [eventLatency,event_idx] = extract_eventLatency(EEG,eventType)

X = zeros(length(EEG.event),1);
eventLatency = zeros(length(EEG.event),1);

for ii = 1:length(EEG.event)
    if(strcmp(EEG.event(ii).type,eventType))
        X(ii) = 1;
        eventLatency(ii) = EEG.event(ii).latency;
        
    end
end

eventLatency(X==0) = [];
event_idx = find(X==1);
end
