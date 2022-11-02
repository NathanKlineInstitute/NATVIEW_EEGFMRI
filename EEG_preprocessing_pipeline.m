% ************************************************************************
%
%   Code for preprocessing EEG data
%
%   Author: Eduardo Gonzalez Moreira
%   email:  eduardo.moreira@nki.rfmh.org
%   date:   11/01/2022
%
% ************************************************************************


%% cleaning
clc
clear
close all


%% adding eeglab folder and subfolders
eeglabdir = uigetdir('/home/meduardo/matlab/', 'Pick EEGLab toolbox directory:');
addpath(eeglabdir)
eeglab


%% data directory

% directory to read the raw data...
bidsdir   = uigetdir('/projects/EEG_FMRI/bids_eeg/BIDS', 'Pick a BIDS directory with raw data:');
datadir   = dir([bidsdir filesep 'sub*']);

% directory to save the preprocessed data...
outputdir = uigetdir('/projects/EEG_FMRI/bids_eeg/BIDS', 'Pick a directory for preprocessed data:');

% initial values
count = 0;
nonprocessedfile = [];


%% going into subject's folder
for ii = 1:numel(datadir)
    
    
    %% going into session's folder
    sessdir = dir([datadir(ii).folder filesep datadir(ii).name filesep 'ses*']);
    
    for ss =  1:numel(sessdir)
        
        
        %% going into eeg folder
        dataeeg = dir([sessdir(ii).folder filesep sessdir(ii).name filesep 'eeg' filesep '*.vhdr']);
        
        for tt = 1:numel(dataeeg)
            
            
            %% checking if preprocessed file exists
            nametmp = dataeeg(tt).name;
            nametmp(end-4:end) = [];
            try
                fileexist = exist([outputdir filesep nametmp '.set'],'file');
            catch me
                fileexist = 0;
            end
            
            
            %% preprocessing steps
            if ~fileexist
                
                tic
                
                fprintf('\n')
                fprintf('**************************************************************************\n')
                fprintf(['*       Processing file ' nametmp '        \n'])
                fprintf('**************************************************************************\n')
                fprintf('\n')
                try
                    %% reading brain vision file and cap layout
                    EEG               = pop_loadbv([dataeeg(tt).folder filesep],dataeeg(tt).name);
                    EEG.chanlocs      = loadbvef('BC-MR-64-X52.bvef');
                    EEG.chanlocs(1:2) = [];
                    
                    
                    %% step 1: downsampling to 250 Hz
                    EEG = pop_resample(EEG,250);
                    
                    
                    %% step 2: remove channels related to EOG and ECG
                    ind1 = find(strcmp({EEG.chanlocs.labels},'ECG'));
                    ind2 = find(strcmp({EEG.chanlocs.labels},'EOGL'));
                    ind3 = find(strcmp({EEG.chanlocs.labels},'EOGU'));
                    EEG  = pop_select(EEG,'nochannel',[ind1,ind2,ind3]);
                    
                    
                    %% step3: filtering, bandpass between 0.3 Hz to 50 Hz
                    EEG = pop_eegfiltnew(EEG,'locutoff',0.3,'hicutoff',50);
                    
                    
                    %% step 4: remove bad channels
                    EEG = pop_clean_rawdata(EEG,'FlatlineCriterion',5,'ChannelCriterion',0.8,...
                        'LineNoiseCriterion',4,'Highpass',[0.75 1.25],'BurstCriterion','off',...
                        'WindowCriterion','off','BurstRejection','off','Distance','Euclidian',...
                        'WindowCriterionTolerances','off');
                    
                    
                    %% step 5: clear data using ASR
                    EEG = pop_clean_rawdata(EEG,'FlatlineCriterion','off','ChannelCriterion','off',...
                        'LineNoiseCriterion','off','Highpass','off','BurstCriterion',20,...
                        'WindowCriterion',0.25,'BurstRejection','on','Distance','Euclidian',...
                        'WindowCriterionTolerances',[-inf 7]);
                    
                    
                    %% step 6: applying the average reference
                    EEG = pop_reref(EEG,[]);
                    
                    
                    %% step 7: computing ICA, flat IC using ICLabel, and removing the highly correlated ICs with muscle and eye artifacts
                    EEG = pop_runica(EEG,'icatype','runica','concatcond','on','options',{'pca',-1});
                    EEG = pop_iclabel(EEG,'default');
                    EEG = pop_icflag(EEG,[NaN NaN; 0.8 1; 0.8 1; NaN NaN; NaN NaN; NaN NaN; NaN NaN]);
                    EEG = pop_subcomp(EEG,[]);
                    
                    
                    %% saving preprocessing data into output directory
                    pop_saveset( EEG,'filename',nametmp,'filepath',outputdir);
                    
                    
                    %% printing
                    fprintf('\n')
                    fprintf('*******************************************\n')
                    fprintf('*****   file analysis is completed   ******\n')
                    fprintf('*******************************************\n')
                    fprintf('\n')
                    
                    
                catch me
                    
                    %% printing
                    fprintf('\n')
                    fprintf('****************************************\n')
                    fprintf('*****   error in preprocessing   *******\n')
                    fprintf('****************************************\n')
                    fprintf('\n')
                    
                    
                end
                
                toc
                
            end
            
        end
        
    end
    
end

fprintf('End...\n')
% End...




