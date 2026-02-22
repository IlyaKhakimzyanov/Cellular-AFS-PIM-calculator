function output = dbmtov(x, Zo)
%
    output = sqrt((.001*2*Zo).*10.^(x./10));
end