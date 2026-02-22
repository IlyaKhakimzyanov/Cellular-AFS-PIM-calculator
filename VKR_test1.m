clear all;
close all;
N = 128;
n = 0:N-1;
f1 = 10;
f2 = 80;

fd = f1 * 4; td = 1/fd;
t = n*td;
f = n*fd/N;

% s1 = sin_harmonic(f1, t, 5);
s1 = thd( sin(2*pi * f1 * t), fd, 3);
% s2 = cos(2*pi*f2*t);
s1 = [s1, zeros(1, 0)];
s3 = cos(2*pi*f1*t) .* cos(2*pi*f2*t);

s1_f = abs(fft(s1));
% s2_f = abs(fft(s2));
% s3_f = abs(fft(s3));
%%
figure();
subplot(211);
hold on;
plot(s1);
% plot(t,s2);
% plot(t,s3);
legend();
hold off;

subplot(212);
hold on;
stem(f, s1_f,'Marker','.'); %xlim([0 length(s1_f)/2]);
% stem(f,s2_f);
% stem(f,s3_f);
hold off;

% function signal = sin_harmonic(freq, arr_time, num_harm)
%     if num_harm <= 0 && num_harm >= 8
%         error('Плохое число гармоник');
%     end
%     s = zeros(1, length(arr_time));
%     for harmonic = 1:num_harm
%     s = s + sin(2*pi * freq * harmonic * arr_time);
%     end
%     signal = s;
% end

%%
  clc;
  clear all;
  close all;
  numFFT = 1024;           % Number of FFT points or subcarriers
  numRBs = 50;             % Number of resource blocks
  rbSize = 12;             % Number of subcarriers per resource block
  cpLen = 72;              % Cyclic prefix length in samples
  numDataCarriers = numRBs*rbSize;    % number of data subcarriers in sub-band
  bitsPerSubCarrier = 2;   % 2: QPSK, 4: 16QAM, 6: 64QAM, 8: 256QAM
  % Define parameters
  transmitPower_dBm = 10;  % Average transmit power in dBm
  noiseFloor_dBm = -90.8;    % Noise floor in dBm
  recivedPower_dBm = -42.7;  % Average Recived power in dBm
 
  CHAN_LEN = 10;           % number of channels taps
  Iterations = 100;
  % Convert dBm to Watts (1 mW = 0 dBm)
  transmitPower_W = 10^(transmitPower_dBm/CHAN_LEN);
  noiseFloor_W = 10^(noiseFloor_dBm/CHAN_LEN);
  recivedPower_W = 10^(recivedPower_dBm/CHAN_LEN);
  Channel_variance_W = recivedPower_W / (transmitPower_W);  % Channel gain
  
  SamplingRate_MHz=20;
  f = [-numFFT/2:numFFT/2-1]*SamplingRate_MHz/numFFT;
  window= [];
  for i=1:Iterations
  % Generate the fading channel
      hnlos = (randn(CHAN_LEN,1) + 1i*randn(CHAN_LEN,1));% NLOS
      hs = sqrt(Channel_variance_W)*hnlos/sqrt(mean(abs(hnlos).^2));
  % AWGN Noise
      noise = 1/sqrt(2)*(randn(numFFT + cpLen+CHAN_LEN-1,1) + 1i*randn(numFFT + cpLen+CHAN_LEN-1,1));
  % Transmit Data Frame
     bitsIn = randi([0 1], bitsPerSubCarrier*numDataCarriers, 1);
     %symbolsIn = qammod(bitsIn, 2^bitsPerSubCarrier, 'InputType', 'bit', ...       %QAM Symbol mapper
     %    'UnitAveragePower', true);
     symbolsIn = QAM_modulation(bitsIn, 2^bitsPerSubCarrier);
     symbolsIn=symbolsIn';
  % Pack data into an OFDM symbol
     offset = (numFFT-numDataCarriers)/2; % for band center
     symbolsInOFDM = [zeros(offset,1); symbolsIn; ...
         zeros(numFFT-offset-numDataCarriers,1)];
     ifftOut = ifft(ifftshift(symbolsInOFDM));
     txSigOFDM = [ifftOut(end-cpLen+1:end); ifftOut];          % Prepend cyclic prefix
     txSigOFDM=sqrt(transmitPower_W/CHAN_LEN)*txSigOFDM/sqrt(mean(abs(txSigOFDM).^2)); %power Scaling
  % Reception
      y_N=sqrt(noiseFloor_W) *noise;
    y_conv=conv(txSigOFDM, hs);
      y_S = y_conv + sqrt(10)*y_N;
  % Power Calculation
     p_y_N(i)=10*log10(mean(abs(y_N).^2));
     p_y_S(i)=10*log10(mean(abs(y_S).^2));
  % Welch Method
     [psd_N(i,:),W] = pwelch(y_N,window,[],numFFT,SamplingRate_MHz);  % Noise PSD
     [psd_S(i,:),W] = pwelch(y_S,window,[],numFFT,SamplingRate_MHz); % Received Signal PSD
  end
  avg_psd_N=sum(psd_N)/Iterations/1e6;    % Averaging & MHz to Hz (PSD [dBm/Hz])
  avg_psd_S=sum(psd_S)/Iterations/1e6;    % Averaging & MHz to Hz (PSD [dBm/Hz])
  Noise_Pow=mean(p_y_N);
  RecvSig_Pow=mean(p_y_S);
  h(1) = plot(f,10*log10(fftshift(avg_psd_N)),'--k', 'LineWidth',2);
  hold on;
  h(2) = plot(f,10*log10(fftshift(avg_psd_S)),'-b', 'LineWidth',2);
  xlabel('Frequency [MHz]')
  ylabel('PSD [dBm/Hz]')
  %legend(h,sprintf('Noise floor = %g dBm',Noise_Pow), sprintf('Recived Signal = %g dBm',RecvSig_Pow))
  grid on;

