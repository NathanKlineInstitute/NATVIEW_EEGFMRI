function natview_stimuli_checkerboard(input_frequency,stimulus_length,repetitions,gridSize,gridSpokes,eyeMode,scannerMode,monkeyMode)
%% PURPOSE:	Uses Psychtoolbox to display flickering circular checkerboard.
%           Checkerboard stimulus uses a block design with a period of rest
%           followed by a period of a flickering checkerboard. Users can
%           specify the flicker frequency, duration of the stimulus, the
%           number of rest-checkerboard repetitions as well as parameters
%           related to the grid size and spokes in the checkerboard.
%
%           This particular release has been modified to work with EyeLink
%           software from SR Research. Using the filename created by the
%           user, it sends trigger codes associated with the task to output
%           EDF file.
%
%           NOTE: Users must change parameter 'TR' to match the fMRI
%           sequence of their scanner.
%
%--------------------------------------------------------------------------
% INPUT:    input_frequency - Frequency rate of flickering checkerboard
%                             (Default: 12 Hz)
%
%           stimulus_length - Length of time of stimulus block in seconds
%                             (Default: 5)
%
%               repetitions - Number of times rest-stimulus block repeats
%                             (Default: 1)
%
%                  gridSize - Number of concentric circles (rows) in grid
%                             (Default: 9)
%
%                gridSpokes - Number of spokes comprised in grid
%                             (Default: 12)
%
%                   eyeMode - Flag to run task with EyeLink software and
%                             collect eye tracking data. When flag is on
%                             (=1), MATLAB interfaces with EyeLink software
%                             and records eye tracking data. When flag is
%                             off (=0), no data is collected.
%                             NOTE: Keep flag off if no eye tracker present
%                             (Default: 0)
%
%                 dummyMode - Flag to run task with EyeLink software or run
%                             in "dummy" mode. When flag is on (=1), MATLAB
%                             interfaces with EyeLink software and records
%                             eye tracking data. When running in dummy mode
%                             (=0), no data is collected.
%                             NOTE: Use this mode if not using eye tracker
%                             (Default: 0)
%
%               scannerMode - Flag to start task with MRI scanner or
%                             manually with keyboard. When flag is on (=1),
%                             scripts waits for scanner trigger to begin
%                             before task starts. When flag is off (=0),
%                             user can start task manually from keyboard.
%                             (Default: 0)
%
%                monkeyMode - Flag to run task with non-human primate (NHP)
%                             subjects. Human participants view projection
%                             screen using a mirror, so text appears in
%                             reverse, right to left. NHPs view projection
%                             screen in sphinx position, so text appears
%                             left to right.
% 
%                             When flag is on (=1), "monkey mode" is
%                             running, text display is left to right.
%
%                             When flag is off (=0), "human mode" is
%                             running, text display is right to left.
%                             (Default: 0)
%
%--------------------------------------------------------------------------
%
% EXAMPLE(S):
% >> natview_stimuli_checkerboard(10,20,5,10,15,1)
% * Subject shown flickering checkerboard with a flicker rate of 10Hz with
%   a stimulus duration of 20s (20s rest, 20s checkerboard) over 5
%   repetions (experiment length: 200s). The circular pattern contains 10
%   concentric circles with 15 spokes. This task run in dummy mode, so EDF
%   file is not saved.
%
% >> natview_stimuli_checkerboard(12,30,5,16,24)
% * Subject shown flickering checkerboard with a flicker rate of 12Hz with
%   a stimulus duration of 30s over 5 repetions (experiment length: 300s).
%   The circular pattern contains 16 concentric circles with 24 spokes.
%   Script saves EyeLink/EDF file with the name
%
%--------------------------------------------------------------------------
%% Task Start Parameters
% Modify the code here to change number of TRs to pause before task begins

TR = 2.1; % TR length in seconds of fMRI sequence
numTR = 1; % Number of TRs to wait before task begins
scannerPause = numTR*TR;

% Output directory default is MATLAB user path, but can be user specified
outputDir = userpath; % Output directory for eye tracking data

%% Error Checking
% Checks input(s) and use default if parameter(s) unused or left empty

% Frequency rate of flickering checkerboard
if(nargin < 1 || isempty(input_frequency))
    Hz = 12; 
else
    Hz = input_frequency;
end

% Length of time of stimulus block in seconds
if(nargin < 2 || isempty(stimulus_length))
    stimulus_length = 5;
