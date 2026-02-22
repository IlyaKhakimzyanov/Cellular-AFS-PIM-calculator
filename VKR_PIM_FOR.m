% work with sc-fdma
clear;
close all;

% Вкл случайное создание символов
if false 
    seed = rng('shuffle');
    % disp(["Сид: ", num2str(seed.Seed)]);
    fprintf("Сид: %d\n", seed.Seed);
    clear seed;
else
    rng('default');
end

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

%%
% --- Используемый коэффицент
% a = Coef_Jin(3:end, 3)';% .* Coef_Jin_modif;
% a = Coef_Jin(:, 2)';% .* Coef_Jin_modif;
% a = Coef_Lingyu_2; % +
a = Coef_Junyu_Luo;

% Включение графиков
is_graph_view = false;
is_for = true;

R = 50; % Ом
% Параметры UE
ue_Fcarrier = (2500+20/2)*1e6;
P_UE = 1e-12; % Ватт %1e-7 мин UE, 1e-13 мин sens levl
% Параметры 2х помех
f1 = 1812.5e6; %1827.5e6; %927.5e6; 
f2 = 2147.5e6; %2162.5e6; %2630e6;
BW_1 = '15MHz';
BW_2 = '15MHz';
Arr_power_1 = [20 20 20];
Arr_power_2 = 10.^( (37:1:49) /10)/1000;

%BER
FOR_SNR = zeros(length(Arr_power_1), length(Arr_power_2));
FOR_BER = zeros(length(Arr_power_1), length(Arr_power_2));
FOR_IM = cell(length(Arr_power_1), length(Arr_power_2));

for loop_1 = 1:length(Arr_power_1)
for loop_2 = 1:length(Arr_power_2)

P_ofdm = [Arr_power_1(loop_1) Arr_power_2(loop_2)]; % Ватт
fprintf('%d.%d)\t%0.1f and %0.1f\t', loop_1, loop_2, P_ofdm(1), P_ofdm(2));

%% IM
BW_1_num = sscanf(BW_1, "%dMHz");
BW_2_num = sscanf(BW_2, "%dMHz");
IM_band = [2*(f1-BW_1_num*1e6/2)-(f2+BW_2_num*1e6/2), 2*(f1+BW_1_num*1e6/2)-(f2-BW_2_num*1e6/2),...     % IM3 low
           2*(f2-BW_2_num*1e6/2)-(f1+BW_1_num*1e6/2), 2*(f2+BW_2_num*1e6/2)-(f1-BW_1_num*1e6/2);...     % IM3 high
           3*(f1-BW_1_num*1e6/2)-2*(f2+BW_2_num*1e6/2), 3*(f1+BW_1_num*1e6/2)-2*(f2-BW_2_num*1e6/2),... % IM5 low
           3*(f2-BW_2_num*1e6/2)-2*(f1+BW_1_num*1e6/2), 3*(f2+BW_2_num*1e6/2)-2*(f1-BW_1_num*1e6/2)];   % IM5 high

%%
% --- Создание UL SC-FDMA сигнала UE
% A3-4 - qpsk RB-25; A3-7 - qpsk RB-100
% A4-5 - 16qm RB-25; A4-8 - 16qam RB-100
% A5-4 - 64qam RB-25; A5-8 - 64qam RB-100
ue_name = "A3-4";
% ue_array_name = ["A3-4", "A4-5", "A5-4"];
ue_array_name = ["A3-7", "A4-8", "A5-7"];
ue_name = ue_array_name(loop_1);
ue = lteRMCUL(ue_name); % 36.104, A3-7 - NRB = 100, BW = 20 MHz (A4-8, A7-1)
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
% Усиление по мощности
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

shift_resam_waveform = Shift_Signal(resam_waveform, resam_fs, ue_Fcarrier);

% Доавление шума
% shift_resam_waveform = awgn(shift_resam_waveform, -20, pow2db(mean(abs(shift_resam_waveform).^2)));

% --- Создание помехи IM3
[OFDM_shift_1, OFDM_1_waveform, OFDM_1_freq] = DL_OFDM_on_carrier('3.2', BW_1, 1, f1, resam_fs, P_ofdm(1), R, false);

