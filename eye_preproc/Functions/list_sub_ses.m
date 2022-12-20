%% List subjects and sessions
function [subs, sessions] = list_sub_ses(directory)

    % List all subjects 
    subs = dir(directory);
    subs = subs(cellfun(@(C) contains(C, 'sub-'), {subs.name}));
    subs(~[subs.isdir]) = [];
    
    % List all sessions in each subject folder
    sessions = cell(length(subs), 1);
    for s = 1:length(subs)  
        ses_struct = dir(sprintf('%s/%s', directory, subs(s).name));
        ses_struct(~cellfun(@(C) contains(C, 'ses'), {ses_struct.name})) = [];  
        sessions{s} = {ses_struct.name};   
    end

end