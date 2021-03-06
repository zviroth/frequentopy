%
%        $Id: frequentopy.m,v 1.0 2017/12/07 
%      usage: frequentopy('modulator=angular','direction=1')
%         by: zvi roth
%       date: 12/07/17
%    purpose: phase-encoded spatial frequency mapping, SF scaled by eccentricity

function myscreen = frequentopy(varargin)

% check arguments
if ~any(nargin == [0:10])
    help frequentopy
    return
end
 
% % evaluate the input arguments
getArgs(varargin, [], 'verbose=0');

% set default parameters
if ieNotDefined('direction'),direction = -1;end
if ieNotDefined('stimLen'),stimLen = 1.5;end
if ieNotDefined('frameLen'),frameLen = 0.25; end
if ieNotDefined('modulator'), modulator = 'radial'; end


% check to see whether screen is still open
global stimulus;

% store paramerts in stimulus variable
% update stimulus every 250 ms
stimulus.frameLen = frameLen;
% stimulus is on for 30 seconds
stimulus.stimLen = stimLen;
% increasing or decreasing spatial frequency
stimulus.directon = direction;
%radial or angular grating
stimulus.modulator = modulator;

% initalize the screen
myscreen.background = 'gray';
myscreen.autoCloseScreen = 0;
myscreen.allowpause = 1;
myscreen.saveData = 1;
%myscreen.displayName = '3tb';
myscreen.displayName = '7t';
%myscreen.displayName = 'laptop';

myscreen = initScreen(myscreen);

global fixStimulus
fixStimulus.diskSize = 0;
fixStimulus.fixWidth = 0.5;
fixStimulus.fixLineWidth = 2;
[task{1} myscreen] = fixStairInitTask(myscreen);

task{2}{1}.waitForBacktick = 1;
seglen = stimulus.frameLen * ones(1,stimulus.stimLen/stimulus.frameLen);
seglen(end) = 0.1;
task{2}{1}.seglen = seglen;
task{2}{1}.synchToVol = zeros(size(seglen));
task{2}{1}.synchToVol(end) = 1;

%vector of all spatial frquencies. For Angular these are angular frequencies.
spatFreq(1) = 2;
spatFreq(2) = 3.1;
for i=3:16
    spatFreq(i) = spatFreq(i-1) + (spatFreq(i-1)-spatFreq(i-2))*1.15;
end
spatFreq=floor(spatFreq);%for Angular the freq must be integers

stimulus.spatFreqs = spatFreq;
if direction == -1
    task{2}{1}.parameter.spatFreq = fliplr(stimulus.spatFreqs);
else
    task{2}{1}.parameter.spatFreq = stimulus.spatFreqs;
end

task{2}{1}.randVars.block.innerEdge = 8;
task{2}{1}.randVars.block.outerEdge = 1;


task{2}{1}.random = 0;
task{2}{1}.numTrials = Inf;
task{2}{1}.collectEyeData = true;

% initialize the task
for phaseNum = 1:length(task{2})
    [task{2}{phaseNum} myscreen] = initTask(task{2}{phaseNum},myscreen,@startSegmentCallback,@screenUpdateCallback,@responseCallback);
end

% do our initialization which creates the gratings
stimulus = myInitStimulus(stimulus,myscreen,task);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Main display loop
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
mglClearScreen(); mglFlush;
phaseNum = 1;
while (phaseNum <= length(task)) && ~myscreen.userHitEsc
    % update the task
    [task{2} myscreen phaseNum] = updateTask(task{2},myscreen,phaseNum);
    % update the fixation task
    [task{1} myscreen] = updateTask(task{1},myscreen,1);
    % flip screen
    myscreen = tickScreen(myscreen,task);
end

% if we got here, we are at the end of the experiment
myscreen = endTask(myscreen,task);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function that gets called at the start of each segment
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [task myscreen] = startSegmentCallback(task, myscreen)

global stimulus;

% randomize the current phase of the stimulus
newPhase = ceil(rand(1)*stimulus.numPhases);
while stimulus.phaseNum == newPhase
    newPhase = ceil(rand(1)*stimulus.numPhases);
end
stimulus.phaseNum = newPhase;

% create the modulator

visualspace = linspace(-stimulus.width, stimulus.width, stimulus.sz);
[x,y] = meshgrid(visualspace);
[th,rad] = cart2pol(x,y);

f=task.thistrial.spatFreq;%angular frequency
a = ((4*f+pi)/(4*f-pi))^(2/pi);
if strcmp(stimulus.modulator, 'angular')
    modulator = f .* th;
elseif strcmp(stimulus.modulator, 'radial')
    modulator = log(rad)/log(a);
else
    disp(sprintf('UHOH: Don''t recognize %s', stimulus.modulator'));
end

% add phase
  grating = cos(modulator + stimulus.phases(newPhase));
%   modulator = sin(modulator);

% make it a square wave
if stimulus.square
    grating = sign(grating);
end

% scale to range of display
grating = 255*(grating+1)/2;

% make it rgba
grating = uint8(permute(repmat(grating, [1 1 4]), [3 1 2]));
grating(4,:,:) = 256;

% update the texture
mglBindTexture(stimulus.tex, grating);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function that gets called to draw the stimulus each frame
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [task myscreen] = screenUpdateCallback(task, myscreen)

global stimulus;

% clear the screen
mglClearScreen;
% draw the texture
mglBltTexture(stimulus.tex, [0 0 stimulus.width stimulus.height], 0, 0, 0);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function to init the dot stimulus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function stimulus = myInitStimulus(stimulus,myscreen,task)

stimulus.pixRes = min(myscreen.screenHeight/myscreen.imageHeight, myscreen.screenWidth/myscreen.imageWidth);

% scale factor
stimulus.sFac = 1;

% spatial frequency
stimulus.sf = 1.4;

% which phases we will have
stimulus.numPhases = 16;
stimulus.phases = 0:(360-0)/stimulus.numPhases:360;

% size of stimulus

% stimulus.height = 0.5*floor(myscreen.imageHeight/0.5)+2;
stimulus.height = 0.5*floor(myscreen.imageWidth/0.5)+2;
stimulus.width = stimulus.height;

% chose a sin or square
stimulus.square = 0;

% initial phase number
stimulus.phaseNum = 1;

% make a grating just to get the size
tmpGrating = mglMakeGrating(stimulus.width, stimulus.height, stimulus.sf, 0, stimulus.phases(1), stimulus.pixRes, stimulus.pixRes);
sz = size(tmpGrating,2);
stimulus.sz=sz;


% make a grating again, but now scale it
tmpGrating = mglMakeGrating(stimulus.width/stimulus.sFac, stimulus.height/stimulus.sFac, stimulus.sf, 0, stimulus.phases(1), stimulus.pixRes, stimulus.pixRes);
r = uint8(permute(repmat(tmpGrating, [1 1 4]), [3 1 2]));
stimulus.tex = mglCreateTexture(r,[],1);

