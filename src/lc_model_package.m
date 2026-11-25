function out = lc_model_package(mode, varargin)
%LC_MODEL_PACKAGE Figure 1 predictions and Figure 2 behavioral simulation.
%   out = lc_model_package('predictions') derives predictions and examples.
%   out = lc_model_package('demo') uses 1000 trials x 2 repetitions.
%   out = lc_model_package('full') uses the supplied 8000 x 500 settings.
%   Name/value options: OutputDir, ForceRecompute, FigureVisible ('on'/'off').
%   See README.md. No empirical data are used. Computations are preserved
%   from the supplied temporalModel_04.m; documented packaging edits only.

if nargin < 1, mode = 'predictions'; end
mode = validatestring(mode, {'predictions','demo','full'});
parser = inputParser;
addParameter(parser, 'OutputDir', '', @(x)ischar(x) || (isstring(x) && isscalar(x)));
addParameter(parser, 'ForceRecompute', false, @(x)islogical(x) && isscalar(x));
addParameter(parser, 'FigureVisible', 'on', @(x)any(strcmp(x,{'on','off'})));
parse(parser, varargin{:});
options = parser.Results;
packageRoot = fileparts(fileparts(mfilename('fullpath')));
if strcmp(mode, 'demo')
    resultsFile = fullfile(packageRoot, 'data', 'Figure2_results.mat');
    assert(isfile(resultsFile), 'Missing data/Figure2_results.mat.');
    load(resultsFile, 'cfg', 'modelNames', 'recoveredWithin', 'populationWithin', 'recoveredAcross', 'populationAcross', 'recoveredTeacherAcross', 'populationTeacherAcross');
    nModels = numel(modelNames);
    stateModelIndex = 1;
    controllerModelIndices = 2:(nModels-1);
    teachingModelIndex = nModels;
    trialLags          = 1:cfg.maxTrialLag;

    % Reproduce the original example trajectories.
    savedRNG = rng;
    rngCleanup = onCleanup(@()rng(savedRNG));
    rng(cfg.randomSeed, 'twister');
    sharedExampleTrial = makeSharedExampleTrial(cfg);
    exampleStateTrial = simulatePersistentStateExampleTrial(cfg, sharedExampleTrial);
    exampleStateTrial.crossTrial = makePersistentCrossTrialExample(cfg, 15);
    plotPersistentStateExampleTrial(exampleStateTrial, cfg);
    exampleControllerTrial = simulateControllerExampleTrial(cfg, 100, sharedExampleTrial);
    plotControllerExampleTrial(exampleControllerTrial, cfg);
    exampleTeachingSequence = simulateTeachingExampleSequence(cfg, 15, 5);
    plotTeachingExampleSequence(exampleTeachingSequence, cfg);
else

    outputDir = char(options.OutputDir);
    if isempty(outputDir), outputDir = fullfile(packageRoot, 'outputs', mode); end
    if ~strcmp(mode, 'predictions')
       if ~exist(outputDir,'dir'), mkdir(outputDir); end
    end
    resultsFile = fullfile(outputDir, 'results.mat');
    initialFigures = findall(groot,'Type','figure');
    savedRNG = rng;
    rngCleanup = onCleanup(@()rng(savedRNG)); 
    savedVisibility = get(groot,'DefaultFigureVisible');
    visibilityCleanup = onCleanup(@()set(groot,'DefaultFigureVisible',savedVisibility));
    set(groot,'DefaultFigureVisible',options.FigureVisible);
    fprintf('\nLC: opto white noise model package | %s\n', mode);

    %% =========================== CONFIGURATION ===============================

    %% 1. Reproducibility and simulation size
    cfg.randomSeed              = 11;
    cfg.nTrials                 = 1000; % nTrials of 8000 used in the manuscript
    cfg.nRepeats                = 400;  % nTrials of 500 used in the manuscript
    if strcmp(mode, 'demo')
       cfg.nTrials = 1000;
       cfg.nRepeats = 2;
    end
    cfg.trainFraction           = 0.80; 
    cfg.maxTrialLag             = 20;

    rng(cfg.randomSeed, "twister");

    %% 2. Full delayed match-to-sample task timeline
    % Internal simulation resolution
    cfg.dtMs                    = 5;

    % Full modeled trial interval
    cfg.windowStartMs           = -400;
    cfg.windowEndMs             = 800;
    cfg.timeMs                  = cfg.windowStartMs : cfg.dtMs : cfg.windowEndMs-cfg.dtMs;
    cfg.nTimeSamples            = numel(cfg.timeMs);

    % Task epochs
    cfg.sampleOnsetMs           = 0;
    cfg.sampleOffsetMs          = 200;
    cfg.delayOnsetMs            = 200;
    cfg.delayOffsetMs           = 400;
    cfg.testOnsetMs             = 400;
    cfg.testOffsetMs            = 600;

    % Sample-test comparison occurs while the test is present
    cfg.decisionEpochStartMs    = 400;
    cfg.decisionEpochEndMs      = 600;

    % Report/readout epoch
    cfg.reportEpochStartMs      = 600;
    cfg.reportEpochEndMs        = 800;

    %% 3. White-noise LC stimulation
    % WN is delivered from -400 ms until test onset
    cfg.wnStartMs               = -400;
    cfg.wnEndMs                 = 400;

    % Experimental temporal resolution of independently randomized states
    cfg.wnStateBinMs            = 25;
    cfg.samplesPerWNState       = cfg.wnStateBinMs / cfg.dtMs;
    cfg.nWNStateBins            = (cfg.wnEndMs-cfg.wnStartMs) / cfg.wnStateBinMs;
    cfg.nWNTimeSamples          = (cfg.wnEndMs-cfg.wnStartMs) / cfg.dtMs;

    % Probability that each independent 25-ms WN state is ON
    cfg.pPulse                  = 0.50;

    % Physical causal input remains binary:
    % ON = 1; OFF = 0. Standardization is performed only in the GLM design.
    cfg.centerWN                = false;

    % Centers of the independently randomized 25-ms bins
    cfg.wnTimeMs                = cfg.wnStartMs + cfg.wnStateBinMs/2 : cfg.wnStateBinMs : cfg.wnEndMs - cfg.wnStateBinMs/2;

    % Centers of the internal 5-ms WN samples
    cfg.wnFineTimeMs            = cfg.wnStartMs : cfg.dtMs : cfg.wnEndMs - cfg.dtMs;

    %% 4. Visual encoding dynamics
    % Each Gabor-evoked representation rises after onset and decays after
    % stimulus offset.
    cfg.sensoryRiseTauMs        = 20;
    cfg.sensoryDecayTauMs       = 20;

    % Memory decay used for the illustrative sample-memory trajectory
    cfg.memoryDecayTauMs        = 400;

    %% 5. Match-to-sample trial structure
    % Equal numbers of match and orientation-change trials
    cfg.pDifferent              = 0.50;

    % Absolute orientation change on nonmatch trials
    cfg.changeMagnitudeDeg      = 20; 

    % Same/different decision rule
    cfg.baseChangeCriterionDeg  = 10;
    cfg.decisionNoiseDeg        = 14;

    % Baseline probability of an uninformative response
    cfg.baselineLapseProb       = 0.05;
    cfg.baselineLapseLogit      = log( cfg.baselineLapseProb / (1-cfg.baselineLapseProb));

    %% 6. Persistent operating-state policy
    % Within-trial dynamics of the WN-induced perturbation
    % Background-state-dependent persistence of the WN perturbation
    cfg.stateTauMinMs           = 50;
    cfg.stateTauMaxMs           = 300;
    cfg.stateTauSlope           = 1; 
    cfg.stateInputGain          = 0.03;

    % Trial-level operating baseline
    cfg.stateBaselineRetention  = 0.8;

    % Single-index coupling from persistent state to accuracy log odds
    cfg.stateBehaviorGain       = 0.40;

    %% Slow endogenous drift in the trial-level operating baseline
    cfg.stateBaselineNoiseSD    = 0.01;

    % Recent-performance monitor
    cfg.performanceLearningRate = 0.10;
    cfg.performanceStateGain    = 0.20;

    % Trial-locked temporal expectation
    cfg.expectationStateGain    = 0.15;
    cfg.expectationDecayTauMs   = 350;

    % Within-trial endogenous state noise
    cfg.stateNoiseSD            = 0.015;

    % Downstream sensitivity to the common operating state
    cfg.stateSampleGain         = 0.3;
    cfg.stateMemoryGain         = 0.75;%0.30; %(also controles how fast the kernel falls off post sample on for persistent state)
    cfg.stateTestGain           = 0.30;

    % Keep the existing decision/report readouts for now
    cfg.stateCriterionGain      = 0.10;
    cfg.stateLapseGain          = -0.25;
    cfg.stateWNWriteGain        = 0.4;

    %% 7. Online-controller policy
    % Controller dynamics
    cfg.controlTauMs            = 25;
    cfg.controlInputGain        = 0.2;

    % Strength with which controller state modulates active visual processing
    cfg.controlSensoryGain      = 1.2;

    % A priori family of controller input-eligibility epochs
    cfg.controlPeakCandidatesMs = [0 100];
    cfg.nControllerModels       = numel(cfg.controlPeakCandidatesMs);

    %% 8. Teaching policy
    cfg.learningRate            = 0.2;
    cfg.weightRetention         = exp(-1/3);
    cfg.teacherBehaviorGain     = 1.00;

    % Probability of positive versus negative simulated teaching feedback
    cfg.pPositiveFeedback       = 0.50;

    %% 9. Model fitting and numerical optimization
    cfg.lambdaGrid              = logspace(-3, 2, 12);
    cfg.maxIter                 = 1000;
    cfg.tolerance               = 1e-7;

    %% 10. Derived task profiles and indices
    cfg.sampleEvidenceProfile   = makeStimulusEvidenceProfile(cfg.sampleOnsetMs, cfg.sampleOffsetMs, cfg);
    cfg.testEvidenceProfile     = makeStimulusEvidenceProfile(cfg.testOnsetMs, cfg.testOffsetMs, cfg);
    cfg.temporalExpectation     = makeTemporalExpectation(cfg);

    cfg.sampleOnsetIndex        = find(cfg.timeMs >= cfg.sampleOnsetMs,1, "first");
    cfg.sampleOffsetIndex       = find(cfg.timeMs >= cfg.sampleOffsetMs, 1, "first");
    cfg.testOnsetIndex          = find(cfg.timeMs >= cfg.testOnsetMs, 1,  "first");
    cfg.testOffsetIndex         = find(cfg.timeMs >= cfg.testOffsetMs, 1, "first");

    controllerNames             = compose( "Controller %+.0f ms", cfg.controlPeakCandidatesMs);
    modelNames                  = [ "Persistent state", controllerNames, "Teaching signal"];
    nModels                     = numel(modelNames);

    stateModelIndex             = 1;
    controllerModelIndices      = 2:(1 + cfg.nControllerModels);
    teachingModelIndex          = nModels;

    %% ---------------- DERIVE ALGORITHMIC IMPULSE PREDICTIONS -----------------
    % These predictions are derived from the governing equations.
    % No temporal kernel is specified by hand.
    kernels = deriveAlgorithmicPredictions(cfg);
    assert(all(kernels.within(:,teachingModelIndex) == 0), 'Teaching must have no direct current-trial impulse.');
    assert(all(all(kernels.across(:,controllerModelIndices) == 0)), 'Controller must have no cross-trial impulse.');
    packageSignature.mode = mode;
    packageSignature.configuration = cfg;
    packageSignature.implementation = fileread([mfilename('fullpath') '.m']);
    packageSignature.demoInputBytes = uint8([]);
    
    demoInputs = [];
    if strcmp(mode, 'demo')
       demoPath = fullfile(packageRoot, 'data', 'demo_inputs.mat');
       assert(exist(demoPath,'file') == 2, 'Missing data/demo_inputs.mat.');
       demoInputs = load(demoPath);
       validateDemoInputs(demoInputs, cfg, nModels);
       inputID = fopen(demoPath, 'rb');
       assert(inputID ~= -1, 'Cannot read demo input file.');
       packageSignature.demoInputBytes = fread(inputID, Inf, '*uint8');
       fclose(inputID);
    end

    %%% -------- EXAMPLE TRIALS: THREE COMPUTATIONAL ALGORITHMS ----------------
    % These inputs are shared exactly across all model examples.
    if ~strcmp(mode, 'predictions')
       sharedExampleTrial = makeSharedExampleTrial(cfg);

       % A. Persistent operating-state model
       exampleStateTrial = simulatePersistentStateExampleTrial(cfg, sharedExampleTrial);
       exampleStateTrial.crossTrial = makePersistentCrossTrialExample(cfg,15);
       plotPersistentStateExampleTrial(exampleStateTrial, cfg);

       % B. Controller model
       controllerPeakMs       = 100;
       exampleControllerTrial = simulateControllerExampleTrial(cfg, controllerPeakMs, sharedExampleTrial);
       plotControllerExampleTrial(exampleControllerTrial, cfg);

       % C. Teaching model
       % Teaching requires a sequence of trials because the update affects
       % subsequent trials rather than the currently perturbed trial.
       nTeachingExampleTrials  = 15;
       teachingUpdateTrial     = 5;
       exampleTeachingSequence = simulateTeachingExampleSequence(cfg, nTeachingExampleTrials, teachingUpdateTrial);
       plotTeachingExampleSequence(exampleTeachingSequence, cfg);
    end

    %% -----------------Plot: Model prediction Figure 1 ----------------------

    persistentColor = [161 120 36]/255;
    controllerColor = [102 45 145]/255;
    teachingColor   = [26 156 51]/255;
    modelColors                           = zeros(nModels,3);
    modelColors(stateModelIndex,:)        = persistentColor;
    modelColors(controllerModelIndices,:) = repmat(controllerColor, numel(controllerModelIndices), 1);
    modelColors(teachingModelIndex,:)     = teachingColor;

    figure('Position',[20 800 500 800],"Color", "w", "Name", "Generating model predictions");hold on;
      tiledlayout(2, 1, "TileSpacing", "compact");
      nexttile;
      for nM = 1:nModels
          plot(cfg.wnFineTimeMs, kernels.within(:,nM), 'LineWidth', 2);hold on
      end
      xline(0, '--k', 'Sample onset');xline(400, ':k', 'Test onset');
      xlabel("LC stimulation time relative to sample onset (ms)");ylabel("Change in log odds of correct response");
      title("Predicted current-trial effects");
      set(gca,'color','none','TickLength',[0.025 0.025],'TickDir', 'out')
      legend(modelNames, "Location", "best");box off;

      nexttile;
      trialLags = 1:cfg.maxTrialLag;
      for nM = 1:nModels
          plot(trialLags, kernels.across(:,nM), "-o", "LineWidth", 2);hold on;
      end
      xlabel("Future trial lag");ylabel("Change in log odds of correct response");
      title("Predicted cross-trial effects");
      set(gca,'color','none','TickLength',[0.025 0.025],'TickDir', 'out')
      legend(modelNames, "Location", "best");box off;

    % Figure 1 can be reproduced without running the recovery simulations.
    if strcmp(mode, 'predictions')
       out = [];
       return;
    end

    simulationCompleted = false;
    if exist(resultsFile, 'file') == 2 && ~options.ForceRecompute
       prior = load(resultsFile, 'packageSignature');
       load(resultsFile);
       simulationCompleted = true;
       fprintf('Loaded matching saved simulation results.\n');
    end
    if ~simulationCompleted
       %% ------------------------- MODEL-RECOVERY LOOP ---------------------------
       % Scores(generating model, fitted model, repetition)
       heldoutLL       = nan(nModels, nModels, cfg.nRepeats);
       heldoutLLWithin = nan(nModels, nModels, cfg.nRepeats);
       heldoutLLAcross = nan(nModels, nModels, cfg.nRepeats);
       heldoutLLCombined = nan(nModels,nModels,cfg.nRepeats);

       % Store recovered kernels for display
       recoveredWithin         = nan(cfg.nWNStateBins, nModels, cfg.nRepeats);
       populationWithin        = nan(cfg.nWNStateBins, nModels, cfg.nRepeats);
       recoveredAcross         = nan(cfg.maxTrialLag, nModels, cfg.nRepeats);
       recoveredTeacherAcross  = nan(cfg.maxTrialLag, nModels, cfg.nRepeats);
       populationAcross        = nan(cfg.maxTrialLag, nModels, cfg.nRepeats);
       populationTeacherAcross = nan(cfg.maxTrialLag, nModels, cfg.nRepeats);

       % Store one representative persistent-state simulation for visualization
       persistentLatents       = [];
       persistentBehavior      = [];
       persistentWN25          = [];
       referenceDesign         = [];
       exampleDatasets = cell(nModels,1);

       modelExpectedAccuracy    = nan(nModels,1);
       modelSampledAccuracy     = nan(nModels,1);
       sampledAccuracyByRepeat  = NaN(nModels,cfg.nRepeats);
       expectedAccuracyByRepeat = NaN(nModels,cfg.nRepeats);
       noLCAccuracyByRepeat     = NaN(nModels,cfg.nRepeats);
       lcAccuracyByRepeat       = NaN(nModels,cfg.nRepeats);

       for repetition = 1:cfg.nRepeats
           if repetition == 1 || mod(repetition,10) == 0
              fprintf('Starting repetition %d / %d\n', repetition, cfg.nRepeats);
           end

           % Generate WN, delta, task conditions and split once here.
           for generatingModel = 1:nModels
              
               % Generate one binary ON/OFF realization per independent 25-ms WN bin
               WN25 = double(rand(cfg.nTrials, cfg.nWNStateBins) < cfg.pPulse);

               % Expand the active -400 to +400 ms WN interval to 5-ms resolution
               WNactive = repelem(WN25, 1, cfg.samplesPerWNState);

               % Pad with true zero stimulation from +400 to +800 ms
               nPostWNSamples = cfg.nTimeSamples - cfg.nWNTimeSamples;
               WN = [WNactive, zeros(cfg.nTrials, nPostWNSamples)];

               %% Match-to-sample trial conditions
               sampleOrientationDeg = 180 * rand(cfg.nTrials,1);
               isDifferent          = rand(cfg.nTrials,1) < cfg.pDifferent;
               changeSign           = 2 * double(rand(cfg.nTrials,1) < 0.5) - 1;
               signedChangeDeg      = changeSign .* cfg.changeMagnitudeDeg .* double(isDifferent);
               testOrientationDeg   = mod(sampleOrientationDeg + signedChangeDeg, 180);
               trueDifferenceDeg    = abs(orientationDifferenceDeg(testOrientationDeg, sampleOrientationDeg));
     
               % Demo only: use the bundled small synthetic stimulation/task inputs.
               % Full mode retains the input generation and RNG call order above.
               if strcmp(mode, 'demo')
                  WN25 = double(demoInputs.WN25(:,:,generatingModel,repetition));
                  WNactive = repelem(WN25, 1, cfg.samplesPerWNState);
                  WN = [WNactive, zeros(cfg.nTrials, nPostWNSamples)];
                  sampleOrientationDeg = double(demoInputs.sampleOrientationDeg(:,generatingModel,repetition));
                  isDifferent = logical(demoInputs.isDifferent(:,generatingModel,repetition));
                  trueDifferenceDeg = double(demoInputs.trueDifferenceDeg(:,generatingModel,repetition));
                  testOrientationDeg = double(demoInputs.testOrientationDeg(:,generatingModel,repetition));
               end
               fprintf('  %s | repetition %d/%d\n', modelNames(generatingModel), repetition, cfg.nRepeats);

               % Simulate behavior directly from the governing equations.
               [y, latent, pTrue]   = simulateAlgorithmicBehavior(WN, WN25, [], trueDifferenceDeg, isDifferent, generatingModel, cfg);
               delta                = 2*y - 1;
               assert(all(isfinite(pTrue)) && all(pTrue>0 & pTrue<1), 'Invalid generating probabilities.');
               assert(all(y==0 | y==1), 'Behavior must be binary.');
               if repetition == 1
                   exampleDatasets{generatingModel} = struct('WN25', WN25, 'sampleOrientationDeg', sampleOrientationDeg, 'testOrientationDeg', testOrientationDeg, 'trueDifferenceDeg', trueDifferenceDeg, 'isDifferent', isDifferent, 'y', y, 'pTrue', pTrue, 'modelNumber', generatingModel);
               end

               WN0             = zeros(size(WN));
               WN250           = zeros(size(WN25));
               [~,~,pTrueNoLC] = simulateAlgorithmicBehavior(WN0,WN250,[],trueDifferenceDeg,isDifferent,generatingModel,cfg);

               noLCAccuracyByRepeat(generatingModel,repetition)     = mean(pTrueNoLC);
               lcAccuracyByRepeat(generatingModel,repetition)       = mean(pTrue);

               % expected performance
               modelExpectedAccuracy(generatingModel)               = mean(pTrue);
               modelSampledAccuracy(generatingModel)                = mean(y);
               expectedAccuracyByRepeat(generatingModel,repetition) = modelExpectedAccuracy(generatingModel);
               sampledAccuracyByRepeat(generatingModel,repetition)  = modelSampledAccuracy(generatingModel);
        
               % Construct predictors only after choices have been generated.
               design = constructDesignMatrices(WN, delta, cfg);
               if isempty(referenceDesign)
                  referenceDesign = design;
               end

               % Retain one representative persistent-state simulation.
               % Do this only once to avoid storing all repeats.
               if generatingModel == stateModelIndex && repetition == 1
                  persistentLatents  = latent;
                  persistentBehavior = y;
                  persistentWN25     = WN25;
               end

               % Train/test split
               nTrain = floor(cfg.trainFraction*cfg.nTrials);
               trainIdx = 1:nTrain;
               testIdx = (nTrain+1):cfg.nTrials;

               % use all trials for kernel recovery
               kernelIdx   = (1:cfg.nTrials)';

               % Recover the current-trial reverse-correlation kernel
               Xwithin     = design.within;

               % No ridge is required: 32 independent predictors and ~8000 training trials
               betaWithin = ridgeLogisticIRLS(Xwithin(kernelIdx,:),y(kernelIdx),0,cfg);

               withinStart = 2;
               withinEnd   = 1 + cfg.nWNStateBins;
               recoveredWithin(:, generatingModel, repetition) = betaWithin(withinStart:withinEnd);

               % Population reverse-correlation kernel: same GLM, but fitted to the model's exact behavioral probabilities.
               betaWithinPopulation = ridgeLogisticIRLS(Xwithin(kernelIdx,:),pTrue(kernelIdx),0,cfg);
               populationWithin(:, generatingModel, repetition) = betaWithinPopulation(withinStart:withinEnd);

           
               % Recover plain cross-trial history
               Xacross    = design.across;
               betaAcross = ridgeLogisticIRLS(Xacross(kernelIdx,:),y(kernelIdx),0,cfg);
               recoveredAcross(:, generatingModel, repetition) = betaAcross(2:end);

               % Population cross-trial kernel: identical GLM fitted to exact probabilities
               betaAcrossPopulation = ridgeLogisticIRLS(Xacross(kernelIdx,:),pTrue(kernelIdx),0,cfg);
               populationAcross(:, generatingModel, repetition) = betaAcrossPopulation(2:end);

               % Recover teaching-gated cross-trial history
               Xteacher    = design.teacherAcross;
               betaTeacher = ridgeLogisticIRLS(Xteacher(kernelIdx,:), y(kernelIdx), 0, cfg);       
               recoveredTeacherAcross(:, generatingModel, repetition) = betaTeacher(2:end);      
               betaTeacherPopulation = ridgeLogisticIRLS(Xteacher(kernelIdx,:), pTrue(kernelIdx), 0, cfg);
               populationTeacherAcross(:, generatingModel, repetition) = betaTeacherPopulation(2:end);

               % Fit the constrained hypothesis models without regularization. These models contain only one or two predictors, so ridge tuning is unnecessary and would add model-dependent validation noise.
               for fittedModel = 1:nModels
                   Xfit    = makeAlgorithmicModelDesign( design, fittedModel, kernels, cfg);
                   betaFit = ridgeLogisticIRLS( Xfit(trainIdx,:), y(trainIdx), 0, cfg);
                   pTest   = logistic( [ones(numel(testIdx),1), Xfit(testIdx,:)] * betaFit);
                   heldoutLL(generatingModel, fittedModel, repetition) = meanBernoulliLogLikelihood(y(testIdx), pTest);

                   % Current-trial-only model identification
                   currentPredictor = design.within * kernels.within25(:,fittedModel);
                   if std(currentPredictor) < 1e-12
                      currentPredictor = zeros(cfg.nTrials,0);
                   else
                      currentPredictor = zscoreSafe(currentPredictor);
                   end
                   betaCurrent = ridgeLogisticIRLS(currentPredictor(trainIdx,:), y(trainIdx), 0, cfg);
                   pCurrentTest = logistic([ones(numel(testIdx),1), currentPredictor(testIdx,:)] * betaCurrent);             
                   heldoutLLWithin(generatingModel,fittedModel,repetition) = meanBernoulliLogLikelihood(y(testIdx),pCurrentTest);

                   % Cross-trial-only model identification
                   if fittedModel == stateModelIndex
                      crossPredictor = design.across * kernels.across(:,stateModelIndex);
                   elseif ismember(fittedModel,controllerModelIndices)
                      % Controller predicts no cross-trial effect. Use a zero predictor so this becomes an intercept-only model.
                      crossPredictor = zeros(cfg.nTrials,0);
                   elseif fittedModel == teachingModelIndex
                      crossPredictor = design.teacherAcross * kernels.across(:,teachingModelIndex);
                   else
                      error('Unknown fitted model.');
                   end
                   if ~isempty(crossPredictor)
                      if std(crossPredictor) < 1e-12
                         crossPredictor = zeros(cfg.nTrials,0);
                      else
                         crossPredictor = zscoreSafe(crossPredictor);
                      end
                   end
                   betaCross = ridgeLogisticIRLS(crossPredictor(trainIdx,:), y(trainIdx), 0, cfg);
                   pCrossTest = logistic([ones(numel(testIdx),1), crossPredictor(testIdx,:)] * betaCross);
                   heldoutLLAcross(generatingModel,fittedModel,repetition) = meanBernoulliLogLikelihood(y(testIdx),pCrossTest);

                   % Combined within + cross model identification: (Supplementary Figure S1)
                   currentPredictor = design.within * kernels.within25(:,fittedModel);
                   if std(currentPredictor) < 1e-12
                      currentPredictor = [];
                   else
                      currentPredictor = zscoreSafe(currentPredictor);
                   end
                   % Cross predictor
                   if fittedModel == stateModelIndex
                      crossPredictor = design.across * kernels.across(:,stateModelIndex);
                   elseif ismember(fittedModel,controllerModelIndices)
                      crossPredictor = [];
                   elseif fittedModel == teachingModelIndex
                      crossPredictor = design.teacherAcross * kernels.across(:,teachingModelIndex);
                   end
                   if ~isempty(crossPredictor)
                      if std(crossPredictor)<1e-12
                         crossPredictor=[];
                      else
                         crossPredictor=zscoreSafe(crossPredictor);
                      end
                   end
                   % Combined design
                   Xcombined=[currentPredictor crossPredictor];
                   betaCombined = ridgeLogisticIRLS(Xcombined(trainIdx,:),y(trainIdx),0,cfg);
                   pCombined = logistic([ones(numel(testIdx),1),Xcombined(testIdx,:)]*betaCombined);
                   heldoutLLCombined(generatingModel,fittedModel,repetition)=meanBernoulliLogLikelihood(y(testIdx),pCombined);
               end
           end
       end

    
       %% --------------------------- RECOVERY RESULTS ----------------------------
       meanLL = mean(heldoutLL, 3, "omitnan");
       nTestTrials = cfg.nTrials - floor(cfg.trainFraction * cfg.nTrials);
       totalHeldoutLL = heldoutLL * nTestTrials;
       meanTotalHeldoutLL = mean(totalHeldoutLL, 3, "omitnan");

       % Convert log likelihood into relative scores within each generating model
       relativeLL = meanLL - max(meanLL, [], 2);
       relativeTotalLL = meanTotalHeldoutLL - max(meanTotalHeldoutLL, [], 2);
    
      recoveryProbability = zeros(nModels, nModels);
      for generatingModel = 1:nModels
          for repetition = 1:cfg.nRepeats
              [~, winner] = max(heldoutLL(generatingModel,:,repetition), [], 2);
              recoveryProbability(generatingModel,winner) = recoveryProbability(generatingModel,winner) + 1;
          end
      end
      recoveryProbability = recoveryProbability ./ cfg.nRepeats;
   
      recoveryProbabilityWithin = zeros(nModels,nModels);
      for generatingModel = 1:nModels
          for repetition = 1:cfg.nRepeats
              [~,winner] = max(heldoutLLWithin(generatingModel,:,repetition), [], 2);
              recoveryProbabilityWithin(generatingModel,winner) = recoveryProbabilityWithin(generatingModel,winner) + 1;
          end
      end
      recoveryProbabilityWithin = recoveryProbabilityWithin ./ cfg.nRepeats;
   
      recoveryProbabilityAcross = zeros(nModels,nModels);
      for generatingModel = 1:nModels
          for repetition = 1:cfg.nRepeats
              [~,winner] = max(heldoutLLAcross(generatingModel,:,repetition), [], 2);
              recoveryProbabilityAcross(generatingModel,winner) = recoveryProbabilityAcross(generatingModel,winner) + 1;
          end
      end
      recoveryProbabilityAcross = recoveryProbabilityAcross ./ cfg.nRepeats;

      recoveryProbabilityCombined=zeros(nModels,nModels);
      for generatingModel=1:nModels
          for repetition=1:cfg.nRepeats
              [~,winner]=max(heldoutLLCombined(generatingModel,:,repetition));
              recoveryProbabilityCombined(generatingModel,winner)=recoveryProbabilityCombined(generatingModel,winner)+1;
          end
      end
      recoveryProbabilityCombined=recoveryProbabilityCombined./cfg.nRepeats;

      %% Recovery strength: true model versus best alternative
      deltaLLRecovery = nan(nModels,cfg.nRepeats);
      for generatingModel = 1:nModels
          otherModels = setdiff(1:nModels,generatingModel);
          for repetition = 1:cfg.nRepeats
              llTrue = heldoutLLCombined(generatingModel,generatingModel,repetition);
              llBestOther = max(heldoutLLCombined(generatingModel,otherModels,repetition));

              % heldoutLL is already mean LL per held-out trial
              deltaLLRecovery(generatingModel,repetition) = llTrue - llBestOther;
          end
      end

      % Summary statistics across independently simulated datasets
      deltaLLMean = mean(deltaLLRecovery,2,'omitnan');
      deltaLLSEM  = std(deltaLLRecovery,0,2,'omitnan') ./ sqrt(cfg.nRepeats);
      deltaLLCI95 = [deltaLLMean - 1.96*deltaLLSEM, deltaLLMean + 1.96*deltaLLSEM];

      % Probability that the true model beats every alternative
      recoveryRate = mean(deltaLLRecovery > 0,2,'omitnan');

      %% saving results
       save(resultsFile, 'packageSignature', 'exampleDatasets', 'cfg', 'WN', 'kernels', ...
        'heldoutLL', 'heldoutLLWithin', 'heldoutLLAcross', 'heldoutLLCombined',...
        'design','meanLL', 'relativeLL', 'relativeTotalLL', ...
        'recoveryProbability', 'recoveryProbabilityWithin', 'recoveryProbabilityAcross', 'recoveryProbabilityCombined',...
        'deltaLLRecovery', 'deltaLLMean', 'deltaLLSEM', 'deltaLLCI95', ...
        'recoveryRate', 'recoveredWithin', 'populationWithin', 'recoveredAcross', 'populationAcross', 'recoveredTeacherAcross', ...
        'populationTeacherAcross', 'persistentLatents', 'persistentBehavior', 'persistentWN25', 'referenceDesign', ...
        'modelNames', 'modelExpectedAccuracy', 'modelSampledAccuracy',...
        'sampledAccuracyByRepeat', 'expectedAccuracyByRepeat', 'noLCAccuracyByRepeat', 'lcAccuracyByRepeat', '-v7.3');

       fprintf('\nSaved behavioral simulation results.\n');
    end

