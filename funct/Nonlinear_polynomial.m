function y = Nonlinear_polynomial(coefpoly, x)
% coefpoly - коэффициентыф;
% x - входной сигнал.
    [row, cols] = size(x);
    if row < cols
        x = x';
    end

    % Деление
    y = zeros(1, length(x))';
    if isreal(x)
        for i = 1:length(coefpoly)
            if coefpoly(i)~=0
                y = y + coefpoly(i) * x.^(i);  
            end
        end
    else
        amplitude = abs(x);
        phase = angle(x);
        for k = 1:length(coefpoly) 
            if coefpoly(k)~=0
                y = y + amplitude.^k * coefpoly(k);
            end
        end
        y = y.*exp(1i*phase);
    end

    if row < cols
        y = y';
    end
end