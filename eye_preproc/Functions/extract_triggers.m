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