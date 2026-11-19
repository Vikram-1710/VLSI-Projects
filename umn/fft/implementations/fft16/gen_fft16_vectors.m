clc;
clear;

N = 16;

% ============================================================
% BIT-ACCURATE MATLAB MODEL FOR CURRENT RTL
%
% Matches RTL behavior:
% - 16-point radix-2 DIF FFT
% - Q15 twiddle constants
% - fixed-point integer arithmetic
% - arithmetic right shift by 15 after twiddle multiplication
% - arithmetic right shift by 1 after every butterfly stage
%
% This should allow TB comparison with TOL = 0 or close to 0.
% ============================================================

% ------------------------------------------------------------
% Helper: arithmetic right shift like SystemVerilog >>> 
% ------------------------------------------------------------
function y = ashr(x, sh)
    y = floor(double(x) / double(2^sh));
end

% ------------------------------------------------------------
% Helper: force signed 16-bit behavior
% For now, values are expected to stay in range, but this keeps
% the model closer to DATA_W = 16.
% ------------------------------------------------------------
function y = sat16(x)
    if x > 32767
        y = 32767;
    elseif x < -32768
        y = -32768;
    else
        y = x;
    end
end

% ------------------------------------------------------------
% RTL Q15 twiddle table
% Matches get_twiddle16() in RTL.
% W16^k = cos(2*pi*k/16) - j*sin(2*pi*k/16)
% ------------------------------------------------------------
function [wr, wi] = get_twiddle16(k)
    kk = mod(k, 8);

    switch kk
        case 0
            wr = 32767;  wi = 0;
        case 1
            wr = 30274;  wi = -12540;
        case 2
            wr = 23170;  wi = -23170;
        case 3
            wr = 12540;  wi = -30274;
        case 4
            wr = 0;      wi = -32768;
        case 5
            wr = -12540; wi = -30274;
        case 6
            wr = -23170; wi = -23170;
        case 7
            wr = -30274; wi = -12540;
        otherwise
            wr = 32767;  wi = 0;
    end
end

% ------------------------------------------------------------
% RTL complex multiply:
%
% p_rr = ar * br
% p_ii = ai * bi
% p_ri = ar * bi
% p_ir = ai * br
%
% tmp_re = p_rr - p_ii
% tmp_im = p_ri + p_ir
%
% yr = tmp_re >>> 15
% yi = tmp_im >>> 15
% ------------------------------------------------------------
function [yr, yi] = cmul_q15_rtl(ar, ai, br, bi)
    p_rr = double(ar) * double(br);
    p_ii = double(ai) * double(bi);
    p_ri = double(ar) * double(bi);
    p_ir = double(ai) * double(br);

    tmp_re = p_rr - p_ii;
    tmp_im = p_ri + p_ir;

    yr = ashr(tmp_re, 15);
    yi = ashr(tmp_im, 15);

    yr = sat16(yr);
    yi = sat16(yi);
end

% ------------------------------------------------------------
% One scaled DIF stage.
%
% y0 = (u + v) >>> 1
% y1 = ((u - v) * W16^k) >>> 1
%
% This matches:
% out_re[i0] = add_re >>> 1;
% out_im[i0] = add_im >>> 1;
% out_re[i1] = t_re >>> 1;
% out_im[i1] = t_im >>> 1;
% ------------------------------------------------------------
function [out_re, out_im] = dif_stage_scaled_rtl(in_re, in_im, HALF_SPAN, TW_STEP)
    out_re = in_re;
    out_im = in_im;

    full_span = 2 * HALF_SPAN;

    for grp = 0:full_span:15
        for j = 0:HALF_SPAN-1
            i0 = grp + j + 1;
            i1 = grp + j + HALF_SPAN + 1;

            u_re = in_re(i0);
            u_im = in_im(i0);
            v_re = in_re(i1);
            v_im = in_im(i1);

            add_re = double(u_re) + double(v_re);
            add_im = double(u_im) + double(v_im);

            d_re = double(u_re) - double(v_re);
            d_im = double(u_im) - double(v_im);

            [w_re, w_im] = get_twiddle16(j * TW_STEP);
            [t_re, t_im] = cmul_q15_rtl(d_re, d_im, w_re, w_im);

            out_re(i0) = sat16(ashr(add_re, 1));
            out_im(i0) = sat16(ashr(add_im, 1));

            out_re(i1) = sat16(ashr(t_re, 1));
            out_im(i1) = sat16(ashr(t_im, 1));
        end
    end
end