end  % End the simulation branch; demo uses loaded results.

%% ================================= PLOTS  =================================


   %% ------------------------------ Plot Figure 2: Kernel Recovery------------------------------
   persistentColor = [161 120 36]/255;
   controllerColor = [102 45 145]/255;
   teachingColor   = [26 156 51]/255;
   modelColors                           = zeros(nModels,3);
   modelColors(stateModelIndex,:)        = persistentColor;
   modelColors(controllerModelIndices,:) = repmat(controllerColor, numel(controllerModelIndices), 1);
   modelColors(teachingModelIndex,:)     = teachingColor;

   figure('Position',[20 20 600 1200],"Color", "w", "Name", "Kernel recovery");
   tiledlayout(nModels, 2, "TileSpacing", "compact");

   for m = 1:nModels
       % Within-trial kernel
       nexttile;
       meanRecovered = mean(recoveredWithin(:,m,:), 3, "omitnan");
       meanRecoveredPlot = smoothdata(meanRecovered,"movmean",2);
       meanRecoveredPlot(1)   = meanRecovered(1);
       meanRecoveredPlot(end) = meanRecovered(end);
       meanPopulation = mean(populationWithin(:,m,:), 3, "omitnan");

       recoveredWithinCI  = 1.96*std(recoveredWithin(:,m,:), 0, 3, "omitnan") ./ sqrt(cfg.nRepeats);
       
       % [hRecovered, ~] = shadedError(cfg.wnTimeMs, meanRecovered, semRecovered, [0.15 0.45 0.80]); hold on;
       hRecovered = plot(cfg.wnTimeMs, meanRecoveredPlot, '-','color',[0.15 0.45 0.80], "LineWidth", 1); hold on;
       plot(cfg.wnTimeMs, meanRecoveredPlot+recoveredWithinCI, ':', cfg.wnTimeMs, meanRecoveredPlot-recoveredWithinCI, ':','color',[0.15 0.45 0.80], "LineWidth", 1); hold on;
       
       hPopulation = plot(cfg.wnTimeMs, meanPopulation, "--k", "LineWidth", 1);hold on;box off;
       set(gca,'ticklength',[0.025 0.025],'TickDir','out', 'xtick', [-400:200:400],'xlim',[-400 400])
       xline(0, ":k", "HandleVisibility", "off");
       xlabel("Time relative to sample onset (ms)"); ylabel("Recovered log-odds weight");
       title(modelNames(m) + ": current-trial recovery");
       if m ==1
          legend([hRecovered, hPopulation], {"Recovered GLM kernel", "Population GLM kernel"}, "Location", "best"); 
          ylim([-0.003 0.01]);
       else
           ylim([-0.007 0.02]);
       end

       % Across-trial kernel
       nexttile;
       if m == teachingModelIndex
         meanRecoveredC = mean(recoveredTeacherAcross(:,m,:), 3, "omitnan");
         meanRecoveredCPlot = smoothdata(meanRecoveredC,"movmean",1);
         meanRecoveredCPlot(1)   = meanRecoveredC(1);
         meanRecoveredCPlot(end) = meanRecoveredC(end);
         recoveredCCI = 1.96*std( recoveredTeacherAcross(:,m,:), 0, 3, "omitnan") ./ sqrt(cfg.nRepeats);
         
         % generatingAcross = kernels.across(:,m) .* referenceDesign.teacherAcrossRawSD(:);
         generatingAcross = mean(populationTeacherAcross(:,m,:), 3, "omitnan");
       else
         meanRecoveredC = mean(recoveredAcross(:,m,:), 3, "omitnan");
         meanRecoveredCPlot = smoothdata(meanRecoveredC,"movmean",2);
         meanRecoveredCPlot(1)   = meanRecoveredC(1);
         meanRecoveredCPlot(end) = meanRecoveredC(end);    
         recoveredCCI     = 1.96*std(recoveredAcross(:,m,:), 0, 3, "omitnan") ./ sqrt(cfg.nRepeats);
         
         % generatingAcross = kernels.across(:,m) .* referenceDesign.acrossRawSD(:);
         generatingAcross = mean(populationAcross(:,m,:), 3, "omitnan");
       end
       hGenerating = plot( 1:cfg.maxTrialLag, generatingAcross, "--k", "LineWidth", 1);hold on;box off;
       hRecoveredC = plot(trialLags, meanRecoveredCPlot, 'color', [0.80 0.30 0.20], "LineWidth", 1); 
       plot(trialLags, meanRecoveredCPlot+recoveredCCI, ':', trialLags, meanRecoveredCPlot-recoveredCCI, ':', 'color', [0.80 0.30 0.20], "LineWidth", 1);
       
       % [hRecovered, ~] = shadedError( trialLags, meanRecovered, semRecovered, [0.80 0.30 0.20]); 
       xlabel("Future trial lag"); ylabel("Recovered log-odds weight");
       title(modelNames(m) + ": cross-trial kernel");
       set(gca,'ticklength',[0.025 0.025],'TickDir','out', 'xtick',[0 5:5:20],'xlim',[0 20])
       if m==1
          legend([hRecoveredC, hGenerating], {"Recovered", "Generating"}, "Location", "best"); box off;
          ylim([-0.005 0.02]);
       end
       ylim([-0.005 0.02]);
   end

   if strcmp(mode, 'demo')
      out = [];
      return;
    end

   %% ---------------- LATENT-STATE READOUT REGRESSIONS ----------------
   if ~isempty(persistentLatents)
      z = persistentLatents.stateMean;
      valid = isfinite(z) & isfinite(persistentLatents.storedSampleFidelity) & isfinite(persistentLatents.stateCriterionShift) & isfinite(persistentLatents.stateLapseProb);
      z = z(valid);
      readoutMatrix = [ persistentLatents.storedSampleFidelity(valid), persistentLatents.stateCriterionShift(valid), persistentLatents.stateLapseProb(valid)];
      
      slopes = zeros(3,1);
      explainedVariance = zeros(3,1);

      for readoutIndex = 1:3
         Xstate = [ones(numel(z),1), z];
         betaState = Xstate \ readoutMatrix(:,readoutIndex);
         prediction = Xstate * betaState;
         residualSS = sum( (readoutMatrix(:,readoutIndex) - prediction).^2);
         totalSS = sum( (readoutMatrix(:,readoutIndex) - mean(readoutMatrix(:,readoutIndex))).^2);
         slopes(readoutIndex) = betaState(2);
         if totalSS < 1e-12
            explainedVariance(readoutIndex) = NaN;
         else
            explainedVariance(readoutIndex) = 1 - residualSS / totalSS;
         end
      end
   end
  
   if any(isnan(meanLL(:)))
      warning("NaN values found in model comparison.");
   end
   if any(mean(persistentBehavior) < [0.52, 0.52]) || mean(persistentBehavior) > 0.90
      warning("Simulated task performance may be too low or too high.");
    end

    %% ---------------- MANUSCRIPT RESULT SUMMARY ----------------
    controller100Index = controllerModelIndices(cfg.controlPeakCandidatesMs==100);
    reportModelIndices = [stateModelIndex controller100Index teachingModelIndex];
    
    recovery3Within    = zeros(3,3);
    recovery3Across    = zeros(3,3);
    recovery3Combined  = zeros(3,3);

    for gg = 1:3
        generatingModel = reportModelIndices(gg);
        for rr = 1:cfg.nRepeats
            [~,winner] = max(heldoutLLWithin(generatingModel,reportModelIndices,rr));
            recovery3Within(gg,winner) = recovery3Within(gg,winner) + 1;
            [~,winner] = max(heldoutLLAcross(generatingModel,reportModelIndices,rr));
            recovery3Across(gg,winner) = recovery3Across(gg,winner) + 1;
            [~,winner] = max(heldoutLLCombined(generatingModel,reportModelIndices,rr));
            recovery3Combined(gg,winner) = recovery3Combined(gg,winner) + 1;
        end
    end

    recovery3Within = recovery3Within ./ cfg.nRepeats;
    recovery3Across = recovery3Across ./ cfg.nRepeats;
    recovery3Combined = recovery3Combined ./ cfg.nRepeats;

    fprintf('\n============================================================\n');
    fprintf('SIMULATION RESULT SUMMARY\n');
    fprintf('============================================================\n');

    fprintf('\nNo-LC baseline versus LC-WN performance:\n');
    fprintf('Persistent state : no LC %.2f +/- %.2f%%; LC %.2f +/- %.2f%%\n',100*mean(noLCAccuracyByRepeat(stateModelIndex,:),'omitnan'),100*std(noLCAccuracyByRepeat(stateModelIndex,:),0,'omitnan')/sqrt(cfg.nRepeats),100*mean(lcAccuracyByRepeat(stateModelIndex,:),'omitnan'),100*std(lcAccuracyByRepeat(stateModelIndex,:),0,'omitnan')/sqrt(cfg.nRepeats));
    fprintf('Controller +100  : no LC %.2f +/- %.2f%%; LC %.2f +/- %.2f%%\n',100*mean(noLCAccuracyByRepeat(controller100Index,:),'omitnan'),100*std(noLCAccuracyByRepeat(controller100Index,:),0,'omitnan')/sqrt(cfg.nRepeats),100*mean(lcAccuracyByRepeat(controller100Index,:),'omitnan'),100*std(lcAccuracyByRepeat(controller100Index,:),0,'omitnan')/sqrt(cfg.nRepeats));
    fprintf('Teaching signal  : no LC %.2f +/- %.2f%%; LC %.2f +/- %.2f%%\n',100*mean(noLCAccuracyByRepeat(teachingModelIndex,:),'omitnan'),100*std(noLCAccuracyByRepeat(teachingModelIndex,:),0,'omitnan')/sqrt(cfg.nRepeats),100*mean(lcAccuracyByRepeat(teachingModelIndex,:),'omitnan'),100*std(lcAccuracyByRepeat(teachingModelIndex,:),0,'omitnan')/sqrt(cfg.nRepeats));

    fprintf('\nBehavioral performance, sampled %% correct:\n');
    fprintf('Persistent state : %.2f +/- %.2f %%\n',100*mean(sampledAccuracyByRepeat(stateModelIndex,:),'omitnan'),100*std(sampledAccuracyByRepeat(stateModelIndex,:),0,'omitnan')/sqrt(cfg.nRepeats));
    fprintf('Controller +100  : %.2f +/- %.2f %%\n',100*mean(sampledAccuracyByRepeat(controller100Index,:),'omitnan'),100*std(sampledAccuracyByRepeat(controller100Index,:),0,'omitnan')/sqrt(cfg.nRepeats));
    fprintf('Teaching signal  : %.2f +/- %.2f %%\n',100*mean(sampledAccuracyByRepeat(teachingModelIndex,:),'omitnan'),100*std(sampledAccuracyByRepeat(teachingModelIndex,:),0,'omitnan')/sqrt(cfg.nRepeats));

    fprintf('\nThree-model recovery: Persistent / Controller +100 ms / Teaching\n');
    fprintf('\nCurrent-trial recovery matrix:\n'); disp(recovery3Within);
    fprintf('\nCross-trial recovery matrix:\n'); disp(recovery3Across);
    fprintf('\nCombined recovery matrix:\n'); disp(recovery3Combined);

    fprintf('\nCorrect three-model recovery probability:\n');
    fprintf('                    Persistent   Controller   Teaching\n');
    fprintf('Current-trial    : %.3f        %.3f        %.3f\n',recovery3Within(1,1),recovery3Within(2,2),recovery3Within(3,3));
    fprintf('Cross-trial      : %.3f        %.3f        %.3f\n',recovery3Across(1,1),recovery3Across(2,2),recovery3Across(3,3));
    fprintf('Combined         : %.3f        %.3f        %.3f\n',recovery3Combined(1,1),recovery3Combined(2,2),recovery3Combined(3,3));


