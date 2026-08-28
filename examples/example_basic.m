config_init
config_add_impairments
config_output_params

config.sample_rate_MHz = 23.04;
config.carrier_frequency_MHz = 1980;
config.frequency_offset_MHz = 0;
config.bandwidth_MHz = 20;

% config.nzpCSI_known = false;
% config.search_unknown_nzpCSI = true;
config.nzpCSI_known = true;
config.CSI1.sc_spacing=4;
config.CSI1.SFN=1;
config.CSI1.SFN_period=2;
config.CSI1.k0=3;
config.CSI1.bitmap=zeros(1,140);
config.CSI1.bitmap(1+[32  36  46  50])=1;
config.CSI1.nID=1007;
config.CSI2.sc_spacing=12;
config.CSI2.SFN=0;
config.CSI2.SFN_period=2;
config.CSI2.k0=11;
config.CSI2.bitmap=zeros(1,140);
config.CSI2.bitmap(1+32)=1;
config.CSI2.nID=1007;

% config.zpCSI_known = false;
config.zpCSI_known = true;
config.CSI0.sc_spacing=12;
config.CSI0.SFN=0;
config.CSI0.SFN_period=2;
config.CSI0.k0=8;
config.CSI0.bitmap=zeros(1,140);
config.CSI0.bitmap(1+36)=1;

config.PDSCH_decoding = true;
config.filename = 'iq_basic.sc16';
config.KNOWN_UE_RNTIs = 0x4601;

GoldenSniffer(config);
