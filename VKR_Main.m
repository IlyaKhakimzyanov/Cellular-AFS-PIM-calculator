clear;
close all;

% Полный путь к папке с функциями
currentFolder = fileparts(mfilename('fullpath'));  % Папка, где лежит test.m
functionsFolder = fullfile(currentFolder, 'funct');

% Проверяем существование папки
if ~isfolder(functionsFolder)
    error('Папка с функциями "%s" не найдена! Создайте папку "funct" и поместите туда файлы функций.', functionsFolder);
else
    addpath(functionsFolder);
end

%% Ввод параметров
% Для дискретизации
time = 1e-3; % Время одного sub-frame, тк в радио не RB а PRB состоящий из 2х RB
time = 1e-6;
F_sample = 15e9; T_sample = 1/F_sample;
% time = 1; F_sample = 32000; T_sample = 1/F_sample;
N_sample = round(time/T_sample);
num_sample = 0:(N_sample - 1);
% Count_sample = length(num_sample);
time_sample = num_sample * T_sample;
freq_sample = num_sample / N_sample * F_sample ;
% Физические параметры
R = 50; % Ом
PowerTx = [20 20];
PowerTx_dBm = 10*log10(PowerTx*1000);
Vol = sqrt(PowerTx .* R) * sqrt(2); % V=sqrt(P*R) * sqrt(2) - она из эффект и ампл вольтажа

Vol1 = Vol(1);
Vol2 = Vol(2);
% Частоты
f1 = 900e6; 
f2 = 1000e6;
% f2 = 1000e6;
time_look = 1/max(f1, f2) * 80 ;
%%
% --- Заготовленные коэффициенты
    %Qiuyan Jin
Coef_Jin = zeros(13,6);
Coef_Jin(3, :) = [0, 1.466, 1.471, 1.486, 1.504, 1.538] *1e-5;
Coef_Jin(5, :) = [0, -3.53, -3.98, -5.29, -6.86, -10.48]*1e-11;
Coef_Jin(7, :) = [0, 0,     0.54,  1.46,  2.70,  11.05] *1e-18;
Coef_Jin(9, :) = [0, 0,     0,     -1.48, -4.83, -65.42]*1e-24;
Coef_Jin(11,:) = [0, 0,     0,     0,     0.31,  17.36] *1e-31;
Coef_Jin(13,:) = [0, 0,     0,     0,     0,     -1.63] *1e-38;
Coef_Jin_modif = [0 0 3/4 0 25/8 0 735/64 0 1323/32 0 38115/256 0 552123/1024];

    %Lingyu Bi DOI 10.1109/TCPMT.2020.3033329
Coef_Lingyu = [0, 0, 4.177*1e-12, 0, -1.494*1e-15, 0, 2.905*1e-19]; % Только для IM3
Coef_Lingyu_2=[0, 0, 5.569*1e-12, 0, -4.781*1e-16, 0, 2.530*1e-20]; % Создание спекрта

    %Junyu Luo DOI 10.1109/AEMCSE51986.2021.00184
Coef_Junyu_Luo = [0.02 0 1.655e-11 0 -1.261e-15 0 6.424e-20];

    %Kozlov 2016 (and Lingyu Bi 2021 )
Coef_Kozlov = [1, 0, 6.60e-9, 0, -2.54e-11, 0, 4.95e-14, 0, -5.5e-17, 0, 3.76*1e-20, 0, -1.65*1e-23, 0, 4.71e-27, 0, -8.76e-31, 0, 1.02e-34, 0, -6.75e-39, 0, 1.94e-43];

    %Khaled M. Gharaibeh 2024
    Khaled_poly = [1.0303, 0 , -3.6048e-4, 0, 1.4993e-7, 0, -4.4793e-11, 0, -1.1546e-13, 0, 6.4532e-16, 0, -1.7754e-18];
    Khaled_PWL = [1.45563; 1.43757; 1.40262; 1.35217; 1.28853; 1.21463; 1.13305; ...
     1.04682; 0.95845; 0.87069; 0.78492; 0.70286; 0.62436];

