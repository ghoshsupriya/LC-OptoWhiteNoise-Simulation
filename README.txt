# MATLAB scripts for Figures 1 and 2

Supriya Ghosh and John H. R. Maunsell
Transient noradrenergic signals act as online controllers of perceptual computation

MATLAB R2025b is used.
The scripts use relative paths and base MATLAB functions. No empirical dataset
or additional toolbox is required for these model predictions and simulations.

## Run

Extract the package and set MATLAB's Current Folder to the package folder
containing the three entry scripts and the src and data folders.

```matlab
run_figure1                 % Display Figure 1 model predictions only
run_manuscript_results      % Display Figure 2 from supplied manuscript results
run_demo                    % Run simulations, or load matching saved results
```

### Figure 1 predictions

run_figure1 displays the within-trial and across-trial prediction panels.
It does not run behavioral recovery simulations, display the example dynamics,
or save any files.

### Figure 2 manuscript results

run_manuscript_results loads data/Figure2_results.mat and displays the Figure 2
kernel recovery plots. It also regenerates the illustrative persistent-state,
controller and teaching trajectories using the saved configuration and seed.
It does not repeat the behavioral simulation and GLM recovery loop or save files.

The supplied MAT file must contain cfg, modelNames, recoveredWithin,
populationWithin, recoveredAcross, populationAcross, recoveredTeacherAcross
and populationTeacherAcross. The saved cfg supplies the simulation settings and
repetition count used to calculate the displayed means and confidence intervals.
Keep this manuscript-results file separate from the demo output.

### Simulation demo

run_demo generates simulated choices and fits the GLMs, displays the example
dynamics, model predictions and recovered kernels, and prints the SIMULATION
RESULT SUMMARY. The kernel recovery plots use automatic y-axis limits; the
manuscript-results plots retain the original limits.

The current simulation configuration in src/lc_model_package.m is:

```matlab
cfg.randomSeed = 11;
cfg.nTrials   = 1000;
cfg.nRepeats  = 400;
```

Trials and repetitions apply to each of four model variants: persistent state,
controller with a 0-ms gate, controller with a 100-ms gate, and teaching.
For a quick execution check, set cfg.nRepeats = 2 in the first configuration
block ("1. Reproducibility and simulation size"). Two repetitions are for
checking execution, not interpreting recovery statistics. Actual runtime
depends on the configuration and computer.

## Saved results and repeated runs

The simulation demo saves only:

    outputs/demo/results.mat

No Excel, CSV, PDF, FIG or execution-report files are written. The output folder
is created when needed. A separate outputs/full folder is not required.

Run run_demo again with the same settings and ForceRecompute = false to load
the saved simulation and redraw its plots. Example trajectories and numerical
predictions are regenerated, but the main simulation and GLM loop is skipped.
The MAT file is also updated with the example structures and summary matrices.

If the saved settings do not match, the script stops rather than silently
overwriting results. Use a different OutputDir, restore the saved settings,
or deliberately recompute. For example, from the package folder:

```matlab
addpath('src')
results = lc_model_package('full', 'OutputDir', fullfile(pwd, 'outputs', 'demo'), 'ForceRecompute', true); 
```

This replaces the demo results. Keep ForceRecompute = false for normal reuse.
After changing model equations or fitting calculations, explicitly recompute;
matching configuration values alone do not establish computational equivalence.

## Recompute the manuscript simulations

To generate the full simulations again, set cfg.nTrials = 8000 and
cfg.nRepeats = 500 in the same configuration block. Use a separate output
directory to preserve the demo results:

```matlab
addpath('src')
results = lc_model_package('full', 'OutputDir', fullfile(pwd, 'outputs', 'manuscript_recompute'), 'ForceRecompute', true);
```

The internal mode 'full' runs the configured simulation size; its name does
not override cfg.nTrials or cfg.nRepeats. The internal mode 'demo' is retained
for loading manuscript results through run_manuscript_results. Use the entry
scripts above for routine operation.

## Calculations and scope

The model equations, logistic fits and original chronological 80/20 split are
retained. Figure 1/2 GLMs use lambda = 0. This package covers Figures 1 and 2;
it does not include the empirical analyses or supplementary sensitivity analysis.
It generates numerical plots and example dynamics, not the final manuscript
schematics or panel assembly. See METHODS_AND_OUTPUTS.txt for the calculations,
figure mapping and saved variables.

Contact: sghosh5@uchicago.edu