%% result stat summary   
% Numerical outputs, figures and summaries are saved separately from inputs.
assert(all(isfinite(recoveredWithin(:))) && all(isfinite(recoveredAcross(:))) && all(isfinite(recoveredTeacherAcross(:))), 'Nonfinite recovered coefficients.');
assert(all(isfinite(heldoutLL(:))) && all(isfinite(heldoutLLCombined(:))), 'Nonfinite held-out log likelihood.');
assert(all(abs(sum(recoveryProbability,2)-1)<1e-10), 'Recovery rows must sum to one.');
save(resultsFile, 'exampleStateTrial', 'exampleControllerTrial', 'exampleTeachingSequence', 'sharedExampleTrial', 'recovery3Within', 'recovery3Across', 'recovery3Combined', '-append');

if strcmp(mode,'full')
    % Small-demo uncertainty is wider than the original manuscript axes.
    demoFigures = findall(groot,'Type','figure','Name','Kernel recovery');
    demoFigures = demoFigures(~ismember(demoFigures,initialFigures));
    for k = 1:numel(demoFigures)
        set(findall(demoFigures(k),'Type','axes'),'YLimMode','auto');
    end
end

out = load(resultsFile);
fprintf('\nCompleted %s. Results: %s\n', mode, outputDir);
end


%% ============================ Helper functions ==========================

function kernels = deriveAlgorithmicPredictions(cfg)
    % Derive impulse-response predictions from the governing equations.
    % No Gaussian or exponential kernel is imposed directly.
    nModels = 2 + cfg.nControllerModels;
    stateModelIndex = 1;
    controllerModelIndices = 2:(1 + cfg.nControllerModels);
    teachingModelIndex = nModels;
    kernels.within = zeros(cfg.nWNTimeSamples, nModels);
    kernels.within25 = zeros(cfg.nWNStateBins, nModels);
    kernels.across = zeros(cfg.maxTrialLag, nModels);

    % Current-trial impulse responses
    for fineBin = 1:cfg.nWNTimeSamples
        impulseWN = zeros(1,cfg.nTimeSamples);
        impulseWN(fineBin) = 1;
        kernels.within(fineBin,stateModelIndex) = stateCurrentTrialImpulse(impulseWN, cfg);
        for candidateIndex = 1:cfg.nControllerModels
            modelIndex = controllerModelIndices(candidateIndex);
            candidatePeakMs = cfg.controlPeakCandidatesMs(candidateIndex);
            kernels.within(fineBin,modelIndex) = controllerCurrentTrialImpulse(impulseWN, candidatePeakMs, cfg);
        end
    end
 
    %% Derive predictions at the independently randomized 25-ms resolution
    % Each experimental predictor represents one complete 25-ms ON state,
    % not the average of five isolated 5-ms impulses.
    for wnBin = 1:cfg.nWNStateBins
        blockInput  = zeros(1, cfg.nTimeSamples);
        firstSample = (wnBin-1) * cfg.samplesPerWNState + 1;
        lastSample = wnBin * cfg.samplesPerWNState;
        blockInput(firstSample:lastSample) = 1;

        % Persistent operating-state model
        kernels.within25(wnBin, stateModelIndex) = stateCurrentTrialImpulse(blockInput, cfg);
        % Controller family
        for candidateIndex  = 1:cfg.nControllerModels
            modelIndex      = controllerModelIndices(candidateIndex);
            candidatePeakMs = cfg.controlPeakCandidatesMs(candidateIndex);
            kernels.within25(wnBin, modelIndex) = controllerCurrentTrialImpulse(blockInput, candidatePeakMs, cfg);
        end
        % Teaching has no current-trial effect
        kernels.within25(wnBin, teachingModelIndex) = 0;
    end

    % Cross-trial impulse responses   
    % Persistent-state cross-trial effects derived by simulation.
    % A single stimulation impulse perturbs the operating state. The resulting
    % state is carried into later trials and can affect multiple computations
    % on each future trial.
    kernels.across(:, stateModelIndex) = deriveStateCrossTrialImpulse(cfg);

    % Controller has no cross-trial carryover
    kernels.across(:, controllerModelIndices) = 0;

    % Teaching weight update: one positive prediction-error-gated stimulation impulse occurs on
    % trial zero; its effect appears first on trial one.
    weight = cfg.learningRate;
    for lag = 1:cfg.maxTrialLag
        kernels.across(lag, teachingModelIndex) = cfg.teacherBehaviorGain * weight;
        weight = cfg.weightRetention * weight;
    end
end

function effect = stateCurrentTrialImpulse(u, cfg)
% Current-trial causal effect of one WN perturbation, evaluated around the
% mean endogenous operating trajectory.

    nTime = numel(u);
    zWNTrace = zeros(nTime,1);
    backgroundTrace = zeros(nTime,1);
    zWN = 0;
    zExpectation = 0;
    for timeIndex = 1:nTime
        zExpectation = zExpectation + (cfg.dtMs / cfg.expectationDecayTauMs) .* ( -zExpectation + cfg.expectationStateGain .* cfg.temporalExpectation(timeIndex) );
        backgroundTrace(timeIndex) = zExpectation;
        tauWN = cfg.stateTauMinMs + (cfg.stateTauMaxMs-cfg.stateTauMinMs) .* logistic(cfg.stateTauSlope .* backgroundTrace(timeIndex));
        aWN = exp(-cfg.dtMs ./ tauWN);
        zWN = aWN .* zWN + cfg.stateInputGain .* u(timeIndex);
        zWNTrace(timeIndex) = zWN;
    end
    baselineState = backgroundTrace;
    perturbedState = backgroundTrace + zWNTrace;

    pBaselineMatch      = stateMatchToSampleProbability(baselineState, 0, false, cfg);
    pBaselineDifferent  = stateMatchToSampleProbability(baselineState, cfg.changeMagnitudeDeg, true, cfg);
    pPerturbedMatch     = stateMatchToSampleProbability(perturbedState, 0, false, cfg);
    pPerturbedDifferent = stateMatchToSampleProbability(perturbedState, cfg.changeMagnitudeDeg,true, cfg);
    pBaseline           = (1-cfg.pDifferent) * pBaselineMatch + cfg.pDifferent * pBaselineDifferent;
    pPerturbed          = (1-cfg.pDifferent) * pPerturbedMatch + cfg.pDifferent * pPerturbedDifferent;
    effect              = logitSafe(pPerturbed) - logitSafe(pBaseline);
end

function [pCorrect, components] = stateMatchToSampleProbability(zTrace, trueDifferenceDeg, isDifferent, cfg)
    % One persistent operating state modulates sample encoding, memory
    % maintenance, test encoding, decision criterion and report reliability.
    t = cfg.timeMs(:);

    %% Sample encoding
    sampleMask      = t >= cfg.sampleOnsetMs & t < cfg.sampleOffsetMs;
    sampleState     = mean(zTrace(sampleMask));
    sampleGainTrace = 1 + cfg.stateSampleGain .* zTrace;
    
    %% Delay-period memory maintenance
    delayMask = t >= cfg.delayOnsetMs & t < cfg.delayOffsetMs;
    
    % Latent-state modulation of delay-period retention
    memoryTauTrace = cfg.memoryDecayTauMs .* ones(size(zTrace));
    memoryTauTrace(delayMask) = cfg.memoryDecayTauMs .* exp(cfg.stateMemoryGain .* zTrace(delayMask));

    %% Test encoding
    testMask = t >= cfg.testOnsetMs & t < cfg.testOffsetMs;
    testState = mean(zTrace(testMask));
    testGainTrace = 1 + cfg.stateTestGain .* zTrace;
    
    %% Decision criterion
    decisionMask = t >= cfg.decisionEpochStartMs & t < cfg.decisionEpochEndMs;
    decisionState = mean(zTrace(decisionMask));
    criterionShiftDeg = cfg.stateCriterionGain * decisionState;

    %% Report reliability
    reportMask = t >= cfg.reportEpochStartMs & t < cfg.reportEpochEndMs;
    reportState = mean(zTrace(reportMask));
    lapseProbability = logistic(cfg.baselineLapseLogit + cfg.stateLapseGain * reportState);

    %% Baseline match-to-sample performance
    [pCorrect, components] = matchToSampleProbability(sampleGainTrace, memoryTauTrace, testGainTrace, criterionShiftDeg, lapseProbability, trueDifferenceDeg, isDifferent, cfg);

    components.sampleState       = sampleState;
    components.memoryTauTrace    = memoryTauTrace;
    components.testState         = testState;
    components.decisionState     = decisionState;
    components.reportState       = reportState;
    components.lapseProbability  = lapseProbability;
    components.criterionShift    = criterionShiftDeg;

end

function crossTrialEffect = deriveStateCrossTrialImpulse(cfg)
    % Behavioral effect of a one-unit raw WN-state predictor at +400 ms, after multiplication by cfg.stateWNWriteGain.
    % The WN innovation is written into a trial-level operating baseline.
    % That baseline is constant within each future trial and decays only
    % across trial boundaries.
    nLags = cfg.maxTrialLag;
    nTime = cfg.nTimeSamples;
    crossTrialEffect = zeros(nLags,1);
    referenceState = makeReferenceOperatingState(cfg);

    %% Baseline behavior
    pBaselineMatch = stateMatchToSampleProbability(referenceState, 0, false, cfg);
    pBaselineDifferent = stateMatchToSampleProbability(referenceState, cfg.changeMagnitudeDeg, true, cfg);
    pBaseline = (1-cfg.pDifferent) * pBaselineMatch + cfg.pDifferent * pBaselineDifferent;

    %% WN-induced operating state is written into the next trial baseline.   
    baselineShift = cfg.stateWNWriteGain;
    for lag = 1:nLags
        perturbedState        = referenceState + baselineShift * ones(nTime,1);
        pPerturbedMatch       = stateMatchToSampleProbability( perturbedState, 0, false, cfg);
        pPerturbedDifferent   = stateMatchToSampleProbability(perturbedState, cfg.changeMagnitudeDeg, true, cfg);
        pPerturbed            = (1-cfg.pDifferent) * pPerturbedMatch + cfg.pDifferent * pPerturbedDifferent;
        crossTrialEffect(lag) = logitSafe(pPerturbed) - logitSafe(pBaseline);
        baselineShift         = cfg.stateBaselineRetention * baselineShift;
    end
end

function effect = controllerCurrentTrialImpulse(u, candidatePeakMs, cfg)
    % Derive the current-trial behavioral consequence of one LC input under
    % the delayed match-to-sample controller model.

    aControl = exp(-cfg.dtMs / cfg.controlTauMs);
    nTime = numel(u);
    c = zeros(nTime,1);
    inputGate = makeControlGate(candidatePeakMs, cfg);
    for timeIndex = 1:nTime
        if timeIndex == 1
            previousControl = 0;
        else
            previousControl = c(timeIndex-1);
        end
        c(timeIndex) = aControl * previousControl + cfg.controlInputGain * u(timeIndex) * inputGate(timeIndex);
    end
    neutralGain = ones(cfg.nTimeSamples,1);
    controlGain = 1 + cfg.controlSensoryGain .* c;
    baselineMemoryTauTrace = cfg.memoryDecayTauMs .* ones(cfg.nTimeSamples,1);

    % Baseline match and nonmatch performance
    pBaseMatch = matchToSampleProbability(neutralGain, baselineMemoryTauTrace, neutralGain, 0, cfg.baselineLapseProb, 0, false, cfg);
    pBaseDifferent = matchToSampleProbability(neutralGain, baselineMemoryTauTrace, neutralGain, 0, cfg.baselineLapseProb, cfg.changeMagnitudeDeg, true, cfg);

    % Controller-modulated match and nonmatch performance
    pControlMatch = matchToSampleProbability(controlGain, baselineMemoryTauTrace, controlGain, 0, cfg.baselineLapseProb, 0, false, cfg);
    pControlDifferent = matchToSampleProbability(controlGain, baselineMemoryTauTrace, controlGain, 0, cfg.baselineLapseProb, cfg.changeMagnitudeDeg, true, cfg);

    % Average over the simulated trial-type distribution
    pBaseline = (1-cfg.pDifferent) * pBaseMatch + cfg.pDifferent * pBaseDifferent;
    pPerturbed = (1-cfg.pDifferent) * pControlMatch + cfg.pDifferent * pControlDifferent;
    effect = logitSafe(pPerturbed) - logitSafe(pBaseline);
end

function gate = makeControlGate(candidatePeakMs, cfg)
    % Defines an a priori computational epoch during which the controller can modulate task-relevant sensory processing.
    % The gate centers are specified before examining experimental kernels.
    t = cfg.timeMs(:);
    % Width of each candidate control epoch
    gateSigmaMs = 35;
    gate = exp(-0.5 * ((t - candidatePeakMs) / gateSigmaMs).^2);
    gate = gate ./ max(gate);
end

function [y, latent, pTrue] = simulateAlgorithmicBehavior(WN, WN25, delta, trueDifferenceDeg, isDifferent, modelNumber, cfg)    
    nTrials = size(WN,1);
    pTrue   = nan(nTrials,1);    
    eta     = zeros(nTrials,1);
    persistentOutcomesAlreadyGenerated = false;
    latent.stateAtSample = zeros(nTrials,1);
    latent.controlAtSample = zeros(nTrials,1);
    latent.teacherWeight = zeros(nTrials,1);

    stateModelIndex = 1;
    controllerModelIndices = 2:(1 + cfg.nControllerModels);
    teachingModelIndex = 2 + cfg.nControllerModels;
    baselineMemoryTauTrace = cfg.memoryDecayTauMs .* ones(cfg.nTimeSamples,1);

    if isfield(cfg,'performanceLogitShift')
       performanceLogitShift = cfg.performanceLogitShift;
    else
       performanceLogitShift = 0;
    end

    if modelNumber == stateModelIndex
       %% Persistent operating-state policy
       % z_n(t) = operatingBaseline_n
       %        + zWN_n(t)
       %        + zExpectation(t)
       %        + performanceContribution_n
       %        + zNoise_n(t)
       % operatingBaseline_n is constant within trial n and changes only across trial boundaries.

       nTime = size(WN,2);
       y = zeros(nTrials,1);

       % Precompute the WN-induced state at stimulation offset
       % ---------------------------------------------------------------
       wnStateAtOffset = zeros(nTrials,1);
       for trialIndex = 1:nTrials
           zWNtmp = 0;
           zExpectationTmp = 0;
           for timeIndex = 1:cfg.nWNTimeSamples
               % Reference background for the cross-trial WN predictor:
               % expectation is retained; stochastic noise and performance
               % history are held at their mean value of zero.
               zExpectationTmp = zExpectationTmp + (cfg.dtMs / cfg.expectationDecayTauMs) .* ( -zExpectationTmp + cfg.expectationStateGain .* cfg.temporalExpectation(timeIndex) );
               backgroundReference = zExpectationTmp;
               tauWN = cfg.stateTauMinMs + (cfg.stateTauMaxMs-cfg.stateTauMinMs) .* logistic(cfg.stateTauSlope .* backgroundReference);
               aWN = exp(-cfg.dtMs ./ tauWN);
               zWNtmp = aWN .* zWNtmp + cfg.stateInputGain .* WN(trialIndex,timeIndex);
           end
           wnStateAtOffset(trialIndex) = zWNtmp;
       end
       meanWNStateAtOffset = mean(wnStateAtOffset);

       % Initialize carried variables
       % ---------------------------------------------------------------
       operatingBaseline = 0;
       performanceMonitor = 0;

       % Allocate latent outputs
       % ---------------------------------------------------------------
       latent.stateAtSample = zeros(nTrials,1);
       latent.stateMean = zeros(nTrials,1);

       latent.operatingBaseline = zeros(nTrials,1);
       latent.performanceMonitor = zeros(nTrials,1);

       latent.stateWNAtOffsetRaw = zeros(nTrials,1);
       latent.stateWNInnovation = zeros(nTrials,1);

       latent.storedSampleFidelity = zeros(nTrials,1);
       latent.meanDelayMemoryTauMs = zeros(nTrials,1);
       latent.storedTestFidelity   = zeros(nTrials,1);
       % latent.finalComparisonFidelity = zeros(nTrials,1);
       latent.stateCriterionShift = zeros(nTrials,1);
       latent.stateLapseProb = zeros(nTrials,1);

       latent.stateTrajectory = cell(nTrials,1);
       latent.stateWNTrajectory = cell(nTrials,1);
       latent.stateExpectationTrajectory = cell(nTrials,1);
       latent.stateNoiseTrajectory = cell(nTrials,1);
       latent.stateTauTrajectory = cell(nTrials,1);
  
       % Simulate trials sequentially
       % ---------------------------------------------------------------
       for trial = 1:nTrials
           % This value is constant throughout the current trial.
           baselineThisTrial = operatingBaseline;

           % Performance history is also fixed during the current trial.
           performanceContribution = cfg.performanceStateGain * performanceMonitor;
           zWN          = 0;
           zExpectation = 0;
           zNoise       = 0;
           zWNTrace          = zeros(nTime,1);
           zExpectationTrace = zeros(nTime,1);
           zNoiseTrace       = zeros(nTime,1);
           tauWNTrialTrace   = zeros(nTime,1);
           zTrace            = zeros(nTime,1);

           for timeIndex = 1:nTime
               % Temporal-expectation contribution
               zExpectation = zExpectation + (cfg.dtMs / cfg.expectationDecayTauMs) .* ( -zExpectation + cfg.expectationStateGain .* cfg.temporalExpectation(timeIndex) );

               % Endogenous within-trial state fluctuation
               % Use the longest state timescale only for smoothing endogenous noise.
               noiseDecay = exp( -cfg.dtMs / cfg.stateTauMaxMs);
               zNoise = noiseDecay .* zNoise + cfg.stateNoiseSD .* randn;

               % Background operating state before the current WN update
               backgroundState = baselineThisTrial + performanceContribution + zExpectation + zNoise;

               % Background-state-dependent WN persistence
               tauWN = cfg.stateTauMinMs + (cfg.stateTauMaxMs-cfg.stateTauMinMs) .* logistic( cfg.stateTauSlope .* backgroundState);
               
               % Numerical protection
               tauWN = min( max(tauWN,cfg.stateTauMinMs), cfg.stateTauMaxMs);
               tauWNTrialTrace(timeIndex) = tauWN;
               
               aWN = exp(-cfg.dtMs ./ tauWN);

               % Physical WN perturbation
               zWN = aWN .* zWN + cfg.stateInputGain .* WN(trial,timeIndex);

               % Total operating state
               zTrace(timeIndex) = backgroundState + zWN;
               zWNTrace(timeIndex) = zWN;
               zExpectationTrace(timeIndex) = zExpectation;
               zNoiseTrace(timeIndex) = zNoise;  
            end

            % Generate behavioral probability
            [pCorrect, components] = stateMatchToSampleProbability( zTrace, trueDifferenceDeg(trial), isDifferent(trial), cfg);

            % Generate the current-trial outcome
            eta(trial) = logitSafe(pCorrect) + performanceLogitShift;
            pTrue(trial) = logistic(eta(trial));
            y(trial) = double(rand < pTrue(trial));

            % Store latent variables
            latent.stateAtSample(trial)      = zTrace(cfg.sampleOnsetIndex);
            latent.stateMean(trial)          = mean(zTrace);
            latent.operatingBaseline(trial)  = baselineThisTrial;
            latent.performanceMonitor(trial) = performanceMonitor;
            latent.stateWNAtOffsetRaw(trial) = wnStateAtOffset(trial);
            
            wnInnovation = wnStateAtOffset(trial) - meanWNStateAtOffset;
            latent.stateWNInnovation(trial)          = wnInnovation;
            
            latent.storedSampleFidelity(trial)       = components.storedSampleFidelity;
            latent.meanDelayMemoryTauMs(trial)       = components.meanDelayMemoryTauMs;
            latent.retainedSampleAtTestOnset(trial)  = components.retainedSampleAtTestOnset;
            latent.storedTestFidelity(trial)         = components.storedTestFidelity;
            % latent.finalComparisonFidelity(trial)    = components.finalComparisonFidelity;
            
            latent.stateCriterionShift(trial)        = components.criterionShift;
            latent.stateLapseProb(trial)             = components.lapseProbability;
            latent.stateTrajectory{trial}            = zTrace;
            latent.stateWNTrajectory{trial}          = zWNTrace;
            latent.stateExpectationTrajectory{trial} = zExpectationTrace;
            latent.stateNoiseTrajectory{trial}       = zNoiseTrace;
            latent.stateTauTrajectory{trial}         = tauWNTrialTrace;

            % Update variables for the next trial
            % -----------------------------------------------------------
            % WN changes the next trial's operating baseline. The carried value does not decay within the next trial.
            operatingBaseline = cfg.stateBaselineRetention * operatingBaseline + cfg.stateWNWriteGain .* wnInnovation + cfg.stateBaselineNoiseSD * randn;

            % Update recent performance only after the outcome is known.
            performanceMonitor = (1-cfg.performanceLearningRate) * performanceMonitor + cfg.performanceLearningRate * (2*y(trial)-1);    
       end
       persistentOutcomesAlreadyGenerated = true;

    elseif ismember(modelNumber, controllerModelIndices)
       % Task-computational controller family
       candidateIndex  = find(controllerModelIndices == modelNumber, 1);
       candidatePeakMs = cfg.controlPeakCandidatesMs(candidateIndex);
       aControl        = exp(-cfg.dtMs / cfg.controlTauMs);
       inputGate       = makeControlGate(candidatePeakMs, cfg);
       for trial = 1:nTrials
           c = zeros(size(WN,2),1);
           for timeIndex = 1:size(WN,2)
               if timeIndex == 1
                  previousControl = 0;
               else
                  previousControl = c(timeIndex-1);
               end
               c(timeIndex) = aControl * previousControl + cfg.controlInputGain * WN(trial,timeIndex) * inputGate(timeIndex);
           end
           controlGainTrace = 1 + cfg.controlSensoryGain .* c;
           [pCorrect, components] = matchToSampleProbability( ...
                                    controlGainTrace, ...       % sample gain
                                    baselineMemoryTauTrace, ... % fixed baseline memory decay
                                    controlGainTrace, ...       % test gain
                                    0, ...                      % no criterion shift
                                    cfg.baselineLapseProb, trueDifferenceDeg(trial), isDifferent(trial), cfg);

            latent.controlWeightedEvidence(trial) = components.effectiveDifferenceDeg;           
            eta(trial) = logitSafe(pCorrect) + performanceLogitShift;
        end

    elseif modelNumber == teachingModelIndex
        % Teaching algorithm
        weight = 0;
        trialDrive = mean(WN25,2); % raw nonnegative LC drive is kept in the main teaching generative model
        
        y = zeros(nTrials,1);
        for trial = 1:nTrials
           latent.teacherWeight(trial) = weight;
           neutralGainTrace = ones(cfg.nTimeSamples,1);
           pBase = matchToSampleProbability(neutralGainTrace, baselineMemoryTauTrace, neutralGainTrace, 0, cfg.baselineLapseProb, trueDifferenceDeg(trial), isDifferent(trial), cfg);          
           eta(trial) = logitSafe(pBase) + cfg.teacherBehaviorGain * weight + performanceLogitShift;
           pTrue(trial) = logistic(eta(trial));
           y(trial) = double(rand < pTrue(trial));
           deltaTrial = 2*y(trial) - 1;
           weight = cfg.weightRetention * weight + cfg.learningRate * deltaTrial * trialDrive(trial);

        end
        persistentOutcomesAlreadyGenerated = true;
     else
        error("Unknown generating model.");
     end
     if ~persistentOutcomesAlreadyGenerated
        pTrue = logistic(eta);
        y = double(rand(nTrials,1) < pTrue);
     end
