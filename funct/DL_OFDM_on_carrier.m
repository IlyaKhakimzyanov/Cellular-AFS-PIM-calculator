function [resam_waveform, cut_waveform, freq_shift, ratio_fs] = DL_OFDM_on_carrier(Type, BW, num_subframe, Fcarrier, Fsample, OutPower, R, isprintdata)
% Выход: ресемпл сигнала, коэф ресемпла, просто OFDM
% Вход: Тип OFDM, Полоса '20MHz' или 20, кол-во сабфреймов, перенос на несущую, 
% частота новая для ресемпла, вых мощность, 50 Ом
    if ~ischar(BW)&&~isstring(BW)
        Name_BW = [num2str(BW),'MHz'];
    else
        Name_BW = BW;
        BW = double(sscanf(Name_BW,'%fMHz'));
    end
    if isempty(R)||isnan(R)
        R = 1;
    end

    enb = lteTestModel(Type, Name_BW);
      
    [waveform, ~, info] = lteTestModelTool(enb);
    waveform = waveform(1:(end/enb.TotSubframes*num_subframe)); % урезание
    fs = info.SamplingRate;
    NFFT = double(info.Nfft) * 2;
    freq_shift = (-NFFT/2:NFFT/2-1)/NFFT * fs;

    % Определение мощности
    power_start = mean(abs(waveform).^2) / R;
    if isprintdata
    fprintf('OFDM fc = %0.1f МГц;\n', Fcarrier/1e6);
    fprintf('-> P [мВт] = %f\t(исходное)\n', power_start*1000);
    fprintf('-> P [дБм] = %0.1f\t(выходное)\n', 10*log10(power_start*1000));
    [PAPR_db, PeakP_db] = papr2(waveform);
    fprintf('-> PARP [дБм] = %0.1f\t(исходное)\n', PAPR_db);
    fprintf('-> PeakP [дБм] = %0.1f\t(исходное)\n', PeakP_db);
    end
   
    % Установка своей мощности
    if ~isempty(OutPower)
        scaling_factor = sqrt(OutPower/power_start);
        waveform = waveform * scaling_factor;
    
        % Новое определение мощности
        power_scale = mean(abs(waveform).^2) / R;
        if isprintdata
        fprintf('-> P [Вт] = %0.1f\t(выходное)\n', power_scale);
        fprintf('-> P [дБм] = %0.1f\t(выходное)\n', 10*log10(power_scale*1000));
        [PAPR_db, PeakP_db] = papr2(waveform);
        fprintf('-> PARP [дБм] = %0.1f\t(выходное)\n', PAPR_db);
        fprintf('-> PeakP [дБм] = %0.1f\t(выходное)\n', PeakP_db);
        end
    elseif ~isempty(OutPower)||~isempty(R)
        error('R or Power not exist');
    end

    % Фильр
    waveform = lowpass(waveform, BW*1e6/2/1.111, fs, ...
        StopbandAttenuation=200);

    % --- Выход
    cut_waveform = waveform;
    % тут я понял что выше часть надо было в отдельную функцию
    [resam_waveform, ratio_fs] = Resample_Wave(cut_waveform, fs, Fsample);
    
    % Фильтр
    % resam_waveform = bandpass(resam_waveform, ...
    %     [-1 1]*1.0/2*BW*1e6+Fcarrier, Fsample, ...
    %     StopbandAttenuation=200);
    
    resam_waveform = Shift_Signal(resam_waveform, Fsample, Fcarrier);
end

function [PAPR_db, PeakP_db] = papr2(x)
% PAPR_db = PAPR [dB]
% AvgP_db = Average Power [dB]
% PeakP_db = Maximum Power [dB]
    Nx=length(x);
    xI=real(x);
    xQ=imag(x);
    Power=xI.*xI+xQ.*xQ;
    Power = Power / 50;
    % Power = mean(abs().^2)/50;
    AvgP=sum(Power)/Nx;
    AvgP_db=10*log10(AvgP);
    PeakP=max(Power);
    PeakP_db=10*log10(PeakP);
    PAPR_db=10*log10(PeakP/AvgP);
end