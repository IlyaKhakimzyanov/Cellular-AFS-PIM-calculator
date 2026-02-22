function [out_bits, out_grid, out_symbol] = Decode_SCFDMA(ue, rx_waveform)
% 

    [puschInd, ~] = ltePUSCHIndices(ue,ue.PUSCH);
    rx_grid = lteSCFDMADemodulate(ue, rx_waveform);
    rxPrecoded = rx_grid(puschInd);
    dePrecodedSymbols = lteULDeprecode(rxPrecoded, ue.NULRB);
    deSymbolScrambl = lteSymbolDemodulate(dePrecodedSymbols, ue.PUSCH.Modulation, 'Soft');
    deBits = lteULDescramble(ue, deSymbolScrambl);
    deBits = zeros(length(deBits),1) + ones(length(deBits),1).*(deBits>0);
    out_bits = deBits;
    out_grid = rx_grid;
    out_symbol = dePrecodedSymbols;
end