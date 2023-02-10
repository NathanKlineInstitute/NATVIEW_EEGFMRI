function natview_stimuli_video(videoName,playbackTime,dummyMode,monkeyMode)      
%% PURPOSE: Script runs Psychtoolbox with the EyeLink 1000 eye tracker.
%           Script plays user-specified videos for participants in various
%           modes.
%
% INPUT:
%   videoName: Code for name of video to played (case insensitive) or full
%              pathname for video
%              ------------------
%               Video Name Guide
%              ------------------    
%            * Despicable Me (English) = 'DME' or 'DM' or 'DespicableMeEng' (600)
%            * Despicable Me (Hungarian) = 'DMH' or 'DespicableMeHun' (600)
%            * The Present = 'TP' or 'ThePresent' (270)
%            * Inscapes = 'INS' or 'Inscapes' (600)
%            * Rest = 'RST' or 'Rest'
%            * Monkey 1 = 'M1' or 'Monkey1' or 'Movie1' (300)
%            * Monkey 2 = 'M2' or 'Monkey2' or 'Movie2' (300)
%            * Monkey 5 = 'M5' or 'Monkey5' or 'Movie5' (300)
%
%              ---------------------------------
%               VideoID (not specified by user)
%              ---------------------------------
%            * Debug/Demo/Default = 'X'
%            * Despicable Me (English) = 'D'
%            * Despicable Me (Hungarian) = 'H'
%            * The Present = 'P'
%            * Inscapes = 'I'
%            * Rest = 'R'
%            * Monkey 1 = 'M'
%            * Monkey 2 = 'N'
%            * Monkey 5 = 'O'
%
%   dummyMode:	Flag runs EyeLink 1000 in dummy mode (no eye tracking)
%               NOTE: If 0, script will crash if eye tracker not connected
%               (Default: 0)
%
%
%   monkeyMode: Flag for running monkeys in scanner in the sphinx position
%               * Video flipped horizontally
%               * Three fixation points used for eye tracker calibration
%               * No drift check before each trial/video
%               (Default: 0)
%
%
%   stop_time:  Length of time to show video (in seconds)
%               (Default: 900)
%
% OUTPUT:
%   edfFile: EyeLink 1000 eye tracking data
%            NOTE: EDF file name uses current date, VideoID, and run number
%                  EDF fileName: YYYYMMDD<VideoID><runNum>
%
% EXAMPLE:
%   >> EyeLink_video('DM');
%   * Shows entire clip of Despicable Me (English) with eye tracking
%
%   >> EyeLink_video('M2',40,0,1);
%   * Shows 40s of Monkey2 video with no eye tracking and in monkey mode
%
%   >> EyeLink_video('TP',[],1,1);
%   * Shows entire clip of The Present with eye tracking and in monkey mode
%
%   >> EyeLink_video('INS',300,0,0);
%   * Shows 300s of Inscapes2 video with no eye tracking
%
%   >> EyeLink_video('Custom.avi');
%   * Shows entire clip of Custom.avi with eye tracking (file in C:\Video)
%
%   >> EyeLink_video('C:\Test\Custom.avi',[],1,0);
%   * Shows entire clip of Custom.avi with eye tracking (file in C:\Test)
%--------------------------------------------------------------------------
%% Task Start Parameters
% Modify the code here to change number of TRs to pause before task begins

TR = 2.1; % TR length in seconds of fMRI sequence
numTR = 1; % Number of TRs to wait before task begins
scannerPause = numTR*TR;

%% Error Checking
% Checks input(s) and use default if parameter(s) unused or left empty
outputDir = userpath;
cd(outputDir); % Go to MATLAB user path

% Video Name: Code of filename for video
if(nargin < 1 || isempty(videoName))
    videoName = 'demo';
end

% Check input videoName validity
if(iscell(videoName))
    if(size(videoName,1) > 1 || size(videoName,2) > 1)
        error('Input videoName wrong size, input must be string or cell string.');
    else
        if(ischar(videoName{:}))
            videoName = videoName{:};
        else
            error('Input videoName does not contain string, input must be string or cell string.');
        end
    end
