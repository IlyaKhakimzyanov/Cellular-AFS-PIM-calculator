% work with sc-fdma
clear;
close all;

% Вкл радном
if false 
    seed = rng('shuffle');
    % disp(["Сид: ", num2str(seed.Seed)]);
    fprintf("Сид: %d\n", seed.Seed);
    clear seed;
else
    rng('default');
end

R = 50; % Ом
% Параметры UE
ue_Fcarrier = (2500+20+10)*1e6;
P_UE = 0.0000001; % Ватт
% Параметры 2х помех
f1 = 2162.5e6;
f2 = 1827.e6;
P_ofdm = [20 20]; % Ватт


%% --- Заготовленные коэффициенты
    %Qiuyan Jin
Coef_Jin = zeros(13,6);
Coef_Jin(3, :) = [0, 1.466, 1.471, 1.486, 1.504, 1.538] *1e-5;
Coef_Jin(5, :) = [0, -3.53, -3.98, -5.29, -6.86, -10.48]*1e-11;
Coef_Jin(7, :) = [0, 0,     0.54,  1.46,  2.70,  11.05] *1e-18;
Coef_Jin(9, :) = [0, 0,     0,     -1.48, -4.83, -65.42]*1e-24;
Coef_Jin(11,:) = [0, 0,     0,     0,     0.31,  17.36] *1e-31;
Coef_Jin(13,:) = [0, 0,     0,     0,     0,     -1.63] *1e-31;
Coef_Jin_modif = [0 0 3/4 0 25/8 0 735/64 0 1323/32 0 38115/256 0 552123/1024];
    
    %Lingyu Bi DOI 10.1109/TCPMT.2020.3033329
Coef_Lingyu_2 = [0, 0, 5.569e-12, 0, -4.781e-16, 0, 2.530e-20];

    %Junyu Luo DOI 10.1109/AEMCSE51986.2021.00184
Coef_Junyu_Luo = [0.00 0 1.655e-11 0 -1.261e-15 0 6.424e-20];

% --- Используемый коэффицент
% a = Coef_Jin(3:end, 3)';% .* Coef_Jin_modif;
% a = Coef_Jin(:, 2)';% .* Coef_Jin_modif;
a = Coef_Lingyu_2; % +
% a = Coef_Junyu_Luo;

%%
% --- Создание UL SC-FDMA сигнала UE
% A3-4 - qpsk RB-25; A3-7 - qpsk RB-100
% A4-5 - 16qm RB-25; A4-8 - 16qam RB-100
% A5-4 - 64qam RB-25; A5-8 - 64qam RB-100
ue = lteRMCUL('A3-4'); % 36.104, A3-7 - NRB = 100, BW = 20 MHz (A4-8, A7-1)
[ue_puschInd, ue_pusch_info] = ltePUSCHIndices(ue, ue.PUSCH);
ue_BW = ceil(ue.NULRB*12*15/1e3 * (5/4.5));
ue_dim = lteULResourceGridSize(ue);
ue_bits = randi([0,1],ue_pusch_info.G,ue.PUSCH.NLayers);
ue_scrBits = lteULScramble(ue,ue_bits); % хз зачем

ue_symbols = lteSymbolModulate(ue_scrBits,ue.PUSCH.Modulation);
ue_precodedSymbols = lteULPrecode(ue_symbols,ue.NULRB);
ue_grid = lteULResourceGrid(ue);
ue_grid(ue_puschInd) = ue_precodedSymbols;
[ue_waveform, ue_info] = lteSCFDMAModulate(ue,ue_grid);
ue_fs = ue_info.SamplingRate;
% ue_waveform = ue_waveform.*10;
ue_power_start = mean(abs(ue_waveform).^2) / R;
ue_power_scale_factor = sqrt(P_UE/ue_power_start);
ue_waveform = ue_waveform * ue_power_scale_factor;

% Фильтр
ue_waveform  = lowpass(ue_waveform, ue_BW*1e6/2/1.111, ue_fs, ...
        StopbandAttenuation=200);

%%
% --- Работа с сигналом
% Ресемпл UE - Увеличенная частота
resam_fs = 9e9;
[resam_waveform, resam_ratio] = Resample_Wave(ue_waveform, ue_fs, resam_fs);
resam_time = (0:length(resam_waveform)-1)*1/resam_fs;

% Перенос сигнала на несущую 

shift_resam_waveform = Shift_Signal(resam_waveform, resam_fs, ue_Fcarrier, 1);

% Доавление шума
% shift_resam_waveform = awgn(shift_resam_waveform, -20, pow2db(mean(abs(shift_resam_waveform).^2)));

% --- Создание помехи IM3