[OFDM_shift_2, OFDM_2_waveform, OFDM_2_freq] = DL_OFDM_on_carrier('3.2', BW_2, 1, f2, resam_fs, P_ofdm(2), R, false);

two_ofdm_DL = OFDM_shift_1 + OFDM_shift_2;

IM3_signal = Nonlinear_polynomial(a, two_ofdm_DL);

IM3_signal = IM3_signal * R; % Из тока в напряжение

% --- Суммирование IM3 и SC-FDAM
shift_add_resam_waveform = shift_resam_waveform  + IM3_signal;

% Перенос обранто
deshift_resam_waveform = Shift_Signal(shift_add_resam_waveform, resam_fs, -ue_Fcarrier);

% Дересемпл
[deresam_waveform, deresam_ratio] = Resample_Wave(deshift_resam_waveform, resam_fs, ue_fs);

% Фильтр
deresam_waveform = lowpass(deresam_waveform, ue_BW*1e6/2/1.1, ue_fs, ...
    StopbandAttenuation=200);

% --- Мощность 
    % UE
ue_power_W = bandpower(ue_waveform, ue_fs, [-1, 1]*ue_BW/2*1e6)/R;
ue_power_dBm = 10*log10(ue_power_W*1000);
% fprintf("P_W: %f;\nP_dbm: %f\n", ue_power_W, ue_power_dBm);
    %SNR
        % UE resam
FOR_SNR_ue_power = bandpower(shift_resam_waveform, resam_fs, ue_Fcarrier + [-1 1]*ue_BW/2*1e6)/R;
        % Noise
% FOR_SNR_noise_power = bandpower(IM3_signal, resam_fs, ue_Fcarrier + [-1 1]*ue_BW/2*1e6)/R;
FOR_SNR_noise_power = bandpower(IM3_signal, resam_fs, [0 resam_fs/2])/R - FOR_SNR_ue_power;
        %SNR
FOR_SNR(loop_1, loop_2) = FOR_SNR_ue_power/FOR_SNR_noise_power;
fprintf('SNR = %0.2f\t', 10*log10(FOR_SNR(loop_1, loop_2) *1000));

    % IM3
IM_power_W = [bandpower(IM3_signal, resam_fs, IM_band(1,1:2)),...
              bandpower(IM3_signal, resam_fs, IM_band(1,3:4));...
              bandpower(IM3_signal, resam_fs, IM_band(2,1:2)),...
              bandpower(IM3_signal, resam_fs, IM_band(2,3:4))]./R;
IM_power_dBm = 10*log10(IM_power_W*1000);
FOR_IM{loop_1, loop_2} = IM_power_dBm;

pow_start = mean(abs(deresam_waveform).^2) / R;
scale_fac = sqrt(ue_power_W/pow_start);
deresam_waveform_low = deresam_waveform * scale_fac / ue_power_scale_factor;

% --- Декодирование
[rx_bits, rx_grid, rx_symbols] = Decode_SCFDMA(ue, deresam_waveform_low);
ber = get_BER(ue_bits, rx_bits);
% disp([rx_bits(50:70), ue_bits(50:70)]);
% fprintf("BER: %f\n", ber);
FOR_BER(loop_1, loop_2) = ber;
fprintf('BER = %f\n', ber)

end
end %два фора

% --- Время
ue_time = (0:length(ue_waveform)-1)*1/ue_fs;


% --- Спектр
ue_nfft = double(ue_info.Nfft)*2;
% resam_nfft = ue_nfft * ceil(resam_ratio)*2;
nfft_coef = 1;
resam_nfft = ceil(length(resam_waveform)*nfft_coef);
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
shift_resam_spectrum = fft(shift_resam_waveform, resam_nfft)/resam_nfft;
shift_resam_spectrum = (abs(shift_resam_spectrum).^2)/R * 2;

    % Только OFDM сигналы
two_ofdm_DL_spectrum = fft(two_ofdm_DL, resam_nfft)/resam_nfft;
two_ofdm_DL_spectrum = (abs(two_ofdm_DL_spectrum).^2)/R*2;
    % IM3