elseif(ischar(videoName))
    fprintft('Video File: %s\n', videoName );
    fprintft('Valid input...\n');
else
    error('Input videoName does not contain string, input must be string or cell string.');
end

% Playback Time: Length of time video is shown (in seconds)
if(nargin < 2 || isempty(playbackTime))
    playbackTime = 900;
end

% Eye Tracking Mode: Flag to run script with/without eye tracking
% Default: Run WITH eye tracking (dummyMode = 0)
if(nargin < 3 || isempty(dummyMode))
    dummyMode = 0;
end

% Monkey Mode: Flag to run task in monkey mode (reverse screen display)
% Default: Run on human participants (monkeyMode = 0)
if(nargin < 4 || isempty(monkeyMode))
    monkeyMode = 0;
end

%% Input video file check
% Video filename and ID coding: The code here takes the user input and
% selects proper output names for EDF file. The file is initially saved as
% an 8-character alphanumeric filename and renamed to a longer filename to
% match study filename convention. If user wants to use file not currently
% in "Video Name Guide," then enter full pathname of file.
videoDir = 'C:\Video\';
[fileDir,fileName,fileExt] = fileparts(videoName);

if(strcmp(videoDir,fileDir) || isempty(fileDir))
    videoName = [fileName,fileExt];
    if(strcmpi(videoName,'DM') || strcmpi(videoName,'DME') || strcmpi(videoName,'DespicableMeEng') || strcmpi(videoName,'Despicable_Me_720x480_English') || strcmpi(videoName,'Despicable_Me_720x480_English.avi'))
        outputName = 'DespicableMeEng';
        videoFile = 'Despicable_Me_720x480_English.avi';
        videoID = 'D';
    elseif(strcmpi(videoName,'DMH') || strcmpi(videoName,'DespicableMeHun') || strcmpi(videoName,'Despicable_Me_720x480_Hungarian') || strcmpi(videoName,'Despicable_Me_720x480_Hungarian.avi'))
        outputName = 'DespicableMeHun';
        videoFile = 'Despicable_Me_720x480_Hungarian.avi';
        videoID = 'H';
    elseif(strcmpi(videoName,'TP') || strcmpi(videoName,'ThePresent') || strcmpi(videoName,'The_Present_720x480') || strcmpi(videoName,'The_Present_720x480.avi'))
        outputName = 'ThePresent';
        videoFile = 'The_Present_720x480.avi';
        videoID = 'P';
    elseif(strcmpi(videoName,'INS') || strcmpi(videoName,'Inscapes') || strcmpi(videoName,'Inscapes_02') || strcmpi(videoName,'Inscapes_02.avi'))
        outputName = 'Inscapes2';
        videoFile = 'Inscapes_02.avi';
        videoID = 'I';
    elseif(strcmpi(videoName,'RST') || strcmpi(videoName,'Rest'))
        outputName = 'Rest';
        videoFile = [];
        videoID = 'R';
    elseif(strcmpi(videoName,'M1') || strcmpi(videoName,'Monkey1') || strcmpi(videoName,'Movie1') || strcmpi(videoName,'Movie1.avi'))
        outputName = 'Monkey1';
        videoFile = 'Movie1.avi';
        videoID = 'M';
    elseif(strcmpi(videoName,'M2') || strcmpi(videoName,'Monkey2') || strcmpi(videoName,'Movie2') || strcmpi(videoName,'Movie2.avi'))
        outputName = 'Monkey2';
        videoFile = 'Movie2.avi';
        videoID = 'N';
    elseif(strcmpi(videoName,'M5') || strcmpi(videoName,'Monkey5') || strcmpi(videoName,'Movie5') || strcmpi(videoName,'Movie5.avi'))
        outputName = 'Monkey5';
        videoFile = 'Movie5.avi';
        videoID = 'O';
    elseif(strcmpi(videoName,'debug') || strcmpi(videoName,'default') || strcmpi(videoName,'demo'))
        outputName = 'DEMO';
        videoFile = 'Despicable_Me_720x480_English.avi';
        videoID = 'X';
    else
        % If user enters full path and filename does not match any videos
        % above, then outputName set to video filename and video set to 'U'
        outputName = 'custom';
        videoFile = videoName;
        videoID = 'custom';
    end