two_ofdm_DL = DL_OFDM_on_carrier('3.2', '15MHz', 1, f1, resam_fs, P_ofdm(1), R);
% % pow2db(mean(abs(two_ofdm_DL).^2))
% % bandpower(two_ofdm_DL, resam_fs, ([-1 1]*15*1e6/2+f1))/R
two_ofdm_DL = two_ofdm_DL + DL_OFDM_on_carrier('3.2', '20MHz', 1, f2, resam_fs, P_ofdm(2), R);

test = dbmtov(wtodbm(20), R)*(cos(2*pi*f1*resam_time)+cos(2*pi*f2*resam_time))';
% test = dbmtov(wtodbm(20), R)*(cos(2*pi*f1*resam_time))';
% two_ofdm_DL = test;

IM3_signal = Nonlinear_polynomial(a, two_ofdm_DL);

IM3_signal = IM3_signal * R; % Из тока в напряжение

% --- Суммирование IM3 и SC-FDAM
shift_add_resam_waveform = shift_resam_waveform  + IM3_signal;

% Перенос обранто
deshift_resam_waveform = Shift_Signal(shift_add_resam_waveform, resam_fs, ue_Fcarrier, -1);

% Дересемпл
[deresam_waveform, deresam_ratio] = Resample_Wave(deshift_resam_waveform, resam_fs, ue_fs);


% Создание приходящего сигнала
% rx_waveform = awgn(ue_waveform, 20, pow2db(mean(abs(ue_waveform).^2)));

% Фильтр
deresam_waveform = lowpass(deresam_waveform, ue_BW*1e6/2/1.1, ue_fs, ...
    StopbandAttenuation=200);


% --- Мощность 
ue_power_W = bandpower(ue_waveform, ue_fs, [-1, 1]*ue_BW/2*1e6)/R;
ue_power_dBm = 10*log10(ue_power_W*1000);
fprintf("P_W: %f;\nP_dbm: %f\n", ue_power_W, ue_power_dBm);

pow_start = mean(abs(deresam_waveform).^2) / R;
scale_fac = sqrt(ue_power_W/pow_start);
deresam_waveform_low = deresam_waveform * scale_fac / ue_power_scale_factor;

% --- Декодирование
[rx_bits, rx_grid, rx_symbols] = Decode_SCFDMA(ue, deresam_waveform_low);
ber = get_BER(ue_bits, rx_bits);
% disp([rx_bits(50:70), ue_bits(50:70)]);
fprintf("BER: %f\n", ber);



% --- Время
ue_time = (0:length(ue_waveform)-1)*1/ue_fs;


% --- Спектр
ue_nfft = double(ue_info.Nfft)*2;
% resam_nfft = ue_nfft * ceil(resam_ratio)*2;
resam_nfft = length(resam_waveform);
    % X - для спектров
ue_freq = (0:ue_nfft-1)/ue_nfft*ue_fs;
ue_freq_shift = (-ue_nfft/2:ue_nfft/2-1)/ue_nfft * ue_fs;

resam_freq = (0:resam_nfft-1)/resam_nfft*resam_fs;
resam_freq_shift = (-resam_nfft/2:resam_nfft/2-1)/resam_nfft * resam_fs;

% window = hann(length(ue_nfft));

    % Исходный сигнал
ue_spectrum = fft(ue_waveform(1:ue_nfft))/ue_nfft;
ue_spectrum_shift = fftshift(ue_spectrum);
ue_spectrum = (abs(ue_spectrum).^2) / R * 2; % Перевод в Ватт
ue_spectrum_shift = (abs(ue_spectrum_shift).^2) / R * 2;

    % Исходный -> Измененена частота
shift_resam_spectrum = fft(shift_resam_waveform(1:resam_nfft))/resam_nfft;
shift_resam_spectrum = (abs(shift_resam_spectrum).^2)/R * 2;

    % Только OFDM сигналы
two_ofdm_DL_spectrum = fft(two_ofdm_DL(1:resam_nfft))/resam_nfft;
two_ofdm_DL_spectrum = (abs(two_ofdm_DL_spectrum).^2)/R*2;
    % IM3
IM3_signal_spectrum = fft(IM3_signal(1:resam_nfft))/resam_nfft; % (abs(f_v1_IM3).^2) / R * 2;
IM3_signal_spectrum_Power = (abs(IM3_signal_spectrum).^2)/R*2;

    % Сигнал с IM3
shift_add_resam_spectrum = fft(shift_add_resam_waveform(1:resam_nfft))/resam_nfft;
shift_add_resam_spectrum = (abs(shift_add_resam_spectrum).^2)/R*2;
    
    % Пришедший и пониженный почастоте
deresam_waveform_low_spectrum = fft(deresam_waveform_low, ue_nfft)/ue_nfft;


%%
% --- Графики