end

% Number of times rest-stimulus block repeats
if(nargin < 3 || isempty(repetitions))
    nRepetitions = 1;
else
    nRepetitions = repetitions;
end

% Number of concentric circles (rows) in grid
if(nargin < 4 || isempty(gridSize))
    gridSize = 9;
end

% Number of spokes comprised in grid
if(nargin < 5 || isempty(gridSpokes))
    gridSpokes = 12;
end

% Eye Tracking Mode: Flag to run script with/without eye tracking
% Default: Run WITH NO eye tracking (eyeMode = 0)
if(nargin < 6 || isempty(eyeMode))
    eyeMode = 0;
end

% Dummy mode used if no eye tracker present or eye tracker not in use
if(eyeMode == 1)
    dummyMode = 0;
else
    dummyMode = 1;
end

% Scanner Mode: Flag to run task with trigger from scanner
% Default: Scanner OFF (scannerMode = 0), i.e., trigger task manually
if(nargin < 7 || isempty(scannerMode))
    scannerMode = 0;
end

% Monkey Mode: Flag to run task in monkey mode (reverse screen display)
% Default: Run on human participants (monkeyMode = 0)
if(nargin < 8 || isempty(monkeyMode))
    monkeyMode = 0;
end

% MATLAB Code analyzer suppression flags
%#ok<*NASGU> % Might be unused
%#ok<*UNRCH> % Cannot be reached

%% User Prompts/Input Parameters
% User will be prompted to enter seriesNum (series number from scanner) and
% runNum (repetition of video presentation). Input used for EDF filename.
% visitNum  = input('Please enter visit number: ');
seriesNum = input('Please enter series number (order after running prescan outside): ');
runNum    = input('Please enter run number: ');

%% Eye Tracking EDF File Naming
% This section of code combines user input and other parameters to generate
% a long and short filename for EDF file saved at the end of task

% Text output based on flickering frequency
outputFreqText = num2str(Hz,'%06.2f'); % Output format for flickering frequency
outputFreqText = strrep(outputFreqText,'.',''); % Remove decimal place from text
% NOTE: Output text format uses leading zeros and removes decimal places
%       Hz = 12     =>  outputFreqText = 01200
%       Hz = 5.25   =>  outputFreqText = 00525
%       Hz = 140.7  =>  outputFreqText = 14070

% Text output based on scannerMode
if(scannerMode == 1)
    outputName = ['Checkerboard_',outputFreqText,'Hz_ScannerON'];
    taskID = 'C'; % Scanner ON
    seriesID = 'S'; % S derived from 'series' on scanner console
else
    outputName = ['Checkerboard_',outputFreqText,'Hz_ScannerOFF'];
    taskID = 'B'; % Scanner OFF
    seriesID = 'P'; % P derived from 'prescan'
end

% Text output for current date (i.e, date data is collected)
currentDate = datetime('today'); % Get current date
dateText = [sprintf('%2.2d',year(currentDate)-2000),sprintf('%2.2d',month(currentDate)),sprintf('%2.2d',day(currentDate))]; % Format: yymmdd
dateTextFull = [sprintf('%4.4d',year(currentDate)),sprintf('%2.2d',month(currentDate)),sprintf('%2.2d',day(currentDate))]; % Format: yyyymmdd

% Text output for EDF filename
edfFileShort = [dateText,taskID,sprintf('%1.1d',runNum)]; % Short EDF filename
edfFileLong = ['EyeLink_',dateTextFull,'_',seriesID,sprintf('%2.2d',seriesNum),'_R',sprintf('%2.2d',runNum),'_',outputName]; % Long EDF filename

edf_outputDir = fullfile(outputDir,'EyeLink'); % EDF output directory
edf_outputDir_raw = fullfile(outputDir,'EyeLink','raw'); % EDF output directory for short filename (short filename saved as "raw" file)

if(~exist(edf_outputDir,'dir'))
    mkdir(edf_outputDir); % Create directory if it does not exist
end

if(~exist(edf_outputDir_raw,'dir'))
    mkdir(edf_outputDir_raw); % Create directory if it does not exist
end

outputEDF_fileName_short = fullfile(edf_outputDir_raw,[edfFileShort,'.edf']);
outputEDF_fileName_long = fullfile(edf_outputDir,[edfFileLong,'.edf']);