else
    
    % If user enters full path with directory other than videoDir, then
    % outputName will be taken from video filename and videoID set to 'U'
    videoDir = fileDir;
    videoName = [fileName,fileExt];
    outputName = 'custom';
    videoFile = videoName;
    videoID = 'custom';
end

video_fileName = fullfile(videoDir,videoFile);

if(strcmp(outputName,'custom'))
    outputName = input('Please enter output name for EyeLink file: ','s');
    while(strcmp(videoID,'custom'))
        videoID = input('Please enter letter for EyeLink short filename (A-Z, except B,C,D,H,I,M,N,O,P,R,X): ','s');
        if(strcmpi(videoID,'D') || strcmpi(videoID,'H') || strcmpi(videoID,'P') || ...
           strcmpi(videoID,'I') || strcmpi(videoID,'R') || strcmpi(videoID,'M') || ...
           strcmpi(videoID,'N') || strcmpi(videoID,'O') || strcmpi(videoID,'X') || isnumeric(videoID))
            disp('Input code not valid, please select valid letter (A-Z, except B,C,D,H,I,M,N,O,P,R,X).');
            videoID = 'custom';
        end
    end
end

fprintf('    Input Name: %s\n',videoName);
fprintf('    Video Path: %s\n',video_fileName);
fprintf('    Video File: %s\n',videoFile);
fprintf('EyeLink Output: %s\n',outputName);
fprintf('    EyeLink ID: %s\n',videoID);

if(~isempty(videoFile))
    if(~exist(video_fileName,'file'))
        error('Input video does not exist, please check directory, filename, file extension.')
    end
end

%% User Prompts/Input Parameters
% User will be prompted to enter seriesNum (series number from scanner) and
% runNum (repetition of video presentation). Input used for EDF filename.
% visitNum  = input('Please enter visit number: ');
seriesNum = input('Please enter series number (order at scanner console): ');
runNum    = input('Please enter run number: ');

nRepetitions = 1;	% Number of times movie is shown to participant
movieRate = 1;      % Movie playback speed

%% Keyboard Initialization (keyboard and trigger settings)
KbName('UnifyKeyNames');
KbQueueCreate;
KbQueueStart;
scannerTrigger = KbName('=+');
scannerWait = KbName('space');

EscKey = KbName('Escape');
BCKSpc = KbName('backspace');

keyboard = -1; %#ok<NASGU>
AllowedKeys = zeros(256,1); % Disable all keys
AllowedKeys([EscKey,BCKSpc,scannerWait]) = 1; %#ok<NASGU> % Allowed escape keys

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

% Get current date for usage in EDF filenames
currentDate = datetime('today'); % Get current date
dateText = [sprintf('%2.2d',year(currentDate)-2000),sprintf('%2.2d',month(currentDate)),sprintf('%2.2d',day(currentDate))];
dateTextFull = [sprintf('%4.4d',year(currentDate)),sprintf('%2.2d',month(currentDate)),sprintf('%2.2d',day(currentDate))];

% EDF filename and output directory
edf_outputDir = 'C:\EyeLink';
edfFile = [dateText,videoID,sprintf('%1.1d',runNum)];

% fprintft('EDFFile: %s\n', edfFile );
fprintf('EDFFile: %s\n', edfFile );

%% Trigger Setup/Settings
triggers = false;
OSBit = 64;
trigger_start = 1;
trigger_end = 99;
trigger_frame = 5;

