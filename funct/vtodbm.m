function output = vtodbm(x, Zo)
%
    output = 10.*log10(x.^2/(.001*Zo*2));
end