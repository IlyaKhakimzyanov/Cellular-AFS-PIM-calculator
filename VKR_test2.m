%%
clear
close all;
% Параметры LTE
enb = struct();                  % Создаем структуру для параметров eNodeB
enb.NDLRB = 100;                 % 100 ресурсных блоков для 20 МГц (18 МГц полезной полосы)
enb.CyclicPrefix = 'Normal';     % Обычный циклический префикс
enb.CellRefP = 1;                % Одна антенна порта
enb.DuplexMode = 'FDD';          % Режим дуплекса FDD
enb.NCellID = 0;                 % Идентификатор соты
enb.NSubframe = 0;               % Номер подкадра
enb = lteTestModel('1.1', '20MHz');


% Генерация эталонного сигнала
[waveform, grid, info] = lteTestModelTool(enb);

% Настройка параметров сигнала
fs = info.SamplingRate;          % Частота дискретизации (30.72 МГц для 20 МГц полосы)
fc = 2.6e9;                      % Центральная частота (пример для band 1)
NFFT = double(info.Nfft)*4;
% n = 0:NFFT-1; time = n * 1/fs;

% Несущая
% carrier = cos(2*pi*fc*time);


% Анализ FFT

window = hann(NFFT);
% window = 1;
spectrum = fft(waveform(1:NFFT) .* window) / NFFT;
move_spec = fft(waveform(1:NFFT) .* exp(-1i*2*pi*fc))/NFFT;
f_axis = (-NFFT/2:NFFT/2-1) * fs/NFFT;


% resample
a = 2;
new_waveform = resample(waveform, a, 1);
new_NFFT = NFFT*a;
new_spectrum = fft(new_waveform(1:new_NFFT));
new_f_axis = (-new_NFFT/2:new_NFFT/2-1) * fs*a/new_NFFT;


% Визуализация
figure;
subplot(3,1,1);
plot(real(waveform)); 
title('Временная область (I-компонента)');

subplot(3,1,2); hold on;
plot(f_axis/1e6, 10*log10(abs(fftshift(spectrum)).^2));
plot(f)
hold off;
xlim([-fs/2e6, fs/2e6]);
title('Спектр (FFT комплексного IQ)');
xlabel('Частота (МГц)');
ylabel('Мощность (дБ)');

subplot(3,1,3);
% plot((f_axis + fc)/1e6, 10*log10(abs(fftshift(move_spec)).^2));
plot(10*log10(abs(fftshift(new_spectrum)).^2));

%
rxgrid = lteOFDMDemodulate(enb, waveform);
[~, noiseEst] = lteDLChannelEstimate(enb, rxgrid);
disp(wtodbm(noiseEst));
rxgrid = lteOFDMDemodulate(enb, waveform);
[~, noiseEst] = lteDLChannelEstimate(enb, rxgrid);
disp(wtodbm(noiseEst));


% saScope = spectrumAnalyzer(SampleRate=info.SamplingRate, Method='welch');
% saScope(waveform);

%%
fd = 20; td=1/fd;
f1 = 5;
T = 4;
time = 0:td:2*pi*T*td-td;
N = length(time);
x = sin(2*pi*f1*time);
y = resample(x, 5, 1);
y_td = td/5*1;
y_time = 0:y_td:2*pi*T*td-y_td;
figure(); hold on;
plot(time, x);
plot(y_time, y);
hold off;
%%
% % Исходные параметры
% f_signal = 5;     % Частота сигнала (Гц)
% fs_old = 20;      % Исходная частота дискретизации (Гц)
% fs_new = 40;      % Новая частота дискретизации (Гц)
% duration = 1;     % Длительность сигнала (сек)
% 
% % Создаем исходный сигнал
% t_old = 0:1/fs_old:duration-1/fs_old;  % Временная шкала для исходного сигнала
% x_old = sin(2*pi*f_signal*t_old);      % Исходный сигнал
% 
% % Ресемплируем сигнал
% p = fs_new / gcd(fs_new, fs_old);      % Числитель коэффициента передискретизации
% q = fs_old / gcd(fs_new, fs_old);      % Знаменатель коэффициента передискретизации
% x_new = resample(x_old, p, q);



%%


% % Визуализация спектра
% spectrumAnalyzer = dsp.SpectrumAnalyzer(...
%     'SampleRate', fs, ...
%     'SpectrumType', 'Power density', ...
%     'SpectralAverages', 10, ...
%     'YLimits', [-100 -40], ...
%     'Title', 'Спектр LTE сигнала 20 МГц');
% 
% spectrumAnalyzer(waveform);

% %%
% rc = 'R.12';
% enb = lteRMCDL(rc);
% 
% txWaveform

%%
% Параметры моделирования
fs = 100e3;      % Частота дискретизации (Гц)
T = 0.001;           % Время моделирования (с)
R = 50;          % Сопротивление (Ом)
T_k = 300;       % Температура (К)
k = 1.38e-23;    % Постоянная Больцмана

% Расчет параметров
N = fs * T;      % Количество отсчетов
B = fs / 2;      % Полоса частот (Гц)
P_n = 4 * k * T_k * R * B;  % Мощность шума

% Генерация теплового шума
noise_voltage = sqrt(P_n) * randn(1, N);

% Временная ось
t = linspace(0, T, N);

% Визуализация
figure;
plot(t, noise_voltage);
xlabel('Время (с)');
ylabel('Напряжение (В)');
title('Моделирование теплового шума');
grid on;


%%
close all;
f1 = 927.5e6;
f2 = 952.5e6;
P_ofdm = [40 40];
resam_fs = 6e9; R = 50;

[two_ofdm_DL, coef, ofdm] = DL_OFDM_on_carrier('3.2', '5MHz', 1, f1, resam_fs, P_ofdm(1), R);
% two_ofdm_DL = two_ofdm_DL + DL_OFDM_on_carrier('3.2', '5MHz', 1, f2, resam_fs, P_ofdm(2), R);

fs = 7680000;
flow = 5/2*1e6;
fhigh = 5/2*1e6+0.5e6;
N = 101;
beta = 7.95;

WpassLow = flow / (fs/2);
WpassHigh = fhigh / (fs/2);

% b = fir1(N-1, [WpassLow WpassHigh], 'low', @blackman, beta);

% ofdm_2 = filter(b, 1, ofdm);
ofdm_2 = lowpass(ofdm, 5e6/2, fs);

% ImpulseResponse="iir", ...
% Steepness=0.95, ...

figure();
subplot(211); hold on;
% plot(10.*log10(abs(fftshift(fft(ofdm))./length(ofdm))*1000));
% plot(10.*log10(abs(fft(ofdm))./length(ofdm)*1000));
pspectrum(ofdm, fs);
% plot(10.*log10(abs(fftshift(fft(ofdm_2))./length(ofdm_2))*1000));
% plot(10.*log10(abs(fft(ofdm_2))./length(ofdm_2)*1000));
pspectrum(ofdm_2, fs);

% two_ofdm_DL = bandpass(two_ofdm_DL, [-2.5e6 2.5e6]+f1, fs*coef);
subplot(212);
plot(10.*log10(abs( fft(two_ofdm_DL)./length(two_ofdm_DL) ) *1000) );
% pspectrum(two_ofdm_DL, fs);