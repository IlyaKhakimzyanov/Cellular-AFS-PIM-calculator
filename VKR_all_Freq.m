clear all;
% Все частоты в GSM UMTS LTE

GSM_num_channel = 124;
DCS_num_channel = 885-512 + 1;
% ARFCNs TS 45.005
GSM_fc_UL = 890 + 0.2 * (1:GSM_num_channel);
GSM_fc_DL = GSM_fc_UL + 45;
DCS_fc_UL = 1710.2 + 0.2 * (0:DCS_num_channel-1);
DCS_fc_DL = DCS_fc_UL + 95;

% Technologies 
All_GSM = [%"GSM", 890, 915, 935, 960, "FDD",
           % ;"DCS", 1710, 1785, 1805, 1880, "FDD"
            ];

All_LTE_Band = [    "Band 1", 1920, 1980, 2110, 2170, "FDD", 15;
                    "Band 3", 1710, 1785, 1805, 1880, "FDD", 15;
                    "Band 8", 880, 915, 925, 960, "FDD", 5;
                    "Band 7", 2500, 2570, 2620, 2690, "FDD", 20;
                    "Band 20", 832, 862, 791, 821, "FDD", 5];
All_LTE_Band = [    All_LTE_Band;
                    "Band 38", 2570, 2620, 2570, 2620, "TDD", 15;
                    "Band 40", 2300, 2400, 2300, 2400, "TDD", 20];

All_NR_n = [        "n53", 2483.5, 2495, 0, 0, "", 0];

num_2G = size(All_GSM, 1);
num_4G = size(All_LTE_Band,1);
num_5G = size(All_NR_n, 1);
str_techno = [];
Cellular_BandWidht = [];
if num_2G ~=0 
    str_techno = [str_techno; All_GSM(:,1)];
    Cellular_BandWidht = [Cellular_BandWidht; 0.2];
end
if num_4G ~= 0
    str_techno = [str_techno; All_LTE_Band(:,1)];
    Cellular_BandWidht = [Cellular_BandWidht; double(All_LTE_Band(:,7))];
end
if num_5G ~= 0
    str_techno = [str_techno; All_NR_n(:,1)];
end
num_techno = num_2G + num_4G;

% Заполнение приемных каналов, куда будут поподать интермодуляции
Rx_pass_band = zeros(num_2G + num_4G + num_5G, 2);
for i = 1:num_2G
    Rx_pass_band(i, 1) = double(All_GSM(i,2));
    Rx_pass_band(i, 2) = double(All_GSM(i,3));
end

for i = 1:num_4G  % +2 GSM and DCS
    Rx_pass_band(i+num_2G, 1) = double(All_LTE_Band(i,2));
    Rx_pass_band(i+num_2G, 2) = double(All_LTE_Band(i,3));
end

for i = 1:num_5G
    Rx_pass_band(i+num_2G+num_4G, 1) = double(All_NR_n(i,2));
    Rx_pass_band(i+num_2G+num_4G, 2) = double(All_NR_n(i,3));
end

Tx_carrier = cell(1);
for i = 1:num_2G
    Tx_carrier{i} = double(All_GSM(i,4)):double(All_GSM(i,5));
end
for i = 1:num_4G
    Tx_carrier{i+num_2G} = (double(All_LTE_Band(i,4))+double(All_LTE_Band(i,7))/2):(double(All_LTE_Band(i,7))):double(All_LTE_Band(i,5));
end

% Таблица, какие несущие и их полосы
Table_EARFCN = table('Size', [0 4],...
               'VariableNames', {'Band', 'BW', 'Carrier', 'EARFCN'},...
               'VariableTypes', {'double', 'double', 'double', 'double'});
for i = 1:num_techno
    if sum(str_techno(1) == ["GSM", "DCS"])
        break
    end
    for j = 1:length(Tx_carrier{i})
        [num_band, EARFCN_DL] = getEARFCN(str_techno(i), Tx_carrier{i}(j));
        Table_EARFCN(end+1,:) = {num_band, Cellular_BandWidht(i), Tx_carrier{i}(j), EARFCN_DL};
    end
end

% Таблица для записи интермод
OutTable = table(   'Size', [0 9], ...
                    'VariableNames', {'Tech1', 'Fr1', 'Tech2', 'Fr2', 'TechIM3', 'IM3','Type IM3', 'Cover RX', 'BW_IM3'}, ...
                    'VariableTypes', {'string', 'double','string', 'double', 'string','double','string', 'double', 'string'});

