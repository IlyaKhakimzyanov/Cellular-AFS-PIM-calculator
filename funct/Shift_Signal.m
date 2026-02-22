function out_signal = Shift_Signal(in_signal, Fs, delta_F)
% Функция для переноса сигнала на дельта F:
% in_signal - входной сигнал; Fs - частота дискрет;
% delta_F - на какую частоту перенести сигнал;
% RightOrLeft - 1 = вверх, -1 = вниз по частоте;
    Ts = 1/Fs;
    time = (0:length(in_signal)-1)*Ts;
    [row, cols] = size(in_signal);
    if row>cols && cols == 1
        time = time';
    elseif row<cols && row == 1
        %
    else
        error('Неправильный размер входного массива');
    end

    out_signal = in_signal .* exp(1i * 2*pi * delta_F * time);

end