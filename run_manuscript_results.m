% Plot manuscript results from the saved full simulation.
packageRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(packageRoot, 'src'));

results = lc_model_package('demo');