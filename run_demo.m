% Run a fresh demonstration simulation.
packageRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(packageRoot, 'src'));

results = lc_model_package('full', 'OutputDir', fullfile(packageRoot, 'outputs', 'demo'), 'ForceRecompute', true);