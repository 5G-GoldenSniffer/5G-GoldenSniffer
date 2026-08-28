% Bit flags:
% 0x0001: PSS_time to s_GSCN correlations log
% 0x0002: CP_corr of presumed PSS
% 0x0004: timing error estimation magnitude/phase
% 0x0008: H_est PSS/SSS for CFO tracking
% 0x0010: CFO and timing error log
% 0x0020: channel estimation for PBCH symbols
% 0x0040: imagesc(synchronized frame)
% 0x0080: CSI channel estimation
% 0x0100: power clustering for blind PDCCH detection
% 0x0200: PDCCH equalized REs (QPSK)
% 0x0400: PDSCH equalized REs (QPSK/16-QAM/64-QAM)
config.FIGURES = 0x0040;
% config.FIGURES = 0x07FF;

% Console messages
%   0: none
%   1: state machine and short per-frame summary
%   2: dci candidates found and detailed per-frame summary
%   3: processed dci details
%   4: PDSCH byte dump
config.VERBOSITY = 1;
