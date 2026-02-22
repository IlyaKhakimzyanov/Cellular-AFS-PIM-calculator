% work with ofdm
clear;
close all;
% Параметры LTE
enb = lteTestModel('3.1', '20MHz');
% enb = struct();                  % Создаем структуру для параметров eNodeB
% enb.NDLRB = 100;                 % 100 ресурсных блоков для 20 МГц (18 МГц полезной полосы)
% enb.CyclicPrefix = 'Normal';     % Обычный циклический префикс
% enb.CellRefP = 1;                % Одна антенна порта
% enb.DuplexMode = 'FDD';          % Режим дуплекса FDD
% enb.NCellID = 0;                 % Идентификатор соты
% enb.NSubframe = 0;               % Номер подкадра
% %%
% cec.FreqWindow = 1;
% cec.TimeWindow = 1;
% cec.InterpType = 'cubic';
% cec.PilotAverage = 'UserDefined';
% cec.InterpWinSize = 3;
% cec.InterpWindow = 'Causal';
%%

%
time_subframe = 1e-3; %1 ms

% --- Генерация эталонного сигнала
[tx_waveform, tx_grid, tx_info] = lteTestModelTool(enb);

tx_fs = tx_info.SamplingRate;
tx_NFFT = double(tx_info.Nfft);
tx_time = 0 : 1/tx_fs : (enb.TotSubframes * time_subframe - 1/tx_fs);
tx_len = length(tx_time);

% Исследование мощности
clc
R = 50;
Power_W_BW = bandpower(tx_waveform, tx_fs, [-10e6 10e6])/R
v_coef = sqrt(20/Power_W_BW); tx_waveform = tx_waveform .* v_coef;
Power_W = mean(abs(tx_waveform).^2)/R
Power_dBm = 10*log(Power_W*1000)
figure();
% plot(vtodbm(abs(fft(tx_waveform,4048)/4048), 50)) 
% plot(vtodbm(abs(fft(cos(2*pi*50*(0:0.001:1-0.001)).*44.7))./(length(0:0.001:1-0.001)), 50))
plot( 10.*log10( abs(fft(tx_waveform)) .^2 / R * 2 *1000 )  ) 
% plot(10.*log10(abs(fft(tx_waveform,4048)).^2./50  .* 1000 ));

% THD - thd

%%

% --- ресэмпл
% resam_fs = tx_fs*10;
resam_fs = 2e9;

% Ресемплируем сигнал
p = resam_fs / gcd(resam_fs, tx_fs);   % Числитель коэффициента передискретизации
q = tx_fs / gcd(resam_fs, tx_fs);      % Знаменатель коэффициента передискретизации
ratio_fs = p/q;

resam_time = 0:1/resam_fs:(enb.TotSubframes*time_subframe - 1/resam_fs);
% resam_waveform = resample(tx_waveform, p, q);
[resam_waveform, coeff] = Resample_Wave(tx_waveform, tx_fs, resam_fs);
resam_len = length(resam_time);


% Перенос сигнала на несущую
resam_waveform = Shift_Signal(resam_waveform, resam_fs, 1800e6, 1);

% --- спектры
tx_len = tx_NFFT*2;
resam_len = tx_len * ceil(ratio_fs);

tx_spectrum = fft(tx_waveform, tx_len)/tx_len;
tx_freq = 0:tx_fs/tx_len:tx_fs - tx_fs/tx_len;
tx_freq_shift = (-tx_len/2:tx_len/2-1)*tx_fs/tx_len;

resam_spectrum = fft(resam_waveform, resam_len)/resam_len;
resam_freq = 0:resam_fs/resam_len:resam_fs - resam_fs/resam_len;
resam_freq_shift = (-resam_len/2:resam_len/2-1)*resam_fs/resam_len;


%(-new_NFFT/2:new_NFFT/2-1) * fs*a/new_NFFT;





%% Graph
% --- Время
time_graph = figure('Name','tx signal OFDM');
% time_graph.Renderer = "painters"; 
hold on;
 %
lim = 100;
plot_lim1 = 1:lim; plot_lim2 = 1:lim*p/q;
plot(tx_time(plot_lim1), real(tx_waveform(plot_lim1)));
 % 
plot(resam_time(plot_lim2), real(resam_waveform(plot_lim2)));

% xlim([0 (0.5e-3 / 7)]); %0.5ms - 1 slot, % 0.5ms / 7 (CP normal)
title('Временная область (I-компонента)');
xlabel('Время, с');
grid on; hold off;

% --- Частота
freq_graph = figure('Name','Спектр сигналов OFDM');
subplot(211);
% plot(tx_freq, abs(tx_spectrum));
plot(tx_freq_shift/1e6, 10*log10(abs(fftshift(tx_spectrum))*1000));
% xlim([-1e7 1e7]);
xlabel('Частота, МГц'); ylabel('A');
grid on; 

subplot(212);
plot(resam_freq/1e6, abs(resam_spectrum));
% plot(resam_freq_shift/1e6, abs(fftshift(resam_spectrum)));
% xlim([-1e7 1e7]);
xlabel('Частота, МГц'); ylabel('A');
grid on;

% function out_signal = Shift_Signal(in_signal, Fs, delta_F, RightOrLeft)
% % Функция для переноса сигнала на дельта F:
% % in_signal - входной сигнал; Fs - частота дискрет;
% % delta_F - на какую частоту перенести сигнал;
% % RightOrLeft - 1 = вверх, -1 = вниз по частоте;
%     Ts = 1/Fs;
%     time = (0:length(in_signal)-1)*Ts;
%     RightOrLeft = RightOrLeft*-1; % с этим он наоборот ввер по частоте поднимается
%     if ~(RightOrLeft == 1 || RightOrLeft == -1)
%         error('RightOrLeft = 1 или -1');
%     end
%     [row, cols] = size(in_signal);
%     if row>cols && cols == 1
%         out_signal = in_signal .* (exp(RightOrLeft * 1i * 2*pi * delta_F * time))';
%     elseif row<cols && row == 1
%             out_signal = in_signal .* exp(RightOrLeft * 1i * 2*pi * delta_F * time);
%     else 
%         error('Неправильный размер входного массива');
%     end
% end