if triggers
    fprintft('Using triggers\n');
    triggerport = hex2dec('D050');
    if OSBit==64
        ioObject = setuptrigger_io64;
    end
else
    fprintft('Not using triggers\n');
end

%% Display Black Screen
PsychDefaultSetup(2);

% EyeLink: STEP 2
% Open graphics window on main screen using PsychToolbox Screen function.
% Get the screen numbers. This gives us a number for each of the screens
% attached to our computer.
screens = Screen('Screens');

% We select the maximum of these numbers. So in a situation where we have
% two screens attached to our monitor we will draw to the external screen.
% When only one screen is attached to the monitor we will draw to this.
screenNumber = max(screens);

% Define black (white will be 1 and black 0). This is because luminace
% values are (in general) defined between 0 and 1.
white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);
grey = white/2;

% Open an on screen window
[window, windowRect] = PsychImaging('OpenWindow',screenNumber,black);

% Get the size of the on screen window
[screenXpixels, ~] = Screen('WindowSize', window);

% Get the centre coordinate of the window
[~, yCenter] = RectCenter(windowRect);

Screen('Flip',window);
Frametime=Screen('GetFlipInterval',window); % Find refresh rate in seconds
Hz = 1;
FramesPerFull = round(playbackTime/Frametime); % Number of frames for all stimuli
FramesPerStim = round((1/Hz)/Frametime); % Number of frames for each stimulus