% ------------------------------------------------------------
% Full RTL-equivalent 16-point scaled DIF FFT.
% Output is already in DIF bit-reversed order.
% ------------------------------------------------------------
function [y_re, y_im] = fft16_rtl_model(x_re, x_im)

    [s1_re, s1_im] = dif_stage_scaled_rtl(x_re,  x_im,  8, 1);
    [s2_re, s2_im] = dif_stage_scaled_rtl(s1_re, s1_im, 4, 2);
    [s3_re, s3_im] = dif_stage_scaled_rtl(s2_re, s2_im, 2, 4);
    [s4_re, s4_im] = dif_stage_scaled_rtl(s3_re, s3_im, 1, 8);

    y_re = s4_re;
    y_im = s4_im;
end

% ============================================================
% Create test cases
% ============================================================

tests = {};

% ------------------------------------------------------------
% 1. All zero input
% ------------------------------------------------------------
ch0 = zeros(1, N);
ch1 = zeros(1, N);

tests{end+1}.name = 'zero';
tests{end}.ch0 = ch0;
tests{end}.ch1 = ch1;

% ------------------------------------------------------------
% 2. Impulse
%
% Use 16 so output is visible after 4 stages of /2 scaling.
% ------------------------------------------------------------
ch0 = zeros(1, N);
ch1 = zeros(1, N);

ch0(1) = 16;
ch1(1) = 16;

tests{end+1}.name = 'impulse';
tests{end}.ch0 = ch0;
tests{end}.ch1 = ch1;

% ------------------------------------------------------------
% 3. Cosine
% ------------------------------------------------------------
n = 0:N-1;

ch0 = round(16 * cos(2*pi*2*n/N));
ch1 = round(16 * cos(2*pi*3*n/N));

tests{end+1}.name = 'cosine';
tests{end}.ch0 = ch0;
tests{end}.ch1 = ch1;

% ------------------------------------------------------------
% 4. Random input
% Fixed values from your current random vector.
% This avoids MATLAB/Octave randi seed/version differences.
% ------------------------------------------------------------
ch0 = [-18 -19 -11 -29  11  -4   6   8 -32   4   5  -7  14 -17 -27 -25];
ch1 = [ -6   8  17  27 -12 -17 -21 -25 -11  27 -23  31  -1  -7 -14  18];

tests{end+1}.name = 'random';
tests{end}.ch0 = ch0;
tests{end}.ch1 = ch1;

% ============================================================
% Generate files
% ============================================================

for t = 1:length(tests)

    test_name = tests{t}.name;

    ch0_re = tests{t}.ch0;
    ch1_re = tests{t}.ch1;

    ch0_im = zeros(1, N);
    ch1_im = zeros(1, N);

    [fft_ch0_re, fft_ch0_im] = fft16_rtl_model(ch0_re, ch0_im);
    [fft_ch1_re, fft_ch1_im] = fft16_rtl_model(ch1_re, ch1_im);

    % --------------------------------------------------------
    % Input file
    % Format:
    % ch0_re ch0_im ch1_re ch1_im
    % --------------------------------------------------------

    input_filename = sprintf('fft16_input_%s.txt', test_name);
    fid = fopen(input_filename, 'w');

    fprintf(fid, '# 16-point 2-channel input file: %s test\n', test_name);
    fprintf(fid, '# Format: ch0_re ch0_im ch1_re ch1_im\n');

    for i = 1:N
        fprintf(fid, '%d %d %d %d\n', ...
            ch0_re(i), ch0_im(i), ch1_re(i), ch1_im(i));
    end

    fclose(fid);

    % --------------------------------------------------------
    % Expected output file
    % Format:
    % idx ch0_re ch0_im ch1_re ch1_im
    % --------------------------------------------------------

    output_filename = sprintf('fft16_expected_%s.txt', test_name);
    fid = fopen(output_filename, 'w');

    fprintf(fid, '# 16-point 2-channel expected output file: %s test\n', test_name);
    fprintf(fid, '# Bit-accurate RTL model: scaled DIF, Q15 twiddle, truncating shifts\n');
    fprintf(fid, '# Format: idx ch0_re ch0_im ch1_re ch1_im\n');

    for i = 1:N
        fprintf(fid, '%d %d %d %d %d\n', ...
            i-1, ...
            round(fft_ch0_re(i)), round(fft_ch0_im(i)), ...
            round(fft_ch1_re(i)), round(fft_ch1_im(i)));
    end

    fclose(fid);

    fprintf('Generated: %s and %s\n', input_filename, output_filename);
end

disp('ALL BIT-ACCURATE 16-POINT TEST FILES GENERATED');
