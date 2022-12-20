function str = remove_string(str, pattern)
    str(regexp(str, pattern):end) = []; 
end