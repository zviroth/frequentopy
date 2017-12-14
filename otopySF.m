%
%        $Id: phEncodedOrientationCM2.m,v 1.2 2016/01/22 15:30:22 eli Exp $
%      usage: phEncodedOrientation
%         by: eli merriam
%       date: 01/27/07
%    purpose: oriented grating stimulus times a radial or angular modulator

function myscreen = otopySF(varargin)

% check arguments
if ~any(nargin == [0:10])
    help otopySzSF
    return
end

% % evaluate the input arguments
getArgs(varargin, [], 'verbose=0');

% set default parameters
if ieNotDefined('direction'),direction = -1;end
if ieNotDefined('stimLen'),stimLen = 1.5;end
if ieNotDefined('frameLen'),frameLen = 0.25; end


% check to see whether screen is still open
global stimulus;

% store paramerts in stimulus variable
% update stimulus every 250 ms
stimulus.frameLen = frameLen;
% stimulus is on for 30 seconds
stimulus.stimLen = stimLen;
% clockwise or counterclockwise
stimulus.directon = direction;

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
fixStimulus.diskSize = 0.75/2;
fixStimulus.fixWidth = 0.75;
fixStimulus.fixLineWidth = 3;
[task{1} myscreen] = fixStairInitTask(myscreen);

task{2}{1}.waitForBacktick = 1;
seglen = stimulus.frameLen * ones(1,stimulus.stimLen/stimulus.frameLen);
seglen(end) = 0.1;
task{2}{1}.seglen = seglen;
task{2}{1}.synchToVol = zeros(size(seglen));
task{2}{1}.synchToVol(end) = 1;
orientation = linspace(0, 180, 17);
orientation = orientation(1:end-1);
stimulus.orientations = orientation;
if direction == -1
    task{2}{1}.parameter.orientation = fliplr(stimulus.orientations);
else
    task{2}{1}.parameter.orientation = stimulus.orientations;
end

task{2}{1}.randVars.block.spatFreq = [0.15 0.3 0.6 1.2 2.4 4.8];
% task{2}{1}.randVars.block.innerEdge = 1:8;
% task{2}{1}.randVars.block.outerEdge = 1:8;

%task{2}{1}.randVars.block.spatFreq = [1.2];
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
while stimulus.phaseNum == newPhase;
    newPhase = ceil(rand(1)*stimulus.numPhases);
end
stimulus.phaseNum = newPhase;

% make the grating
grating = mglMakeGrating(stimulus.width/stimulus.sFac, stimulus.height/stimulus.sFac, task.thistrial.spatFreq*stimulus.sFac, ...
    task.thistrial.orientation, stimulus.phases(newPhase), stimulus.pixRes, stimulus.pixRes);

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
mglBltTexture(stimulus.tex, [0 0 stimulus.height stimulus.height], 0, 0, 0);
% mglBltTexture(stimulus.innerMaskTex{task.thistrial.innerEdge}, [0 0 stimulus.height stimulus.height], 0, 0, 0);
% mglBltTexture(stimulus.outerMaskTex{task.thistrial.outerEdge}, [0 0 stimulus.height stimulus.height], 0, 0, 0);


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
stimulus.height = floor(myscreen.imageWidth/0.5)+2;
stimulus.width = stimulus.height;

% size of annulus
stimulus.outer = stimulus.height;
stimulus.outTransition = 0;

stimulus.inner = 0.75;
stimulus.inTransition = 0;

% chose a sin or square
stimulus.square = 0;

% initial phase number
stimulus.phaseNum = 1;

% make a grating just to get the size
tmpGrating = mglMakeGrating(stimulus.width, stimulus.height, stimulus.sf, 0, stimulus.phases(1), stimulus.pixRes, stimulus.pixRes);
sz = size(tmpGrating,2);

% outer = linspace(20, 13, 8);
% inner = linspace(1, 4.5, 8);
% stimulus.outer=1;
% stimulus.inner = 1;
% outer = linspace(7, 10.5, 8);
% inner = linspace(0.5, 4, 8);

% for iMask = 1:8
%     stimulus.outer = outer(iMask);
%     stimulus.inner = inner(iMask);
%     
%     % create mask for fixation and edge
%     out = stimulus.outer/stimulus.width;
%     in = stimulus.inner/stimulus.width;
%     twOut = stimulus.outTransition/stimulus.width;
%     twIn = stimulus.inTransition/stimulus.width;
%     outerMask = mkDisc(sz,(out*sz)/2,[(sz+1)/2 (sz+1)/2],twOut*sz,[1 0]);
%     innerMask = mkDisc(sz,(in*sz)/2,[(sz+1)/2 (sz+1)/2],twIn*sz,[0 1]);
%     
%     % rescale mask to max out at 1
%     outerMask = outerMask/max(outerMask(:));
%     innerMask = innerMask/max(innerMask(:));
%     
%     outerMask(:,:,4) = (-1*(outerMask*255))+255;
%     innerMask(:,:,4) = (-1*(innerMask*255))+255;
%     
%     outerMask(:,:,1:3) = 128;
%     innerMask(:,:,1:3) = 128;
%     
%     innerMask = uint8(permute(innerMask, [3 1 2]));
%     outerMask = uint8(permute(outerMask, [3 1 2]));
%     
%     stimulus.innerMaskTex{iMask} = mglCreateTexture(innerMask);
%     stimulus.outerMaskTex{iMask} = mglCreateTexture(outerMask);
%     
% end




% make a grating again, but now scale it
tmpGrating = mglMakeGrating(stimulus.width/stimulus.sFac, stimulus.height/stimulus.sFac, stimulus.sf, 0, stimulus.phases(1), stimulus.pixRes, stimulus.pixRes);
r = uint8(permute(repmat(tmpGrating, [1 1 4]), [3 1 2]));
stimulus.tex = mglCreateTexture(r,[],1);

