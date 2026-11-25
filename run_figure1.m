% RUN_FIGURE1 - Figure 1/2 model predictions and behavioral simulation.
% See README.md for outputs and full versus demonstration settings.
packageRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(packageRoot,'src'));
results = lc_model_package('predictions');
