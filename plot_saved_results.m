function figures = plot_saved_results(folder)
%PLOT_SAVED_RESULTS Open previously exported figures without recomputation.
%   plot_saved_results                    opens outputs/full/*.fig
%   plot_saved_results('outputs/demo')     opens the demo figures
if nargin < 1
    folder = fullfile(fileparts(mfilename('fullpath')),'outputs','full');
end
files = dir(fullfile(folder,'*.fig'));
assert(~isempty(files),'No saved FIG files found. Run a package entry point first.');
figures = gobjects(numel(files),1);
for k = 1:numel(files)
    figures(k) = openfig(fullfile(files(k).folder,files(k).name),'new','visible');
end
end