h = scatterplot(rx_symbols(:), [], [], 'b.');
% h.Color="w"; 
hold on;
scatterplot(ue_symbols,[],[],'r+', h); % График позиций QAM
grid
legend('Примем сигнала', 'Положения символов');
ylim([-1 1]*1.5);
xlim([-1 1]*1.5);
% set(h, 'Color', 'w');

h=gca;                %Axis handle
% h.Position=[17,556,420,420];
% 
h.Title.String="Созвездие QAM";
h.Title.Color ='k';     %Color of title
h.YColor='k';         %Y-axis color including ylabel
h.XColor='k';         %X-axis color including xlabel
h.Color ='w';         %inside-axis color
h.Parent.Color='w';    %outside-axis color
h.Parent.Position=[23,556,420,420];
h.Children(1).MarkerSize=10;
h.Children(1).LineWidth=1.5;
h.Legend.Color='w';
h.Legend.EdgeColor='k';
h.Legend.TextColor='k';
h.Legend.Location="north";
% h.Legend.Title.Color='k';
hold off;

% scat = figure(); hold on;
% scatter(real(rx_symbols()), imag(rx_symbols()), [],"Marker", ".");
% scatter(real(ue_symbols(:)), imag(ue_symbols(:)), [], "Marker", "o");
% scat_lim = [-1 1]*1.5;
% xlim(scat_lim); ylim(scat_lim);
% legend('1','2');
% grid on; hold off;

%%
% >>> Время
figure();
plot(ue_time, real(ue_waveform));
% >>> Частота
figure('Name',"Сигнал от UE и до переноса в RFмодуле", 'Position',[680,253,560,734]); 
subplot(311);hold on;
plot(ue_freq_shift/1e6, 10*log10(ue_spectrum_shift*1000));
plot([ue_freq_shift(1),ue_freq_shift(end)]/1e6, [ue_power_dBm, ue_power_dBm])
% plot(ue_freq_shift/1e6, 10*log10(abs(fftshift(rx_spectrum))*1000));
ylabel('Амплитуда, дБм'); xlabel('Частота, МГц');
title("Спекрт выходного сигнала UE (SC-FDMA)");
grid on; hold off;
subplot(312);
plot(resam_freq/1e6, 10*log10(shift_resam_spectrum.*1000));
% plot(resam_freq/1e6, abs(resam_spectrum));
ylabel('Амплитуда, '); xlabel('Частота, МГц');
title("Сигнал UE перенесенный на Fc");
xlim( ue_Fcarrier/1e6 + [-1 1]*ue_BW );
grid on; hold off;

subplot(313); hold on;
plot(ue_freq_shift/1e6, 10*log10(abs(fftshift(deresam_waveform_low_spectrum)).^2/R*2.*1000));
title("Принятый сигнал и перенесенный на f = 0 Гц");
grid on; hold off;
%%
figure('Name','Гетеродинная среда');
% fig_x_lim = [0.4 1.6]*(f1+f2)/2/1e6;
fig_x_lim = abs(0.3 + [-1 1]) * ((max(f1, f2) + ue_Fcarrier)/2/1e6);
subplot(311);
plot(resam_freq/1e6, 10*log10(two_ofdm_DL_spectrum*1000));
% pspectrum(two_ofdm_DL, resam_fs, 'Leakage',1);


% xlim( ([-abs(f1-f2) abs(f1-f2)]+((f1+f2)/2))/1e6 );
% xlim(fig_x_lim);
grid on;

subplot(312);
plot(resam_freq/1e6, 10*log10(IM3_signal_spectrum_Power*1000));
% pspectrum(IM3_signal,resam_fs, 'Leakage',0);
xlim(fig_x_lim);
grid on;

subplot(313); hold on;
plot(resam_freq/1e6, 10*log10(shift_add_resam_spectrum*1000));
% plot(resam_freq/1e6, 10*log10(shift_resam_spectrum*1000))
% pspectrum(shift_add_resam_waveform,resam_fs);
xlim(fig_x_lim);
grid on; hold off;

% figure();
% imagesc(abs(ue_grid)); % Гарафик ресурсной сетик

%%
scope = dsp.SpectrumAnalyzer;

scope.SampleRate = resam_fs;
scope.Method = 'filter-bank';
scope.ReferenceLoad = 50;
% scope.InputDomain = "frequency";
% scope.Window = 'blackman-harris';
scope.PlotAsTwoSidedSpectrum = false;
% scope.StartFrequency
scope.FrequencySpan = "span-and-center-frequency";
scope.Span = 3e9;
scope.CenterFrequency = mean(f1+f2)/2;
scope.RBWSource = "property";
scope.RBW = 0.5e6;

% scope.col

% scope(real(two_ofdm_DL));
% scope(real(IM3_signal));
scope(real(shift_add_resam_waveform));



% scope.BackgroundColor = "white";
% scope.AxesColor = "white";
% scope.FontColor = "black";
% scope.LineColor = "black";