%% Keyboard Initialization (keyboard and trigger settings)
KbName('UnifyKeyNames');
KbQueueCreate;
KbQueueStart;
scannerTrigger = KbName('=+');
scannerWait = KbName('space');

EscKey = KbName('Escape');
BCKSpc = KbName('backspace');

keyboard = -1;
AllowedKeys = zeros(256,1); % Disable all keys
AllowedKeys([EscKey,BCKSpc,scannerWait]) = 1; % Allowed escape keys

%% EyeLink Setup
% EyeLink: STEP 1
% Added a dialog box to set your own EDF file name before opening
% experiment graphics. Make sure the entered EDF file name is 1 to 8
% characters in length and only numbers or letters are allowed.

% * Original code here used to prompt user for filename with pop-up prompt.
%   This has been changed to generate a filename automatically.
% prompt    = {'Enter tracker EDF file name (1 to 8 letters or numbers)'};
% dlg_title = 'Create EDF file';
% num_lines = 1;
% def       = {'DEMO'};
% answer    = inputdlg(prompt,dlg_title,num_lines,def);
% edfFile   = answer{1};

fprintft('EDFFile: %s\n', edfFileShort );

%% Trigger Setup/Event Code Settings
% The values in this section denote numeric value assigned to event codes 
triggers = false;
OSBit = 64; 
event_start = 1; % Begin task
event_end = 99; % End task
event_rest = 10; % Begin rest block
event_checker = 25; % Begin flickering checkerboard block
event_frame_rest1 = 11; % Rest block event code, 1s interval
event_frame_rest2 = 12; % Rest block event code, 2s interval
event_frame_checker1 = 26; % Checkerboard block event code, 1s interval
event_frame_checker2 = 27; % Checkerboard block event code, 1s interval

if triggers
    fprintft('Using triggers\n'); 
    triggerport = hex2dec('D050');
    if OSBit==64
        ioObject = setuptrigger_io64;
    end
else
    fprintft('Not using triggers\n');
end

%% Psychtoolbox/Screen Setup
% Here we call some default settings for setting up Psychtoolbox
PsychDefaultSetup(2);

% Get the screen numbers. Gives a number for each screen connected to computer.
screens = Screen('Screens');

% Draw to the external screen if avaliable
screenNumber = max(screens);

% Define black and white
white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);
grey = white/2;

% Open an on screen window
[window, windowRect] = PsychImaging('OpenWindow',screenNumber,black);

% Get the size of the on screen window
[screenXpixels, screenYpixels] = Screen('WindowSize', window);

% Get the centre coordinate of the window
[~, yCenter] = RectCenter(windowRect);

Screen('Flip',window);
Frametime=Screen('GetFlipInterval',window); % Find refresh rate in seconds

FramesPerFull = round(stimulus_length/Frametime); % Number of frames for all stimuli
FramesPerStim = round((1/Hz)/Frametime); % Number of frames for each stimulus


%% Crosshair Parameters
crossDim = 10;
cross_baseRect = [0 0 crossDim crossDim];

% Make the coordinates for our grid of squares
crossMesh = 2;
[cross_xPos, cross_yPos] = meshgrid(-crossMesh:1:crossMesh, -crossMesh:1:crossMesh);

% Calculate the number of squares and reshape the matrices of coordinates into a vector
[cross_s1, cross_s2] = size(cross_xPos);
cross_numSquares = cross_s1 * cross_s2;
cross_xPos = reshape(cross_xPos, 1, cross_numSquares);
cross_yPos = reshape(cross_yPos, 1, cross_numSquares);

% Scale the grid spacing to the size of our squares and centre
cross_xPosLeft = cross_xPos .* crossDim + screenXpixels * 0.5;
cross_yPosLeft = cross_yPos .* crossDim + yCenter;

% Crosshair grid
bwColorsC = [0 0 1 0 0; 0 0 1 0 0; 1 1 1 1 1; 0 0 1 0 0; 0 0 1 0 0];
bwColorsC = reshape(bwColorsC, 1, cross_numSquares);
bwColorsC = repmat(bwColorsC, 3, 1);

% Make our rectangle coordinates
cross_RectCoordinates = nan(4,3);
for ii = 1:cross_numSquares
    cross_RectCoordinates(:, ii) = CenterRectOnPointd(cross_baseRect,cross_xPosLeft(ii),cross_yPosLeft(ii));
