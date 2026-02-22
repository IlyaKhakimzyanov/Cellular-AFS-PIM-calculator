clear all;
% Все частоты в GSM UMTS LTE

GSM_num_channel = 124;
DCS_num_channel = 885-512 + 1;
% ARFCNs TS 45.005
GSM_fc_UL = 890 + 0.2 * (1:GSM_num_channel);
GSM_fc_DL = GSM_fc_UL + 45;
DCS_fc_UL = 1710.2 + 0.2 * (0:DCS_num_channel-1);
DCS_fc_DL = DCS_fc_UL + 95;


% GSM = table();
% Technologies 
All_GSM = ["GSM", 890, 915, 935, 960, "FDD"
           % ;"DCS", 1710, 1785, 1805, 1880, "FDD"
            ];

All_LTE_Band = [    "Band 1", 1920, 1980, 2110, 2170, "FDD", 15;
                    "Band 3", 1710, 1785, 1805, 1880, "FDD", 15;
                    "Band 8", 880, 915, 925, 960, "FDD", 5;
                    "Band 7", 2500, 2570, 2620, 2690, "FDD", 20;
                    "Band 20", 832, 862, 791, 821, "FDD", 5];

num_2G = size(All_GSM, 1);
num_4G = size(All_LTE_Band,1);
str_techno = [];
Cellular_BandWidht = [];
if num_2G ~=0 
    str_techno = [str_techno; All_GSM(:,1)];
    Cellular_BandWidht = [Cellular_BandWidht; 0];
end
if num_4G ~= 0
    str_techno = [str_techno; All_LTE_Band(:,1)];
    Cellular_BandWidht = [Cellular_BandWidht; double(All_LTE_Band(:,7))];
end
% str_techno = [All_GSM(:,1); All_LTE_Band(:,1)];
num_techno = num_2G + num_4G;

% Заполнение приемных каналов, куда будут поподать интермодуляции
Rx_pass_band = zeros(num_2G + num_4G, 2);
for i = 1:num_2G
    Rx_pass_band(i, 1) = double(All_GSM(i,2));
    Rx_pass_band(i, 2) = double(All_GSM(i,3));
end

for i = 1:num_4G  % +2 GSM and DCS
    Rx_pass_band(i+num_2G, 1) = double(All_LTE_Band(i,2));
    Rx_pass_band(i+num_2G, 2) = double(All_LTE_Band(i,3));
end
% Ручное добавления всех несущих которые будут перемножаться
% будет массив 
Tx_carrier = cell(1);
% Tx_carrier = [  {GSM_fc_DL};
%                 {DCS_fc_DL}];
for i = 1:num_2G
    Tx_carrier{i} = double(All_GSM(i,4)):double(All_GSM(i,5));
end
for i = 1:num_4G
    Tx_carrier{i+num_2G} = (double(All_LTE_Band(i,4))+double(All_LTE_Band(i,7))/2):(double(All_LTE_Band(i,7))):double(All_LTE_Band(i,5));
end

% Таблица для записи интермод
OutTable = table(   'Size', [0 9], ...
                    'VariableNames', {'Tech1', 'Fr1', 'Tech2', 'Fr2', 'TechIM3', 'IM3','Type IM3', 'IM5', 'TypeIM5'}, ...
                    'VariableTypes', {'string', 'double','string', 'double', 'string','double','string', 'double', 'string'});


% --- Интермодуляция ---
for techno = 1:num_techno
    fprintf("Num tech %d\n", techno);
    % Сначала интермод со своими диапазоном
    for num_fc1 = 1:(length(Tx_carrier{techno}) - 1)
        for num_fc2 = (num_fc1 + 1):length(Tx_carrier{techno})
            % интермод и заполеннеие таблицы
            OutTable = DoIM(Tx_carrier{techno}(num_fc1), techno, ...
                Tx_carrier{techno}(num_fc2), techno, ...
                OutTable, str_techno, Rx_pass_band, 0);
        end
    end
    % Интермод в других диапазонах
    if techno ~= num_techno
        for sec_techno = (techno+1):num_techno
            for fc1 = Tx_carrier{techno}
                for fc2 = Tx_carrier{sec_techno}
                    % интермод и заполеннеие таблицы
                    OutTable = DoIM(fc1, techno, ...
                        fc2, sec_techno, ...
                        OutTable, str_techno, Rx_pass_band, Cellular_BandWidht(techno), Cellular_BandWidht(sec_techno));
                end
            end
        end
    end
end

% stem([GSM_fc_UL, GSM_fc_DL, DCS_fc_UL, DCS_fc_DL], ones(1,124+124+374+374))
%%
[Hits_num, Hits_cover, Hits_IMtype] = IM3_Hits_RxBand(900, 20, 950, 20, [0 3000; 810 830])

