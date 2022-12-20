function row = check_json_field(row, metadata, variable)

    if isfield(metadata, variable) 
        if isempty(metadata.SamplingFrequency) || ~isnumeric(metadata.SamplingFrequency)

            idx_col = cellfun(@(C) contains(C, variable), row.Properties.VariableNames) & ...
            cellfun(@(C) contains(C, 'Var'), row.Properties.VariableNames);

            row(:, idx_col) = {0};

        end
    else

        idx_col = cellfun(@(C) contains(C, variable), row.Properties.VariableNames) & ...
        cellfun(@(C) contains(C, 'Field'), row.Properties.VariableNames);

        row(:, idx_col) = {0};

    end

end