IM3_signal_spectrum = fft(IM3_signal, resam_nfft)/resam_nfft; % (abs(f_v1_IM3).^2) / R * 2;
IM3_signal_spectrum_Power = (abs(IM3_signal_spectrum).^2)/R*2;

    % Сигнал с IM3
shift_add_resam_spectrum = fft(shift_add_resam_waveform, resam_nfft)/resam_nfft;
shift_add_resam_spectrum = (abs(shift_add_resam_spectrum).^2)/R*2;
    
    % Пришедший и пониженный почастоте
deresam_waveform_low_spectrum = fft(deresam_waveform_low, ue_nfft)/ue_nfft;


%%
if is_graph_view
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
% plot([ue_freq_shift(1),ue_freq_shift(end)]/1e6, [ue_power_dBm, ue_power_dBm])
% plot(ue_freq_shift/1e6, 10*log10(abs(fftshift(rx_spectrum))*1000));
ylabel('Мощность, дБм'); xlabel('Частота, МГц');
title(['Спекрт выходного сигнала UE (SC-FDMA), полоса ', num2str(ue_BW), ' МГц']);
grid on; hold off;
subplot(312);
plot(resam_freq/1e6, 10*log10(shift_resam_spectrum.*1000));
% plot(resam_freq/1e6, abs(resam_spectrum));
ylabel('Мощность, дБм'); xlabel('Частота, МГц');
title("Сигнал UE перенесенный на несущую");
xlim( ue_Fcarrier/1e6 + [-1 1]*ue_BW );
grid on; hold off;

subplot(313); hold on;
plot(ue_freq_shift/1e6, 10*log10(abs(fftshift(deresam_waveform_low_spectrum)).^2/R*2.*1000));
title("Принятый сигнал и перенесенный на f = 0 Гц");
grid on; hold off;
%%
figure('Name','OFDM сигналы');
subplot(221); 
plot(OFDM_1_freq/1e6, 10*log10(((abs(fftshift(fft(OFDM_1_waveform(1:length(OFDM_1_freq))))/length(OFDM_1_freq)).^2)/R*2)*1000) );
xlabel('Частота, МГц'); ylabel('Мощность, дБм');    
% legend(['Полоса ', num2str(sscanf(BW_1, "%dMHz")), ' МГц'], 'Location','northeast');
title(['Полоса ', num2str(sscanf(BW_1, "%dMHz")), ' МГц']);
grid on;

subplot(223);
plot(resam_freq/1e6, 10*log10(((abs(fft(OFDM_shift_1)/resam_nfft).^2)/R*2)*1000) );
xlabel('Частота, МГц'); ylabel('Мощность, дБм');
x_lim = ([-1 1]*2*sscanf(BW_1, "%dMHz")*1e6 + f1) / 1e6;
xlim(x_lim);
x_diff = sscanf(BW_1, "%dMHz")/2;
xticks([flip(-f1/1e6:x_diff:-x_lim(1))*-1, f1/1e6+x_diff:x_diff:x_lim(2)]);
title(['Полоса ', num2str(sscanf(BW_1, "%dMHz")), ' МГц; Несущая f = ', num2str(round(f1/1e6,1)), ' МГц']);
% clear x_lim x_diff;
grid on;
% periodogram(OFDM_1_waveform,'power');

subplot(222);
plot(OFDM_2_freq/1e6, 10*log10(((abs(fftshift(fft(OFDM_2_waveform(1:length(OFDM_2_freq))))/length(OFDM_2_freq)).^2)/R*2)*1000) );
xlabel('Частота, МГц'); ylabel('Мощность, дБм');
% legend(['Полоса ', num2str(sscanf(BW_2, "%dMHz")), ' МГц'], 'Location','northeast');
title(['Полоса ', num2str(sscanf(BW_2, "%dMHz")), ' МГц']);
grid on;

