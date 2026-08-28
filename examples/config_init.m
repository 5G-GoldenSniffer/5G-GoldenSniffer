clear config
config.dir = 'captures';

currentFolder = pwd;
if contains(currentFolder,'examples') && exist([currentFolder filesep '..' filesep 'GoldenSniffer.m'],'file')
	cd('..');
end
