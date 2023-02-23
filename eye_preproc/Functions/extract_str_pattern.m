function patterns = extract_str_pattern(full_str, pattern_str, extra_char) 

    % Extract 'pattern_str' from 'full_str', addting 'extra_car' characters at the end

    idx_sub = regexp(full_str, pattern_str);
    
    patterns = cell(length(idx_sub), 1);
    
    for s = 1:length(idx_sub)
        patterns{s} = full_str(idx_sub(s):idx_sub(s)+length(pattern_str)+extra_char);
    end

end