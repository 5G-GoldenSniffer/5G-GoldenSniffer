% dci encoder (with explicit initializations)
%
%   Copyright 2024-2026 the authors
%   Licensed under MIT License
%
%   Permission is hereby granted, free of charge, to any person obtaining a copy
%   of this software and associated documentation files (the "Software"), to
%   deal in the Software without restriction, including without limitation the
%   rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
%   sell copies of the Software, and to permit persons to whom the Software is
%   furnished to do so, subject to the following conditions:
%
%   The above copyright notice and this permission notice shall be included in
%   all copies or substantial portions of the Software.
%
%   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
%   IN THE SOFTWARE.
%
function b_tilde = dci_encode(a,rnti_crc,rnti_scr,N_ID,Mbit,crc_init,x1_init)
	if size(a,1)>size(a,2)
		a = a.';
	end
	A = numel(a);

	% +++ CRC attachment 38.212 7.3.2 p.193
	L = 24;
	a_prime = [crc_init,a,zeros(1,L)];
	gCRC24C = [1 1 0 1 1 0 0 1 0 1 0 1 1 0 0 0 1 0 0 0 1 0 1 1 1];
	% --- 38.212 5.1 p.11
	for i = 1:A+L
		if a_prime(i)
			a_prime(i+(0:L)) = mod(a_prime(i+(0:L))+gCRC24C,2);
		end
	end
	p = a_prime(end-L+1:end);
	% if sum(crc_init)==24 && x1_init==1
	%     % p == 13086690???
	%     sum(p.*2.^(23:-1:0))
	%     keyboard
	% end
	% ---
	if 1
		b = [a,p];
	else % verification
		b = [crc_init,a,p];
		for i = 1:A+L
			if b(i)
				b(i+(0:L)) = mod(b(i+(0:L))+gCRC24C,2);
			end
		end
		sum(abs(b))
		%%%keyboard
	end
	c = b;
	c(end-15:end) = mod(c(end-15:end)+rnti_crc,2);
	K = A+L;
	% +++
	% *** Channel coding 38.212 7.3.3 p.194
	nmax = 9;
	I_IL = 1;
	nPC = 0;
	nPC_wm = 0;
	% /// Polar coding 38.212 5.3.1 p.13
	E = Mbit;
	n1 = ceil(log2(E));
	if E <= 9/8*2^(n1-1) && K/E < 9/16
		n1 = n1-1;
	end
	Rmin = 1/8;
	n2 = ceil(log2(K/Rmin));
	nmin=5;
	n = max(nmin,min([n1,n2,nmax]));
	N = 2^n;
	% Interleaving 38.212 5.3.1.1 p.14
	if I_IL == 0
		c_prime = c;
	else
		PImax_IL = [0 2 4 7 9 14 19 20 24 25 26 28 31 34 42 45 49 50 51 ...
			53 54 56 58 59 61 62 65 66 67 69 70 71 72 76 77 81 82 83 87 ...
			88 89 91 93 95 98 101 104 106 108 110 111 113 115 118 119 ...
			120 122 123 126 127 129 132 134 138 139 140 1 3 5 8 10 15 ...
			21 27 29 32 35 43 46 52 55 57 60 63 68 73 78 84 90 92 94 96 ...
			99 102 105 107 109 112 114 116 121 124 128 130 133 135 141 ...
			6 11 16 22 30 33 36 44 47 64 74 79 85 97 100 103 117 125 ...
			131 136 142 12 17 23 37 48 75 80 86 137 143 13 18 38 144 39 ...
			145 40 146 41 147 148 149 150 151 152 153 154 155 156 157 ...
			158 159 160 161 162 163];
		PI = zeros(1,K);
		k = 0;
		Kmax_IL = 164;
		for m = 0:Kmax_IL-1
			if PImax_IL(1+m) >= Kmax_IL-K
				PI(1+k) = PImax_IL(1+m)-(Kmax_IL-K);
				k = k + 1;
			end
		end
		c_prime = c(1+PI); % diretto
		%c_prime(1+PI) = c; % inverso
	end
	% 38.212 5.3.1.2 Polar Encoding
	Qmax = [...
		0 1 2 4 8 16 32 3 5 64 9 6 17 10 18 128 12 33 65 20 256 34 ...
		24 36 7 129 66 512 11 40 68 130 19 13 48 14 72 257 21 132 35 ...
		258 26 513 80 37 25 22 136 260 264 38 514 96 67 41 144 28 69 ...
		42 516 49 74 272 160 520 288 528 192 544 70 44 131 81 50 73 ...
		15 320 133 52 23 134 384 76 137 82 56 27 97 39 259 84 138 145 ...
		261 29 43 98 515 88 140 30 146 71 262 265 161 576 45 100 640 ...
		51 148 46 75 266 273 517 104 162 53 193 152 77 164 768 268 ...
		274 518 54 83 57 521 112 135 78 289 194 85 276 522 58 168 139 ...
		99 86 60 280 89 290 529 524 196 141 101 147 176 142 530 321 ...
		31 200 90 545 292 322 532 263 149 102 105 304 296 163 92 47 ...
		267 385 546 324 208 386 150 153 165 106 55 328 536 577 548 ...
		113 154 79 269 108 578 224 166 519 552 195 270 641 523 275 ...
		580 291 59 169 560 114 277 156 87 197 116 170 61 531 525 642 ...
		281 278 526 177 293 388 91 584 769 198 172 120 201 336 62 282 ...
		143 103 178 294 93 644 202 592 323 392 297 770 107 180 151 ...
		209 284 648 94 204 298 400 608 352 325 533 155 210 305 547 ...
		300 109 184 534 537 115 167 225 326 306 772 157 656 329 110 ...
		117 212 171 776 330 226 549 538 387 308 216 416 271 279 158 ...
		337 550 672 118 332 579 540 389 173 121 553 199 784 179 228 ...
		338 312 704 390 174 554 581 393 283 122 448 353 561 203 63 ...
		340 394 527 582 556 181 295 285 232 124 205 182 643 562 286 ...
		585 299 354 211 401 185 396 344 586 645 593 535 240 206 95 ...
		327 564 800 402 356 307 301 417 213 568 832 588 186 646 404 ...
		227 896 594 418 302 649 771 360 539 111 331 214 309 188 449 ...
		217 408 609 596 551 650 229 159 420 310 541 773 610 657 333 ...
		119 600 339 218 368 652 230 391 313 450 542 334 233 555 774 ...
		175 123 658 612 341 777 220 314 424 395 673 583 355 287 183 ...
		234 125 557 660 616 342 316 241 778 563 345 452 397 403 207 ...
		674 558 785 432 357 187 236 664 624 587 780 705 126 242 565 ...
		398 346 456 358 405 303 569 244 595 189 566 676 361 706 589 ...
		215 786 647 348 419 406 464 680 801 362 590 409 570 788 597 ...
		572 219 311 708 598 601 651 421 792 802 611 602 410 231 688 ...
		653 248 369 190 364 654 659 335 480 315 221 370 613 422 425 ...
		451 614 543 235 412 343 372 775 317 222 426 453 237 559 833 ...
		804 712 834 661 808 779 617 604 433 720 816 836 347 897 243 ...
		662 454 318 675 618 898 781 376 428 665 736 567 840 625 238 ...
		359 457 399 787 591 678 434 677 349 245 458 666 620 363 127 ...
		191 782 407 436 626 571 465 681 246 707 350 599 668 790 460 ...
		249 682 573 411 803 789 709 365 440 628 689 374 423 466 793 ...
		250 371 481 574 413 603 366 468 655 900 805 615 684 710 429 ...
		794 252 373 605 848 690 713 632 482 806 427 904 414 223 663 ...
		692 835 619 472 455 796 809 714 721 837 716 864 810 606 912 ...
		722 696 377 435 817 319 621 812 484 430 838 667 488 239 378 ...
		459 622 627 437 380 818 461 496 669 679 724 841 629 351 467 ...
		438 737 251 462 442 441 469 247 683 842 738 899 670 783 849 ...
		820 728 928 791 367 901 630 685 844 633 711 253 691 824 902 ...
		686 740 850 375 444 470 483 415 485 905 795 473 634 744 852 ...
		960 865 693 797 906 715 807 474 636 694 254 717 575 913 798 ...
		811 379 697 431 607 489 866 723 486 908 718 813 476 856 839 ...
		725 698 914 752 868 819 814 439 929 490 623 671 739 916 463 ...
		843 381 497 930 821 726 961 872 492 631 729 700 443 741 845 ...
		920 382 822 851 730 498 880 742 445 471 635 932 687 903 825 ...
		500 846 745 826 732 446 962 936 475 853 867 637 907 487 695 ...
		746 828 753 854 857 504 799 255 964 909 719 477 915 638 748 ...
		944 869 491 699 754 858 478 968 383 910 815 976 870 917 727 ...
		493 873 701 931 756 860 499 731 823 922 874 918 502 933 743 ...
		760 881 494 702 921 501 876 847 992 447 733 827 934 882 937 ...
		963 747 505 855 924 734 829 965 938 884 506 749 945 966 755 ...
		859 940 830 911 871 639 888 479 946 750 969 508 861 757 970 ...
		919 875 862 758 948 977 923 972 761 877 952 495 703 935 978 ...
		883 762 503 925 878 735 993 885 939 994 980 926 764 941 967 ...
		886 831 947 507 889 984 751 942 996 971 890 509 949 973 1000 ...
		892 950 863 759 1008 510 979 953 763 974 954 879 981 982 927 ...
		995 765 956 887 985 997 986 943 891 998 766 511 988 1001 951 ...
		1002 893 975 894 1009 955 1004 1010 957 983 958 987 1012 999 ...
		1016 767 989 1003 990 1005 959 1011 1013 895 1006 1014 1017 ...
		1018 991 1020 1007 1015 1019 1021 1022 1023];
	Q = Qmax(Qmax<N); % base 0
	% ,,, 5.4.1.1 p.27
	P = [0 1 2 4 3 5 6 7 8 16 9 17 10 18 11 19 12 20 13 21 14 22 15 ...
		23 24 25 26 28 27 29 30 31];
	J = zeros(1,N);
	for k = 0:N-1
		J(1+k) = P(1+floor(32*k/N))*N/32+mod(k,N/32);
	end
	% ,,,
	% ### 38.212 p.28
	QtmpF = zeros(1,N);
	if E < N
		if K/E <= 7/16
			for k = 0:N-E-1
				QtmpF(1+J(1+k))=1;
			end
			if E >= 3*N/4
				QtmpF(1+(0:ceil(3*N/4-E/2)-1)) = 1;
			else
				QtmpF(1+(0:ceil(9*N/16-E/4)-1)) = 1;
			end
		else
			for k = E:N-1
				QtmpF(1+J(1+k))=1;
			end
		end
	end
	QtmpI = 1 - QtmpF; % QtmpI(i)==1 se i \in Q_{I,tmp}
	k = 0;
	i = N;
	QI = zeros(1,N);
	while k < K+nPC
		if i == 0
			%%%keyboard
		end
		if QtmpI(1+Q(i))
			k = k+1;
			QI(1+Q(i)) = 1;
		end
		i = i - 1;
	end
	%QF = 1-QI;
	% ###
	GN = [1 0; 1 1]; % N = 2
	for k = 2:n
		GN = [GN, zeros(2^(k-1)); GN, GN];
	end
	%x=de2bi(0:N-1)*2.^(n-1:-1:0)';
	%PG=zeros(N);for i = 1:N,PG(i,1+x(i))=1;end
	%GN = PG*GN;
	% 38.212 5.3.1.2 Polar Encoding p.15
	u = zeros(1,N);
	k = 0;
	if nPC > 0
		y0=0;y1=0;y2=0;y3=0;y4=0;
		for n = 0:N-1
			yt=y0;y0=y1;y1=y2;y2=y3;y3=y4;y4=yt;
			if QI(1+n) % n \elem \bar{Q}_I^N
				if Q_PC(1+n)
					u(1+n) = y0;
				else
					u(1+n) = c_prime(1+k);
					k = k + 1;
					y0 = mod(y0+u(1+n),2);
				end
			else
				u(1+n)=0;
			end
		end
	else % nPC==0
		for n = 0:N-1
			if QI(1+n) % n \elem \bar{Q}_I^N
				u(1+n) = c_prime(1+k);
				k = k + 1;
			else
				u(1+n) = 0;
			end
		end
	end
	d = mod(u*GN,2);
	% if sum(crc_init)==24 && x1_init==1
	%     d_ref = nrPolarEncode(c',E,nmax,I_IL==1)';
	% 	sum(abs(d-d_ref))
	% 	keyboard
	% end
	% ***
	% === 38.212 7.3.4 Rate Matching p.194
	I_BIL = 0;
	% ^^^ 38.212 5.4.1 p.27
	y = d(1+J);
	% ... 38.212 5.4.1.2 p.29
	e = zeros(1,E);
	if E >= N
		for k = 0:E-1
			e(1+k) = y(1+mod(k,N));
		end
	else
		if K/E <= 7/16
			for k = 0:E-1
				e(1+k) = y(1+k+N-E);
			end
		else
			for k = 0:E-1
				e(1+k) = y(1+k);
			end
		end
	end
	% ... 38.212 5.4.1.3 p.29
	f = zeros(1,E);
	if I_BIL == 1
		T = 1;
		while T*(T+1)/2 < E
			T = T+1;
		end
		% T*(T+1)/2 >= E
		k = 0;
		for i = 0:T-1
			for j = 0:T-1-i
				if k < E
					v(1+i,1+j) = e(1+k);
				else
					v(1+i,1+j) = -1;
				end
				k = k+1;
			end
		end
		k = 0;
		for j = 0:T-1
			for i = 0:T-1-j
				if v(1+i,1+j) >= 0
					f(1+k) = v(1+i,1+j);
					k = k+1;
				end
			end
		end
	else
		f = e;
	end
	% if sum(crc_init)==24 && x1_init==1
	%     f_ref = nrDCIEncode(a.',sum(rnti.*2.^(15:-1:0)),E);
	%     sum(abs(f-f_ref.'))
	%     keyboard
	% end
	% ^^^
	% Scrambling 38.211 7.3.2.3 p.99

	c_init_DCI = mod(sum(rnti_scr.*2.^(numel(rnti_scr)-1:-1:0))*2^16 + sum(N_ID.*2.^(15:-1:0)),2^31);
	% 38.211 5.2.1 p.18
	c_DCI = scrambling(Mbit,c_init_DCI,x1_init);
	b_tilde = mod(f+c_DCI,2);

	% if sum(crc_init)==24 && x1_init==1
	% 	symbols = nrPDCCH(f.',sum(N_ID.*2.^(15:-1:0)),sum(rnti.*2.^(15:-1:0)));
	% 	temp=zeros(1,E);
	% 	temp(1:2:end)=real(symbols)<0;
	% 	temp(2:2:end)=imag(symbols)<0;
	% 	sum(abs(temp-b_tilde))
	% 	keyboard
	% end
end

% 
% 
% 
% function b_tilde = dci_encode(a, rnti_crc, rnti_scr, N_ID, Mbit, crc_init, x1_init)
% 	%dci_encode DCI encoding according to 3GPP TS 38.212
% 	%   B_TILDE = dci_encode(A, RNTI_CRC, RNTI_SCR, N_ID, MBIT, CRC_INIT, X1_INIT)
% 	%   encodes DCI bits A according to the 5G NR standard.
% 	%
% 	%   Inputs:
% 	%       a        - DCI payload bits (row vector)
% 	%       rnti_crc - RNTI bits for CRC scrambling (16 bits)
% 	%       rnti_scr - RNTI bits for scrambling (15 bits, = rnti_crc & 0x7FFF)
% 	%       N_ID     - Cell ID or PDCCH DMRS scrambling ID (16 bits)
% 	%       Mbit     - Output length in bits
% 	%       crc_init - CRC initialization bits (24 bits)
% 	%       x1_init  - X1 sequence initialization
% 	%
% 	%   Output:
% 	%       b_tilde  - Encoded and scrambled DCI bits
% 	%
% 	%   Reference: 3GPP TS 38.212 Sections 5.1, 5.3.1, 5.4.1, 7.3.2-7.3.4
% 	%              3GPP TS 38.211 Section 7.3.2.3
% 
% 	%   Copyright 2024 GoldenSniffer Project
% 
% 	if size(a, 1) > size(a, 2)
% 		a = a.';
% 	end
% 	A = numel(a);
% 
% 	% === CRC Attachment (TS 38.212 Section 7.3.2) ===
% 	L = 24;
% 	a_prime = [crc_init, a, zeros(1, L)];
% 	gCRC24C = [1 1 0 1 1 0 0 1 0 1 0 1 1 0 0 0 1 0 0 0 1 0 1 1 1];
% 
% 	% CRC computation (TS 38.212 Section 5.1)
% 	for i = 1:A + L
% 		if a_prime(i)
% 			a_prime(i + (0:L)) = mod(a_prime(i + (0:L)) + gCRC24C, 2);
% 		end
% 	end
% 	p = a_prime(end - L + 1:end);
% 
% 	b = [a, p];
% 	c = b;
% 	c(end - 15:end) = mod(c(end - 15:end) + rnti_crc, 2);
% 	K = A + L;
% 
% 	% === Polar Coding (TS 38.212 Section 7.3.3 / 5.3.1) ===
% 	nmax = 9;
% 	I_IL = 1;
% 	nPC = 0;
% 
% 	% Determine polar code length N
% 	E = Mbit;
% 	n1 = ceil(log2(E));
% 	if E <= 9/8 * 2^(n1-1) && K/E < 9/16
% 		n1 = n1 - 1;
% 	end
% 	Rmin = 1/8;
% 	n2 = ceil(log2(K/Rmin));
% 	nmin = 5;
% 	n = max(nmin, min([n1, n2, nmax]));
% 	N = 2^n;
% 
% 	% Input bit interleaving (TS 38.212 Section 5.3.1.1)
% 	if I_IL == 0
% 		c_prime = c;
% 	else
% 		PImax_IL = [0 2 4 7 9 14 19 20 24 25 26 28 31 34 42 45 49 50 51 ...
% 			53 54 56 58 59 61 62 65 66 67 69 70 71 72 76 77 81 82 83 87 ...
% 			88 89 91 93 95 98 101 104 106 108 110 111 113 115 118 119 ...
% 			120 122 123 126 127 129 132 134 138 139 140 1 3 5 8 10 15 ...
% 			21 27 29 32 35 43 46 52 55 57 60 63 68 73 78 84 90 92 94 96 ...
% 			99 102 105 107 109 112 114 116 121 124 128 130 133 135 141 ...
% 			6 11 16 22 30 33 36 44 47 64 74 79 85 97 100 103 117 125 ...
% 			131 136 142 12 17 23 37 48 75 80 86 137 143 13 18 38 144 39 ...
% 			145 40 146 41 147 148 149 150 151 152 153 154 155 156 157 ...
% 			158 159 160 161 162 163];
% 		PI = zeros(1, K);
% 		k = 0;
% 		Kmax_IL = 164;
% 		for m = 0:Kmax_IL - 1
% 			if PImax_IL(1 + m) >= Kmax_IL - K
% 				PI(1 + k) = PImax_IL(1 + m) - (Kmax_IL - K);
% 				k = k + 1;
% 			end
% 		end
% 		c_prime = c(1 + PI);
% 	end
% 
% 	% Polar encoding (TS 38.212 Section 5.3.1.2)
% 	Qmax = [...
% 		0 1 2 4 8 16 32 3 5 64 9 6 17 10 18 128 12 33 65 20 256 34 ...
% 		24 36 7 129 66 512 11 40 68 130 19 13 48 14 72 257 21 132 35 ...
% 		258 26 513 80 37 25 22 136 260 264 38 514 96 67 41 144 28 69 ...
% 		42 516 49 74 272 160 520 288 528 192 544 70 44 131 81 50 73 ...
% 		15 320 133 52 23 134 384 76 137 82 56 27 97 39 259 84 138 145 ...
% 		261 29 43 98 515 88 140 30 146 71 262 265 161 576 45 100 640 ...
% 		51 148 46 75 266 273 517 104 162 53 193 152 77 164 768 268 ...
% 		274 518 54 83 57 521 112 135 78 289 194 85 276 522 58 168 139 ...
% 		99 86 60 280 89 290 529 524 196 141 101 147 176 142 530 321 ...
% 		31 200 90 545 292 322 532 263 149 102 105 304 296 163 92 47 ...
% 		267 385 546 324 208 386 150 153 165 106 55 328 536 577 548 ...
% 		113 154 79 269 108 578 224 166 519 552 195 270 641 523 275 ...
% 		580 291 59 169 560 114 277 156 87 197 116 170 61 531 525 642 ...
% 		281 278 526 177 293 388 91 584 769 198 172 120 201 336 62 282 ...
% 		143 103 178 294 93 644 202 592 323 392 297 770 107 180 151 ...
% 		209 284 648 94 204 298 400 608 352 325 533 155 210 305 547 ...
% 		300 109 184 534 537 115 167 225 326 306 772 157 656 329 110 ...
% 		117 212 171 776 330 226 549 538 387 308 216 416 271 279 158 ...
% 		337 550 672 118 332 579 540 389 173 121 553 199 784 179 228 ...
% 		338 312 704 390 174 554 581 393 283 122 448 353 561 203 63 ...
% 		340 394 527 582 556 181 295 285 232 124 205 182 643 562 286 ...
% 		585 299 354 211 401 185 396 344 586 645 593 535 240 206 95 ...
% 		327 564 800 402 356 307 301 417 213 568 832 588 186 646 404 ...
% 		227 896 594 418 302 649 771 360 539 111 331 214 309 188 449 ...
% 		217 408 609 596 551 650 229 159 420 310 541 773 610 657 333 ...
% 		119 600 339 218 368 652 230 391 313 450 542 334 233 555 774 ...
% 		175 123 658 612 341 777 220 314 424 395 673 583 355 287 183 ...
% 		234 125 557 660 616 342 316 241 778 563 345 452 397 403 207 ...
% 		674 558 785 432 357 187 236 664 624 587 780 705 126 242 565 ...
% 		398 346 456 358 405 303 569 244 595 189 566 676 361 706 589 ...
% 		215 786 647 348 419 406 464 680 801 362 590 409 570 788 597 ...
% 		572 219 311 708 598 601 651 421 792 802 611 602 410 231 688 ...
% 		653 248 369 190 364 654 659 335 480 315 221 370 613 422 425 ...
% 		451 614 543 235 412 343 372 775 317 222 426 453 237 559 833 ...
% 		804 712 834 661 808 779 617 604 433 720 816 836 347 897 243 ...
% 		662 454 318 675 618 898 781 376 428 665 736 567 840 625 238 ...
% 		359 457 399 787 591 678 434 677 349 245 458 666 620 363 127 ...
% 		191 782 407 436 626 571 465 681 246 707 350 599 668 790 460 ...
% 		249 682 573 411 803 789 709 365 440 628 689 374 423 466 793 ...
% 		250 371 481 574 413 603 366 468 655 900 805 615 684 710 429 ...
% 		794 252 373 605 848 690 713 632 482 806 427 904 414 223 663 ...
% 		692 835 619 472 455 796 809 714 721 837 716 864 810 606 912 ...
% 		722 696 377 435 817 319 621 812 484 430 838 667 488 239 378 ...
% 		459 622 627 437 380 818 461 496 669 679 724 841 629 351 467 ...
% 		438 737 251 462 442 441 469 247 683 842 738 899 670 783 849 ...
% 		820 728 928 791 367 901 630 685 844 633 711 253 691 824 902 ...
% 		686 740 850 375 444 470 483 415 485 905 795 473 634 744 852 ...
% 		960 865 693 797 906 715 807 474 636 694 254 717 575 913 798 ...
% 		811 379 697 431 607 489 866 723 486 908 718 813 476 856 839 ...
% 		725 698 914 752 868 819 814 439 929 490 623 671 739 916 463 ...
% 		843 381 497 930 821 726 961 872 492 631 729 700 443 741 845 ...
% 		920 382 822 851 730 498 880 742 445 471 635 932 687 903 825 ...
% 		500 846 745 826 732 446 962 936 475 853 867 637 907 487 695 ...
% 		746 828 753 854 857 504 799 255 964 909 719 477 915 638 748 ...
% 		944 869 491 699 754 858 478 968 383 910 815 976 870 917 727 ...
% 		493 873 701 931 756 860 499 731 823 922 874 918 502 933 743 ...
% 		760 881 494 702 921 501 876 847 992 447 733 827 934 882 937 ...
% 		963 747 505 855 924 734 829 965 938 884 506 749 945 966 755 ...
% 		859 940 830 911 871 639 888 479 946 750 969 508 861 757 970 ...
% 		919 875 862 758 948 977 923 972 761 877 952 495 703 935 978 ...
% 		883 762 503 925 878 735 993 885 939 994 980 926 764 941 967 ...
% 		886 831 947 507 889 984 751 942 996 971 890 509 949 973 1000 ...
% 		892 950 863 759 1008 510 979 953 763 974 954 879 981 982 927 ...
% 		995 765 956 887 985 997 986 943 891 998 766 511 988 1001 951 ...
% 		1002 893 975 894 1009 955 1004 1010 957 983 958 987 1012 999 ...
% 		1016 767 989 1003 990 1005 959 1011 1013 895 1006 1014 1017 ...
% 		1018 991 1020 1007 1015 1019 1021 1022 1023];
% 	Q = Qmax(Qmax < N);
% 
% 	% Sub-block interleaving (TS 38.212 Section 5.4.1.1)
% 	P = [0 1 2 4 3 5 6 7 8 16 9 17 10 18 11 19 12 20 13 21 14 22 15 ...
% 		23 24 25 26 28 27 29 30 31];
% 	J = zeros(1, N);
% 	for k = 0:N - 1
% 		J(1 + k) = P(1 + floor(32 * k / N)) * N / 32 + mod(k, N / 32);
% 	end
% 
% 	% Determine frozen bit positions (TS 38.212 Section 5.3.1.2)
% 	QtmpF = zeros(1, N);
% 	if E < N
% 		if K/E <= 7/16
% 			for k = 0:N - E - 1
% 				QtmpF(1 + J(1 + k)) = 1;
% 			end
% 			if E >= 3 * N / 4
% 				QtmpF(1 + (0:ceil(3 * N / 4 - E / 2) - 1)) = 1;
% 			else
% 				QtmpF(1 + (0:ceil(9 * N / 16 - E / 4) - 1)) = 1;
% 			end
% 		else
% 			for k = E:N - 1
% 				QtmpF(1 + J(1 + k)) = 1;
% 			end
% 		end
% 	end
% 	QtmpI = 1 - QtmpF;
% 	k = 0;
% 	i = N;
% 	QI = zeros(1, N);
% 	while k < K + nPC
% 		if i == 0
% 			break;
% 		end
% 		if QtmpI(1 + Q(i))
% 			k = k + 1;
% 			QI(1 + Q(i)) = 1;
% 		end
% 		i = i - 1;
% 	end
% 
% 	% Generate polar encoding matrix
% 	GN = [1 0; 1 1];
% 	for k = 2:n
% 		GN = [GN, zeros(2^(k-1)); GN, GN];
% 	end
% 
% 	% Polar encoding
% 	u = zeros(1, N);
% 	k = 0;
% 	for nn = 0:N - 1
% 		if QI(1 + nn)
% 			u(1 + nn) = c_prime(1 + k);
% 			k = k + 1;
% 		else
% 			u(1 + nn) = 0;
% 		end
% 	end
% 	d = mod(u * GN, 2);
% 
% 	% === Rate Matching (TS 38.212 Section 7.3.4 / 5.4.1) ===
% 	y = d(1 + J);
% 
% 	% Bit selection (TS 38.212 Section 5.4.1.2)
% 	e = zeros(1, E);
% 	if E >= N
% 		for k = 0:E - 1
% 			e(1 + k) = y(1 + mod(k, N));
% 		end
% 	else
% 		if K/E <= 7/16
% 			for k = 0:E - 1
% 				e(1 + k) = y(1 + k + N - E);
% 			end
% 		else
% 			for k = 0:E - 1
% 				e(1 + k) = y(1 + k);
% 			end
% 		end
% 	end
% 
% 	f = e;
% 
% 	% === Scrambling (TS 38.211 Section 7.3.2.3) ===
% 	c_init_DCI = mod(sum(rnti_scr .* 2.^(numel(rnti_scr) - 1:-1:0)) * 2^16 + ...
% 		sum(N_ID .* 2.^(15:-1:0)), 2^31);
% 
% 	c_DCI = scrambling(Mbit, c_init_DCI, x1_init);
% 	b_tilde = mod(f + c_DCI, 2);
% 
% end
% 
% function c = scrambling(len, c_init, x1_init)
% 	%scrambling Generate Gold sequence for scrambling
% 	%   C = scrambling(LEN, C_INIT, X1_INIT) generates a Gold sequence of
% 	%   length LEN with initialization C_INIT and X1_INIT.
% 	%
% 	%   Reference: 3GPP TS 38.211 Section 5.2.1
% 
% 	Nc = 1600;
% 	x1 = zeros(1, Nc + len);
% 	x2 = zeros(1, Nc + len);
% 
% 	% Initialize x1 sequence
% 	x1(1) = x1_init;
% 
% 	% Initialize x2 sequence with c_init
% 	x2(1:31) = de2bi(c_init, 31);
% 
% 	% Generate sequences
% 	for i = 1:(Nc + len - 31)
% 		x1(i + 31) = mod(x1(i + 3) + x1(i), 2);
% 		x2(i + 31) = mod(x2(i + 3) + x2(i + 2) + x2(i + 1) + x2(i), 2);
% 	end
% 
% 	% Generate output sequence
% 	c = mod(x1(Nc + 1:Nc + len) + x2(Nc + 1:Nc + len), 2);
% end
% 
% function bits = de2bi(d, n)
% 	%de2bi Convert decimal to binary vector (LSB first)
% 	bits = zeros(1, n);
% 	for i = 1:n
% 		bits(i) = mod(d, 2);
% 		d = floor(d / 2);
% 	end
% end