end

function design = constructDesignMatrices(WN, delta, cfg)
    nTrials = size(WN,1);

    % Collapse the piecewise-constant 5-ms representation back to the
    % independently randomized 25-ms stimulation states.
    % Only the -400 to +400 ms interval contains randomized WN input
    WNactive = WN(:,1:cfg.nWNTimeSamples);
    WN25 = squeeze(mean(reshape(WNactive, nTrials, cfg.samplesPerWNState, cfg.nWNStateBins), 2));
    
    % Current-trial stimulation predictors
    design.withinRawSD = std(WN25,0,1);
    design.withinRawSD(design.withinRawSD < eps) = 1;
    design.within = zscoreSafe(WN25);

    % WN-induced operating-state component at stimulation offset.
    % Expectation, performance history and endogenous noise are deliberately
    % excluded because reverse correlation estimates the causal WN component.
    stateAtWNOffsetDrive = zeros(nTrials,1);
    for trial = 1:nTrials
        zWN = 0;
        zExpectation = 0;
        for timeIndex = 1:cfg.nWNTimeSamples
            zExpectation = zExpectation + (cfg.dtMs / cfg.expectationDecayTauMs) .* ( -zExpectation + cfg.expectationStateGain .* cfg.temporalExpectation(timeIndex) );
            tauWN = cfg.stateTauMinMs + (cfg.stateTauMaxMs-cfg.stateTauMinMs) .* logistic(cfg.stateTauSlope .* zExpectation);
            aWN = exp(-cfg.dtMs ./ tauWN);
            zWN = aWN .* zWN + cfg.stateInputGain .* WN(trial,timeIndex);
        end
        stateAtWNOffsetDrive(trial) = zWN;
    end
    stateAtWNOffsetDrive = stateAtWNOffsetDrive - mean(stateAtWNOffsetDrive);
      
    % Trial-level stimulation drive
    trialDrive = mean(WN25,2);
    trialDrive = zscoreSafe(trialDrive);

    % Plain stimulation-history predictors:
    % relevant for persistent-state carryover.
    design.across = zeros(nTrials, cfg.maxTrialLag);

    % Stimulation × feedback history:
    % required for a genuine teaching model.
    design.teacherAcross = zeros(nTrials, cfg.maxTrialLag);
    teachingDrive = trialDrive .* delta;
    for lag = 1:cfg.maxTrialLag
        design.across(1+lag:end,lag) = stateAtWNOffsetDrive(1:end-lag);
        design.teacherAcross(1+lag:end,lag) = teachingDrive(1:end-lag);
    end

    % Store raw predictor scales before standardization
    design.acrossRawSD = std(design.across, 0, 1);
    design.acrossRawSD(design.acrossRawSD < eps) = 1;

    design.teacherAcrossRawSD = std(design.teacherAcross, 0, 1);
    design.teacherAcrossRawSD(design.teacherAcrossRawSD < eps) = 1;

    % Standardize predictors used by the GLM
    design.across = zscoreSafe(design.across);
    design.teacherAcross = zscoreSafe(design.teacherAcross);
end

function X = makeAlgorithmicModelDesign( design, modelNumber, kernels, cfg)
    stateModelIndex = 1;
    controllerModelIndices = 2:(1 + cfg.nControllerModels);
    teachingModelIndex = 2 + cfg.nControllerModels;
    if modelNumber == stateModelIndex
        currentPredictor = design.within * kernels.within25(:, stateModelIndex);
        persistentPredictor = design.across * kernels.across(:, stateModelIndex);
        X = [currentPredictor, persistentPredictor];
    elseif ismember(modelNumber, controllerModelIndices)
        X = design.within * kernels.within25(:, modelNumber);
    elseif modelNumber == teachingModelIndex
        X = design.teacherAcross * kernels.across(:, teachingModelIndex);
    else
        error("Unknown fitted model.");
    end
    X = zscoreSafe(X);
end

function profile = makeStimulusEvidenceProfile(onsetMs, offsetMs, cfg)
    % Visual encoding rises after Gabor onset, remains available throughout
    % the stimulus, and decays only after stimulus offset.
    t = cfg.timeMs(:);
    profile = zeros(size(t));
    duringStimulus = t >= onsetMs & t < offsetMs;
    timeFromOnset = t(duringStimulus) - onsetMs;
    profile(duringStimulus) = 1 - exp(-timeFromOnset / cfg.sensoryRiseTauMs);
    afterOffset = t >= offsetMs;
    responseAtOffset = 1 - exp(-(offsetMs-onsetMs) / cfg.sensoryRiseTauMs);
    profile(afterOffset) = responseAtOffset .* exp(-(t(afterOffset)-offsetMs) / cfg.sensoryDecayTauMs);
    normalization = sum(profile) * cfg.dtMs;
    if normalization <= 0
        error('Stimulus evidence profile has zero integral.');
    end
    profile = profile / normalization;
end

function differenceDeg = orientationDifferenceDeg(angle1Deg, angle2Deg)
    % Signed circular difference for orientation, which is periodic over 180°.
    differenceDeg = 0.5 * atan2d( sind(2 * (angle1Deg-angle2Deg)), cosd(2 * (angle1Deg-angle2Deg)));
end

function beta = ridgeLogisticIRLS(X, y, lambda, cfg)
    X = [ones(size(X,1),1), X];
    nParameters = size(X,2);
    beta = zeros(nParameters,1);
    % Do not penalize the intercept
    penalty = eye(nParameters);
    penalty(1,1) = 0;

    for iteration = 1:cfg.maxIter
        eta = X * beta;
        p   = logistic(eta);
        weights = max(p .* (1-p), 1e-8);
        z = eta + (y-p) ./ weights;
        WX = X .* weights;
        hessian = X' * WX + lambda * penalty;
        gradientTarget = X' * (weights .* z);
        betaNew = hessian \ gradientTarget;
        if norm(betaNew-beta) < cfg.tolerance * (1 + norm(beta))
            beta = betaNew;
            return;
        end
        beta = betaNew;
    end
    warning("IRLS reached maximum iterations without full convergence.");
end

function Xz = zscoreSafe(X)
    mu = mean(X,1);
    sd = std(X,0,1);
    sd(sd < eps) = 1;
    Xz = (X - mu) ./ sd;
end

function p = logistic(x)
    % Numerically stable logistic transformation
    p = zeros(size(x));
    positive = x >= 0;
    p(positive) = 1 ./ (1 + exp(-x(positive)));
    expX = exp(x(~positive));
    p(~positive) = expX ./ (1 + expX);
    p = min(max(p, 1e-8), 1-1e-8);
end

function ll = meanBernoulliLogLikelihood(y, p)
    p = min(max(p, 1e-8), 1-1e-8);
    ll = mean(y .* log(p) + (1-y) .* log(1-p));
end

function [hMean, hPatch] = shadedError(x, meanY, semY, colorValue)
    x     = x(:);
    meanY = meanY(:);
    semY  = semY(:);
    hPatch = fill([x; flipud(x)], [meanY-semY; flipud(meanY+semY)], colorValue, "FaceAlpha", 0.20, "EdgeColor", "none", "HandleVisibility", "off");
    hold on;
    hMean = plot( x, meanY, "Color", colorValue, "LineWidth", 2);
end

function value = logitSafe(p)
    p = min(max(p,1e-8),1-1e-8);
    value = log(p ./ (1-p));
end

function expectation = makeTemporalExpectation(cfg)
   % Temporal expectation rises linearly from trial onset to sample onset,
   % reaches one at sample onset, and subsequently decays.
    t = cfg.timeMs(:);
    expectation = zeros(size(t));
    risingMask = t >= cfg.windowStartMs & t < cfg.sampleOnsetMs;
    expectation(risingMask) = (t(risingMask) - cfg.windowStartMs) ./ (cfg.sampleOnsetMs - cfg.windowStartMs);
    decayMask = t >= cfg.sampleOnsetMs;
    expectation(decayMask) = exp( -(t(decayMask)-cfg.sampleOnsetMs) ./ cfg.expectationDecayTauMs);
end

function referenceState = makeReferenceOperatingState(cfg)
   % Deterministic expectation-related background trajectory.
   % Performance, baseline drift and endogenous noise are set to zero.
    nTime = cfg.nTimeSamples;
    referenceState = zeros(nTime,1);
    zExpectation = 0;
    for timeIndex = 1:nTime
        zExpectation = zExpectation + (cfg.dtMs / cfg.expectationDecayTauMs) .* ( -zExpectation + cfg.expectationStateGain .* cfg.temporalExpectation(timeIndex) );
        referenceState(timeIndex) = zExpectation;
    end
end

function example = simulatePersistentStateExampleTrial(cfg, shared)
    % Simulate one illustrative persistent-state trial.
    % The example is evaluated around the deterministic reference
    % operating trajectory. Trial-level baseline fluctuations,
    % performance-history effects and endogenous state noise are set to
    % their expected value of zero. This function is for visualization
    % only and does not affect model recovery.

    t = cfg.timeMs(:);
    nTime = numel(t);

    %% 1. Shared experimental input and task condition
    WN25raw = shared.WN25raw;
    WNmodel = shared.WNmodel;
    example.sampleOrientationDeg = shared.sampleOrientationDeg;
    example.testOrientationDeg   = shared.testOrientationDeg;
    example.isDifferent          = shared.isDifferent;
    example.trueDifferenceDeg    = shared.trueDifferenceDeg;   

    %% 3. Persistent operating-state dynamics
    % The deterministic expectation-related background state determines
    % the effective persistence of the WN-induced perturbation.
    zExpectation = 0;
    zWN = 0;
    zExpectationTrace = zeros(nTime,1);
    zWNTrace          = zeros(nTime,1);
    tauWNTrace        = zeros(nTime,1);
    zTrace            = zeros(nTime,1);
    for timeIndex = 1:nTime
        % Expectation-related background state
        zExpectation = zExpectation + (cfg.dtMs / cfg.expectationDecayTauMs) .* ( -zExpectation + cfg.expectationStateGain .* cfg.temporalExpectation(timeIndex) );
        backgroundState = zExpectation;

        % Background-state-dependent persistence of the WN perturbation
        tauWN = cfg.stateTauMinMs + (cfg.stateTauMaxMs-cfg.stateTauMinMs) .* logistic( cfg.stateTauSlope .* backgroundState);
        tauWN = min( max(tauWN, cfg.stateTauMinMs), cfg.stateTauMaxMs);
        aWN = exp(-cfg.dtMs ./ tauWN);

        % Physical LC input: ON = 1, OFF = 0
        zWN = aWN .* zWN + cfg.stateInputGain .* WNmodel(timeIndex);

        % Total operating state
        zTrace(timeIndex) = backgroundState + zWN;
        zExpectationTrace(timeIndex) = zExpectation;
        zWNTrace(timeIndex) = zWN;
        tauWNTrace(timeIndex) = tauWN;
    end

    %% 4. Shared state readouts 
    sampleMask        = t >= cfg.sampleOnsetMs & t < cfg.sampleOffsetMs;
    delayMask         = t >= cfg.delayOnsetMs & t < cfg.delayOffsetMs;
    testMask          = t >= cfg.testOnsetMs & t < cfg.testOffsetMs;
    decisionMask      = t >= cfg.decisionEpochStartMs & t < cfg.decisionEpochEndMs;
    reportMask        = t >= cfg.reportEpochStartMs & t < cfg.reportEpochEndMs;
    sampleState       = mean(zTrace(sampleMask));
    delayState        = mean(zTrace(delayMask));
    testState         = mean(zTrace(testMask));
    decisionState     = mean(zTrace(decisionMask));
    reportState       = mean(zTrace(reportMask));    
    sampleGainTrace   = 1 + cfg.stateSampleGain .* zTrace;
    % Latent-state modulation of memory retention
    memoryTauTrace = cfg.memoryDecayTauMs .* ones(nTime,1);
    memoryTauTrace(delayMask) = cfg.memoryDecayTauMs .* exp(cfg.stateMemoryGain .* zTrace(delayMask));
    testGainTrace     = 1 + cfg.stateTestGain .* zTrace;
    criterionShiftDeg = cfg.stateCriterionGain * decisionState;
    lapseProbability  = logistic(cfg.baselineLapseLogit + cfg.stateLapseGain * reportState);

    %% 5. Shared encoding, memory, comparison, and decision computation
    [probabilityCorrect, decisionComponents] = matchToSampleProbability( sampleGainTrace, memoryTauTrace, testGainTrace, criterionShiftDeg, lapseProbability, example.trueDifferenceDeg, example.isDifferent, cfg);    
    criterionDeg                 =  decisionComponents.criterionDeg;
    sampledCorrect               =  shared.outcomeUniform < probabilityCorrect;

    %% 6. Time-resolved display-only traces
    decisionMask =  t >= cfg.decisionEpochStartMs  & t < cfg.decisionEpochEndMs;
    reportMask =  t >= cfg.reportEpochStartMs  & t < cfg.reportEpochEndMs;
    criterionTrace = nan(nTime,1);
    criterionTrace(decisionMask) = criterionDeg;
    lapseTrace = nan(nTime,1);
    lapseTrace(reportMask) = lapseProbability;

    %% 7. Store all variables for plotting 
    % Shared physical input
    example.WN25raw = shared.WN25raw;
    example.WNmodel = shared.WNmodel;
    example.nOnBins = shared.nOnBins;
    if isfield(shared, 'expectedOnBins')
       example.expectedOnBins = shared.expectedOnBins;
    else
       example.expectedOnBins = round(cfg.nWNStateBins .* cfg.pPulse);
    end

    % Shared task condition
    example.sampleOrientationDeg = shared.sampleOrientationDeg;
    example.testOrientationDeg   = shared.testOrientationDeg;
    example.trueDifferenceDeg    = shared.trueDifferenceDeg;
    example.isDifferent          = shared.isDifferent;
    example.memoryDecayTauMs     = shared.memoryDecayTauMs;

    % Persistent-state specific transformation
    example.zTrace            = zTrace;
    example.zExpectationTrace = zExpectationTrace;
    example.zWNTrace          = zWNTrace;
    example.tauWNTrace        = tauWNTrace;
    example.sampleState       = sampleState;
    example.delayState        = delayState;
    example.testState         = testState;
    example.decisionState     = decisionState;
    example.reportState       = reportState;

    example.sampleGainTrace      = sampleGainTrace;
    example.testGainTrace        = testGainTrace;
    example.memoryTauTrace       = memoryTauTrace;
    example.meanDelayMemoryTauMs = mean(memoryTauTrace(delayMask));
    example.criterionShiftDeg    = criterionShiftDeg;
    example.lapseProbability     = lapseProbability;

    % Shared downstream computation
    % encoding
    example.decisionComponents            = decisionComponents;
    example.baselineSampleEncoding        = decisionComponents.baselineSampleEncoding; 
    example.baselineTestEncoding          = decisionComponents.baselineTestEncoding;
    example.stateModulatedSampleEncoding  = decisionComponents.sampleEncoding;
    example.stateModulatedTestEncoding    =  decisionComponents.testEncoding;
    % memory trace
    example.baselineSampleMemoryTrace  = decisionComponents.baselineSampleMemoryTrace;
    example.baselineTestMemoryTrace    = decisionComponents.baselineTestMemoryTrace;
   
    example.sampleMemoryTrace             = decisionComponents.sampleMemoryTrace;
    example.testMemoryTrace               = decisionComponents.testMemoryTrace;
    % example.comparisonFidelityTrace       = decisionComponents.comparisonFidelityTrace;

    example.isDifferent                     = decisionComponents.isDifferent;
    example.trueDifferenceDeg               = decisionComponents.trueDifferenceDeg;
    example.criterionDeg                    = decisionComponents.criterionDeg;
    example.baselineDifferenceSignalDeg     = decisionComponents.baselineDifferenceSignalDeg;
    example.differenceSignalDeg             = decisionComponents.differenceSignalDeg;

    example.baselineDecisionVariableTrace   = decisionComponents.baselineDecisionVariableTrace;
    example.decisionVariableTrace           = decisionComponents.decisionVariableTrace;
    example.baselineStandardizedDecisionTrace      = decisionComponents.baselineStandardizedDecisionTrace;
    example.standardizedDecisionTrace              = decisionComponents.standardizedDecisionTrace;
    example.pReportDifferentTrace           = decisionComponents.pReportDifferentTrace;
    example.pReportSameTrace                = decisionComponents.pReportSameTrace;
    example.criterionTrace                  = criterionTrace;
    example.lapseTrace                      = lapseTrace;

    % Scalar summaries from the shared function
    example.sampleOffsetIndex  = decisionComponents.sampleOffsetIndex;
    example.testOnsetIndex     = decisionComponents.testOnsetIndex;
    example.testOffsetIndex    = decisionComponents.testOffsetIndex;
    example.finalDecisionIndex = decisionComponents.finalDecisionIndex;
    
    example.baselineStoredSampleFidelity = decisionComponents.baselineStoredSampleFidelity;
    example.baselineStoredTestFidelity   = decisionComponents.baselineStoredTestFidelity;   
    example.storedSampleFidelity         = decisionComponents.storedSampleFidelity;
    example.storedTestFidelity           = decisionComponents.storedTestFidelity;
    % example.finalComparisonFidelity      = decisionComponents.finalComparisonFidelity;

    example.sampleRelativeStrength          = decisionComponents.sampleRelativeStrength;
    example.testRelativeStrength            = decisionComponents.testRelativeStrength;
    example.effectiveComparisonNoiseTrace   = decisionComponents.effectiveComparisonNoiseTrace;
    example.pReportDifferentPerceptualTrace = decisionComponents.pReportDifferentPerceptualTrace;
    example.baselinePReportDifferentPerceptualTrace = decisionComponents.baselinePReportDifferentPerceptualTrace;
    
    example.effectiveDifferenceDeg              = decisionComponents.effectiveDifferenceDeg;
    example.baselinePReportDifferentPerceptual  = decisionComponents.baselinePReportDifferentPerceptual;
    example.pReportDifferentPerceptual          = decisionComponents.pReportDifferentPerceptual;
    example.baselinePReportDifferent           = decisionComponents.baselinePReportDifferent;
    example.pReportDifferent                    = decisionComponents.pReportDifferent;
    example.pReportSame                         = decisionComponents.pReportSame;
    example.probabilityCorrect = probabilityCorrect;
    example.baselinePCorrect   = decisionComponents.baselinePCorrect;
    example.pCorrect           = decisionComponents.pCorrect;
    example.baselinePError     = decisionComponents.baselinePError;
    example.pError             = decisionComponents.pError;
    example.pHit               = decisionComponents.pHit;
    example.pMiss              = decisionComponents.pMiss;
    example.pCorrectRejection  = decisionComponents.pCorrectRejection;
    example.pFalseAlarm        = decisionComponents.pFalseAlarm;
   
    % Sampled behavioral outcome
    example.sampledCorrect = sampledCorrect;
    
end