% --- Интермодуляция ---
% for techno = 1:num_techno-1
%     for f1 = Tx_carrier{techno}(1:end-1)
%         for f2 = Tx_carrier{techno}((find(Tx_carrier{techno}==f1)+1):end)
%             OutTable = DoIM(f1, techno, ...
%                         f2, techno, ...
%                         OutTable, str_techno, Rx_pass_band, ...
%                         Cellular_BandWidht(techno), Cellular_BandWidht(techno));
%         end
%     end
%     for sec_techno = techno:num_techno
%         for f1 = Tx_carrier{techno}
%             for f2 = Tx_carrier{sec_techno}
%                 % интермод и заполеннеие таблицы
%                 OutTable = DoIM(f1, techno, ...
%                     f2, sec_techno, ...
%                     OutTable, str_techno, Rx_pass_band, ...
%                     Cellular_BandWidht(techno), Cellular_BandWidht(sec_techno));
%             end
%         end
%     end
% end

for techno = 1:num_techno
    for f1 = Tx_carrier{techno}
        for sec_techno = techno:num_techno
            for f2 = Tx_carrier{sec_techno}
                if f1~=f2&&techno~=sec_techno
                    OutTable = DoIM(f1, techno, ...
                    f2, sec_techno, ...
                    OutTable, str_techno, Rx_pass_band, ...
                    Cellular_BandWidht(techno), Cellular_BandWidht(sec_techno));
                end
            end
        end
    end
end


%%
% [a, b, c, d, ff] = IM3_Hits_RxBand(2592.5, 15, 2622.5, 15, Rx_pass_band)
% check_overlap()

function WriteTable = DoIM(f1, idtech1, f2, idtech2, WriteTable, nameTech, Rx_band, BW1, BW2)
    tech1 = nameTech(idtech1); tech2 = nameTech(idtech2);

    [Hits_num, Hits_cover, Hits_IMtype, fc_IM3, IM3_band] = IM3_Hits_RxBand(f1, BW1, f2, BW2, Rx_band);
    if ~isempty(Hits_num)
        for i = 1:length(Hits_num)
            WriteTable(end+1,:) = {tech1, f1, tech2, f2, nameTech(Hits_num(i)), ...
                fc_IM3(i), Hits_IMtype(i), Hits_cover(i)/100, [num2str(IM3_band(i,1)) + "-" + num2str(IM3_band(i,2))]};
        end
    end
end
    
function [Hits_num, Hits_cover, Hits_IMtype, fc_IM3, BW_IM3] = IM3_Hits_RxBand(f1, BW1, f2, BW2, Rx_band) 
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
    Hits_num = []; Hits_cover = []; Hits_IMtype = {}; fc_IM3 = []; BW_IM3 = [];
    for RxRow = 1:CountRx_band
        for IMRow = 1:4
            [is_intersecting, over_perc] = check_overlap(Rx_band(RxRow,:), IM3_band(IMRow,:));
            if is_intersecting
                % Возможно неправильный метод заполения, но так проще 
                % (может быть дольше)
                Hits_num = [Hits_num; RxRow];
                Hits_cover = [Hits_cover; over_perc];
                Hits_IMtype = [Hits_IMtype, type_IM3(IMRow)];
                fc_IM3 = [fc_IM3; f_IM3(IMRow)];
                BW_IM3 = [BW_IM3; IM3_band(IMRow,:)];
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
        segment_a_length = a2 - a1;
        if overlap_length == 0
            overlap_percentage = 0.001;
        else
            % Процент перекрытия относительно второго отрезка
            overlap_percentage = (overlap_length / segment_a_length) * 100;
        end
    else
        overlap_percentage = 0;
    end
end

function [num_band, numEARFCN_DL] = getEARFCN(band, F_DL)
    % band - название "Band 2", freq - несущая канала

    % Band F_DL_low(MHz) NOffs-DL
    band_data = [
    1    2110    0;
    2    1930    600;
    3    1805    1200;
    4    2110    1950;
    5    869    2400;
    6    875    2650;
    7    2620    2750;
    8    925    3450;
    9    1844.9 3800;
    10   2110    4150;
    11   1475.9 4750;
    12   729    5010;
    13   746    5180;
    14   758    5280;
    17   734    5730;
    18   860    5850;
    19   875    6000;
    20   791    6150;
    21   1495.9 6450;
    22   3510    6600;
    23   2180    7500;
    24   1525    7700;
    25   1930    8040;
    26   859    8690;
    27   852    9040;
    28   758    9210;
    29   717    9660;
    30   2350    9770;
    31   462.5  9870;
    32   1452   36000;
    33   1900   36100;
    34   2010   36200;
    35   1850   36300;
    36   1930   36400;
    37   1910   36500;
    38   2570   36600;
    39   1880   36700;
    40   2300   36800
    ];
    if isstring(band)
        num_band = sscanf(band, "Band %d");
    else
        num_band = band;
    end
    index_band = find(band_data(:,1)==num_band);
    numEARFCN_DL = (F_DL - band_data(index_band, 2)) / 0.1 + band_data(index_band, 3);
end