end

%% Circular Grid Parameters
gridResolution=screenYpixels; % This parameter controls the resolution

h_gridRes=(gridResolution-1)/2;
[xx,yy]=meshgrid(-h_gridRes:h_gridRes);
[THETA,rr] = cart2pol(xx,yy);
rr=(rr./(gridResolution/2))*pi;
% r(r<0.04)=0; % uncomment to put a dot at the centre.
rr(rr>(pi+0.01))=inf; % uncomment if you want to get exact circle

f=sin(rr*gridSize); % 1st concentric filter
f1=sin(THETA*gridSpokes); % 1st radial filter
f1=f1>=0; % binarize
f11=f.*f1; % point-wise multiply
f=sin(rr*gridSize+pi); % 2nd concentric filter shifted by pi
f1=sin(THETA*gridSpokes+pi);% 2nd radial filter shifted by pi
f1=f1>=0; % binarize
f12 = f.*f1; % point-wise multiply
f =(f11+f12)>=0; % add the two filters and threshold
f_inv=(f11+f12)<=0; % add the two filters and threshold
checkerboard = double(f);
checkerboard_invert = double(f_inv);

%% EyeLink Initialization
trial = 1;
% STEP 3
% Provide Eyelink with details about the graphics environment
% and perform some initializations. The information is returned
% in a structure that also contains useful defaults
% and control codes (e.g. tracker state bit and Eyelink key values).
el=EyelinkInitDefaults(window);


% STEP 4
% Initialization of the connection with the Eyelink Gazetracker.
% exit program if this fails.
if ~EyelinkInit(dummyMode)
    fprintft('Eyelink Init aborted.\n');
    cleanup;  % cleanup function
    return;
end

% the following code is used to check the version of the eye tracker
% and version of the host software
sw_version = 0;

[~,vs]=Eyelink('GetTrackerVersion');
fprintft('Running experiment on a ''%s'' tracker.\n', vs );

% open file to record data to
ii = Eyelink('Openfile', edfFileShort);
if ii~=0
    fprintft('Cannot create EDF file ''%s'' ', edffilename);
    Eyelink( 'Shutdown');
    Screen('CloseAll');
    return;
end

Eyelink('command', 'add_file_preamble_text ''Recorded by EyelinkToolbox demo-experiment''');
[width, height]=Screen('WindowSize', screenNumber);