function plotPersistentStateExampleTrial(example, cfg)
   % Display the complete computational sequence for one representative
   % persistent-state delayed match-to-sample trial.

    t = cfg.timeMs(:);
    stateColor    = [161 120 36]/255;
    modColor      = [0.10 0.55 0.25];
    baselineColor = [0.55 0.55 0.55];
    sampleColor   = [0.15 0.45 0.80];
    testColor     = [0.85 0.30 0.10];
    noiseColor    = [0.55 0.20 0.65];
    epochColor    = [0.75 0.75 0.75];
    wnColor       = [237 177 32]/255;

    figure('Color', 'w', 'Position', [400 20 500 1400], 'Name', 'Figure 1A: persistent operating-state algorithm');
    tl = tiledlayout(14, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    %% Shared epoch formatting helper values
    epochColor = [0.75 0.75 0.75];

    %% 1. LC WN input 
    ax1 = nexttile(tl);
    stairs(t, example.WNmodel, 'Color', wnColor, 'LineWidth', 1); hold(ax1,'on');
    addExampleEpochLines(ax1,cfg,epochColor);
    xlim(ax1,[cfg.windowStartMs cfg.windowEndMs]);
    ylim(ax1,[-0.1 1.2]);
    yticks(ax1,[0 1]);
    yticklabels(ax1,{'OFF','ON'});
    ylabel(ax1,'LC WN');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    title(ax1,'1  Binary LC perturbation');
    box(ax1,'off');

    %% 2. Persistent operating state
    ax2 = nexttile(tl);
    plot(ax2,t,example.zExpectationTrace, '--', 'Color',baselineColor, 'LineWidth',1);hold(ax2,'on');
    plot(ax2,t,example.zTrace, 'Color',stateColor, 'LineWidth',1);
    yline(ax2,0,':k');
    addExampleEpochLines(ax2,cfg,epochColor);
    xlim(ax2,[cfg.windowStartMs cfg.windowEndMs]);
    ylabel(ax2,'z(t)');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    title(ax2,'2  Persistent operating state');
    legend(ax2, {'Reference state','WN-perturbed state'}, 'Box','off', 'Location','best');
    box(ax2,'off');

    %% 3. Shared-state modulation of sample, memory retention τM(t)
    ax3 = nexttile(tl);
    plot(ax3,t,example.sampleGainTrace, '-','Color',sampleColor, 'LineWidth',1);hold(ax3,'on');
    plot(ax3,t,example.testGainTrace, '-','Color',testColor, 'LineWidth',1);
    yline(ax3,1,':', 'Color',baselineColor);
    ylabel('Sensory gain');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    addExampleEpochLines(ax3,cfg,epochColor);
    xlim([cfg.windowStartMs cfg.windowEndMs]); %ylim([300 700])    
    title( '3  Shared-state modulation');
    legend( {'Sample gain','Test gain','Neutral'}, 'Location', 'best', 'Box', 'off');
    box(ax3,'off');
    
    %% 4. Encoded sample and test representations 
    ax4 = nexttile(tl);
    plot(ax4,t,example.baselineSampleEncoding, '--', 'Color',[0.55 0.68 0.85], 'LineWidth',1);hold(ax4,'on');
    plot(ax4,t,example.stateModulatedSampleEncoding, 'Color',sampleColor, 'LineWidth',1);
    plot(ax4,t,example.baselineTestEncoding, '--', 'Color',[0.90 0.68 0.55], 'LineWidth',1);
    plot(ax4,t,example.stateModulatedTestEncoding, 'Color',testColor, 'LineWidth',1);
    addExampleEpochLines(ax4,cfg,epochColor);
    xlim(ax4,[cfg.windowStartMs cfg.windowEndMs]);
    ylabel(ax4,'Response');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    title(ax4,'4  Stimulus-evoked sensory responses');
    legend(ax4, {'sample baseline','sample + state', 'test baseline','test + state'}, 'Box','off','Location','best');
    box(ax4,'off');

    %% 5. Memory retention time constant
    ax5 = nexttile(tl);
    plot(ax5,t, cfg.memoryDecayTauMs .* ones(size(t)), '--', 'Color',baselineColor, 'LineWidth',1); hold(ax5,'on');
    plot(ax5,t,example.memoryTauTrace, 'Color',modColor, 'LineWidth', 1);
    addExampleEpochLines(ax5,cfg,epochColor);
    xlim(ax5,[cfg.windowStartMs cfg.windowEndMs]);ylim([0 1000])    
    ylabel(ax5,'\tau_M (ms)');
    title(ax5,'5  State-dependent sample-memory retention');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    legend(ax5, {'Baseline','State-modulated'}, 'Box','off', 'Location','best');
    box(ax5,'off');

    %% 6. Stored sample and test representations
    ax6 = nexttile(tl);
    plot(ax6,t,example.baselineSampleMemoryTrace, '--', 'Color',[0.55 0.68 0.85], 'LineWidth',1);
    hold(ax6,'on');
    plot(ax6,t,example.sampleMemoryTrace, 'Color',sampleColor, 'LineWidth',1.9);
    plot(ax6,t,example.baselineTestMemoryTrace, '--', 'Color',[0.90 0.68 0.55],'LineWidth',1);
    plot(ax6,t,example.testMemoryTrace, 'Color',testColor, 'LineWidth',1.9);
    addExampleEpochLines(ax6,cfg,epochColor);
    xlim(ax6,[cfg.windowStartMs cfg.windowEndMs]);
    ylabel(ax6,'Representation');
    title(ax6,'6  Sample and test representations');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    legend(ax6, {'Sample baseline','Sample + state', 'Test baseline','Test + state'}, 'Box','off', 'Location','best');
    box(ax6,'off');

    %% 7. Comparison uncertainty
    ax7 = nexttile(tl);
    baselineNoise = cfg.decisionNoiseDeg .* ones(size(t));
    baselineNoise(t < cfg.testOnsetMs) = NaN;
    plot(ax7,t,baselineNoise, '--', 'Color',baselineColor, 'LineWidth',1); hold(ax7,'on');
    plot(ax7,t,example.effectiveComparisonNoiseTrace, 'Color',noiseColor, 'LineWidth',1);
    addExampleEpochLines(ax7,cfg,epochColor);
    xlim(ax7,[cfg.windowStartMs cfg.windowEndMs]);%ylim(ax7, [8 12])
    ylabel(ax7,'\sigma_{comparison} (deg)');
    title(ax7,'7  Representation-dependent comparison uncertainty');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    legend(ax7, {'Baseline uncertainty','State-modulated uncertainty'}, 'Box','off', 'Location','best');
    box(ax7,'off');

    %% 8. Criterion and lapse/readout reliability
    ax8 = nexttile(tl);
    yyaxis left;
    plot(ax8,t, example.criterionTrace, 'Color', [0.85 0.25 0.10], 'LineWidth', 1);
    ylabel(ax8,'Change criterion (deg)');ylim(ax8, [5 15])
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    yyaxis right;
    plot(ax8,t, example.lapseTrace, 'Color', [0.20 0.25 0.70], 'LineWidth', 1);
    ylabel(ax8,'Lapse probability');
    addExampleEpochLines(ax8,cfg,epochColor);
    xlim(ax8,[cfg.windowStartMs cfg.windowEndMs]); ylim(ax8, [-1 1])
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    title(ax8, ['8  The same latent state also modulates ', 'decision criterion and report reliability']);
    legend(ax8,{'Change criterion','Lapse probability'}, 'Location', 'best', 'Box', 'off');
    box(ax8, 'off');
 
    %% 9. Choice  probability
    ax9 = nexttile(tl);
    bar(ax9, 600, example.baselinePReportDifferentPerceptual, 25, 'FaceColor', 'none','EdgeColor', baselineColor); hold(ax9,'on');
    bar(ax9,625, example.pReportDifferentPerceptual, 25, 'FaceColor', 'none','EdgeColor', modColor);      
    bar(ax9,675, example.baselinePReportDifferent,  25, 'FaceColor', 'none', 'EdgeColor', baselineColor);
    bar(ax9,700, example.pReportDifferent,  25, 'FaceColor', 'none', 'EdgeColor', modColor);   
    yline(ax9, 0.5, ':k', 'Chance');
    xlim(ax9,[cfg.windowStartMs cfg.windowEndMs]);ylim(ax9, [0 1]);
    xticks(ax9, [625, 700]);
    xticklabels(ax9,{'perceptual','reported'});ylabel(ax9,'P(different)');
    xtickangle(ax9,15);
    title(ax9,'9  Perceptual probability of reporting "different"');
    legend(ax9, {'Baseline','State-modulated','',''}, 'Box','off', 'Location','best');
    box(ax9,'off');

    %% 10. WN-driven state at perturbation offset
    ax10 = nexttile(tl);
    plot(ax10, 1:example.crossTrial.nTrials, example.crossTrial.stateAtWNOffsetDrive, '-o','Color',stateColor,'MarkerFaceColor',stateColor,'LineWidth',1);
    yline(ax10,0,':k'); xlim(ax10, [0.5 example.crossTrial.nTrials+0.5]);
    ylabel(ax10,'s_n');
    title(ax10,'10  WN-driven state remaining at perturbation offset on each trial');
    set(ax10,'Color','none','TickDir','out','xtick',[1:example.crossTrial.nTrials]);
    box(ax10,'off');

    %% 11. Residual WN state written into next-trial operating baseline
    ax11 = nexttile(tl);
    bar(ax11,[0 1],[0 example.crossTrial.baselineNext],0.55,'FaceColor',stateColor);
    yline(ax11,0,':k');
    xlim(ax11,[-0.6 1.6]);
    xticks(ax11,[0 1]);
    xticklabels(ax11,{'b_n','b_{n+1}'});
    ylabel(ax11,'Operating baseline');
    title(ax11,sprintf('11  Residual state is written into next-trial baseline:  b_{n+1}=r_{state}b_n+g_{write}s_n'));
    set(ax11,'Color','none','TickDir','out');
    box(ax11,'off');

    %% 12. Baseline displacement retained across subsequent trials
    ax12 = nexttile(tl);
    futureLag = 1:cfg.maxTrialLag;
    plot(ax12,futureLag, example.crossTrial.baselineDisplacement,'-o','Color',stateColor,'MarkerFaceColor',stateColor,'LineWidth',1);
    yline(ax12,0,':k'); xlim(ax12, [0 cfg.maxTrialLag]);
    xlabel(ax12,'Future-trial lag'); ylabel(ax12,'\Delta b_{n+j}');
    title(ax12,'12  Baseline displacement persists across subsequent trials');
    set(ax12,'Color','none','TickDir','out', 'xtick', 1:cfg.maxTrialLag);
    box(ax12,'off');

    %% 13. Shifted baseline changes future behavioral probability
    ax13 = nexttile(tl);
    plot(ax13,futureLag,example.crossTrial.pBaseline.*ones(size(futureLag)),'--','Color',baselineColor,'LineWidth',1); hold(ax13,'on');
    plot(ax13,futureLag,example.crossTrial.pFuture,'-o','Color',stateColor,'MarkerFaceColor',stateColor,'LineWidth',1);
    xlabel(ax13,'Future-trial lag'); ylabel(ax13,'P(correct)');
    xlim(ax13, [0 cfg.maxTrialLag])
    title(ax13,'13  Shifted operating baseline alters future-trial performance');
    legend(ax13,{'Reference','After WN perturbation'},'Box','off','Location','best');
    set(ax13,'Color','none','TickDir','out', 'xtick', 1:cfg.maxTrialLag);
    box(ax13,'off');

    %% 14. Cross-trial GLM recovery
    ax14 = nexttile(tl);
    lags = 1:example.crossTrial.maxLag;
    exampleCurrentTrial = example.crossTrial.nTrials;
    historyValues = example.crossTrial.stateAtWNOffsetDrive(exampleCurrentTrial-lags);
    stem(ax14,lags,historyValues,'filled','Color',stateColor,'LineWidth',1,'MarkerSize',6); hold(ax14,'on');
    yline(ax14,0,':k');xlim(ax14, [0.5 example.crossTrial.nTrials+0.5])
    xlabel(ax14,'Previous-trial lag'); ylabel(ax14,'s_{n-k}');
    title(ax14,'14  History of residual states predicts current-trial behavior → cross-trial kernel');
    set(ax14,'Color','none','TickDir','out','xtick', 1:example.crossTrial.nTrials);
    box(ax14,'off');

    % Figure-wide task-epoch labels
    annotation( 'textbox', [0.13 1.0 0.75 0.03], 'String', ['Pre-sample |   ', 'Sample   |  ', 'Delay  |  ', 'Test  |   ', 'Decision'], 'HorizontalAlignment', 'center', 'EdgeColor', 'none');
end

function example = simulateControllerExampleTrial(cfg, controllerPeakMs, shared)
   % SIMULATECONTROLLEREXAMPLETRIAL
   %
   % Simulates one illustrative delayed match-to-sample trial under the online-controller model.
   %
   % The controller and persistent-state examples share:
   %   - the exact same binary WN realization;
   %   - sample and test evidence profiles;
   %   - sample and test orientations;
   %   - trial type and orientation difference;
   %   - leaky sample/test memory dynamics;
   %   - comparison rule;
   %   - decision criterion and decision noise;
   %   - baseline lapse probability;
   %   - sampled-outcome random number.
   %
   % The controller-specific transformation is:
   %
   %   gatedInput(t) = WN(t) .* gate(t)
   %
   %   c(t) = aControl*c(t-dt)  + controlInputGain*gatedInput(t)
   %
   %   gain(t) = 1 + controlSensoryGain*c(t)
   %
   % The controller changes the currently active sensory computation only.
   % It does not modify memory fidelity, decision criterion, lapse probability, or any cross-trial state.

    %% Validate inputs

    validateattributes( controllerPeakMs, {'numeric'}, {'scalar','real','finite'});
    validateattributes(shared, {'struct'}, {'scalar'});

    requiredSharedFields = { ...
        'WN25raw', ...
        'WNmodel', ...
        'nOnBins', ...
        'sampleOrientationDeg', ...
        'testOrientationDeg', ...
        'trueDifferenceDeg', ...
        'isDifferent', ...
        'memoryDecayTauMs', ...
        'outcomeUniform'};

    for fieldIndex = 1:numel(requiredSharedFields)
        assert(isfield(shared, requiredSharedFields{fieldIndex}), 'shared is missing required field "%s".', requiredSharedFields{fieldIndex});
    end

    t = cfg.timeMs(:);
    nTime = numel(t);

    %% 1. Shared physical input and task condition

    WN25raw = shared.WN25raw(:);
    WNmodel = shared.WNmodel(:);
    assert(numel(WNmodel) == nTime, 'shared.WNmodel must contain one value per cfg.timeMs sample.');
    sampleOrientationDeg = shared.sampleOrientationDeg;
    testOrientationDeg = shared.testOrientationDeg;
    trueDifferenceDeg = shared.trueDifferenceDeg;
    isDifferent = logical(shared.isDifferent);
    assert(shared.memoryDecayTauMs == cfg.memoryDecayTauMs, ['The shared example and cfg specify different ', 'memory-decay constants.']);

    %% 2. Controller eligibility gate

    inputGate = makeControlGate(controllerPeakMs, cfg);
    inputGate = inputGate(:);
    assert(numel(inputGate) == nTime, 'Controller gate must contain one value per cfg.timeMs sample.');

    %% 3. Controller dynamics

    aControl = exp(-cfg.dtMs ./ cfg.controlTauMs);
    gatedInput = WNmodel .* inputGate;
    controlState = zeros(nTime,1);
    previousControl = 0;

    for timeIndex = 1:nTime
        controlState(timeIndex) = aControl .* previousControl + cfg.controlInputGain .* gatedInput(timeIndex);
        previousControl = controlState(timeIndex);
    end

    %% 4. Controller-specific gain

    neutralGainTrace = ones(nTime,1);
    controlGainTrace = 1 + cfg.controlSensoryGain .* controlState;
    baselineMemoryTauTrace = cfg.memoryDecayTauMs .* ones(cfg.nTimeSamples,1);

    % Do not separately floor the gain here. matchToSampleProbability applies the common gain floor identically to every model.

    %% 5. Shared downstream computation: neutral baseline

    [pBaselineCorrect, baselineComponents] = matchToSampleProbability( ...
            neutralGainTrace, ...          % sample gain
            baselineMemoryTauTrace, ...    % memory decay unchanged
            neutralGainTrace, ...          % test gain
            0, ...                         % criterion shift unchanged
            cfg.baselineLapseProb, ...     % baseline lapse
            trueDifferenceDeg, isDifferent, cfg);

    %% 6. Shared downstream computation: controller condition

    [pControlledCorrect, controlledComponents] = matchToSampleProbability( ...
            controlGainTrace, ...          % controller-modulated sample
            baselineMemoryTauTrace, ...    % memory decay unchanged
            controlGainTrace, ...          % controller-modulated test
            0, ...                         % criterion shift unchanged
            cfg.baselineLapseProb, ...     % lapse unchanged
            trueDifferenceDeg, isDifferent, cfg);

    currentTrialLogOddsEffect = logitSafe(pControlledCorrect) - logitSafe(pBaselineCorrect);

    %% 7. Matched sampled outcomes

    outcomeUniform = shared.outcomeUniform;
    sampledBaselineCorrect = outcomeUniform < pBaselineCorrect;
    sampledControlledCorrect = outcomeUniform < pControlledCorrect;

    %% 8. Consistency checks
    % The neutral call must reproduce the completely unmodulated traces.

    numericalTolerance = 1e-12;
    assert(max(abs(baselineComponents.sampleEncoding - baselineComponents.baselineSampleEncoding)) < numericalTolerance, ['Neutral sample encoding does not match the fully ', 'unmodulated sample encoding.']);
    assert(max(abs(baselineComponents.testEncoding - baselineComponents.baselineTestEncoding)) < numericalTolerance, ['Neutral test encoding does not match the fully ', 'unmodulated test encoding.']);

    assert(max(abs(baselineComponents.sampleMemoryTrace - baselineComponents.baselineSampleMemoryTrace)) < numericalTolerance, ['Neutral sample-memory trace does not match the fully ', 'unmodulated sample-memory trace.']);
    assert(max(abs(baselineComponents.testMemoryTrace - baselineComponents.baselineTestMemoryTrace)) < numericalTolerance, ['Neutral test-memory trace does not match the fully ', 'unmodulated test-memory trace.']);

    % The fully unmodulated reference traces must be identical regardless
    % of whether they are returned by the baseline or controlled call.
    assert(max(abs(baselineComponents.baselineSampleMemoryTrace - controlledComponents.baselineSampleMemoryTrace)) < numericalTolerance, 'Baseline sample-memory references differ across calls.');
    assert(max(abs(baselineComponents.baselineTestMemoryTrace - controlledComponents.baselineTestMemoryTrace)) < numericalTolerance, 'Baseline test-memory references differ across calls.');

    %% 9. Store variables for plotting

    % Shared physical input
    example.WN25raw = shared.WN25raw;
    example.WNmodel = shared.WNmodel;
    example.nOnBins = shared.nOnBins;
    if isfield(shared, 'expectedOnBins')
        example.expectedOnBins = shared.expectedOnBins;
    else
        example.expectedOnBins = round(cfg.nWNStateBins .* cfg.pPulse);
    end

    % Shared task condition
    example.sampleOrientationDeg = sampleOrientationDeg;
    example.testOrientationDeg = testOrientationDeg;
    example.trueDifferenceDeg = trueDifferenceDeg;
    example.isDifferent = isDifferent;
    example.memoryDecayTauMs = cfg.memoryDecayTauMs;
    example.outcomeUniform = outcomeUniform;

    % Controller-specific transformation
    example.controllerPeakMs = controllerPeakMs;
    example.inputGate = inputGate;
    example.gatedInput = gatedInput;
    example.controlState = controlState;
    example.neutralGainTrace = neutralGainTrace;
    example.controlGainTrace = controlledComponents.sampleGainTrace;

    % Complete shared-computation structures
    example.baselineComponents = baselineComponents;
    example.controlledComponents = controlledComponents;

    % Evidence profiles
    example.sampleProfile = baselineComponents.baselineSampleEncoding;
    example.testProfile = baselineComponents.baselineTestEncoding;

    % Fully unmodulated sensory encodings
    example.baselineSampleEncoding = baselineComponents.baselineSampleEncoding;
    example.baselineTestEncoding = baselineComponents.baselineTestEncoding;

    % Controller-modulated sensory encodings
    example.controlledSampleEncoding = controlledComponents.sampleEncoding;
    example.controlledTestEncoding = controlledComponents.testEncoding;

    % Fully unmodulated sample/test memory traces
    example.baselineSampleMemoryTrace = baselineComponents.baselineSampleMemoryTrace;
    example.baselineTestMemoryTrace = baselineComponents.baselineTestMemoryTrace;

    % Controller-modulated memory traces
    example.controlledSampleMemoryTrace = controlledComponents.sampleMemoryTrace;
    example.controlledTestMemoryTrace = controlledComponents.testMemoryTrace;

    example.baselineEffectiveComparisonNoiseTrace = baselineComponents.effectiveComparisonNoiseTrace;
    example.controlledEffectiveComparisonNoiseTrace = controlledComponents.effectiveComparisonNoiseTrace;

    % Comparison-fidelity traces
    % example.baselineComparisonFidelityTrace = sqrt(max(example.baselineSampleMemoryTrace,0) .* max(example.baselineTestMemoryTrace,0));
    % example.controlledComparisonFidelityTrace = controlledComponents.comparisonFidelityTrace;

    % Difference signals
    example.baselineDifferenceSignalDeg = baselineComponents.differenceSignalDeg;
    example.controlledDifferenceSignalDeg = controlledComponents.differenceSignalDeg;

    % Decision-variable traces: not used anymore
    example.baselineDecisionVariableTrace = baselineComponents.decisionVariableTrace;
    example.controlledDecisionVariableTrace = controlledComponents.decisionVariableTrace;
    example.baselineStandardizedDecisionTrace = baselineComponents.baselineStandardizedDecisionTrace;
    example.controlledDecisionStandardizedTrace = controlledComponents.standardizedDecisionTrace;

    % Response-probability traces
    example.baselinePReportDifferentPerceptualTrace     = baselineComponents.pReportDifferentPerceptualTrace;
    example.controlledPReportDifferentPerceptualTrace   = controlledComponents.pReportDifferentPerceptualTrace;
    example.baselinePReportDifferentTrace               = baselineComponents.pReportDifferentTrace;
    example.controlledPReportDifferentTrace             = controlledComponents.pReportDifferentTrace;
    example.baselinePReportSameTrace                    = baselineComponents.pReportSameTrace;
    example.controlledPReportSameTrace                  = controlledComponents.pReportSameTrace;

    % Shared criterion and lapse
    example.criterionShiftDeg = 0;
    example.criterionDeg = controlledComponents.criterionDeg;
    example.lapseProbability = cfg.baselineLapseProb;

    % Indices
    example.sampleOffsetIndex = controlledComponents.sampleOffsetIndex;
    example.testOnsetIndex = controlledComponents.testOnsetIndex;
    example.testOffsetIndex = controlledComponents.testOffsetIndex;
    example.finalDecisionIndex = controlledComponents.finalDecisionIndex;

    % Scalar fidelity summaries
    example.baselineStoredSampleFidelity = baselineComponents.storedSampleFidelity;
    example.baselineStoredTestFidelity = baselineComponents.storedTestFidelity;
    example.controlledStoredSampleFidelity = controlledComponents.storedSampleFidelity;
    example.controlledStoredTestFidelity = controlledComponents.storedTestFidelity;
    % example.baselineFinalComparisonFidelity = baselineComponents.finalComparisonFidelity;
    % example.controlledFinalComparisonFidelity = controlledComponents.finalComparisonFidelity;
    example.baselineEffectiveDifferenceDeg = baselineComponents.effectiveDifferenceDeg;
    example.controlledEffectiveDifferenceDeg = controlledComponents.effectiveDifferenceDeg;

    % Final behavioral probabilities
    example.pBaselineCorrect = pBaselineCorrect;
    example.pControlledCorrect = pControlledCorrect;
    example.baselinePError = baselineComponents.pError;
    example.controlledPError = controlledComponents.pError;
    example.baselinePReportDifferentPerceptual = baselineComponents.pReportDifferentPerceptual;
    example.controlledPReportDifferentPerceptual = controlledComponents.pReportDifferentPerceptual;
    example.baselinePReportDifferent = baselineComponents.pReportDifferent;
    example.controlledPReportDifferent = controlledComponents.pReportDifferent;
    example.baselinePReportSame = baselineComponents.pReportSame;
    example.controlledPReportSame = controlledComponents.pReportSame;
    example.baselinePHit = baselineComponents.pHit;
    example.controlledPHit = controlledComponents.pHit;
    example.baselinePMiss = baselineComponents.pMiss;
    example.controlledPMiss = controlledComponents.pMiss;
    example.baselinePCorrectRejection = baselineComponents.pCorrectRejection;
    example.controlledPCorrectRejection = controlledComponents.pCorrectRejection;
    example.baselinePFalseAlarm = baselineComponents.pFalseAlarm;
    example.controlledPFalseAlarm = controlledComponents.pFalseAlarm;
    example.currentTrialLogOddsEffect = currentTrialLogOddsEffect;

    % Matched sampled outcomes
    example.sampledBaselineCorrect = sampledBaselineCorrect;
    example.sampledControlledCorrect = sampledControlledCorrect;

    % Compatibility aliases for older plotting code
    example.baselineSampleMemory = example.baselineSampleMemoryTrace;
    example.controlledSampleMemory = example.controlledSampleMemoryTrace;
    example.baselineTestMemory = example.baselineTestMemoryTrace;
    example.controlledTestMemory = example.controlledTestMemoryTrace;
    example.sampleAccumulationBaseline = example.baselineSampleMemoryTrace;
    example.sampleAccumulationControlled = example.controlledSampleMemoryTrace;
    example.testAccumulationBaseline = example.baselineTestMemoryTrace;
    example.testAccumulationControlled = example.controlledTestMemoryTrace;
end

function plotControllerExampleTrial(example, cfg)
    % PLOTCONTROLLEREXAMPLETRIAL
    %
    % Displays the complete computational sequence for one representative controller-model trial.
    %
    % Each panel has a nonredundant purpose:
    %   1. physical LC stimulation
    %   2. controller eligibility gate
    %   3. gated LC input
    %   4. transient controller state
    %   5. transient gain
    %   6. effect on the active sensory representation
    %   7. accumulated evidence
    %   8. behavioral consequence

    t = cfg.timeMs(:);

    controllerColor   = [230 102 102]/255;
    modColor          = [0.10 0.55 0.25];
    baselineColor     = [0.55 0.55 0.55];
    sampleColor       = [0.15 0.45 0.80];
    testColor         = [0.85 0.30 0.10];
    noiseColor        = [0.55 0.20 0.65];
    epochColor        = [0.75 0.75 0.75];
    wnColor           = [237 177 32]/255;

    figure('Color', 'w', 'Position', [800 20 500 1100], 'Name', sprintf('Figure 1B: controller algorithm (%+g ms)', example.controllerPeakMs));

    controllerLayout = tiledlayout(11, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    %% 1. Experimental WN states
    ax1 = nexttile(controllerLayout);
    stairs(ax1, cfg.wnTimeMs - cfg.wnStateBinMs/2, example.WN25raw, 'Color', wnColor, 'LineWidth', 1.8); hold(ax1, 'on');
    addExampleEpochLines(ax1, cfg, epochColor);
    xlim(ax1, [cfg.windowStartMs cfg.windowEndMs]); ylim(ax1, [-0.1 1.2]);
    yticks(ax1, [0 1]); yticklabels(ax1, {'OFF','ON'}); ylabel(ax1, 'LC WN');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    title(ax1, sprintf('1  Binary LC WN stimulation: %d/%d ON bins', example.nOnBins, cfg.nWNStateBins)); 
    box(ax1, 'off');

    %% 2. Eligibility gate
    ax2 = nexttile(controllerLayout);
    plot(ax2, t, example.inputGate, 'Color', controllerColor, 'LineWidth', 2.2); hold(ax2, 'on');
    addExampleEpochLines(ax2, cfg, epochColor);
    xline(ax2, example.controllerPeakMs, '--', sprintf('%+g ms', example.controllerPeakMs), 'Color', controllerColor, 'LabelVerticalAlignment', 'bottom');
    xlim(ax2, [cfg.windowStartMs cfg.windowEndMs]);ylim(ax2, [-0.05 1.10]);ylabel(ax2, 'Eligibility');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    title(ax2, '2  A priori temporal gate for the active computation');
    box(ax2, 'off');

    %% 3. Gated LC input
    ax3 = nexttile(controllerLayout);
    stairs(ax3, t, example.WNmodel, 'Color', wnColor, 'LineWidth', 1.0); hold(ax3, 'on');
    plot(ax3, t, example.gatedInput, 'Color', controllerColor, 'LineWidth', 2.0);
    addExampleEpochLines(ax3, cfg, epochColor);
    xlim(ax3, [cfg.windowStartMs cfg.windowEndMs]); ylabel(ax3, 'Input');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    title(ax3, '3  Only LC input overlapping the gate reaches the controller');
    legend(ax3, {'Physical WN input','Gate-weighted input'}, 'Box', 'off'); 
    box(ax3, 'off');

    %% 4. Controller state
    ax4 = nexttile(controllerLayout);
    plot( ax4, t, example.controlState, 'Color', controllerColor, 'LineWidth', 2.2); hold(ax4, 'on');
    addExampleEpochLines(ax4, cfg, epochColor);
    yline(ax4, 0, ':', 'Color', baselineColor);
    xlim(ax4, [cfg.windowStartMs cfg.windowEndMs]);
    ylabel(ax4, 'c(t)');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    title(ax4, '4  Transient online control state');
    box(ax4, 'off');

    %% 5. Sensory gain
    
    ax5 = nexttile(controllerLayout);
    plot(ax5,t,example.controlGainTrace, '-','Color',sampleColor, 'LineWidth',1.8);hold(ax5,'on');
    plot(ax5,t,example.neutralGainTrace, '-','Color',baselineColor, 'LineWidth',1.8);
    ylabel(ax5,'Response gain');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    addExampleEpochLines(ax5,cfg,epochColor);

    xlim(ax5,[cfg.windowStartMs cfg.windowEndMs]); %ylim([300 700])    
    title(ax5 ,'5  Gain');
    legend(ax5, {'Control gain','Neutral'}, 'Location', 'best', 'Box', 'off');
    box(ax5,'off');

    %% 6. Encoded sample and test representations
    ax6 = nexttile(controllerLayout);
    plot(ax6, t, example.baselineSampleEncoding, '--', 'Color', [0.45 0.65 0.85], 'LineWidth', 1.2);hold(ax6, 'on');
    plot(ax6, t, example.controlledSampleEncoding, 'Color', sampleColor, 'LineWidth', 2.0);
    plot(ax6, t, example.baselineTestEncoding, '--', 'Color', [0.90 0.65 0.45], 'LineWidth', 1.2);
    plot(ax6, t, example.controlledTestEncoding, 'Color', testColor, 'LineWidth', 2.0);
    addExampleEpochLines(ax6, cfg, epochColor);
    xlim(ax6, [cfg.windowStartMs cfg.windowEndMs]);ylabel(ax6, 'Response');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    title(ax6, '6  Selective modulation of sensory encoding');
    legend(ax6, {'Sample baseline', 'Sample controller-modulated', 'Test baseline', 'Test controller-modulated'}, 'Location', 'best', 'Box', 'off');
    box(ax6, 'off');

    %% 7. Sample/test representations
    
    ax7 = nexttile(controllerLayout);
    plot(ax7, t, example.baselineSampleMemoryTrace, '--', 'Color', [0.55 0.68 0.85], 'LineWidth', 1.2); hold(ax7, 'on');
    plot(ax7, t, example.controlledSampleMemoryTrace, 'Color', sampleColor, 'LineWidth', 2.0);
    plot( ax7, t, example.baselineTestMemoryTrace, '--', 'Color', [0.90 0.68 0.55], 'LineWidth', 1.2);
    plot(ax7, t, example.controlledTestMemoryTrace, 'Color', testColor, 'LineWidth', 2.0);
    addExampleEpochLines(ax7, cfg, epochColor);
    xlim(ax7, [cfg.windowStartMs cfg.windowEndMs]);
    ylabel(ax7, 'Representation');
    title(ax7, '7  Sample and test representations');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    legend(ax7, {'Sample baseline', 'Sample controller', 'Test baseline', 'Test controller'}, 'Location', 'best', 'Box', 'off');
    box(ax7, 'off');

    %% 8. Comparison uncertainty

    ax8 = nexttile(controllerLayout); 
    plot(ax8, t, example.baselineEffectiveComparisonNoiseTrace, '--', 'Color', baselineColor, 'LineWidth', 1); hold(ax8, 'on');
    plot(ax8, t, example.controlledEffectiveComparisonNoiseTrace, 'Color', noiseColor, 'LineWidth', 2.0);
    ylabel(ax8, '\sigma_{comparison} (deg)');
    addExampleEpochLines(ax8, cfg, epochColor);
    xlim(ax8, [cfg.windowStartMs cfg.windowEndMs]);
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    title(ax8, '8  Comparison uncertainty');
    legend(ax8, {'Baseline uncertainty','Controller-modulated uncertainty','',''}, 'Box','off', 'Location','best');
    box(ax8, 'off');

    %% 9. Choice probability

    ax9 = nexttile(controllerLayout);
    bar(ax9, 600, example.baselinePReportDifferentPerceptual, 25, 'FaceColor', 'none','EdgeColor', baselineColor); hold(ax9,'on');
    bar(ax9,625, example.controlledPReportDifferentPerceptual, 25, 'FaceColor', 'none','EdgeColor', modColor);      
    bar(ax9,675, example.baselinePReportDifferent,  25, 'FaceColor', 'none', 'EdgeColor', baselineColor);
    bar(ax9,700, example.controlledPReportDifferent,  25, 'FaceColor', 'none', 'EdgeColor', modColor);   
    yline(ax9, 0.5, ':k', 'Chance');
    xlim(ax9,[cfg.windowStartMs cfg.windowEndMs]);ylim(ax9, [0 1]);
    xticks(ax9, [625, 700]);
    xticklabels(ax9,{'perceptual','reported'});ylabel(ax9,'P(different)');
    xtickangle(ax9,15);
    title(ax9,'9  Perceptual probability of reporting "different"');
    legend(ax9, {'Baseline','State-modulated','',''}, 'Box','off', 'Location','best');
    box(ax9,'off');

    %% 10. Cross-trial component: no carryover

    ax10 = nexttile(controllerLayout);
    trialLag = 1:cfg.maxTrialLag;
    crossTrialController = zeros(size(trialLag));
    plot(ax10, trialLag, crossTrialController, '-o', 'Color', controllerColor, 'LineWidth', 1, 'MarkerSize', 6);
    xlim(ax10, [0 cfg.maxTrialLag]);ylim(ax10, [-0.05 0.05]);
    xlabel(ax10, 'Future trial lag');ylabel(ax10, '\Delta controller, c(t)');
    title(ax10, '10  No cross-trial carryover');
    yline(ax10, 0, ':k');
    set(ax10, 'Color','none', 'TickLength',[0.0125 0.0125], 'TickDir','out','xtick',1:cfg.maxTrialLag);
    box(ax10,'off');

    %% 11. Cross-trial probability of correct performance

    ax11 = nexttile(controllerLayout);
    plot(ax11, trialLag, example.pBaselineCorrect.*ones(size(trialLag)),'--','Color',baselineColor,'LineWidth',1.5); hold(ax11,'on');
    plot(ax11, trialLag, example.pBaselineCorrect,'-o','Color',controllerColor,'MarkerFaceColor',controllerColor,'MarkerSize',6,'LineWidth',1);
    xlim(ax11,[0 cfg.maxTrialLag]); ylim(ax11,[0.75 0.8]);
    xlabel(ax11,'Future trial lag'); ylabel(ax11,'P_{n+j}(correct)');
    title(ax11,'11  Controller has no effect on subsequent trials performance');
    set(ax11,'Color','none','TickLength',[0.0125 0.0125],'TickDir','out','xtick',1:cfg.maxTrialLag);
    box(ax11,'off');
   
    %% Global formatting
    title(controllerLayout, sprintf('Controller model: example trial with gate centered at %+g ms', example.controllerPeakMs), 'FontWeight', 'normal', 'FontSize', 10);
    allAxes = findall(ancestor(ax1, 'figure'), 'Type', 'axes');
    set(allAxes, 'FontName', 'Arial', 'FontSize', 8, 'LineWidth', 0.8, 'TickDir', 'out');
end

function example = simulateTeachingExampleSequence( cfg, nExampleTrials, highlightedTrial)
    % SIMULATETEACHINGEXAMPLESEQUENCE
    % Generates a short illustrative sequence under the teaching-model equations.
    % Shared within-trial computation: pBase(n) = matchToSampleProbability(...)
    % Teaching-model readout:etaTeaching(n) = logit(pBase(n)) + teacherBehaviorGain*w(n)
    %   pTeaching(n) = logistic(etaTeaching(n))
    % Post-trial update: w(n+1) = weightRetention*w(n) + learningRate*delta(n)*trialDrive(n)
    % The weight used on trial n is therefore the pre-update value w(n).
    % LC stimulation and feedback on trial n affect behavior beginning on trial n+1, not the current trial.
    % This illustrative function does not affect model fitting or recovery.

    %% Validate inputs

    validateattributes(nExampleTrials, {'numeric'}, {'scalar','integer','>=',3});
    validateattributes(highlightedTrial, {'numeric'}, {'scalar','integer','>=',1,'<=',nExampleTrials});
    requiredCfgFields = { ...
        'randomSeed', ...
        'nWNStateBins', ...
        'pPulse', ...
        'pPositiveFeedback', ...
        'changeMagnitudeDeg', ...
        'nTimeSamples', ...
        'nWNTimeSamples', ...
        'samplesPerWNState', ...
        'baselineLapseProb', ...
        'weightRetention', ...
        'learningRate', ...
        'teacherBehaviorGain', ...
        'reportEpochStartMs', ...
        'timeMs'};

    for fieldIndex = 1:numel(requiredCfgFields)
        assert(isfield(cfg, requiredCfgFields{fieldIndex}), 'cfg is missing required field "%s".', requiredCfgFields{fieldIndex});
    end
    assert(cfg.nWNTimeSamples <= cfg.nTimeSamples, 'cfg.nWNTimeSamples cannot exceed cfg.nTimeSamples.');
    assert(numel(cfg.timeMs) == cfg.nTimeSamples, 'cfg.timeMs must contain cfg.nTimeSamples values.');

    %% Use a local random stream without changing the global RNG
    localStream = RandStream('mt19937ar', 'Seed', cfg.randomSeed + 1004); %1001

    %% 1. Trial-wise binary LC WN stimulation
    WN25 = double(rand(localStream, nExampleTrials, cfg.nWNStateBins) < cfg.pPulse);
    trialDriveRaw = mean(WN25, 2);
    trialDrive = trialDriveRaw; %zscoreSafe(trialDriveRaw);


    %% 3. Shared delayed match-to-sample conditions
    % All illustrative trials use the same nonmatch condition so that changes in P(correct) arise from the teaching weight rather than changes in stimulus condition.
   
    isDifferent       = true(nExampleTrials,1);
    trueDifferenceDeg = cfg.changeMagnitudeDeg .* ones(nExampleTrials,1);
    neutralGainTrace  = ones(cfg.nTimeSamples,1);

    %% 4. Exact across-trial teaching recurrence
    
    teacherWeightBefore = zeros(nExampleTrials,1);
    teacherWeightAfter = zeros(nExampleTrials,1);
    pBase = zeros(nExampleTrials,1);
    pTeaching = zeros(nExampleTrials,1);
    etaBase = zeros(nExampleTrials,1);
    etaTeaching = zeros(nExampleTrials,1);
    teachingLogOddsOffset = zeros(nExampleTrials,1);

    % Store the complete shared-computation output for each trial.
    baseComponents = cell(nExampleTrials,1);
    baselineMemoryTauTrace = cfg.memoryDecayTauMs .* ones(cfg.nTimeSamples,1);

    % Common random numbers used to sample the behavioral outcome on each trial
    outcomeUniform = rand(localStream, nExampleTrials, 1);
    delta = zeros(nExampleTrials,1);
    signedTeachingDrive = zeros(nExampleTrials,1);
    sampledBaseCorrect = zeros(nExampleTrials,1);
    sampledTeachingCorrect = zeros(nExampleTrials,1);
    weight = 0;

    for trialIndex = 1:nExampleTrials
        % The current trial uses the pre-update weight.
        teacherWeightBefore(trialIndex) = weight;
        [pBase(trialIndex), baseComponents{trialIndex}] = matchToSampleProbability( ...
                neutralGainTrace, ...                 % neutral sample gain
                baselineMemoryTauTrace, ...           % neutral memory
                neutralGainTrace, ...                 % neutral test gain
                0, ...                                % no criterion shift
                cfg.baselineLapseProb, ...            % baseline lapse
                trueDifferenceDeg(trialIndex), isDifferent(trialIndex), cfg);

        etaBase(trialIndex) = logitSafe(pBase(trialIndex));
        teachingLogOddsOffset(trialIndex) = cfg.teacherBehaviorGain .* teacherWeightBefore(trialIndex);
        etaTeaching(trialIndex) = etaBase(trialIndex) + teachingLogOddsOffset(trialIndex);
        pTeaching(trialIndex) = logistic(etaTeaching(trialIndex));
        pTeaching(trialIndex) = min(max(pTeaching(trialIndex), 1e-8), 1-1e-8);

        % Sample baseline and teaching-model outcomes using the same random draw
        sampledBaseCorrect(trialIndex) = outcomeUniform(trialIndex) < pBase(trialIndex);
        sampledTeachingCorrect(trialIndex) = outcomeUniform(trialIndex) < pTeaching(trialIndex);

        % Signed outcome feedback: correct = +1, incorrect = -1
        delta(trialIndex) = 2 .* sampledTeachingCorrect(trialIndex) - 1;

        % LC-dependent teaching signal
        signedTeachingDrive(trialIndex) = delta(trialIndex) .* trialDrive(trialIndex);

        % The update occurs after the current trial.
        weight = cfg.weightRetention .* weight + cfg.learningRate .* signedTeachingDrive(trialIndex);
        teacherWeightAfter(trialIndex) = weight;
    end


    %% 6. WN trace for the highlighted update trial

    % Select a naturally occurring positive teaching event for illustration.
    % Exclude the last trial because its consequence should be visible on n+1.
    candidateDrive = signedTeachingDrive(1:end-1);
    positiveCandidates = find(candidateDrive > 0);
    if ~isempty(positiveCandidates)
      [~, localIndex] = max(candidateDrive(positiveCandidates));
      highlightedTrial = positiveCandidates(localIndex);
    else
      % Fallback: choose the largest-magnitude naturally occurring update.
      [~, highlightedTrial] = max(abs(candidateDrive));
    end


    WN25Highlighted = WN25(highlightedTrial,:);
    WNactiveHighlighted = repelem(WN25Highlighted, cfg.samplesPerWNState);
    assert(numel(WNactiveHighlighted) == cfg.nWNTimeSamples, ['The repeated WN sequence does not match ', 'cfg.nWNTimeSamples.']);
    nPostWNSamples = cfg.nTimeSamples - cfg.nWNTimeSamples;
    WNmodelHighlighted = [WNactiveHighlighted, zeros(1,nPostWNSamples)]';

    %% 7. Feedback-locked teaching impulse for visualization

    teachingImpulse = zeros(cfg.nTimeSamples,1);
    feedbackTimeMs = cfg.reportEpochStartMs;
    feedbackIndex = find(cfg.timeMs(:) >= feedbackTimeMs, 1, 'first');
    assert(~isempty(feedbackIndex), 'cfg.reportEpochStartMs lies outside cfg.timeMs.');
    teachingImpulse(feedbackIndex) = signedTeachingDrive(highlightedTrial);

    %% 8. Verification of causal ordering

    assert(teacherWeightBefore(highlightedTrial) ~= teacherWeightAfter(highlightedTrial) || signedTeachingDrive(highlightedTrial) == 0, 'Highlighted trial did not produce the expected weight update.');

    if highlightedTrial < nExampleTrials
        expectedNextWeight = teacherWeightAfter(highlightedTrial);
        assert(abs(teacherWeightBefore(highlightedTrial+1) - expectedNextWeight) < 1e-12, ['The post-trial update was not carried into ', 'the next trial correctly.']);
    end

    futureLag = (1:cfg.maxTrialLag)';
    teachingWeightImpulse = cfg.learningRate*signedTeachingDrive(highlightedTrial);
    teachingWeightAcross = teachingWeightImpulse.*cfg.weightRetention.^(futureLag-1);
    pReferenceAcross = mean(pBase,'omitnan');
    etaReferenceAcross = log(pReferenceAcross/(1-pReferenceAcross));
    pTeachingAcross = 1./(1+exp(-(etaReferenceAcross+cfg.teacherBehaviorGain.*teachingWeightAcross)));

    %% 9. Output

    example.nTrials = nExampleTrials;
    example.highlightedTrial = highlightedTrial;

    % Trial-wise physical stimulation
    example.WN25 = WN25;
    example.WN25Highlighted = WN25Highlighted;
    example.WNmodelHighlighted = WNmodelHighlighted;

    % Teaching inputs
    example.trialDriveRaw = trialDriveRaw;
    example.trialDrive = trialDrive;
    example.delta = delta;
    example.signedTeachingDrive = signedTeachingDrive;

    % Shared task conditions
    example.isDifferent = isDifferent;
    example.trueDifferenceDeg = trueDifferenceDeg;
    example.neutralGainTrace = neutralGainTrace;

    % Shared perceptual computation
    example.baseComponents = baseComponents;
    example.highlightedBaseComponents = baseComponents{highlightedTrial};
    example.pBase = pBase;
    example.etaBase = etaBase;

    % Teaching-model quantities
    example.teacherWeightBefore = teacherWeightBefore;
    example.teacherWeightAfter = teacherWeightAfter;
    example.teachingLogOddsOffset = teachingLogOddsOffset;
    example.etaTeaching = etaTeaching;
    example.pTeaching = pTeaching;

    % Matched behavioral samples
    example.outcomeUniform = outcomeUniform;
    example.sampledBaseCorrect = sampledBaseCorrect;
    example.sampledTeachingCorrect = sampledTeachingCorrect;

    % Compatibility alias for older plotting code
    example.sampledCorrect = sampledTeachingCorrect;

    % Highlighted trial
    example.teachingImpulse = teachingImpulse;
    example.feedbackTimeMs = feedbackTimeMs;
    example.feedbackIndex = feedbackIndex;
    example.highlightedWeightBefore = teacherWeightBefore(highlightedTrial);
    example.highlightedWeightAfter = teacherWeightAfter(highlightedTrial);
    example.highlightedDrive = signedTeachingDrive(highlightedTrial);
    example.highlightedPBase = pBase(highlightedTrial);
    example.highlightedPTeaching = pTeaching(highlightedTrial);
    if highlightedTrial < nExampleTrials
        example.firstAffectedTrial = highlightedTrial + 1;
    else
        example.firstAffectedTrial = NaN;
    end

    example.futureLag = futureLag;
    example.teachingWeightImpulse = teachingWeightImpulse;
    example.teachingWeightAcross = teachingWeightAcross;
    example.pReferenceAcross = pReferenceAcross;
    example.pTeachingAcross = pTeachingAcross;
end

function plotTeachingExampleSequence(example, cfg)
    % PLOTTEACHINGEXAMPLESEQUENCE
    %
    % Displays the teaching-model causal sequence:
    %
    %   LC drive on trial n
    %       x signed feedback
    %       -> post-trial teaching update
    %       -> policy weight on trial n+1
    %       -> future-trial behavioral log-odds offset
    %
    % The shared within-trial perceptual computation remains neutral.

    %% Setup

    t = cfg.timeMs(:);
    trialNumber = (1:example.nTrials)';
    teachingColor = [26 156 51]/255;
    highlightedColor = [1.00 0.55 0.10];
    weightColor = [170 170 255]/255;
    baselineColor = [0.55 0.55 0.55];
    probabilityColor = [26 156 51]/255;
    epochColor        = [0.75 0.75 0.75];
    wnColor = [237 177 32]/255;

    highlightedTrial = example.highlightedTrial;
    figure('Color', 'w', 'Position', [1200 20 500 900], 'Name', 'Figure 1C: teaching-signal algorithm');
    teachingLayout = tiledlayout(9, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    %% 1. LC WN stimulation on highlighted trial

    ax1 = nexttile(teachingLayout);
    stairs(ax1, cfg.wnTimeMs- cfg.wnStateBinMs/2, example.WN25Highlighted, 'Color', wnColor, 'LineWidth', 1);
    hold(ax1, 'on');
    addExampleEpochLines(ax1, cfg, epochColor);
    xlim(ax1, [cfg.windowStartMs cfg.windowEndMs]);ylim(ax1, [-0.1 1.2]);
    yticks(ax1, [0 1]);yticklabels(ax1, {'OFF','ON'});
    ylabel(ax1, 'LC WN');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    title(ax1, sprintf('1  LC WN stimulation on update trial# %d', highlightedTrial));
    box(ax1, 'off');

    %% 2. Trial-level LC drive and feedback

    ax2 = nexttile(teachingLayout);
    yyaxis(ax2, 'left');
    stem(ax2, trialNumber, example.trialDrive, 'filled', 'Color', [0.25 0.45 0.75], 'MarkerFaceColor', [56 105 26]/255, 'LineWidth', 1);
    ylabel(ax2, 'standardized LC drive, u_n');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    
    yyaxis(ax2, 'right');
    stairs(ax2, trialNumber, example.delta, 'Color', teachingColor, 'LineWidth', 1); hold(ax2, 'on');
    ylabel(ax2, 'Feedback, \delta_n');   
    xline(ax2, highlightedTrial, ':k', 'Update trial');
    xlim(ax2, [0.5 example.nTrials+0.5]);
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out','xtick',[1:example.nTrials])
    title(ax2, ['2  Teaching drive combines trial-level LC input ', 'with signed feedback']);
    box(ax2, 'off');

    %% 3. Signed teaching drive

    ax3 = nexttile(teachingLayout);
    barHandle = bar(ax3, trialNumber, example.signedTeachingDrive, 0.65, 'FaceColor', 'flat', 'EdgeColor', 'none');
    barHandle.CData = repmat(teachingColor, example.nTrials, 1);
    barHandle.CData(highlightedTrial,:) = highlightedColor; hold(ax3, 'on');

    xline(ax3, highlightedTrial, ':k');yline(ax3, 0, '-', 'Color', baselineColor);
    xlim(ax3, [0.5 example.nTrials+0.5]);
    ylabel(ax3, '\delta_n u_n');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    title(ax3, '3  LC x feedback teaching on each trial');
    box(ax3, 'off');

    %% 4. Feedback-locked teaching event

    ax4 = nexttile(teachingLayout);
    stem(ax4, t, example.teachingImpulse, 'Color', teachingColor, 'MarkerFaceColor', teachingColor, 'MarkerSize', 6, 'LineWidth', 1.0); hold(ax4, 'on');
    addExampleEpochLines(ax4, cfg, epochColor);
    xlim(ax4, [cfg.windowStartMs cfg.windowEndMs]);
    ylabel(ax4, 'Teaching signal');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out')
    title(ax4, ['4  Feedback-locked update signal; ', 'no direct same-trial sensory modulation']);
    box(ax4, 'off');

    %% 5. Policy weight before and after each trial

    ax5 = nexttile(teachingLayout);
    stairs(ax5, trialNumber, example.teacherWeightBefore, 'Color', weightColor, 'LineWidth', 1); hold(ax5, 'on');
    plot(ax5, trialNumber, example.teacherWeightAfter, 'o', 'Color', teachingColor, 'MarkerFaceColor', teachingColor, 'MarkerSize', 6, 'LineWidth', 1.0);
    xline(ax5, highlightedTrial, ':k', 'Update trial');yline(ax5, 0,':', 'Color', baselineColor);
    xlim(ax5, [0.5 example.nTrials+0.5]);
    ylabel(ax5, 'Policy weight, w_n');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out','xtick',[1:example.nTrials])
    title(ax5, sprintf(['5  Post-trial update: w_{n+1} = %.3f w_n ', '+ %.2f \\delta_n u_n'], cfg.weightRetention, cfg.learningRate));
    legend(ax5, {'Weight used on trial n', 'Weight after trial n'}, 'Location', 'best', 'Box', 'off');
    box(ax5, 'off');

    %% 6. Future-trial log-odds offset

    ax6 = nexttile(teachingLayout);
    stairs(ax6, trialNumber, example.teachingLogOddsOffset, 'Color', weightColor, 'LineWidth', 1); hold(ax6, 'on');
    xline(ax6, highlightedTrial, ':k');yline(ax6, 0, ':', 'Color', baselineColor);
    if highlightedTrial < example.nTrials
        xline(ax6, highlightedTrial+1, '--', 'Color', probabilityColor, 'Label', 'First post-update trial');
    end
    xlim(ax6, [0.5 example.nTrials+0.5]);
    ylabel(ax6, '\Delta log odds');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out','xtick',[1:example.nTrials])
    title(ax6, ['6  Updated weight alters behavioral log odds ', 'on subsequent trials']);
    box(ax6, 'off');

    %% 7. Baseline and teaching-model P(correct)

    ax7 = nexttile(teachingLayout);
    plot(ax7, trialNumber, example.pBase, '--', 'Color', baselineColor, 'LineWidth', 1);
    hold(ax7, 'on');
    plot(ax7, trialNumber, example.pTeaching, '-o', 'Color', probabilityColor, 'MarkerFaceColor', probabilityColor, 'MarkerSize', 6, 'LineWidth', 1);
    xline(ax7, highlightedTrial, ':k');yline(ax7, 0.5, ':k', 'Chance');
    xlim(ax7, [0.5 example.nTrials+0.5]);ylim(ax7, [0.4 1]);ylabel(ax7, 'P(correct)');
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out','xtick',[1:example.nTrials])
    title(ax7, '7  Teaching modifies future-trial behavioral probability');
    legend(ax7, {'Shared perceptual computation', 'Teaching model'}, 'Location', 'best', 'Box', 'off');
    box(ax7, 'off');

    %% 8. Matched sampled outcomes

    ax8 = nexttile(teachingLayout);
    stairs(ax8, trialNumber, example.sampledTeachingCorrect, 'Color', probabilityColor, 'LineWidth', 1); hold(ax8, 'on');
    scatter(ax8, trialNumber, example.sampledTeachingCorrect, 48, probabilityColor, 'filled');
    xline(ax8, highlightedTrial, ':k');
    xlim(ax8, [0.5 example.nTrials+0.5]);ylim(ax8, [-0.15 1.15]);
    yticks(ax8, [0 1]);yticklabels(ax8, {'Incorrect','Correct'});
    xlabel(ax8, 'Trial number');ylabel(ax8, 'Outcome');
    if highlightedTrial < example.nTrials
        outcomeTitle = sprintf(['8  Update on trial %d is first expressed ', 'on trial %d'], highlightedTrial, highlightedTrial+1);
    else
        outcomeTitle = sprintf('8  Update occurs after final displayed trial %d', highlightedTrial);
    end
    set(gca,'color','none','ticklength', [0.0125 0.0125], 'tickdir', 'out','xtick',[1:example.nTrials])
    title(ax8, outcomeTitle);
    box(ax8, 'off');

    %% 9. Cross-trial probability of correct performance

    ax9 = nexttile(teachingLayout);
    plot(ax9,example.futureLag,example.pReferenceAcross.*ones(size(example.futureLag)),'--','Color',baselineColor,'LineWidth',1.5); hold(ax9,'on');
    plot(ax9,example.futureLag,example.pTeachingAcross,'-o','Color',probabilityColor,'MarkerFaceColor',probabilityColor,'MarkerSize',6,'LineWidth',1);
    yline(ax9,0.5,':k','Chance');
    xlim(ax9,[0 cfg.maxTrialLag]); ylim(ax9,[0.75 0.8]);
    xlabel(ax9,'Future-trial lag'); ylabel(ax9,'P(correct)');
    title(ax9,'9  Teaching event alters performance on subsequent trials');
    legend(ax9,{'Reference','After teaching event'},'Location','best','Box','off');
    set(ax9,'Color','none','TickLength',[0.0125 0.0125],'TickDir','out','xtick',1:cfg.maxTrialLag);
    box(ax9,'off');

    %% Global formatting

    title(teachingLayout, 'Teaching model: example across-trial algorithm', 'FontSize', 10);
    allAxes = findall(ancestor(ax1, 'figure'), 'Type', 'axes');
    set(allAxes, 'FontName', 'Arial', 'FontSize', 8, 'LineWidth', 0.8, 'TickDir', 'out');
end

function [pCorrect, components] = matchToSampleProbability(sampleGainTrace, memoryTauTrace, testGainTrace, criterionShiftDeg, lapseProbability, trueDifferenceDeg, isDifferent, cfg)
    % MATCHTOSAMPLEPROBABILITY
    % Shared delayed match-to-sample computation used by all computational models.

    % Model-specific inputs
    % ---------------------
    % sampleGainTrace: Time-resolved modulation of sample encoding.
    % memoryTauTrace: Time-resolved sample-memory decay constant. The persistent-state model can modulate this during the delay; other models use the fixed baseline memory time constant.
    % testGainTrace: Time-resolved modulation of test encoding.
    % criterionShiftDeg: Additive shift of the same/different decision criterion in degrees.
    % lapseProbability: Probability of a stimulus-independent random response.
    %
    % Shared computation
    % ------------------
    % 1. Encode sample and test evidence.
    % 2. Integrate the sample through a leaky memory state.
    % 3. Accumulate test evidence.
    % 4. Compute the time-resolved sample-test comparison.
    % 5. Apply the common decision criterion and logistic decision rule.
    % 6. Mix the perceptual response with the lapse process.
    % 7. Read out P(correct) at test offset.
    %
    % All models must call this function rather than independently reproducing memory, comparison, or decision computations.

    %% Validate configuration and inputs

    t = cfg.timeMs(:);
    nTime = numel(t);

    requiredCfgFields = {'timeMs',  'dtMs', 'sampleEvidenceProfile', 'testEvidenceProfile', 'memoryDecayTauMs', 'testOnsetMs', 'testOffsetMs', 'baseChangeCriterionDeg', 'decisionNoiseDeg'};
    for fieldIndex = 1:numel(requiredCfgFields)
        assert(isfield(cfg, requiredCfgFields{fieldIndex}), 'cfg is missing required field "%s".', requiredCfgFields{fieldIndex});
    end

    memoryTauTrace = memoryTauTrace(:);
    assert(numel(memoryTauTrace) == nTime, 'memoryTauTrace must contain one value per cfg.timeMs sample.');
    assert(all(isfinite(memoryTauTrace)) && all(memoryTauTrace > 0), 'All memoryTauTrace values must be finite and positive.');
    validateattributes(criterionShiftDeg, {'numeric'}, {'scalar','real','finite'});
    validateattributes(lapseProbability, {'numeric'}, {'scalar','real','finite'});
    validateattributes(trueDifferenceDeg, {'numeric'}, {'scalar','real','finite','nonnegative'});
    validateattributes(isDifferent, {'logical','numeric'}, {'scalar'});

    isDifferent = logical(isDifferent);

    sampleGainTrace = sampleGainTrace(:);
    testGainTrace   = testGainTrace(:);

    sampleProfile = cfg.sampleEvidenceProfile(:);
    testProfile   = cfg.testEvidenceProfile(:);

    assert(numel(sampleGainTrace) == nTime, 'sampleGainTrace must contain one value per cfg.timeMs sample.');
    assert(numel(testGainTrace) == nTime, 'testGainTrace must contain one value per cfg.timeMs sample.');
    assert(numel(sampleProfile) == nTime, 'cfg.sampleEvidenceProfile must match cfg.timeMs.');
    assert(numel(testProfile) == nTime, 'cfg.testEvidenceProfile must match cfg.timeMs.');
    assert(cfg.memoryDecayTauMs > 0, 'cfg.memoryDecayTauMs must be positive.');
    assert(cfg.decisionNoiseDeg > 0, 'cfg.decisionNoiseDeg must be positive.');

    %% 1. Bound model-specific inputs

    % Gain cannot be negative. The floor prevents sign inversion while
    % preserving the model-specific temporal modulation.
    minimumGain = 0.05;

    sampleGainTrace = max(sampleGainTrace, minimumGain);
    testGainTrace   = max(testGainTrace, minimumGain);

    % A lapse probability must lie between zero and one.
    lapseProbability = min(max(lapseProbability, 0), 1);

    %% 2. Encoded sensory evidence

    % Completely unmodulated sensory evidence
    baselineSampleEncoding = sampleProfile;
    baselineTestEncoding   = testProfile;

    % Model-modulated sensory evidence
    sampleEncoding = sampleProfile .* sampleGainTrace;
    testEncoding = testProfile .* testGainTrace;

    %% 3. Shared leaky accumulation dynamics
    %
    % Baseline sample/test representations use the fixed task memory constant.
    % The model-specific sample memory uses memoryTauTrace(t).
    % Test-memory dynamics remain common across models.

    aMemoryBaseline = exp(-cfg.dtMs ./ cfg.memoryDecayTauMs);
    baselineSampleMemoryTrace = zeros(nTime,1);
    baselineTestMemoryTrace   = zeros(nTime,1);
    sampleMemoryTrace = zeros(nTime,1);
    testMemoryTrace   = zeros(nTime,1);
    baselineSampleState = 0;
    baselineTestState   = 0;
    sampleState = 0;
    testState   = 0;

    for timeIndex = 1:nTime
        % Fully unmodulated sample memory
        baselineSampleState = aMemoryBaseline .* baselineSampleState + baselineSampleEncoding(timeIndex) .* cfg.dtMs;
        baselineSampleMemoryTrace(timeIndex) = baselineSampleState;

        % Persistent/model-specific sample memory
        aMemoryModel = exp(-cfg.dtMs ./ memoryTauTrace(timeIndex));
        sampleState = aMemoryModel .* sampleState + sampleEncoding(timeIndex) .* cfg.dtMs;
        sampleMemoryTrace(timeIndex) = sampleState;

        % Fully unmodulated test representation
        baselineTestState = aMemoryBaseline .* baselineTestState + baselineTestEncoding(timeIndex) .* cfg.dtMs;
        baselineTestMemoryTrace(timeIndex) = baselineTestState;

        % Model-modulated test representation
        % Test sensory gain may vary across models, but the memory decay
        % governing the test representation is shared and fixed.
        testState = aMemoryBaseline .* testState + testEncoding(timeIndex) .* cfg.dtMs;
        testMemoryTrace(timeIndex) = testState;
    end

   
    %% 4. Delay-period sample-memory retention
    % Memory fidelity acts only on the stored sample representation.
    % The test representation is affected by test gain but not by the separate sample-memory fidelity parameter.

    % Epoch indices
    testOnsetIndex = find(t >= cfg.testOnsetMs, 1, 'first');
    testOffsetIndex = find(t >= cfg.testOffsetMs, 1, 'first');
    assert(~isempty(testOnsetIndex), 'cfg.testOnsetMs lies outside cfg.timeMs.');
    assert(~isempty(testOffsetIndex), 'cfg.testOffsetMs lies outside cfg.timeMs.');
    assert( testOffsetIndex >= testOnsetIndex, 'Test offset must not precede test onset.');

    delayMask = t >= cfg.delayOnsetMs & t < cfg.delayOffsetMs;
    retainedSampleAtTestOnset         = sampleMemoryTrace(testOnsetIndex);
    baselineRetainedSampleAtTestOnset = baselineSampleMemoryTrace(testOnsetIndex);


    %% 5. Time-resolved sample-test comparison
    % LC-dependent sample/test gains change the strength of the sensory representations. Stronger representations provide greater precision
    % for estimating the sample-test orientation difference.
    % The mean represented orientation difference remains the physical difference; representation strength controls comparison uncertainty.

    validComparisonMask = t >= cfg.testOnsetMs;
    minimumStrength = 1e-12;

    % Relative representation strength with respect to the fully unmodulated sample and test representations.
    sampleRelativeStrength = nan(nTime,1);
    testRelativeStrength   = nan(nTime,1);
    sampleRelativeStrength(validComparisonMask) = max(sampleMemoryTrace(validComparisonMask), minimumStrength) ./ max(baselineSampleMemoryTrace(validComparisonMask), minimumStrength);
    testRelativeStrength(validComparisonMask) = max(testMemoryTrace(validComparisonMask), minimumStrength) ./ max(baselineTestMemoryTrace(validComparisonMask), minimumStrength);

    % Comparison noise. Interpret representation strength as proportional to information: variance therefore scales inversely with representation strength.
    % The factor 1/2 guarantees that when both relative strengths equal 1, effectiveComparisonNoiseTrace = cfg.decisionNoiseDeg.

    effectiveComparisonNoiseTrace = nan(nTime,1);
    effectiveComparisonNoiseTrace(validComparisonMask) = cfg.decisionNoiseDeg .* sqrt(0.5 .* (1 ./ sampleRelativeStrength(validComparisonMask) + 1 ./ testRelativeStrength(validComparisonMask)));

    % The mean internal orientation difference is the actual stimulus difference; 
    % LC-gain changes its precision rather than multiplying the physical orientation difference.
    baselineDifferenceSignalDeg = trueDifferenceDeg .* ones(nTime,1);
    differenceSignalDeg = trueDifferenceDeg .* ones(nTime,1);

    %% 6. Common decision computation
    % Same/different decision from an uncertain internal estimate of the orientation difference

    baselineCriterionDeg = cfg.baseChangeCriterionDeg;
    baselineLapseProbability = cfg.baselineLapseProb;
    criterionDeg = cfg.baseChangeCriterionDeg + criterionShiftDeg;

    % Standard normal CDF without requiring normcdf / Statistics Toolbox.
    normalCDF = @(x) 0.5 .* erfc(-x ./ sqrt(2));

    % Baseline perceptual decision: Baseline sample/test strength is defined as 1, therefore the baseline comparison noise is exactly cfg.decisionNoiseDeg.
    baselineComparisonNoise = cfg.decisionNoiseDeg;
    baselineUpperTail =  1 - normalCDF((baselineCriterionDeg - trueDifferenceDeg) ./ baselineComparisonNoise);
    baselineLowerTail = normalCDF((-baselineCriterionDeg - trueDifferenceDeg) ./ baselineComparisonNoise);
    baselinePReportDifferentPerceptualTrace = nan(nTime,1);
    baselinePReportDifferentPerceptualTrace(validComparisonMask) = baselineUpperTail + baselineLowerTail;

    % Model-modulated perceptual decision
    upperTail = nan(nTime,1);
    lowerTail = nan(nTime,1);
    upperTail(validComparisonMask) = 1 - normalCDF((criterionDeg - trueDifferenceDeg) ./ effectiveComparisonNoiseTrace(validComparisonMask));
    lowerTail(validComparisonMask) = normalCDF((-criterionDeg - trueDifferenceDeg) ./ effectiveComparisonNoiseTrace(validComparisonMask));
    pReportDifferentPerceptualTrace = upperTail + lowerTail;

    % Useful decision-variable traces for visualization only.
    % These are standardized distances from the positive criterion boundary; choice probability itself is computed from both tails above.
    baselineDecisionVariableTrace = trueDifferenceDeg - baselineCriterionDeg;
    baselineDecisionVariableTrace = baselineDecisionVariableTrace .* ones(nTime,1);
    decisionVariableTrace = trueDifferenceDeg - criterionDeg;
    decisionVariableTrace = decisionVariableTrace .* ones(nTime,1);
    baselineStandardizedDecisionTrace = baselineDecisionVariableTrace ./ baselineComparisonNoise;
    standardizedDecisionTrace         = decisionVariableTrace ./ effectiveComparisonNoiseTrace;

    %% 7. Lapse mixture at the response level

    pReportDifferentTrace = (1-lapseProbability) .* pReportDifferentPerceptualTrace + lapseProbability .* 0.5;
    pReportSameTrace = 1 - pReportDifferentTrace;

    baselinePReportDifferentTrace = (1-baselineLapseProbability) .* baselinePReportDifferentPerceptualTrace + baselineLapseProbability .* 0.5;
    baselinePReportSameTrace = 1 - baselinePReportDifferentTrace;

    %% 8. Mask periods before the test

    preTestMask = t < cfg.testOnsetMs;

    % comparisonFidelityTrace(preTestMask)         = NaN;
    baselineDifferenceSignalDeg(preTestMask)      = NaN;
    differenceSignalDeg(preTestMask)              = NaN;
    baselineDecisionVariableTrace(preTestMask)    = NaN;
    decisionVariableTrace(preTestMask)            = NaN;
    baselineStandardizedDecisionTrace(preTestMask)= NaN;
    standardizedDecisionTrace(preTestMask)        = NaN;
    pReportDifferentPerceptualTrace(preTestMask)  = NaN;
    baselinePReportDifferentTrace(preTestMask)    = NaN;
    pReportDifferentTrace(preTestMask)            = NaN;
    baselinePReportSameTrace(preTestMask)         = NaN;
    pReportSameTrace(preTestMask)                 = NaN;

    %% 9. Final behavioral readout

    % The model currently defines the perceptual decision at test offset.
    % Change this index only if the generative model explicitly specifies
    % a later report-time readout.
    finalDecisionIndex       = testOffsetIndex;
    baselinePReportDifferent = baselinePReportDifferentTrace(finalDecisionIndex);
    pReportDifferent         = pReportDifferentTrace(finalDecisionIndex);
    baselinePReportSame      = baselinePReportSameTrace(finalDecisionIndex);
    pReportSame              = pReportSameTrace(finalDecisionIndex);
    assert(isfinite(pReportDifferent), 'Final P(report different) is not finite.');

    if isDifferent
        % Nonmatch trial
        pHit              = pReportDifferent;
        pMiss             = pReportSame;
        pCorrectRejection = 0;
        pFalseAlarm       = 0;
        pCorrect = pHit;
        pError   = pMiss;

        baselinePHit     = baselinePReportDifferent;
        baselinePMiss    = baselinePReportSame;
        baselinePCorrect = baselinePHit;
        baselinePError   = baselinePMiss;
    else
        % Match trial
        pHit              = 0;
        pMiss             = 0;
        pCorrectRejection = pReportSame;
        pFalseAlarm       = pReportDifferent;
        pCorrect = pCorrectRejection;
        pError   = pFalseAlarm;


        baselinePCorrectRejection = baselinePReportSame;
        baselinePFalseAlarm       = baselinePReportDifferent;
        baselinePCorrect          = baselinePCorrectRejection;
        baselinePError            = baselinePFalseAlarm;
    end

    pCorrect = min(max(pCorrect, 1e-8), 1-1e-8);
    pError   = min(max(pError,   1e-8), 1-1e-8);

    baselinePCorrect = min(max(baselinePCorrect, 1e-8), 1-1e-8);
    baselinePError   = min(max(baselinePError,   1e-8), 1-1e-8);

    %% 10. Scalar summaries

    sampleOffsetIndex = find(t < cfg.sampleOffsetMs, 1, 'last');
    assert(~isempty(sampleOffsetIndex), 'Sample offset lies outside cfg.timeMs.');
    
    baselineStoredSampleFidelity = baselineSampleMemoryTrace(sampleOffsetIndex);
    baselineStoredTestFidelity   = baselineTestMemoryTrace(testOffsetIndex);
    storedSampleFidelity         = sampleMemoryTrace(sampleOffsetIndex);
    storedTestFidelity           = testMemoryTrace(testOffsetIndex);
    % finalComparisonFidelity      = comparisonFidelityTrace(finalDecisionIndex);
    effectiveDifferenceDeg       = differenceSignalDeg(finalDecisionIndex);

    %% 11. Return all quantities used for behavior and visualization

    components.sampleGainTrace = sampleGainTrace;
    components.testGainTrace   = testGainTrace;
    components.baselineSampleEncoding   = baselineSampleEncoding;
    components.baselineTestEncoding     = baselineTestEncoding;
    components.sampleEncoding           = sampleEncoding;
    components.testEncoding             = testEncoding;

    components.baselineSampleMemoryTrace  = baselineSampleMemoryTrace;
    components.baselineTestMemoryTrace    = baselineTestMemoryTrace;
    
    components.sampleMemoryTrace          = sampleMemoryTrace;
    components.memoryTauTrace             = memoryTauTrace;
    components.testMemoryTrace            = testMemoryTrace;
    components.meanDelayMemoryTauMs       =  mean(memoryTauTrace(delayMask));
    components.retainedSampleAtTestOnset  =  retainedSampleAtTestOnset;
    components.baselineRetainedSampleAtTestOnset = baselineRetainedSampleAtTestOnset;

    components.sampleRelativeStrength        = sampleRelativeStrength;
    components.testRelativeStrength          = testRelativeStrength;
    components.effectiveComparisonNoiseTrace = effectiveComparisonNoiseTrace;
    
    % components.comparisonFidelityTrace         = comparisonFidelityTrace;
    components.baselineDifferenceSignalDeg     = baselineDifferenceSignalDeg;
    components.differenceSignalDeg             = differenceSignalDeg;
    components.criterionDeg                    = criterionDeg;
    components.criterionShiftDeg               = criterionShiftDeg;
    components.baselineDecisionVariableTrace   = baselineDecisionVariableTrace;
    components.decisionVariableTrace           = decisionVariableTrace;
    components.baselineStandardizedDecisionTrace      = baselineStandardizedDecisionTrace;
    components.standardizedDecisionTrace              = standardizedDecisionTrace;
    components.baselinePReportDifferentPerceptualTrace   = baselinePReportDifferentPerceptualTrace;
    components.pReportDifferentPerceptualTrace          = pReportDifferentPerceptualTrace;
    components.baselinePReportDifferentTrace            = baselinePReportDifferentTrace;
    components.pReportDifferentTrace                    = pReportDifferentTrace;
    components.baselinePReportSameTrace                 = baselinePReportSameTrace;
    components.pReportSameTrace                         = pReportSameTrace;
    
    components.lapseProbability   = lapseProbability;
    components.trueDifferenceDeg  = trueDifferenceDeg;
    components.isDifferent        = isDifferent;
    components.sampleOffsetIndex  = sampleOffsetIndex;
    components.testOnsetIndex     = testOnsetIndex;
    components.testOffsetIndex    = testOffsetIndex;
    components.finalDecisionIndex = finalDecisionIndex;
    
    components.baselineStoredSampleFidelity = baselineStoredSampleFidelity;
    components.baselineStoredTestFidelity   = baselineStoredTestFidelity;
    components.storedSampleFidelity         = storedSampleFidelity;
    components.storedTestFidelity           = storedTestFidelity;
    % components.finalComparisonFidelity      = finalComparisonFidelity;

    components.effectiveDifferenceDeg       = effectiveDifferenceDeg;
    components.baselinePReportDifferentPerceptual   = baselinePReportDifferentPerceptualTrace(finalDecisionIndex);
    components.pReportDifferentPerceptual           = pReportDifferentPerceptualTrace(finalDecisionIndex);
    components.baselinePReportDifferent             = baselinePReportDifferent;
    components.pReportDifferent                     = pReportDifferent;
    components.pReportSame                          = pReportSame;
    components.pHit              = pHit;
    components.pMiss             = pMiss;
    components.pCorrectRejection = pCorrectRejection;
    components.pFalseAlarm       = pFalseAlarm;
    components.pCorrect          = pCorrect;
    components.pError            = pError;
    components.baselinePCorrect  = baselinePCorrect;
    components.baselinePError    = baselinePError;
end

function addExampleEpochLines(ax, cfg, epochColor)
    % ADDEXAMPLEEPOCHLINES
    % Adds task-epoch boundaries using the same formatting across algorithm
    % figures.
    xline(ax, cfg.sampleOnsetMs, ':k');
    xline(ax, cfg.sampleOffsetMs, ':', 'Color', epochColor);
    xline(ax, cfg.testOnsetMs, ':k');
    xline(ax, cfg.testOffsetMs, ':', 'Color', epochColor);
end

function shared = makeSharedExampleTrial(cfg)
   % MAKESHAREDEXAMPLETRIAL
   %
   % Generates all physical and task-level quantities that must be identical
   % across the persistent-state and controller example figures.
   %
   % Model-specific latent dynamics are deliberately excluded.

    %% Reproducible WN realization
    localStream = RandStream('mt19937ar', 'Seed', 32);

    expectedOnBins = round(cfg.nWNStateBins .* cfg.pPulse);
    
    bestDifference = inf;
    WN25raw = [];

    for candidateIndex = 1:1000
        candidate = double(rand(localStream, 1, cfg.nWNStateBins) < cfg.pPulse);
        candidateDifference = abs(sum(candidate) - expectedOnBins);
        if candidateDifference < bestDifference
            bestDifference = candidateDifference;
            WN25raw = candidate;
        end
        if bestDifference == 0
            break;
        end
    end
    WNactive = repelem(WN25raw, cfg.samplesPerWNState);
    WNmodel = [WNactive, zeros(1, cfg.nTimeSamples-cfg.nWNTimeSamples)]';

    %% Identical task condition
    sampleOrientationDeg = 45;
    isDifferent = true;
    trueDifferenceDeg = cfg.changeMagnitudeDeg;
    testOrientationDeg = mod(sampleOrientationDeg + trueDifferenceDeg, 180);

    %% Identical stimulus profiles
    sampleProfile = cfg.sampleEvidenceProfile(:);
    testProfile = cfg.testEvidenceProfile(:);

    %% Identical fixed baseline quantities
    shared.WN25raw = WN25raw;
    shared.WNmodel = WNmodel;
    shared.nOnBins = sum(WN25raw);
    shared.expectedOnBins = expectedOnBins;

    shared.sampleOrientationDeg = sampleOrientationDeg;
    shared.testOrientationDeg = testOrientationDeg;
    shared.isDifferent = isDifferent;
    shared.trueDifferenceDeg = trueDifferenceDeg;

    shared.sampleProfile = sampleProfile;
    shared.testProfile = testProfile;

    shared.baseCriterionDeg = cfg.baseChangeCriterionDeg;
    shared.baselineLapseProb = cfg.baselineLapseProb;
    shared.memoryDecayTauMs = cfg.memoryDecayTauMs;

    % Use the same random stream for illustrative sampled outcomes.
    shared.outcomeUniform = rand(localStream,1);
end

function example = makePersistentCrossTrialExample(cfg,nTrials)
    s = RandStream('mt19937ar','Seed',41);
    WN25 = double(rand(s,nTrials,cfg.nWNStateBins) < cfg.pPulse);
    WNactive = repelem(WN25,1,cfg.samplesPerWNState);
    WN = [WNactive zeros(nTrials,cfg.nTimeSamples-cfg.nWNTimeSamples)];
    stateAtWNOffsetDrive = zeros(nTrials,1);
    for trial = 1:nTrials
        zWN = 0;
        zExpectation = 0;
        for timeIndex = 1:cfg.nWNTimeSamples
            zExpectation = zExpectation + (cfg.dtMs/cfg.expectationDecayTauMs)*(-zExpectation + cfg.expectationStateGain*cfg.temporalExpectation(timeIndex));
            tauWN = cfg.stateTauMinMs + (cfg.stateTauMaxMs-cfg.stateTauMinMs)*logistic(cfg.stateTauSlope*zExpectation);
            zWN = exp(-cfg.dtMs/tauWN)*zWN + cfg.stateInputGain*WN(trial,timeIndex);
        end
        stateAtWNOffsetDrive(trial) = zWN;
    end
    stateAtWNOffsetDrive = stateAtWNOffsetDrive - mean(stateAtWNOffsetDrive);
    positiveRows = find(stateAtWNOffsetDrive>0);
    if isempty(positiveRows)
       exampleTrial = find(abs(stateAtWNOffsetDrive)==max(abs(stateAtWNOffsetDrive)),1);
    else
       [~,ii] = max(stateAtWNOffsetDrive(positiveRows));
       exampleTrial = positiveRows(ii);
    end
    sExample = stateAtWNOffsetDrive(exampleTrial);
    baselineNext = cfg.stateWNWriteGain*sExample;
    futureLag = (1:cfg.maxTrialLag)';
    baselineDisplacement = baselineNext.*cfg.stateBaselineRetention.^(futureLag-1);
    referenceState = makeReferenceOperatingState(cfg);
    pBaselineMatch = stateMatchToSampleProbability(referenceState,0,false,cfg);
    pBaselineDifferent = stateMatchToSampleProbability(referenceState,cfg.changeMagnitudeDeg,true,cfg);
    pBaseline = (1-cfg.pDifferent)*pBaselineMatch+cfg.pDifferent*pBaselineDifferent;
    pFuture = NaN(cfg.maxTrialLag,1);
    for lag = 1:cfg.maxTrialLag
        perturbedState = referenceState+baselineDisplacement(lag).*ones(cfg.nTimeSamples,1);
        pMatch = stateMatchToSampleProbability(perturbedState,0,false,cfg);
        pDifferent = stateMatchToSampleProbability(perturbedState,cfg.changeMagnitudeDeg,true,cfg);
        pFuture(lag) = (1-cfg.pDifferent)*pMatch+cfg.pDifferent*pDifferent;
    end

    maxLag = min(cfg.maxTrialLag,nTrials-1);
    across = zeros(nTrials,maxLag);
    for lag = 1:maxLag
        across(1+lag:end,lag) = stateAtWNOffsetDrive(1:end-lag);
    end
    example.exampleTrial = exampleTrial;
    example.sExample     = sExample;
    example.baselineNext = baselineNext;
    example.baselineDisplacement = baselineDisplacement;
    example.pBaseline = pBaseline;
    example.pFuture   = pFuture;

    example.nTrials    = nTrials;
    example.maxLag     = maxLag;
    example.trialDrive = mean(WN25,2);
    example.stateAtWNOffsetDrive = stateAtWNOffsetDrive;
    example.across = zscoreSafe(across);
end

function validateDemoInputs(D, cfg, nModels)
required = {'WN25','sampleOrientationDeg','testOrientationDeg','isDifferent','trueDifferenceDeg'};
assert(all(isfield(D,required)), 'Demo input fields are incomplete.');
assert(isequal(size(D.WN25),[cfg.nTrials cfg.nWNStateBins nModels cfg.nRepeats]), 'Demo WN25 dimensions must be trials x bins x models x repetitions.');
assert(all(D.WN25(:)==0 | D.WN25(:)==1), 'Demo stimulation must be binary.');
for k = 2:numel(required)
    A = D.(required{k});
    assert(isequal(size(A),[cfg.nTrials nModels cfg.nRepeats]) && all(isfinite(A(:))), 'Invalid demo task dimensions or values.');
end
assert(all(D.isDifferent(:)==0 | D.isDifferent(:)==1), 'Invalid trial-type flag.');
assert(all(D.trueDifferenceDeg(:)==cfg.changeMagnitudeDeg*double(D.isDifferent(:))), 'Demo orientation difference disagrees with the model configuration.');
end

function exportPredictionTables(cfg, kernels, modelNames, outputDir)
T = array2table([cfg.wnFineTimeMs(:) kernels.within], 'VariableNames', {'Time_ms','Persistent','Controller_0ms','Controller_100ms','Teaching'});
writetable(T, fullfile(outputDir,'Figure1_within_predictions.csv'));
T = array2table([(1:cfg.maxTrialLag)' kernels.across], 'VariableNames', {'TrialLag','Persistent','Controller_0ms','Controller_100ms','Teaching'});
writetable(T, fullfile(outputDir,'Figure1_across_predictions.csv'));
T = array2table([cfg.wnTimeMs(:) kernels.within25], 'VariableNames', {'BinCenter_ms','Persistent','Controller_0ms','Controller_100ms','Teaching'});
writetable(T, fullfile(outputDir,'Predictions_25ms.csv'));
assert(numel(modelNames)==4, 'Update export labels if adding model candidates.');
end

function exportRecoveryTables(cfg, names, rw, pw, ra, pa, rt, pt, accuracy, outputDir)
model = strings(0,1); domain = strings(0,1); coordinate = []; recovered = [];
ciLo = []; ciHi = []; population = [];
for m = 1:numel(names)
    for d = 1:2
        if d == 1
            R = rw(:,m,:); P = pw(:,m,:); x = cfg.wnTimeMs(:); domainName = "WithinTrial";
        elseif m == numel(names)
            R = rt(:,m,:); P = pt(:,m,:); x = (1:cfg.maxTrialLag)'; domainName = "TeachingHistory";
        else
            R = ra(:,m,:); P = pa(:,m,:); x = (1:cfg.maxTrialLag)'; domainName = "PersistentHistory";
        end
        mu = mean(R,3,'omitnan'); se = std(R,0,3,'omitnan')/sqrt(cfg.nRepeats);
        model = [model; repmat(names(m),numel(x),1)]; 
        domain = [domain; repmat(domainName,numel(x),1)]; 
        coordinate = [coordinate; x]; recovered = [recovered; mu]; 
        ciLo = [ciLo; mu-1.96*se]; ciHi = [ciHi; mu+1.96*se]; 
        population = [population; mean(P,3,'omitnan')]; 
    end
end
T = table(model,domain,coordinate,recovered,ciLo,ciHi,population, 'VariableNames',{'Model','Domain','Time_ms_or_TrialLag','RecoveredMean', 'Lower95CI','Upper95CI','PopulationMean'});
writetable(T,fullfile(outputDir,'Figure2_kernel_summary.csv'));
T = table(names(:),mean(accuracy,2,'omitnan'),std(accuracy,0,2,'omitnan')/sqrt(cfg.nRepeats), 'VariableNames',{'Model','AccuracyMean','AccuracySEM'});
writetable(T,fullfile(outputDir,'Behavioral_accuracy.csv'));
end

function exportNewFigures(initialFigures, outputDir)
figures = findall(groot,'Type','figure');
figures = figures(~ismember(figures, initialFigures));
for k = 1:numel(figures)
    f = figures(k);
    label = get(f,'Name');
    switch label
        case 'Generating model predictions', stem = 'Figure1_predictions';
        case 'Kernel recovery', stem = 'Figure2_kernel_recovery';
        case 'Figure 1A: persistent operating-state algorithm', stem = 'Model_example_persistent';
        case 'Figure 1B: controller algorithm (+100 ms)', stem = 'Model_example_controller';
        case 'Figure 1C: teaching-signal algorithm', stem = 'Model_example_teaching';
        case 'Model recovery strength', stem = 'Model_recovery_strength';
        otherwise
            stem = regexprep(label,'[^a-zA-Z0-9]+','_');
            if isempty(stem), stem = sprintf('Additional_plot_%02d',k); end
    end
    axesList = findall(f,'Type','axes');
    for j = 1:numel(axesList)
        if isprop(axesList(j),'Toolbar') && ~isempty(axesList(j).Toolbar)
            axesList(j).Toolbar.Visible = 'off';
        end
    end
    drawnow;
    savefig(f,fullfile(outputDir,[stem '.fig']));
    exportgraphics(f,fullfile(outputDir,[stem '.pdf']),'ContentType','vector','BackgroundColor','white');
end
end

function writeRuntimeReport(outputDir, mode, secondsElapsed, usedCache, cfg)
environment.matlabVersion = version;
environment.matlabRelease = version('-release');
environment.architecture = computer;
environment.products = ver;
environment.mode = mode;
environment.usedCache = usedCache;
environment.elapsedSeconds = secondsElapsed;
environment.nTrials = cfg.nTrials;
environment.nRepeats = cfg.nRepeats;
environment.timestamp = datestr(now,30);
[osStatus,osDescription] = systemOperatingSystem;
environment.osCommandStatus = osStatus;
environment.operatingSystem = strtrim(osDescription);
save(fullfile(outputDir,'run_environment.mat'),'environment');
fid = fopen(fullfile(outputDir,'run_environment.txt'),'w');
assert(fid ~= -1,'Cannot write environment report.');
cleanup = onCleanup(@()fclose(fid)); 
fprintf(fid,'MATLAB: %s\nRelease: %s\nComputer: %s\nOperating system: %s\n', environment.matlabVersion,environment.matlabRelease,environment.architecture,environment.operatingSystem);
fprintf(fid,'Mode: %s\nUsed cached simulations: %d\nElapsed seconds: %.3f\n',mode,usedCache,secondsElapsed);
fprintf(fid,'Trials/dataset: %d\nRepetitions: %d\nTimestamp: %s\n',cfg.nTrials,cfg.nRepeats,environment.timestamp);
fprintf(fid,'Installed products (not all are dependencies):\n');
for k = 1:numel(environment.products)
    fprintf(fid,'  %s %s (%s)\n',environment.products(k).Name, environment.products(k).Version,environment.products(k).Release);
end
end

function [status, description] = systemOperatingSystem
if ismac
    [status,description] = system('sw_vers');
elseif ispc
    [status,description] = system('ver');
else
    [status,description] = system('uname -srm');
end
end
