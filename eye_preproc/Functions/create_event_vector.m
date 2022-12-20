%% Create a vector from event data
function event_vector = create_event_vector(event_data, n_sample, event_type)

    % Extract the tield from the struct
    event_idx = getfield(event_data, event_type);

    % Create empty vectors
    event_vector = zeros(n_sample,1);

    % Fill with zeros at the time of events
    for i = 1:length(event_idx)
        event_vector(event_idx(i,1):event_idx(i,2)) = 1;
    end

end