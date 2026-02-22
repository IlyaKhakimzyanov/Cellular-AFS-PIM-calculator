clear all;
close all;
clc;

% Параметры сигнала
fs = 5e9;          % Частота дискретизации (Гц)
T = 1e-6;            % Длительность сигнала (с)
t = 0:1/fs:T-1/fs;   % Временная ось
f1 = 925e6;            % Частота первого тона (Гц)
f2 = 960e6;            % Частота второго тона (Гц)

% Входной сигнал: два тона с амплитудой 44.72 (для мощности ~30 дБм)
x = 44.72 * (sin(2*pi*f1*t) + cos(2*pi*f2*t));

% Коэффициенты TD-PWL модели из Таблицы 1 статьи
a = [1.45563; 1.43757; 1.40262; 1.35217; 1.28853; 1.21463; 1.13305; ...
     1.04682; 0.95845; 0.87069; 0.78492; 0.70286; 0.62436];

% Пороги для TD-PWL (равномерное разбиение, примерные значения)
lambda = linspace(0, max(abs(x)), length(a)+1);

% Применение TD-PWL модели
y = zeros(size(x));
for i = 1:length(a)
    % Пороговая декомпозиция (формула 3 из статьи)
    Xi = zeros(size(x));
    idx = (abs(x) >= lambda(i)) & (abs(x) < lambda(i+1));
    Xi(idx) = x(idx) - lambda(i);
    idx = (abs(x) >= lambda(i+1));
    Xi(idx) = lambda(i+1) - lambda(i);
    
    % Добавление вклада i-го сегмента
    y = y + a(i) * Xi;
end

% Построение графиков
figure;

% Входной и выходной сигналы во временной области
subplot(2,2,1);
plot(t, x, 'b');
title('Входной сигнал x(t)');
xlabel('Время (с)');
ylabel('Амплитуда');
grid on;

subplot(2,2,2);
plot(t, y, 'r');
title('Выходной сигнал y(t) после PWL');
xlabel('Время (с)');
ylabel('Амплитуда');
grid on;

% Спектры входного и выходного сигналов
N = length(x);
f = (0:N-1) * fs / N;

X_fft = abs(fft(x)) / N;
Y_fft = abs(fft(y)) / N;

subplot(2,2,3);
plot(f, 20*log10(X_fft), 'b');
title('Спектр входного сигнала');
xlabel('Частота (Гц)');
ylabel('Амплитуда (дБ)');
xlim([800e6 1000e6]);
grid on;

subplot(2,2,4);
plot(f, 20*log10(Y_fft), 'r');
title('Спектр выходного сигнала');
xlabel('Частота (Гц)');
ylabel('Амплитуда (дБ)');
xlim([800e6 1000e6]);
grid on;

%%
% Параметры
fs = 5e9;
t = 0:1/fs:1e-6;%-1/fs;
f1 = 925e6;
f2 = 960e6;
V = 44.72;
R = 50; 

% Сигналы
v_in = V * (cos(2*pi*f1*t) + cos(2*pi*f2*t));
a_coeffs = [1.52e-5, -4.29e-10, 7.18e-14, -5.39e-18, 1.67e-22, -1.88e-25];
i_out = poly_iv_model(v_in, a_coeffs);

% Спектры
N = length(t);
f = (-N/2:N/2-1)*(fs/N)/1e6;  % Частотная ось (МГц)
V_f = abs(fftshift(fft(v_in)))/N;
I_f = abs(fftshift(fft(i_out)))/N;

% Перевод в мощность и dBm
Pv = V_f.^2 / (2*R);        % Мощность от напряжения
Pi = (I_f.^2) * R / 2;      % Мощность от тока

Pv_dBm = 10*log10(Pv / 1e-3); % в dBm
Pi_dBm = 10*log10(Pi / 1e-3);

% График
figure;
plot(f, Pv_dBm,'DisplayName', 'Вх(по напряжению)');
hold on;
plot(f, Pi_dBm, 'DisplayName', 'Вых(по току)');
xlim([850 1030]);
ylim([-150 0]);
xlabel('Частота, МГц');
ylabel('Амплитуда, dBm');
title('Спектры сигналов в dBm');
legend;
grid on;

function i_out = poly_iv_model(v_in, a_coeffs)
    i_out = zeros(size(v_in));
    for k = 1:length(a_coeffs)
        degree = 2*k - 1; % Степень: 1, 3, 5, ...
        i_out = i_out + a_coeffs(k) * v_in.^degree;
    end
end