function x_QAM_modeulated = QAM_modulation(x_encoded, M)
    x_encoded = string(x_encoded);
    M=log2(M);
    greycode = generate_grey_code(M/2);
    if mod(length(x_encoded),M) ~= 0
       x_encoded = [x_encoded zeros(1, M - mod(length(x_encoded),M))];  
    end
    
    x_QAM_modeulated = zeros(1,length(x_encoded)/M);
    AMi_vector = zeros(1, length(greycode));
    AMq_vector = zeros(1, length(greycode));
    for m = 1 : length(greycode)
        AMi_vector(m) = 2*m - 1 - length(greycode);
    end
    AMq_vector = AMi_vector;
    AMi_vector;
    
    k=1;
    for i = 1:length(x_QAM_modeulated)
        sequence=x_encoded(k:k-1+M);
        sequence_even=sequence(1:length(sequence)/2);
        sequence_odd=sequence((length(sequence)/2)+1:length(sequence));
        sequence_even = strjoin(sequence_even,"");
        sequence_odd = strjoin(sequence_odd,"");
        index_even = find (greycode == sequence_even);
        index_odd = find (greycode == sequence_odd);
        AMi = AMi_vector(index_even);
        AMq = AMq_vector(index_odd);
        x_QAM_modeulated(i) = AMi + AMq*j;
        %x_QAM_modeulated(i)= x_QAM_modeulated(i)/sqrt(mean(abs(x_QAM_modeulated(i)).^2));
        k = k + M;
    end
end

    function grey_code = generate_grey_code(n)
    arr = strings(1,2);
    
    arr(1) = '0';
    arr(2) = '1';
    
    i=2;
    j=0;
    
   
    while(i < 2^n)
        start = i-1;
        step = -1;
        N= length(arr);
        start+step*(0:N-1);
        for j = start+step*(0:N-1)
            arr = [arr arr(j+1)];
        end    
        
        for j = linspace(1,i,i)
            arr(j) = "0" + arr(j);
        end
        
        for j = linspace(i,(2*i)-1,i)
            arr(j+1) = "1" + arr(j+1);
        end
        
        i = bitshift(i,1);
    end      
  
    grey_code = arr;
    end