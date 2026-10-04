function P = proposed_params()
% PROPOSED_PARAMS  Settings of the proposed triple-carrier scheme
% (same values as python/wmark/schemes.py -> HybridQIMScheme). They were
% chosen on a training set of images and validated on held-out images.
    P.dcLambda  = 0.85;   % carrier 1: distortion-compensated QIM factor
    P.pairRatio = 0.8;    % carrier 2: QIM step on the low-pair difference = pairRatio * alpha
    P.midRatio  = 0.3;    % carrier 3: order-rule margin on the mid pair  = midRatio * alpha
    P.pairKey   = 7001;   % key offsets so each carrier uses different secret positions
    P.midKey    = 9001;
    % 1-based DCT positions inside each 8x8 block
    P.low1 = [3 2];  P.low2 = [2 3];      % carrier 2: D(3,2) - D(2,3)
    P.mid1 = [4 3];  P.mid2 = [3 4];      % carrier 3: D(4,3) vs D(3,4) (same pair as Block DCT)
end