% --- Используемые коэффиценты
% a = Coef_Jin(3:end, 4)';% a = a.* Coef_Jin_modif(1:length(a));
% a = Coef_Lingyu;
a = Coef_Lingyu_2; % Пока лучшая
% a = Coef_Junyu_Luo;
% a = Coef_Kozlov(1:7);
% a = Khaled_poly;
%% Отрисовка характеристик
% --- Входная/выходная мощность
P_in_dBm = linspace(30, 46, 46-30+1); % Input power
P_in = 10.^(P_in_dBm/10)/1000;
V_in = sqrt( P_in * R) * sqrt(2);
i_out = Nonlinear_polynomial(a, V_in);
% i_out = a(3) * V_in.^3;
P_out = R/2 * i_out.^2;
P_out_dBm = 10*log10(P_out*1000);

x = [P_in_dBm(1) P_in_dBm(2)]; 
y = [P_out_dBm(1) P_out_dBm(2)];
P_line = (P_in_dBm - x(1)) / (x(2) - x(1)) * (y(2) - y(1)) + y(1);

Compression_Point = NaN;
for i = 1:length(P_in_dBm)
    if abs(P_line(i) - P_out_dBm(i)) >= 1
        Compression_Point = i;
        break
    end
end

fig = figure('Position', [7,456,1290,477]);
% set(fig(gcf, type));
subplot(121);
hold on; grid minor;
plot(P_in_dBm, P_out_dBm, 'Marker','.','MarkerSize',12, 'LineWidth', 1.2);
plot(P_in_dBm, P_line, 'LineStyle','--', 'LineWidth',1.2);
xlabel('Мощность Pвх, дБм'); ylabel('Мощность Pвых, дБм');
xlim([P_in_dBm(1), P_in_dBm(end)]);
legend('Нелинейная характерисика', 'Линейный элемент', 'Location','southeast');

