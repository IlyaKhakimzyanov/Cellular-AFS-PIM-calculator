function signal = SimSignalOFDM(Fc, BW, P_Watt)
    LTE_BW = [1.4 3 5 10 15 20];
        LIE_N_RB = [6 15 25 50 75 100];
    disp(find(LTE_BW, BW))
    N_RB = LIE_N_RB(find(LTE_BW, BW))
    a = Fc + P_Watt;
    % switch BW
    %     case 5
    %         % N = 
    % end
%     N = 
%     SCS = 15e6; %15 kHz
%     for i = 1:N
% 
%     end
end