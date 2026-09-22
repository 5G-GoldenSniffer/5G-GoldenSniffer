function example_iq_tdd(id,run)
	if nargin < 1
		id = 11;
	end
	if id<11 || id>18 && id~=23
		fprintf('supported ids: 11-18, 23\n');
		return
	end
	if nargin < 2
		run = 0;
	end
	if run < 0 || run > 2
		fprintf('supported runs: 0-2\n');
		return
	end

	config_init
	config_add_impairments
	config_output_params
	switch id
		case {11,13,14}
			ncellid = 123;
		case {12,18,23}
			ncellid = 300;
		case {15,16,17}
			ncellid = 1;
		otherwise
			ncellid = -1;
	end
	config.sample_rate_MHz = 23.04;
	config.carrier_frequency_MHz = 3820.02;
	config.frequency_offset_MHz = 0;
	config.bandwidth_MHz = 20;

	% config.nzpCSI_known=false;
	% config.search_unknown_nzpCSI=true;
	config.nzpCSI_known=true;
	config.CSI1.sc_spacing=4;
	config.CSI1.SFN=0;
	config.CSI1.SFN_period=2;
	config.CSI1.k0=mod(ncellid,4);
	config.CSI1.bitmap=zeros(1,280);
	config.CSI1.bitmap(1+[32  36  46  50])=1;
	config.CSI1.nID=ncellid;
	config.CSI2.sc_spacing=12;
	config.CSI2.SFN=0;
	config.CSI2.SFN_period=2;
	config.CSI2.k0=mod(ncellid,12);
	config.CSI2.bitmap=zeros(1,280);
	config.CSI2.bitmap(1+60)=1;
	config.CSI2.nID=ncellid;
	
	% config.zpCSI_known=false;
	config.zpCSI_known=true;
	config.CSI0.sc_spacing=12;
	config.CSI0.SFN=0;
	config.CSI0.SFN_period=2;
	config.CSI0.k0=4*(ncellid==1); % RFC
	config.CSI0.bitmap=zeros(1,280);
	config.CSI0.bitmap(1+64)=1;

	config.TA = 360;
	config.TDD_pattern = [0 0 0 0 0 0 1 1 1 1];
	config.PDSCH_decoding = true;
	config.filename = ['iq_3820.02M_23.04M_conf',num2str(id),'_',num2str(run),'.sc16'];
	config.KNOWN_UE_RNTIs = [];
	
	GoldenSniffer(config);
end