% text(P_in_dBm(Compression_Point), P_out_dBm(Compression_Point), {'Точка компрессии 1dBm, ', num2str(round(P_line(Compression_Point), 1))}, 'VerticalAlignment', 'top');
% text(Power+0.2, IM_Power_dBm(2,:), num2str(round(IM_Power_dBm(2,:)', 1)), 'VerticalAlignment', 'bottom'); % %'HorizontalAlignment', 'left' 
hold off;
subplot(122);
hold on; grid on;
plot(V_in, i_out*1000, 'Marker','.','MarkerSize',12, 'LineWidth',1.2);
xlabel('Напряжение, В'); ylabel('Ток, мА');
xlim([V_in(1), V_in(end)]); %xticks(V_in(1:2:end));
hold off;
clear x y;
set(findobj(gcf,'type','axes'),'FontName','Arial','FontSize',12, 'LineWidth', 1);

%% Мощность PIM от 
% Перенести после графиков
% SimSignalOFDM(2100e6, 10, 20, F_sample, Count_sample)

%% --- 

% Функции сигналов
v1 = Vol1 * cos(2*pi*f1*time_sample) + Vol2 * cos(2*pi*f2*time_sample);
% v1 = SimSignalOFDM(900, 10, 20, F_sample, N_sample) + SimSignalOFDM(2110, 10, 20, F_sample, N_sample) ;

i1_IM3 = Nonlinear_polynomial(a, v1);
% i1_IM3 = Nonlinear_polynomial(a, Vol1) .* cos(2*pi*(2*f1-f2)*time_sample);
% i1_IM3 = 3/4 * a(3) *Vol1^3 .*cos(2*pi*(2*f1-f2) * time_sample);
% i1_IM3 = PWL(Khaled_PWL, v1);
% i1_IM3 = Vol1 * (1 + 6e-4 * tanh(3e-2 * v1/Vol1));

v1_IM3 = i1_IM3 * R ; %* (cos(2*pi*(2*f1-f2)*time_sample) + cos(2*pi*(3*f1-2*f2)*time_sample))

% FFT
f_v1 = fft(v1) / N_sample; % Нормализация
Power_f_v1 = (abs(f_v1).^2) / R * 2; % Превращаю обратно в мощность
Power_f_v1_dBm = 10*log10(Power_f_v1 * 1000);

f_v1_IM3 = fft(v1_IM3) / N_sample;
Power_f_v1_IM3 = (abs(f_v1_IM3).^2) / R * 2;
Power_f_v1_IM3_dBm = 10*log10(Power_f_v1_IM3 * 1000);
%% --- Графики
grapth_time_lim = time*0.06;
grapth_time_lim = time_look;

figure('Name','Tx и Rx сигнал', 'Position', [263,153,1457,778]);

% Сигнал с выхода передатчика
subplot(221); hold on;
plot(time_sample, v1); 
title('Двухтональный сигнал ДО'); 
% xlim([0 grapth_time_lim]);
grid on; hold off;

% Спектр сигнала с выхода передатчика
subplot(222); hold on;
% h = stem(freq_sample/1e6, Power_f_v1_dBm, 'Marker','.');
% h.BaseValue = min(Power_f_v1_dBm);
plot(freq_sample/1e6, Power_f_v1_dBm, 'Marker','.');
% title('Спекрт двухтонального сигнала');
xlabel('Частота, МГц'); ylabel('Мощность, дБм');
xlim( (abs(f1-f2)*8 * [-1 1] + mean([f1 f2])) / 1e6);
grid on; hold off;

% Сигнал после нелинейного участка
subplot(223); hold on;
plot(time_sample, v1_IM3); 
title('Двухтональный сигнал После'); grid on;
% xlim([0 grapth_time_lim]);
grid on; hold off;

% Спектр сигнала после нелинейного участка
subplot(224); hold on;
plot(freq_sample/1e6, Power_f_v1_IM3_dBm, 'Marker','.');
% title('Сигнал после нелинейного участка');
xlabel('Частота, МГц'); ylabel('Мощность, дБм');
% xlim( (abs(f1-f2)*10 * [1 1] + mean([f1 f2])) / 1e6);
xlim([0 f2*3+f1]/1e6);
% xlim([925-150 960+150]); ylim([-200 0]);
grid on; hold off;

set(findobj(gcf,'type','axes'),'FontName','Arial','FontSize',12, 'LineWidth', 1);
%%
figure();
hold on;
% h = 
plot(freq_sample/1e6, Power_f_v1_dBm, 'Marker','.');
plot(freq_sample/1e6, Power_f_v1_IM3_dBm, 'Marker','.');
plot([freq_sample(1)/1e6, freq_sample(end)/1e6], [PowerTx_dBm(1), PowerTx_dBm(1)]-105);
% h.BaseValue = min([Power_f_v1_dBm, Power_f_v1_IM3_dBm]);
% xlim([925-150 960+150]);
xlim( (abs(f1-f2)*10 * [-1 1] + mean([f1 f2])) / 1e6);
ylim([-150 inf]);
% yticks(-118:6:53);
legend('Двухтональный входной сигнал', 'Сигнал после модели нелинейного участка');
xlabel('Частота, МГц'); ylabel('Мощность, дБм');
grid on; hold off;


%% Мощность сигнала
find_f = 2*f1-f2;
IM3_Power_W = bandpower(v1_IM3, F_sample, find_f+[-10 10])/R;
% IM3_Power_W = bandpower(v1_IM3, F_sample, [find_f-10 find_f+10])/R;
IM3_Power_dBm = 10*log10(IM3_Power_W*1000);
fprintf("IM3 = %f;\nIM3_dBm = %f\n", IM3_Power_W, IM3_Power_dBm);

%%
% i1_IM3 = PWL(Khaled_PWL, v1);

%%
graph_show_IM(a, f1, f2, R, time_sample);

%%
% figure();
% line = 1:1:5;
% s = [1 1 1 1 1 1 1];
% % s = [1 1 1/2.25 1 1/6.25 1 1];
% k = 0;
% for i = line
%     k = k+1;
%     subplot(length(line), 1, k); hold on; grid on; xlim([0 3000]);
%     spec = abs(fft(s(i) * (cos(2*pi*f1*time_sample) + cos(2*pi*f2*time_sample)).^i)) / N_sample;
%     plot(freq_sample, spec);
%     clear spec;
%     hold off;
% end
% clear k line;

%% Функции

% function y = polyn(coefpoly, x)
%     % 3 5 7 9 11 13
%     % if length(coefpoly) > 6 
%     %     error('Слишком много коэф для полинома'); 
%     % end
%     % coefpoly = [coefpoly, zeros(1, 6 - length(coefpoly)) ];
%     % disp(coefpoly);
%     y = zeros(1, length(x));
%     for i = 1:length(coefpoly)
%         y = y + coefpoly(i) * x.^(i);
%     end
% end

function y = PWL(a, x)
    K = length(a);
    N = length(x);
    xmax = max(x);
    lambda = linspace(0, xmax, K+1);
    if length(lambda) ~= K+1
        error('Длина вектора lambda должна быть K+1.');
    end

    X = zeros(length(x), K);
    abs_x = abs(x);
    sgn_x = sign(x);           % знак нужен для восстановления фазы

    for i = 1:K
        Xi = zeros(N,1);
    
        % Условие 1: |x| < la_i - X_i = 0 (уже по умолчанию)
        
        % Условие 2: la_i ≤ |x| <= la_{i+1}
        mask2 = abs_x >= lambda(i) & abs_x <= lambda(i+1);
        Xi(mask2) = (abs_x(mask2) - lambda(i)) .* sgn_x(mask2);
    
        % Условие 3: |x| > la_{i+1}
        mask3 = abs_x > lambda(i+1);
        Xi(mask3) = (lambda(i+1) - lambda(i)) .* sgn_x(mask3);
    
        X(:, i) = Xi;
    end
    y = X * a(:);
end

function graph_show_IM(a, f1, f2, R, t)
    if ~isempty(findobj('Type', 'figure', 'Name', 'Исследование IM3-7'))
        close('Исследование IM3-7');
    end

    Power = 30:44;
    Power_W = 10.^(Power/10)/1000;
    Fs = 1/(t(2)-t(1));
    IM_Power = zeros(4, length(Power));
    find_IM = [2*f1-f2,   2*f2-f1;
              3*f1-2*f2, 3*f2-2*f1;
              4*f1-3*f2, 4*f2-3*f1];
    offset = 10; % Гц
    
    for i = 1:length(Power)

        Amp = sqrt(Power_W(i) * R) * sqrt(2);
        signal = Amp * (cos(2*pi*f1*t) + cos(2*pi*f2*t));
        i_IM = Nonlinear_polynomial(a, signal);
        v_IM = i_IM * R;

        % IM_Power_W = bandpower(v_IM, F_sample, [find_f-10 find_f+10])/R;
        % IM_Power_dBm = 10*log10(IM_Power_W*1000);
        IM_Power(1, i) = bandpower(v_IM, Fs, [f1-offset, f1+offset])/R;
        IM_Power(2, i) = bandpower(v_IM, Fs, [find_IM(1,2)-offset, find_IM(1,2)+offset])/R;
        IM_Power(3, i) = bandpower(v_IM, Fs, [find_IM(2,2)-offset, find_IM(2,2)+offset])/R;
        IM_Power(4, i) = bandpower(v_IM, Fs, [find_IM(3,2)-offset, find_IM(3,2)+offset])/R;
    end
    IM_Power_dBm = 10*log10(IM_Power.*1000);
    figure('Name','Исследование IM3-7','Position',[82,280,1695,675]); 
    % График 1
    subplot(121); hold on;
    plot(Power, 10*log10(IM_Power(1, :)*1000));
    plot(Power, 10*log10(IM_Power(2, :).*1000), 'Marker','square');
    plot(Power, 10*log10(IM_Power(3, :).*1000), 'Marker','*');
    plot(Power, 10*log10(IM_Power(4, :).*1000), 'Marker','x');
    legend({'Pin'; 'IM3'; 'IM5'; 'IM7'}, 'Location', 'northwest');
    xlabel('Уровень мощности Pin, дБм');
    ylabel('Уровень мощности IM, дБм');
    set(gca, 'FontSize', 12);
    grid on; hold off;
    % График 2
    diff = max( Power(end) - Power(1), max(IM_Power_dBm(2,:)) - min(IM_Power_dBm(2,:)) );
    subplot(122);
    yyaxis left;
    % plot(Power, Power, 'Marker','o');
    plot(Power, IM_Power_dBm(1,:), 'Marker','o');
    ylabel('Уровень мощности Pin, дБм');
    ylim([Power(1), Power(1)+diff]);
    
    yyaxis right;
    plot(Power, IM_Power_dBm(2,:), 'Marker','square');
    text(Power+0.2, IM_Power_dBm(2,:), num2str(round(IM_Power_dBm(2,:)', 1)), 'VerticalAlignment', 'bottom'); % %'HorizontalAlignment', 'left' 
    ylabel('Уровень мощности IM3, дБм');
    ylim([IM_Power_dBm(2,1), IM_Power_dBm(2,1)+diff]);
    
    xlabel('Уровень мощности Pin, дБм');
    xticks(Power);
    set(gca, 'FontSize', 12);
    % title('График с двумя осями Y');
    grid on;
    legend('Несущая Pin', 'IM3', 'Location', 'northwest');
end

