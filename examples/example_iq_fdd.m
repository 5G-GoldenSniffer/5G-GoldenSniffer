function example_iq_fdd(id)
	if nargin < 1
		id = 1;
	end
	if id<1 || (id>10 && id<19) || id ==23 || id > 25
		fprintf('supported ids: 1-10,19-22,24,25\n');
		return
	end

	config_init
	config_add_impairments
	config_output_params

	switch id
		case 9
			ncellid = 104;
			k0_zp = 8;
		case {10,21,24,25}
			ncellid = 1007;
			k0_zp = 8;
		case {19,20,22}
			ncellid = 300;
			k0_zp = 0;
		otherwise % 1-8
			ncellid = 1;
			k0_zp = 4;
	end

	config.sample_rate_MHz = 23.04;
	config.carrier_frequency_MHz = 1980;
	config.frequency_offset_MHz = 0;
	config.bandwidth_MHz = 20;

	% config.nzpCSI_known = false;
	% config.search_unknown_nzpCSI=true;
	config.nzpCSI_known = true;
	config.CSI1.sc_spacing=4;
	config.CSI1.SFN=1;
	config.CSI1.SFN_period=2;
	config.CSI1.k0=mod(ncellid,4);
	config.CSI1.bitmap=zeros(1,140);
	config.CSI1.bitmap(1+[32  36  46  50])=1;
	config.CSI1.nID=ncellid;
	config.CSI2.sc_spacing=12;
	config.CSI2.SFN=0;
	config.CSI2.SFN_period=2;
	config.CSI2.k0=mod(ncellid,12);
	config.CSI2.bitmap=zeros(1,140);
	config.CSI2.bitmap(1+32)=1;
	config.CSI2.nID=ncellid; 

	% config.zpCSI_known = false;
	config.zpCSI_known = true;
	config.CSI0.sc_spacing=12;
	config.CSI0.SFN=0;
	config.CSI0.SFN_period=2;
	config.CSI0.k0=k0_zp;
	config.CSI0.bitmap=zeros(1,140);
	config.CSI0.bitmap(1+36)=1;

	config.PDSCH_decoding = true;

	config.filename = ['iq_1980M_23.04M_conf',num2str(id),'_0.sc16'];
	switch id
		case {1,2}
			config.KNOWN_UE_RNTIs = 0x4602;
		case {3,4,5,6,7,8,9,10,19}
			config.KNOWN_UE_RNTIs = 0x4601;
		case {20,21,22,24,25}
			config.KNOWN_UE_RNTIs = [0x4601 0x4602];
	end

	GoldenSniffer(config);
end