% Надо изменить способ запроса таблицы в функцию, тк она много раз так
% будет делать, и лучше думаю просто возвращать массив того что надо
% записать
function WriteTable = DoIM(f1, idtech)

function WriteTable = DoIM(f1, idtech1, f2, idtech2, WriteTable, nameTech, Rx_band, BW1, BW2)
    tech1 = nameTech(idtech1); tech2 = nameTech(idtech2);
    [flag, hit_band] = isHitsRx(2*f1+f2, Rx_band, BW1, BW2);
    if flag
        WriteTable(end+1,:) = {tech1, f1, tech2, f2, nameTech(hit_band), 2*f1+f2, '2*f1+f2', 0,''};
    end
    [flag, hit_band] = isHitsRx(2*f1-f2, Rx_band, BW1, BW2);
    if flag
        WriteTable(end+1,:) = {tech1, f1, tech2, f2, nameTech(hit_band), 2*f1-f2, '2*f1-f2', 0,''};
    end
    [flag, hit_band] = isHitsRx(f1+2*f2, Rx_band, BW1, BW2);
    if flag
        WriteTable(end+1,:) = {tech1, f1, tech2, f2, nameTech(hit_band), f1+2*f2, 'f1+2*f2', 0,''};
    end
    [flag, hit_band] = isHitsRx(f1-2*f2, Rx_band, BW1, BW2);
    if flag
        WriteTable(end+1,:) = {tech1, f1, tech2, f2, nameTech(hit_band), f1-2*f2, 'f1-2*f2', 0,''};
    end

end
    
function [Hits_num, Hits_cover, Hits_IMtype] = IM3_Hits_RxBand(f1, BW1, f2, BW2, Rx_band) 
    [CountRx_band, ~] = size(Rx_band);
    type_IM3 = {'2*f1-f2',... 
                '2*f2-f1',...
                '2*f1+f2',...
                '2*f2+f1'};
    f_low = [f1 - BW1*0.5, f2 - BW2*0.5];
    f_high =[f1 + BW1*0.5, f2 + BW2*0.5];
    
    f_IM3 = [getFreqIM3(f1, f2)',...
             getFreqIM3(f_low(1), f_high(2))', getFreqIM3(f_high(1), f_low(2))',...
             getFreqIM3(f_low(1), f_low(2))', getFreqIM3(f_high(1), f_high(2))' ];
    IM3_band = [min(f_IM3(:,2:5)')', max(f_IM3(:,2:5)')'];
    f_IM3 = f_IM3(:, 1);
    % [Куда попал, сколько процентов, тип IM3]
    Hits_num = []; Hits_cover = []; Hits_IMtype = {};
    for RxRow = 1:CountRx_band
        for IMRow = 1:4
            [is_over, over_perc] = check_overlap(Rx_band(RxRow,:), IM3_band(IMRow,:));
            if is_over
                % Возможно неправильный метод заполения, но так проще 
                % (может быть дольше)
                Hits_num = [Hits_num; RxRow];
                Hits_cover = [Hits_cover; over_perc];
                Hits_IMtype = [Hits_IMtype, type_IM3(IMRow)];
            end
        end
    end
end

function ArrayFreq = getFreqIM3(f1, f2)
    f = sort([f1, f2]);
    ArrayFreq = [2*f(1) - f(2),... 
                 2*f(2) - f(1),...
                 2*f(1) + f(2),...
                 2*f(2) + f(1)];
end

function [is_intersecting, overlap_percentage] = check_overlap(segment1, segment2)
    %Проверка перекрытия 2х полос
    %segment1 -  отрезок для которого важно перекрытие, segment2-не информ.
    a1 = segment1(1); a2 = segment1(2);
    b1 = segment2(1); b2 = segment2(2);
    % Пересекает?
    is_intersecting = ~(a2 < b1 || b2 < a1);
    % Процент перекрытия
    if is_intersecting
        % Границы пересечения
        overlap_start = max(a1, b1);
        overlap_end = min(a2, b2);
        overlap_length = overlap_end - overlap_start;
        % Длина второго отрезка
        segment1_length = a2 - a1;
        % Процент перекрытия относительно второго отрезка
        overlap_percentage = (overlap_length / segment1_length) * 100;
    else
        overlap_percentage = 0;
    end
end

% Удалить
% function [flag, band] = isHitsRx(freq, Rx_band, BW1, BW2) % bandwidth
% [numRows, numCols] = size(Rx_band);
%     band = 0;
%     for row = 1:numRows
%         if Rx_band(row, 1) <= freq + bandwidth*3/2 && ...
%         freq - bandwidth*3/2 <= Rx_band(row, 2)
%             flag = true;
%             band = row;
%             return
%         end
%     end
%     flag = false;
% end