% ORIGINAL STEP 2:
% Open a graphics window on the main screen using the PsychToolbox's Screen function.
% screenNumber=max(Screen('Screens'));
% [window, wRect]=Screen('OpenWindow', screenNumber, 0,[],32,2);
% Screen(window,'BlendFunction',GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

%% Rest/Crosshair Parameters:
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
if(strcmp(outputName,'Rest2'))
    bwColorsC = [0 0 0 0 0; 0 0 0 0 0; 0 0 0 0 0; 0 0 0 0 0; 0 0 0 0 0];
else
    bwColorsC = [0 0 1 0 0; 0 0 1 0 0; 1 1 1 1 1; 0 0 1 0 0; 0 0 1 0 0];
end

bwColorsC = reshape(bwColorsC, 1, cross_numSquares);
bwColorsC = repmat(bwColorsC, 3, 1);

% Make our rectangle coordinates
cross_RectCoordinates = nan(4,3);
for ii = 1:cross_numSquares
    cross_RectCoordinates(:, ii) = CenterRectOnPointd(cross_baseRect,cross_xPosLeft(ii),cross_yPosLeft(ii));
end

%% EyeLink Initialization
trial = 1;

% STEP 3
% Provide Eyelink with details about the graphics environment and perform
% some initializations. The information is returned in a structure that
% also contains useful defaults and control codes (e.g. tracker state bit
% and Eyelink key values).
el = EyelinkInitDefaults(window);


% STEP 4
% Initialization of the connection with the Eyelink Gazetracker.
% Exit program if this fails.
if(~EyelinkInit(dummyMode))
    % fprintft('Eyelink Init aborted.\n');
    fprintf('Eyelink Init aborted.\n');
    cleanup;  % cleanup function
    return;
end

% Checks version of the eye tracker and version of the host software
sw_version = 0;

% [v,vs] = Eyelink('GetTrackerVersion');
[~,vs] = Eyelink('GetTrackerVersion');
% fprintft('Running experiment on a ''%s'' tracker.\n', vs);
fprintf('Running experiment on a ''%s'' tracker.\n', vs);

% open file to record data to
ii = Eyelink('Openfile', edfFile);
if(ii ~= 0)
    % fprintft('Cannot create EDF file ''%s'' ', edfFile);
    fprintf('Cannot create EDF file ''%s'' ', edfFile);
    Eyelink('Shutdown');
    Screen('CloseAll');
    return;
end

Eyelink('command', 'add_file_preamble_text ''Recorded by EyelinkToolbox demo-experiment''');
[width, height]=Screen('WindowSize', screenNumber);


% STEP 5
% SET UP TRACKER CONFIGURATION
% Setting the proper recording resolution, proper calibration type, as well as the data file content;
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

% set EDF file contents using the file_sample_data and file-event_filter commands
Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');

% set link data thtough link_sample_data and link_event_filter
Eyelink('command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');

% check the software version
% add "HTARGET" to record possible target data for EyeLink Remote
if(sw_version >= 4)
    Eyelink('command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,HTARGET,GAZERES,STATUS,INPUT');
    Eyelink('command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,HTARGET,STATUS,INPUT');
else
    Eyelink('command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS,INPUT');
    Eyelink('command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS,INPUT');
end

% allow to use the big button on the eyelink gamepad to accept the calibration/drift correction target
Eyelink('command', 'button_function 5 "accept_target_fixation"');

% make sure we're still connected.
if(Eyelink('IsConnected')~=1 && dummyMode == 0)
    fprintf('not connected, clean up\n');
    Eyelink('Shutdown');
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
% Now starts running individual trials; You can keep the rest of the code
% except for the implementation of graphics and event monitoring. Each
% trial should have a pair of "StartRecording" and "StopRecording" calls as
% well integration messages to the data file (message to mark the time of
% critical events and the image/interest area/condition information for the trial)

% STEP 7.1
% Sending a 'TRIALID' message to mark the start of a trial in Data Viewer.
% This is different than the start of recording message START that is logged
% when the trial recording begins. The viewer will not parse any messages,
% events, or samples, that exist in the data file prior to this message.
Eyelink('Message', 'TRIALID %d', trial);

% STEP 7.2
% Do a drift correction at the beginning of each trial Performing drift
% correction (checking) is optional for EyeLink 1000 eye trackers.
if(monkeyMode ~= 1)
    EyelinkDoDriftCorrection(el); % Only do drift correction for humans
end

% Show the black background after black screen
el.backgroundcolour = [0 0 0];
Screen('FillRect', window, el.backgroundcolour);

% STEP 7.3
% start recording eye position (preceded by a short pause so that the tracker
% can finish the mode transition). The paramerters for the 'StartRecording'
% call controls the file_samples, file_events, link_samples, link_events availability
Eyelink('Command', 'set_idle_mode');
WaitSecs(0.05);

Eyelink('StartRecording');
% record a few samples before we actually start displaying otherwise you may lose a few msec of data
WaitSecs(0.1);

%% Scanner Trigger
while 1
    % [pressed, firstPress] = KbQueueCheck();
    [~, firstPress] = KbQueueCheck();
        
    if(firstPress(scannerTrigger))
        startExperiment = GetSecs; %#ok<NASGU>
        Eyelink('Message','SCANNER START');
        break
    end
end

%% Scanner pause after trigger

% Add pause here to delay start of video or stimulus after scanner begins
% *** Scanner PAUSE ***
WaitSecs(scannerPause);

%% Video Playback
HideCursor;
KbReleaseWait;

for rr = 1:nRepetitions
    if(strcmpi(outputName,'Rest') || strcmpi(outputName,'Rest2'))
        frameCount = 0;
        Screen('Flip', window);
        
        % Make sure all triggers are "turned off"
        if triggers
            sendtrigger_io64(ioObject,triggerport,0);
        end
        
        % Send start trigger
        if triggers
            sendtrigger_io64(ioObject,triggerport,trigger_start,0.002);
            Eyelink('Message','REST START');
        end
        
        while(frameCount <= FramesPerFull) % && ~KbCheck)
            if frameCount==FramesPerFull
                break; %End session
            end
            
            if ~mod(frameCount,FramesPerStim)
                bwRect = bwColorsC;
            end
            
            if(mod(frameCount,60) == 0)
                if triggers
                    sendtrigger_io64(ioObject,triggerport,trigger_frame,0.002);
                    Eyelink('Message',['REST MARKER ',sprintf('%5.5d',frameCount)]);
                end
            end
            
            Screen('FillRect', window, bwRect, cross_RectCoordinates);
            Screen('Flip', window);
            frameCount = frameCount + 1; %Increase frame counter
        end
        
        % Send end trigger
        if triggers
            sendtrigger_io64(ioObject,triggerport,trigger_end,0.002);
            Eyelink('Message','REST END');
        end
    else
        Screen('Flip', window);
        
        % Make sure all triggers are "turned off"
        if triggers
            sendtrigger_io64(ioObject,triggerport,0);
        end
        
        % Send start trigger
        if triggers
            sendtrigger_io64(ioObject,triggerport,trigger_start,0.002);
            Eyelink('Message','VIDEO START');
        end
        
        %% PLAY MOVIE HERE
        % Open movie file:
        movie = Screen('OpenMovie', window, video_fileName);
        
        % Start playback engine:
        Screen('PlayMovie', movie, movieRate);
        
        if(monkeyMode == 1)
            Screen('glScale',window,-1,1);
            Screen('glTranslate',window,-1024,1);
        end
        % Playback loop: Runs until end of movie, keypress, or stop time length
        tic; cur_time = toc; % Start timer
        frameCount = 0; % Count number of frames
        while(cur_time < playbackTime) % && ~KbCheck)
            % Wait for next movie frame, retrieve texture handle to it
            movieTexture = Screen('GetMovieImage', window, movie);
            
            % Valid texture returned? Negative value means end of movie reached
            if(movieTexture <= 0)
                % We're done, break out of loop:
                break;
            end
            
            % OLD VERSION TO RUN IN MONKEY MODE:
            % Draw the new texture immediately to screen:
            % if(monkeyMode == 1)
            %     img = Screen('GetImage',movieTexture);
            %     Screen('Close', movieTexture);
            %     movieTexture = Screen('MakeTexture',window,fliplr(img));
            %     Screen('DrawTexture',window,movieTexture);
            % else
            %     Screen('DrawTexture',window,movieTexture);
            % end
            
            Screen('DrawTexture',window,movieTexture);
            
            % Frame Count: At 60Hz, every 1s (or 60 frames), send trigger
            frameCount = frameCount + 1;
            
            if(mod(frameCount,60) == 0)
                if triggers
                    sendtrigger_io64(ioObject,triggerport,trigger_frame,0.002);
                    Eyelink('Message',['VIDEO MARKER ',sprintf('%5.5d',frameCount)]);
                end
            end
            
            % Update display:
            Screen('Flip',window);
            
            % Release texture:
            Screen('Close',movieTexture);
            cur_time = toc;
        end
        
        % Stop playback:
        Screen('PlayMovie', movie, 0);
        
        % Close movie:
        Screen('CloseMovie', movie);
        
        % Send end trigger
        if triggers
            sendtrigger_io64(ioObject,triggerport,trigger_end,0.002);
            Eyelink('Message','VIDEO END');
        end
    end
end

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
    fprintf('Receiving data file ''%s''\n', edfFile );
    status=Eyelink('ReceiveFile');
    if status > 0
        fprintf('ReceiveFile status %d\n', status);
    end
    if 2==exist(edfFile, 'file')
        fprintf('Data file ''%s'' can be found in ''%s''\n', edfFile, pwd );
    end
catch
    fprintf('Problem receiving data file ''%s''\n', edfFile );
end

% STEP 9
% close the eye tracker and window
Eyelink('command', 'generate_default_targets = YES');
Eyelink('ShutDown');
if(dummyMode == 0)
    outputEDF_fileName = fullfile(edf_outputDir,['EyeLink_',dateTextFull,'_S',sprintf('%2.2d',seriesNum),'_R',sprintf('%2.2d',runNum),'_',outputName,'.edf']);
    movefile([edfFile,'.edf'],fullfile(edf_outputDir,[edfFile,'.edf']));
    copyfile(fullfile(edf_outputDir,[edfFile,'.edf']),outputEDF_fileName);
end
sca;