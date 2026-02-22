function [resam_waveform, ratio_fs] = Resample_Wave(waveform, fs, resam_fs)
%Resample_Wave
    p = resam_fs / gcd(resam_fs, fs);   % Числитель коэффициента передискретизации
    q = fs / gcd(resam_fs, fs);      % Знаменатель коэффициента передискретизации
    ratio_fs = p/q;
    
    resam_waveform = resample(waveform, p, q);
end