subplot(224);
plot(resam_freq/1e6, 10*log10(((abs(fft(OFDM_shift_2)/resam_nfft).^2)/R*2)*1000) );
xlabel('Частота, МГц'); ylabel('Мощность, дБм');
x_lim = ([-1 1]*2*sscanf(BW_2, "%dMHz")*1e6 + f2) / 1e6;
xlim(x_lim);
x_diff = sscanf(BW_2, "%dMHz")/2;
xticks([flip(-f2/1e6:x_diff:-x_lim(1))*-1, f2/1e6+x_diff:x_diff:x_lim(2)]);
title(['Полоса ', num2str(sscanf(BW_2, "%dMHz")), ' МГц; Несущая f = ', num2str(round(f2/1e6,1)), ' МГц']);
clear x_lim x_diff;
grid on;

set(findobj(gcf,'type','axes'),'FontSize',12);
%%
figure('Name','Гетеродинная среда');
fig_x_lim = [0.4 1.6]*(f1+f2)/2/1e6;
% fig_x_lim = abs(0.3 + [-1 1]) * ((max(f1, f2) + ue_Fcarrier)/2/1e6);

subplot(221);
plot(resam_freq(1:end/2)/1e6, 10*log10(two_ofdm_DL_spectrum(1:end/2)*1000));
% pspectrum(two_ofdm_DL, resam_fs, 'Leakage',1);
xlim( ([-abs(f1-f2) abs(f1-f2)]+((f1+f2)/2))/1e6 );
ylim_data = [min(10*log10(two_ofdm_DL_spectrum(1:end/2)*1000)), max(10*log10(two_ofdm_DL_spectrum(1:end/2)*1000))];
ylim([ ylim_data(1), ylim_data(2) - ylim_data(1) * 0.1 + ylim_data(2) ]);
% xlim(fig_x_lim);
xlabel('Частота, МГц'); ylabel('Мощность, дБм');

title(['f1 = ', num2str(round(f1/1e6,1)), ' МГц; f2 = ', num2str(round(f2/1e6,1)), ' МГц']);
fig_data = gca; max_data = max(fig_data.Children.YData); %gca gcf
text(f1/1e6, max_data, [num2str(sscanf(BW_1, "%dMHz")),' МГц'], 'VerticalAlignment', 'bottom', 'FontSize',12, 'HorizontalAlignment','center');
text(f2/1e6, max_data, [num2str(sscanf(BW_2, "%dMHz")),' МГц'], 'VerticalAlignment', 'bottom', 'FontSize',12, 'HorizontalAlignment','center');
grid on;
clear ylim_data fig_data max_data;

subplot(222);
plot(resam_freq(1:end/2)/1e6, 10*log10(IM3_signal_spectrum_Power(1:end/2)*1000));
% pspectrum(IM3_signal,resam_fs, 'Leakage',0);
xlim(fig_x_lim);
xlabel('Частота, МГц'); ylabel('Мощность, дБм');
grid on;

subplot(223); hold on;
plot(resam_freq(1:end/2)/1e6, 10*log10(shift_add_resam_spectrum(1:end/2)*1000));
% plot(resam_freq/1e6, 10*log10(shift_resam_spectrum*1000))
% pspectrum(shift_add_resam_waveform,resam_fs);
xlim(fig_x_lim);
xlabel('Частота, МГц'); ylabel('Мощность, дБм');
grid on; hold off;

set(findobj(gcf,'type','axes'),'FontSize',12);
% set(gca, 'FontSize', 12);
%%
% scope = dsp.SpectrumAnalyzer;
% 
% scope.SampleRate = resam_fs;
% scope.Method = 'filter-bank';
% scope.ReferenceLoad = 50;
% % scope.InputDomain = "frequency";
% % scope.Window = 'blackman-harris';
% scope.PlotAsTwoSidedSpectrum = false;
% % scope.StartFrequency
% scope.FrequencySpan = "span-and-center-frequency";
% scope.Span = 3e9;
% scope.CenterFrequency = mean(f1+f2)/2;
% scope.RBWSource = "property";
% scope.RBW = 0.5e6;
% 
% % scope.col
% 
% scope(real(two_ofdm_DL));
% % scope(real(IM3_signal));
% % scope(real(shift_add_resam_waveform));
% 
% 
% 
% % scope.BackgroundColor = "white";
% % scope.AxesColor = "white";
% % scope.FontColor = "black";
% % scope.LineColor = "black";
end
%%
if is_for
if ~is_graph_view
    close all;
