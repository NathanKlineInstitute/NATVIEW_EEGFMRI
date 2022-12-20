function data = preprocess_eyelink_data(data, options, metadata, bl_sample)
% [data,data_nan] = preprocessEyelinkData(data,timestamps,metadata,options)
% 
% data          (samples x modality) : eye link data matrix containing a column per measurement e.g. horizontal, vertical eye movements, pupil and head movements 
% timestamps    (samples x 1)        : column vector with timestamps for each sample
% 
% metadata.eye.blinks.timestamps_edf (samples x 2): contains a two column vector with start and end times of each blink
% options: containing fields 
%           'blinkfilling'           : 'interp' if blinks should be interpolated,
%           'filter_length_eye'      : length of median filter in seconds,
%           'fs_eyeheadtracking'     : sampling frequency of collected data in Hz
%
% adapted from jmad/jenma 2022
%

% Convert data table to array
data = table2array(data);

if ~isfield(options,'blinkfilling')
    options.blinkfilling = 'interp';
    fprintf('No blink filling approach specified, setting to linear interpolation\n')
end

if ~isfield(options,'filter_length_eye')
    options.filter_length_eye = 0.2;% filter lenght of median filter in seconds
    fprintf('No filter for median filter specified, setting to 200ms\n')

end

buffer_samples = round((options.buffer_ms/1000)*metadata.SamplingFrequency); %buffer in samples

idx_blinks = false(length(data),1);

idx_eyes = find(contains(metadata.Columns, 'Gaze'));
idx_pupil = find(contains(metadata.Columns, 'Pupil'));
idx_res = find(contains(metadata.Columns, 'Resolution'));

%% find blinks and set them to NaN
fprintf('Preprocessing Eyetracking data\n')
for ii = 1:length(bl_sample)
    
    % Get index for start and end of blink
    idx_blink_start = bl_sample(ii,1);
    idx_blink_end = bl_sample(ii,2);
    
    % extend with buffer_samples on each side of blink
    idx_blink_start = max(1,idx_blink_start-buffer_samples);
    idx_blink_end = min(length(data),idx_blink_end+buffer_samples);
    
    % fill in with nan
    data(idx_blink_start:idx_blink_end,[idx_eyes idx_pupil idx_res]) = NaN;
    idx_blinks(idx_blink_start:idx_blink_end) = true;
    
    if rem(ii,50)==0
        fprintf('.')
    end

end

fprintf('\n')

%% fill in nans with linearly interpolated data
if strcmpi(options.blinkfilling,'interpolation') || strcmpi(options.blinkfilling,'interp')
    % take all the NaNs and use interpolation to fill in to values
    data = fillmissing(data,'linear','EndValues','nearest');
end


%% filter the eye tracking data to remove spurious blinks
no_taps = round(metadata.SamplingFrequency*options.filter_length_eye);

if no_taps>0
    data(:,[idx_eyes idx_pupil idx_res]) = medfilt1(data(:,[idx_eyes idx_pupil idx_res])-data(1,[idx_eyes idx_pupil idx_res]),no_taps) ...
        + data(1,[idx_eyes idx_pupil idx_res]);
end

%% remove initial sample offsets in data
if data(1,1)~=mean(round(data(metadata.SamplingFrequency*0.1,1)))
    data(1:5,:) = NaN;
    data = fillmissing(data,'linear','EndValues','extrap');
end

%% check if nan painting succeeded
if any(isnan(data(:)))
    error('NaNs not cleaned')
end

%% Add blink indices to data
data = [data, idx_blinks];

end
