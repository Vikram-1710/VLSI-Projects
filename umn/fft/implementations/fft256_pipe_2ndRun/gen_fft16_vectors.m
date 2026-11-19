clc;
clear;

N = 256;

% ============================================================
% BIT-ACCURATE MATLAB/OCTAVE MODEL FOR PIPELINED ITERATIVE RTL
%
% Matches:
% - 256-point radix-2 DIF FFT
% - Q15 twiddles reused from the original 512-entry ROM
%   W256^k = W512^(2k)
% - arithmetic right shift by 15 after complex multiply
% - arithmetic right shift by 1 after every butterfly stage
% - 8 total stages, so total scaling is /256
% - output is DIF bit-reversed order naturally
% ============================================================

function y = ashr(x, sh)
    y = floor(double(x) / double(2^sh));
end

function y = wrap16(x)
    y = mod(round(x) + 32768, 65536) - 32768;
end

function [wr, wi] = get_twiddle256_from_512rom(k)
    addr512 = mod(2*k, 512);

    wr = round(cos(2*pi*double(addr512)/512) * 32767);
    wi = round(-sin(2*pi*double(addr512)/512) * 32767);

    if wr > 32767
        wr = 32767;
    end
    if wr < -32768
        wr = -32768;
    end

    if wi > 32767
        wi = 32767;
    end
    if wi < -32768
        wi = -32768;
    end
end

function [yr, yi] = cmul_q15_rtl(ar, ai, br, bi)
    ar = wrap16(ar);
    ai = wrap16(ai);
    br = wrap16(br);
    bi = wrap16(bi);

    p_rr = double(ar) * double(br);
    p_ii = double(ai) * double(bi);
    p_ri = double(ar) * double(bi);
    p_ir = double(ai) * double(br);

    tmp_re = p_rr - p_ii;
    tmp_im = p_ri + p_ir;

    yr = wrap16(ashr(tmp_re, 15));
    yi = wrap16(ashr(tmp_im, 15));
end

function [out_re, out_im] = dif_stage_scaled_rtl(in_re, in_im, HALF_SPAN, TW_STEP)
    out_re = in_re;
    out_im = in_im;

    full_span = 2 * HALF_SPAN;

    for grp = 0:full_span:255
        for j = 0:HALF_SPAN-1
            i0 = grp + j + 1;
            i1 = grp + j + HALF_SPAN + 1;

            u_re = wrap16(in_re(i0));
            u_im = wrap16(in_im(i0));
            v_re = wrap16(in_re(i1));
            v_im = wrap16(in_im(i1));

            add_re = double(u_re) + double(v_re);
            add_im = double(u_im) + double(v_im);

            d_re = wrap16(double(u_re) - double(v_re));
            d_im = wrap16(double(u_im) - double(v_im));

            [w_re, w_im] = get_twiddle256_from_512rom(j * TW_STEP);
            [t_re, t_im] = cmul_q15_rtl(d_re, d_im, w_re, w_im);

            out_re(i0) = wrap16(ashr(add_re, 1));
            out_im(i0) = wrap16(ashr(add_im, 1));

            out_re(i1) = wrap16(ashr(t_re, 1));
            out_im(i1) = wrap16(ashr(t_im, 1));
        end
    end
end

function [y_re, y_im] = fft256_rtl_model(x_re, x_im)
    [s1_re, s1_im] = dif_stage_scaled_rtl(x_re,  x_im,  128, 1);
    [s2_re, s2_im] = dif_stage_scaled_rtl(s1_re, s1_im, 64,  2);
    [s3_re, s3_im] = dif_stage_scaled_rtl(s2_re, s2_im, 32,  4);
    [s4_re, s4_im] = dif_stage_scaled_rtl(s3_re, s3_im, 16,  8);
    [s5_re, s5_im] = dif_stage_scaled_rtl(s4_re, s4_im, 8,   16);
    [s6_re, s6_im] = dif_stage_scaled_rtl(s5_re, s5_im, 4,   32);
    [s7_re, s7_im] = dif_stage_scaled_rtl(s6_re, s6_im, 2,   64);
    [s8_re, s8_im] = dif_stage_scaled_rtl(s7_re, s7_im, 1,   128);

    y_re = s8_re;
    y_im = s8_im;
end

tests = {};

% ------------------------------------------------------------
% 1. Zero test
% ------------------------------------------------------------
ch0 = zeros(1, N);
ch1 = zeros(1, N);

tests{end+1}.name = 'zero';
tests{end}.ch0 = ch0;
tests{end}.ch1 = ch1;

% ------------------------------------------------------------
% 2. Impulse test
% Use 256 so output remains visible after /256 scaling.
% ------------------------------------------------------------
ch0 = zeros(1, N);
ch1 = zeros(1, N);

ch0(1) = 256;
ch1(1) = 256;

tests{end+1}.name = 'impulse';
tests{end}.ch0 = ch0;
tests{end}.ch1 = ch1;

% ------------------------------------------------------------
% 3. Cosine test
% ------------------------------------------------------------
n = 0:N-1;

ch0 = round(256 * cos(2*pi*5*n/N));
ch1 = round(256 * cos(2*pi*11*n/N));

tests{end+1}.name = 'cosine';
tests{end}.ch0 = ch0;
tests{end}.ch1 = ch1;

% ------------------------------------------------------------
% 4. Random test
% Fixed seed for repeatability.
% ------------------------------------------------------------
rand('seed', 7);

ch0 = randi([-128, 128], 1, N);
ch1 = randi([-128, 128], 1, N);

tests{end+1}.name = 'random';
tests{end}.ch0 = ch0;
tests{end}.ch1 = ch1;

for t = 1:length(tests)

    test_name = tests{t}.name;

    ch0_re = tests{t}.ch0;
    ch1_re = tests{t}.ch1;

    ch0_im = zeros(1, N);
    ch1_im = zeros(1, N);

    [fft_ch0_re, fft_ch0_im] = fft256_rtl_model(ch0_re, ch0_im);
    [fft_ch1_re, fft_ch1_im] = fft256_rtl_model(ch1_re, ch1_im);

    input_filename = sprintf('fft256_input_%s.txt', test_name);
    fid = fopen(input_filename, 'w');

    fprintf(fid, '# 256-point 2-channel input file: %s test\n', test_name);
    fprintf(fid, '# Format: ch0_re ch0_im ch1_re ch1_im\n');

    for i = 1:N
        fprintf(fid, '%d %d %d %d\n', ...
            ch0_re(i), ch0_im(i), ch1_re(i), ch1_im(i));
    end

    fclose(fid);

    output_filename = sprintf('fft256_expected_%s.txt', test_name);
    fid = fopen(output_filename, 'w');

    fprintf(fid, '# 256-point 2-channel expected output file: %s test\n', test_name);
    fprintf(fid, '# Bit-accurate RTL model: iterative scaled DIF, Q15 twiddle, truncating shifts\n');
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

disp('ALL BIT-ACCURATE PIPELINED 256-POINT TEST FILES GENERATED');

