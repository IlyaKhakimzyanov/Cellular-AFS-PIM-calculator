function ber = get_BER(data_orig, data_come)
    ber = sum(data_come ~= data_orig) / numel(data_orig);
end