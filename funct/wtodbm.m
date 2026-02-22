function output = wtodbm(x)
% x - Power [Watt]
    output = 10.*log10(x.*1000);
end