end
%
figure();
plot(10*log10(Arr_power_2*1000), 10*log10(FOR_SNR(:,:)*1000));

set(findobj(gcf,'type','axes'),'FontSize',12);

% BER
if size(FOR_BER,1)>1 && size(FOR_BER,2)>1
figure('Name','BER or Bit Error Rate', 'Position',[38,59,560,477]);
hold on;
markers = {'o', 's', 'd', '.', 'x', 's', 'd', '^', 'v', '>', '<', 'p', 'h'};
for i = 1:min(size(FOR_SNR))
    % semilogy(10*log10(FOR_SNR(i,:)*1000), FOR_BER(i,:));
    plot(10*log10(FOR_SNR(i,:)*1000), FOR_BER(i,:), ...
        'Marker', markers{i}, ...
        'Color','k', ...
        'MarkerSize',7);
end
xlabel('SNR, дБ'); ylabel('BER (Bit Error Rate)');
legend('QPSK', '16QAM', '64QAM', 'Location','southwest');
grid on; hold off;
set(findobj(gcf,'type','axes'),'FontSize',12);
set(gca, 'YScale', 'log');
end

% IM
flag_IM = true;
if size(Arr_power_1,2)==1
    line_x = 10*log10(Arr_power_2*1000);
    text_x = "Мощность сигнала OFDM с F_{DL2}, дБм";
    idx_equal_power = find(Arr_power_1*1.05>=Arr_power_2 & Arr_power_2>=Arr_power_1*0.95);
    point_text = ['P_{1} = ', num2str(Arr_power_1), ' Вт'];
    data_IM_equal = [FOR_IM{1,idx_equal_power}(1,1), FOR_IM{1,idx_equal_power}(2,1)];
elseif size(Arr_power_2, 2)==1
    line_x = 10*log10(Arr_power_1*1000);
    text_x = "Мощность сигнала OFDM с F_{DL1}, дБм";
    idx_equal_power = find(Arr_power_2*1.05>=Arr_power_1 & Arr_power_1>=Arr_power_2*0.95);
    point_text = ['P_{2} = ', num2str(Arr_power_2), ' Вт'];
    data_IM_equal = [FOR_IM{idx_equal_power,1}(1,1), FOR_IM{idx_equal_power,1}(2,1)];
else
    flag_IM = false;
end
if flag_IM

figure('Position',[1062,51,852,561]);
subplot(111); hold on;
plot(line_x, cellfun(@(x) x(1,1), FOR_IM), 'Marker','.','MarkerSize',15);
plot(line_x, cellfun(@(x) x(1,2), FOR_IM), 'Marker','o');
xlabel(text_x); ylabel('Мощность ПИМ, дБм');

% subplot(111); hold on;
plot(line_x, cellfun(@(x) x(2,1), FOR_IM), 'Marker','square', 'MarkerSize',10, 'Color','blue');
plot(line_x, cellfun(@(x) x(2,2), FOR_IM), 'Marker','x', 'MarkerSize',10);
xlabel(text_x); ylabel('Мощность ПИМ, дБм');

plot([line_x(idx_equal_power), line_x(idx_equal_power)], ...
     [data_IM_equal(1)*0.9, data_IM_equal(2)*1.1 ], ...
     'LineStyle','--','Color','k');
text(line_x(idx_equal_power), data_IM_equal(1)*0.9, point_text, ...
    "FontSize", 12, "HorizontalAlignment","center","VerticalAlignment","bottom");

legend('ИМ3: 2f1-f2', 'ИМ3: 2f2-f1', 'ИМ5: 3f1-2f2', 'ИМ5: 3f2-2f1', '', ...
       'Location','southeast');
xticks([ line_x(1)-1, line_x, line_x(end)+1]);
grid on; hold off;
set(findobj(gcf,'type','axes'),'FontSize',12);
end

end % вкл графики