% STEP 5
% SET UP TRACKER CONFIGURATION
% Setting the proper recording resolution, proper calibration type,
% as well as the data file content;
Eyelink('command','screen_pixel_coords = %ld %ld %ld %ld', 0, 0, width-1, height-1);
Eyelink('message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, width-1, height-1);
% set calibration type.
if(monkeyMode == 1)
    % Change position of EyeLink calibration targets: https://github.com/Psychtoolbox-3/Psychtoolbox-3/blob/master/Psychtoolbox/PsychHardware/EyelinkToolbox/EyelinkDemos/SR-ResearchDemo/ELCustomCalibration/EyelinkPictureCustomCalibration.m
    Eyelink('command', 'calibration_type = HV3'); % Number of points for calibration
    
    % CHANGE EYELINK TARGET POSITIONS
    Eyelink('command', 'generate_default_targets = NO');
    Eyelink('command', 'calibration_samples = 3');
    Eyelink('command', 'calibration_sequence = 0,1,2');
    Eyelink('command', 'calibration_targets = %d,%d %d,%d %d,%d',round(width*0.5),round(height*0.2), round(width*0.2),round(height*0.8), round(width*0.8),round(height*0.8));
    % Eyelink('command', 'calibration_targets = %d,%d %d,%d %d,%d',320,100, 100,320, 540,320 );
    Eyelink('command', 'validation_samples = 3');
    Eyelink('command', 'validation_sequence = 0,1,2');
    Eyelink('command', 'validation_targets = %d,%d %d,%d %d,%d',round(width*0.5),round(height*0.2), round(width*0.2),round(height*0.8), round(width*0.8),round(height*0.8));
    % Eyelink('command', 'validation_targets = %d,%d %d,%d %d,%d',320,100, 100,320, 540,320 );

    % Eyelink('command', 'calibration_targets = %d,%d %d,%d %d,%d',320,440, 40,40, 600,40 );
else
    Eyelink('command','calibration_type = HV9'); % Number of points for calibration
end

% set parser (conservative saccade thresholds)

% set EDF file contents using the file_sample_data and
% file-event_filter commands
% set link data thtough link_sample_data and link_event_filter
Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
Eyelink('command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');

% check the software version
% add "HTARGET" to record possible target data for EyeLink Remote
if sw_version >=4
    Eyelink('command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,HTARGET,GAZERES,STATUS,INPUT');
    Eyelink('command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,HTARGET,STATUS,INPUT');
else
    Eyelink('command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS,INPUT');
    Eyelink('command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS,INPUT');
end

% allow to use the big button on the eyelink gamepad to accept the
% calibration/drift correction target
Eyelink('command', 'button_function 5 "accept_target_fixation"');

% make sure we're still connected.
if Eyelink('IsConnected')~=1 && dummyMode == 0
    fprintf('not connected, clean up\n');
    Eyelink( 'Shutdown');
    Screen('CloseAll');
    return;
end


% STEP 6
% Calibrate the eye tracker
% setup the proper calibration foreground and background colors
el.backgroundcolour = 0.5*[grey grey grey];
el.calibrationtargetcolour = [1 1 1];

% parameters are in frequency, volume, and duration
% set the second value in each line to 0 to turn off the sound
el.cal_target_beep=[600 0 0.05];
el.drift_correction_target_beep=[600 0 0.05];
el.calibration_failed_beep=[400 0 0.25];
el.calibration_success_beep=[800 0 0.25];
el.drift_correction_failed_beep=[400 0 0.25];
el.drift_correction_success_beep=[800 0 0.25];

% you must call this function to apply the changes from above
EyelinkUpdateDefaults(el);

% Hide the mouse cursor;
Screen('HideCursorHelper', window);
EyelinkDoTrackerSetup(el);

%% Start collection of EyelLink data
% STEP 7
% Now starts running individual trials;
% You can keep the rest of the code except for the implementation
% of graphics and event monitoring
% Each trial should have a pair of "StartRecording" and "StopRecording"
% calls as well integration messages to the data file (message to mark
% the time of critical events and the image/interest area/condition
% information for the trial)

% STEP 7.1
% Sending a 'TRIALID' message to mark the start of a trial in Data
% Viewer.  This is different than the start of recording message
% START that is logged when the trial recording begins. The viewer
% will not parse any messages, events, or samples, that exist in
% the data file prior to this message.
Eyelink('Message', 'TRIALID %d', trial);

% STEP 7.2
% Do a drift correction at the beginning of each trial
% Performing drift correction (checking) is optional for
% EyeLink 1000 eye trackers.
if(monkeyMode ~= 1)
    EyelinkDoDriftCorrection(el); % Only do drift correction for humans
end

% Show the black background after black screen
el.backgroundcolour = [0 0 0];
Screen('FillRect', window, el.backgroundcolour);

% STEP 7.3
% start recording eye position (preceded by a short pause so that
% the tracker can finish the mode transition)
% The paramerters for the 'StartRecording' call controls the
% file_samples, file_events, link_samples, link_events availability
Eyelink('Command', 'set_idle_mode');
WaitSecs(0.05);

Eyelink('StartRecording');
% record a few samples before we actually start displaying
% otherwise you may lose a few msec of data
WaitSecs(0.1);

%% Convert grid to image, stretch to screen height
% Make the image into a texture
Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
checkerboardTexture = Screen('MakeTexture', window, checkerboard);
checkerboard_invertTexture = Screen('MakeTexture', window, checkerboard_invert);

% Get the size of the image
[s1, s2] = size(checkerboardTexture);

% Get the aspect ratio of the image. We need this to maintain the aspect
% ratio of the image when we draw it different sizes. Otherwise, if we
% don't match the aspect ratio the image will appear warped / stretched
aspectRatio = s2/s1;

% Set the height of drawn image to a fraction of the screen height
heightScalers = 1; % Apparent height of image relative to screen size
imageHeights = screenYpixels .* heightScalers;
imageWidths = imageHeights .* aspectRatio;

% Make the destination rectangles for our image
dstRects = zeros(4,1);
theRect = [0 0 imageWidths imageHeights];
dstRects(:,1) = CenterRectOnPointd(theRect,screenXpixels/2,screenYpixels/2);
    
% Draw the image to the screen, unless otherwise specified PTB will draw
% the texture full size in the center of the screen.
% Screen('DrawTextures', window, imageTexture, [], dstRects);

%% Scanner Trigger
% Add Scanner waiting screen
% [screenXpixels, screenYpixels] = Screen('WindowSize', window);
% Screen('TextSize', window, 70);
% DrawFormattedText(window, 'Waiting for Scanner', 'center',screenYpixels * 0.5, [1 1 1]);

while 1
    [~, firstPress] = KbQueueCheck();
        
    if(firstPress(scannerTrigger))
        % startExperiment = GetSecs;
        Eyelink('Message','SCANNER START');
        break
    end
end

WaitSecs(scannerPause);

%% Checkerboard Stimulus
HideCursor;
KbReleaseWait;
% StartC = zeros(nRepetitions,1);
% StartR = zeros(nRepetitions,1);

% Make sure all triggers are "turned off"
if triggers
    sendtrigger_io64(ioObject,triggerport,0);
end

% Send start trigger
if triggers
    sendtrigger_io64(ioObject,triggerport,event_start,0.002); % Changed code here to make code match sampling of BrainVision EEG system, TR was 0.002 originally
    Eyelink('Message','TASK START');
end

for nn = 1:nRepetitions
    repetitionFlip = 0;
    Framecounter = 0; % Frame counter begins at 0
    if triggers
        sendtrigger_io64(ioObject,triggerport,event_rest,0.002); % Changed code here to make code match sampling of BrainVision EEG system, TR was 0.002 originally
        Eyelink('Message',['REST START: N = ',sprintf('%2.1d',nn)]);
        % trigger_rest = trigger_rest + 1;
    end
    while 1
        if Framecounter==FramesPerFull
            break; %End session
        end
        
        if ~mod(Framecounter,FramesPerStim)
            bwRect = bwColorsC;
        end
        
        if(mod(Framecounter,60)==0)
            if triggers
                sendtrigger_io64(ioObject,triggerport,event_frame_rest1,0.002); % Changed code here to make code match sampling of BrainVision EEG system, TR was 0.002 originally
                Eyelink('Message',['REST BLOCK 1s: N = ',sprintf('%2.1d',nn),' | FRAME = ',sprintf('%4.1d',Framecounter)]);
                % trigger_rest = trigger_rest + 1;
            end
        end
        
        if(mod(Framecounter,120)==0)
            if triggers
                sendtrigger_io64(ioObject,triggerport,event_frame_rest2,0.002); % Changed code here to make code match sampling of BrainVision EEG system, TR was 0.002 originally
                Eyelink('Message',['REST BLOCK 2s: N = ',sprintf('%2.1d',nn),' | FRAME = ',sprintf('%4.1d',Framecounter)]);
                % trigger_rest = trigger_rest + 1;
            end
        end
        
        Screen('FillRect', window, bwRect, cross_RectCoordinates);
        Screen('Flip', window);
        Framecounter = Framecounter + 1; %Increase frame counter
    end
    
    Framecounter = 0;
    % StartC(nn) = GetSecs; %Measure start time of session
    if triggers
        sendtrigger_io64(ioObject,triggerport,event_checker,0.002); % Changed code here to make code match sampling of BrainVision EEG system, TR was 0.002 originally
        Eyelink('Message',['CHECKERBOARD START: N = ',sprintf('%2.1d',nn)]);
        % trigger_checker = trigger_checker + 1;
    end
    while 1 
        if Framecounter==FramesPerFull
            break; %End session
        end
        
        if ~mod(Framecounter,FramesPerStim)
            if(repetitionFlip == 0)
                bwRect = checkerboardTexture;
                repetitionFlip = 1;
            elseif(repetitionFlip == 1)
                bwRect = checkerboard_invertTexture;
                repetitionFlip = 0;
            end
        end
        
        if(mod(Framecounter,60)==0)
            if triggers
                sendtrigger_io64(ioObject,triggerport,event_frame_checker1,0.002); % Changed code here to make code match sampling of BrainVision EEG system, TR was 0.002 originally
                Eyelink('Message',['CHECKERBOARD BLOCK 1s: N = ',sprintf('%2.1d',nn),' | FRAME = ',sprintf('%4.1d',Framecounter)]);
                % trigger_rest = trigger_rest + 1;
            end
        end
        
        if(mod(Framecounter,120)==0)
            if triggers
                sendtrigger_io64(ioObject,triggerport,event_frame_checker2,0.002); % Changed code here to make code match sampling of BrainVision EEG system, TR was 0.002 originally
                Eyelink('Message',['CHECKERBOARD BLOCK 2s: N = ',sprintf('%2.1d',nn),' | FRAME = ',sprintf('%4.1d',Framecounter)]);
                % trigger_rest = trigger_rest + 1;
            end
        end
        
        Screen('DrawTextures', window, bwRect, [], dstRects);
        % Screen('DrawTextures', window, imageTexture, [], dstRects);
        % Screen('FillRect', window, bwRect, allRectsLeft);
        % Screen('FillRect', window, randomcolour, windowRect);
        Screen('Flip',window);
        
        Framecounter = Framecounter + 1; %Increase frame counter
    end
end

if triggers
    sendtrigger_io64(ioObject,triggerport,event_end,0.002); % Changed code here to make code match sampling of BrainVision EEG system, TR was 0.002 originally
    Eyelink('Message','TASK END');
end
% EndT = GetSecs; %Measure end time of session
% timeElapsed = EndT - StartT; %Shows full length of time all stimuli were presented

Screen('Flip', window);

% adds 100 msec of data to catch final events
WaitSecs(0.1);

% stop the recording of eye-movements for the current trial
Eyelink('StopRecording');

% STEP 7.7
% Send out necessary integration messages for data analysis
% Send out interest area information for the trial
% See "Protocol for EyeLink Data to Viewer Integration-> Interest
% Area Commands" section of the EyeLink Data Viewer User Manual
% IMPORTANT! Don't send too many messages in a very short period of time or
% the EyeLink tracker may not be able to write them all to the EDF file.
% Consider adding a short delay every few messages.

% Please note that  floor(A) is used to round A to the nearest integers less than or equal to A

WaitSecs(0.001);
Eyelink('Message', '!V IAREA ELLIPSE %d %d %d %d %d %s', 1, floor(width/2)-50, floor(height/2)-50, floor(width/2)+50, floor(height/2)+50,'center');
Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d %s', 2, floor(width/4)-50, floor(height/2)-50, floor(width/4)+50, floor(height/2)+50,'left');
Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d %s', 3, floor(3*width/4)-50, floor(height/2)-50, floor(3*width/4)+50, floor(height/2)+50,'right');
Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d %s', 4, floor(width/2)-50, floor(height/4)-50, floor(width/2)+50, floor(height/4)+50,'up');
Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d %s', 5, floor(width/2)-50, floor(3*height/4)-50, floor(width/2)+50, floor(3*height/4)+50,'down');

% Send messages to report trial condition information
% Each message may be a pair of trial condition variable and its
% corresponding value follwing the '!V TRIAL_VAR' token message
% See "Protocol for EyeLink Data to Viewer Integration-> Trial
% Message Commands" section of the EyeLink Data Viewer User Manual
WaitSecs(0.001);
Eyelink('Message', '!V TRIAL_VAR index %d', trial)
% Eyelink('Message', '!V TRIAL_VAR imgfile %s', imgfile)

% STEP 7.8
% Sending a 'TRIAL_RESULT' message to mark the end of a trial in
% Data Viewer. This is different than the end of recording message
% END that is logged when the trial recording ends. The viewer will
% not parse any messages, events, or samples that exist in the data
% file after this message.
Eyelink('Message', 'TRIAL_RESULT 0')

%% End Experiment and save data
% STEP 8
% End of Experiment; close the file first
% close graphics window, close data file and shut down tracker

Eyelink('Command', 'set_idle_mode');
WaitSecs(0.5);
Eyelink('CloseFile');

% download data file
try
    fprintf('Receiving data file ''%s''\n', edfFileShort );
    status=Eyelink('ReceiveFile');
    if status > 0
        fprintf('ReceiveFile status %d\n', status);
    end
    if 2==exist(edfFileShort, 'file')
        fprintf('Data file ''%s'' can be found in ''%s''\n', edfFileShort, pwd );
    end
catch
    fprintf('Problem receiving data file ''%s''\n', edfFileShort );
end

% STEP 9
% close the eye tracker and window
Eyelink('command', 'generate_default_targets = YES');
Eyelink('ShutDown');
if(dummyMode == 0)
    movefile([edfFileShort,'.edf'],outputEDF_fileName_short);
    copyfile(outputEDF_fileName_short,outputEDF_fileName_long);
end
sca;
