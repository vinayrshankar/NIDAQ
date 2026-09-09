function NI_MultiChannel_Recorder_v4_03
% NI_MultiChannel_Recorder_v4_03
% -------------------------------------------------------------------------
% V4 INDEPENDENT-WINDOW NI RECORDER
%
% AUTHOR / MAINTAINER
%   Vinay Shankar
%   Email:   vinay@tfaworld.org
%   Website: https://tfaworld.org/
%   GitHub:  https://github.com/vinayrshankar/NIDAQ
%
% Copyright and project authorship: Vinay Shankar.
% Distributed under the GNU General Public License v2.0 (GPL-2.0).
% Please preserve this author/contact block in redistributed or modified copies.
%
% This is a standalone V4 implementation. It does NOT reuse the plotting
% architecture or configuration file from earlier recorder versions.
%
% Design rules in V4:
%   1) The control/configuration UI contains NO signal axes.
%   2) Every enabled channel gets its own independent UIFigure window.
%   3) Every channel window owns exactly one UIAxes and one plot line.
%   4) No channel can ever be overlaid on another channel's axes.
%   5) Each channel has its own Label, Unit, Scale, Offset, TerminalConfig,
%      AutoY setting, YMin and YMax.
%   6) Only one timing column is saved: SampleStartUTC_ms.
%   7) Elapsed time exists only internally for live plotting.
%   8) V4 uses its own persistent configuration file.
%
% -------------------------------------------------------------------------
% RECORDER ARCHITECTURE AND RESEARCH WORKFLOW
% Designed and maintained by Vinay Shankar (vinay@tfaworld.org).
% Project documentation and releases: https://github.com/vinayrshankar/NIDAQ
% Website: https://tfaworld.org/
% -------------------------------------------------------------------------
% Acquisition API:
%   dq = daq("ni")
%   addinput(...)
%   dq.ScansAvailableFcn
%   start(dq,"continuous")
%   read(...,OutputFormat="Matrix")
%
% Engineering conversion:
%   calibratedValue = rawVoltage .* Scale + calibrationOffset
%   finalValue      = calibratedValue + tareOffset
%
% Baseline / TARE:
%   TARE uses the mean of a user-selected recent baseline window.
%   tareOffset = -mean(calibrated baseline)
%   TARE never overwrites the saved calibration Scale/Offset configuration.
% -------------------------------------------------------------------------

APP_VERSION = "4.0.3-baseline-tare";
AUTHOR_NAME = "Vinay Shankar";
AUTHOR_EMAIL = "vinay@tfaworld.org";
AUTHOR_WEBSITE = "https://tfaworld.org/";
PROJECT_REPOSITORY = "https://github.com/vinayrshankar/NIDAQ";
PROJECT_LICENSE = "GPL-2.0";
AUTO_CONFIG_FILE = fullfile(prefdir,'NI_MultiChannel_Recorder_v4_03_lastconfig.mat');
baselineDurationSetting = 1.0;

%% Runtime state
S = struct();
S.dq               = [];
S.running          = false;
S.dirty            = false;
S.rawData          = zeros(0,0);
S.scaledData       = zeros(0,0);
S.timeSec          = zeros(0,1);   % internal only; never saved as a column
S.triggerUTCms     = NaN;
S.actualRate       = NaN;
S.callbackScanCount = NaN;
S.labels           = strings(0,1);
S.units            = strings(0,1);
S.devices          = strings(0,1);
S.channelIDs       = strings(0,1);
S.scales           = zeros(0,1);
S.offsets          = zeros(0,1);
S.tareOffsets      = zeros(0,1);
S.baselineMeans    = zeros(0,1);
S.baselineDuration = NaN;
S.tareTimestampUTCms = NaN;
S.terminals        = strings(0,1);
S.autoY            = false(0,1);
S.yMin             = zeros(0,1);
S.yMax             = zeros(0,1);
S.plotFigures      = gobjects(0);
S.axesHandles      = gobjects(0);
S.lineHandles      = gobjects(0);
S.valueLabels      = gobjects(0);
S.tareLabels       = gobjects(0);
S.baselineFig      = gobjects(0);
S.baselineTable    = gobjects(0);
S.baselineDurationField = gobjects(0);
S.baselineStatusLabel = gobjects(0);
S.maxPlotPoints    = 6000;
S.lastError        = "";

%% Device discovery
[deviceIDs, discoveryMessage] = discoverDevices(false);
if isempty(deviceIDs)
    defaultDevice = "dev2";   % editable fallback
else
    defaultDevice = deviceIDs(1);
end

%% Control window - intentionally contains NO plot axes
controlFig = uifigure( ...
    'Name',['NI Multi-Channel Recorder V4 — ' char(APP_VERSION) ' — Vinay Shankar'], ...
    'Position',[80 70 1220 760], ...
    'CloseRequestFcn',@closeApplication);

root = uigridlayout(controlFig,[4 1]);
root.RowHeight = {52,170,'1x',64};
root.Padding = [10 10 10 10];
root.RowSpacing = 8;

% V4 banner
banner = uipanel(root,'Title','V4 Architecture');
banner.Layout.Row = 1;
bannerGrid = uigridlayout(banner,[1 2]);
bannerGrid.ColumnWidth = {'1x',260};
bannerGrid.Padding = [8 2 8 2];
uilabel(bannerGrid, ...
    'Text','V4.0.3: independent signal windows + Baseline/TARE. TARE applies a separate runtime zero offset without changing calibration.', ...
    'FontWeight','bold');
versionLabel = uilabel(bannerGrid,'Text',['Version: ' char(APP_VERSION)], ...
    'HorizontalAlignment','right');

% Acquisition settings
settingsPanel = uipanel(root,'Title','Acquisition / Configuration');
settingsPanel.Layout.Row = 2;
settingsGrid = uigridlayout(settingsPanel,[4 6]);
settingsGrid.ColumnWidth = {115,150,115,125,'1x',170};
settingsGrid.RowHeight = {30,30,30,30};
settingsGrid.Padding = [8 8 8 8];
settingsGrid.ColumnSpacing = 8;
settingsGrid.RowSpacing = 6;

uilabel(settingsGrid,'Text','Default device');
deviceField = uieditfield(settingsGrid,'text','Value',char(defaultDevice));

uilabel(settingsGrid,'Text','Sample rate (Hz)');
rateField = uieditfield(settingsGrid,'numeric','Value',5000,'Limits',[0.001 Inf], ...
    'ValueChangedFcn',@settingsChanged);

refreshButton = uibutton(settingsGrid,'push','Text','Refresh NI devices', ...
    'ButtonPushedFcn',@refreshDevices);
resetButton = uibutton(settingsGrid,'push','Text','DAQ reset + refresh', ...
    'ButtonPushedFcn',@resetAndRefresh);

uilabel(settingsGrid,'Text','Plot window (s)');
windowField = uieditfield(settingsGrid,'numeric','Value',10,'Limits',[0.1 Inf], ...
    'ValueChangedFcn',@settingsChanged);

applyDeviceButton = uibutton(settingsGrid,'push','Text','Apply device to rows', ...
    'ButtonPushedFcn',@applyDeviceToRows);
openWindowsButton = uibutton(settingsGrid,'push','Text','OPEN / REBUILD SIGNAL WINDOWS', ...
    'FontWeight','bold','ButtonPushedFcn',@rebuildSignalWindowsFromTable);
openWindowsButton.Layout.Column = [5 6];

saveCfgButton = uibutton(settingsGrid,'push','Text','Save V4 config', ...
    'ButtonPushedFcn',@saveConfigurationAs);
loadCfgButton = uibutton(settingsGrid,'push','Text','Load V4 config', ...
    'ButtonPushedFcn',@loadConfigurationFromFile);

diagnosticsButton = uibutton(settingsGrid,'push','Text','NI diagnostics', ...
    'ButtonPushedFcn',@showDiagnostics);
closeWindowsButton = uibutton(settingsGrid,'push','Text','Close signal windows', ...
    'ButtonPushedFcn',@closeSignalWindows);

statusLabel = uilabel(settingsGrid,'Text','Ready — Vinay Shankar | vinay@tfaworld.org');
statusLabel.Layout.Column = [1 4];
statusLabel.Layout.Row = 4;
windowStatusLabel = uilabel(settingsGrid,'Text','Signal windows: 0','HorizontalAlignment','right');
windowStatusLabel.Layout.Column = [5 6];
windowStatusLabel.Layout.Row = 4;

% Channel table
channelPanel = uipanel(root,'Title','Channels — each enabled row becomes one completely separate signal window');
channelPanel.Layout.Row = 3;
channelGrid = uigridlayout(channelPanel,[1 1]);
channelGrid.Padding = [6 6 6 6];

channelTable = uitable(channelGrid);
channelTable.ColumnName = {'Use','Device','Channel','Label','Unit','Scale','Offset','Terminal','Auto Y','Y Min','Y Max'};
channelTable.ColumnEditable = true(1,11);
channelTable.ColumnWidth = {45,80,70,150,85,75,75,150,60,75,75};
channelTable.ColumnFormat = { ...
    'logical','char','char','char','char','numeric','numeric', ...
    {'Default','Differential','SingleEnded','SingleEndedNonReferenced','PseudoDifferential'}, ...
    'logical','numeric','numeric'};
channelTable.Data = defaultChannelRows(defaultDevice,16);
channelTable.CellEditCallback = @channelTableEdited;

% Bottom acquisition controls
bottom = uigridlayout(root,[1 8]);
bottom.Layout.Row = 4;
bottom.ColumnWidth = {115,115,150,130,130,'1x',180,180};
bottom.Padding = [0 4 0 0];

startButton = uibutton(bottom,'push','Text','START', ...
    'FontWeight','bold','ButtonPushedFcn',@startAcquisition);
stopButton = uibutton(bottom,'push','Text','STOP', ...
    'FontWeight','bold','Enable','off','ButtonPushedFcn',@stopAcquisition);
tareButton = uibutton(bottom,'push','Text','BASELINE / TARE', ...
    'FontWeight','bold','ButtonPushedFcn',@openBaselineScreen);
saveButton = uibutton(bottom,'push','Text','SAVE DATA', ...
    'FontWeight','bold','Enable','off','ButtonPushedFcn',@saveAcquisition);
clearButton = uibutton(bottom,'push','Text','CLEAR DISPLAY', ...
    'ButtonPushedFcn',@clearDisplays);
runStatus = uilabel(bottom,'Text','Idle');
scanStatus = uilabel(bottom,'Text','Scans: 0','HorizontalAlignment','right');
rateStatus = uilabel(bottom,'Text','Actual rate: -- Hz','HorizontalAlignment','right');

%% Restore V4-only configuration and immediately create separate windows
loadAutoConfiguration();
rebuildSignalWindowsFromTable();
if strlength(discoveryMessage) > 0
    statusLabel.Text = char(discoveryMessage);
end

%% Nested functions
    function rows = defaultChannelRows(deviceID,nRows)
        rows = cell(nRows,11);
        defaultLabels = {'Flow','EMG_1','EMG_2','Pressure'};
        defaultUnits  = {'L/s','mV','mV','cmH2O'};
        defaultYMin   = [-10,-5,-5,-20];
        defaultYMax   = [ 10, 5, 5,100];
        for k = 1:nRows
            rows{k,1} = (k <= 2);
            rows{k,2} = char(deviceID);
            rows{k,3} = sprintf('ai%d',k-1);
            if k <= numel(defaultLabels)
                rows{k,4} = defaultLabels{k};
                rows{k,5} = defaultUnits{k};
                rows{k,10} = defaultYMin(k);
                rows{k,11} = defaultYMax(k);
            else
                rows{k,4} = sprintf('Channel_%d',k);
                rows{k,5} = 'V';
                rows{k,10} = -10;
                rows{k,11} = 10;
            end
            rows{k,6} = 1;
            rows{k,7} = 0;
            rows{k,8} = 'Default';
            rows{k,9} = true;
        end
    end

    function [ids,msg] = discoverDevices(doReset)
        ids = strings(0,1);
        msg = "";
        try
            if doReset
                daqreset;
            end
            dlist = daqlist("ni");
            if ~isempty(dlist)
                ids = unique(string(dlist.DeviceID),'stable');
            else
                msg = "No NI devices detected by daqlist(""ni"").";
            end
        catch ME
            msg = "NI discovery failed: " + string(ME.message);
        end
    end

    function refreshDevices(~,~)
        [ids,msg] = discoverDevices(false);
        deviceIDs = ids; %#ok<NASGU>
        if isempty(ids)
            statusLabel.Text = char(msg);
        else
            deviceField.Value = char(ids(1));
            statusLabel.Text = sprintf('Detected NI device(s): %s',strjoin(cellstr(ids),', '));
        end
    end

    function resetAndRefresh(~,~)
        statusLabel.Text = 'Resetting DAQ...';
        drawnow;
        [ids,msg] = discoverDevices(true);
        if isempty(ids)
            statusLabel.Text = char(msg);
        else
            deviceField.Value = char(ids(1));
            statusLabel.Text = sprintf('DAQ reset complete. Detected: %s',strjoin(cellstr(ids),', '));
        end
    end

    function showDiagnostics(~,~)
        try
            vendors = evalc('disp(daqvendorlist)');
        catch ME
            vendors = ['daqvendorlist failed: ' ME.message];
        end
        try
            devices = evalc('disp(daqlist("ni"))');
        catch ME
            devices = ['daqlist("ni") failed: ' ME.message];
        end
        msg = sprintf('DAQ VENDORS\n%s\n\nNI DEVICES\n%s',vendors,devices);
        uialert(controlFig,msg,'NI diagnostics','Icon','info');
    end

    function settingsChanged(~,~)
        saveAutoConfiguration();
        updateSignalWindowXAxis();
    end

    function applyDeviceToRows(~,~)
        rows = channelTable.Data;
        for k = 1:size(rows,1)
            rows{k,2} = deviceField.Value;
        end
        channelTable.Data = rows;
        saveAutoConfiguration();
        if ~S.running
            rebuildSignalWindowsFromTable();
        end
    end

    function channelTableEdited(~,evt)
        saveAutoConfiguration();
        if ~S.running
            % Rebuild only when the edit changes window identity/appearance.
            editedColumn = evt.Indices(2);
            if ismember(editedColumn,[1 2 3 4 5 9 10 11])
                rebuildSignalWindowsFromTable();
            end
        end
    end

    function cfg = getEnabledConfig(validateAll)
        rows = channelTable.Data;
        if isempty(rows)
            error('Channel table is empty.');
        end

        useMask = false(size(rows,1),1);
        for r = 1:size(rows,1)
            useMask(r) = logical(rows{r,1});
        end
        idx = find(useMask);

        if validateAll && isempty(idx)
            error('Enable at least one channel in the Use column.');
        end

        n = numel(idx);
        devicesLocal = strings(n,1);
        channelIDsLocal = strings(n,1);
        labelsLocal = strings(n,1);
        unitsLocal = strings(n,1);
        scalesLocal = zeros(n,1);
        offsetsLocal = zeros(n,1);
        terminalsLocal = strings(n,1);
        autoYLocal = false(n,1);
        yMinLocal = zeros(n,1);
        yMaxLocal = zeros(n,1);

        for j = 1:n
            r = idx(j);
            devicesLocal(j) = string(rows{r,2});
            channelIDsLocal(j) = string(rows{r,3});
            labelsLocal(j) = string(rows{r,4});
            unitsLocal(j) = string(rows{r,5});
            scalesLocal(j) = numericCell(rows{r,6},NaN);
            offsetsLocal(j) = numericCell(rows{r,7},NaN);
            terminalsLocal(j) = string(rows{r,8});
            autoYLocal(j) = logical(rows{r,9});
            yMinLocal(j) = numericCell(rows{r,10},NaN);
            yMaxLocal(j) = numericCell(rows{r,11},NaN);

            if strlength(labelsLocal(j)) == 0
                labelsLocal(j) = "Channel_" + string(r);
            end
            if strlength(unitsLocal(j)) == 0
                unitsLocal(j) = "V";
            end

            if validateAll
                if strlength(devicesLocal(j)) == 0
                    error('Enabled row %d has a blank Device.',r);
                end
                if strlength(channelIDsLocal(j)) == 0
                    error('Enabled row %d has a blank Channel.',r);
                end
                if ~isfinite(scalesLocal(j))
                    error('Enabled row %d has an invalid Scale.',r);
                end
                if ~isfinite(offsetsLocal(j))
                    error('Enabled row %d has an invalid Offset.',r);
                end
                if ~autoYLocal(j)
                    if ~isfinite(yMinLocal(j)) || ~isfinite(yMaxLocal(j)) || yMinLocal(j) >= yMaxLocal(j)
                        error('Enabled row %d needs Y Min < Y Max when Auto Y is off.',r);
                    end
                end
            end
        end

        labelsLocal = string(matlab.lang.makeUniqueStrings(cellstr(labelsLocal)));

        if validateAll
            if ~isfinite(rateField.Value) || rateField.Value <= 0
                error('Sample rate must be a positive finite number.');
            end
            if ~isfinite(windowField.Value) || windowField.Value <= 0
                error('Plot window must be a positive finite number.');
            end
        end

        cfg = struct( ...
            'idx',idx, ...
            'devices',devicesLocal, ...
            'channelIDs',channelIDsLocal, ...
            'labels',labelsLocal, ...
            'units',unitsLocal, ...
            'scales',scalesLocal, ...
            'offsets',offsetsLocal, ...
            'terminals',terminalsLocal, ...
            'autoY',autoYLocal, ...
            'yMin',yMinLocal, ...
            'yMax',yMaxLocal, ...
            'requestedRate',rateField.Value);
    end

    function x = numericCell(v,fallback)
        if isnumeric(v) && isscalar(v)
            x = double(v);
        else
            x = str2double(string(v));
        end
        if isempty(x) || ~isscalar(x) || isnan(x)
            x = fallback;
        end
    end

    function rebuildSignalWindowsFromTable(varargin)
        if S.running
            uialert(controlFig,'Stop acquisition before rebuilding signal windows.', ...
                'Acquisition running','Icon','warning');
            return;
        end
        try
            cfg = getEnabledConfig(false);
        catch ME
            statusLabel.Text = ME.message;
            return;
        end
        createIndependentSignalWindows(cfg);
    end

    % ---------------------------------------------------------------------
    % INDEPENDENT SIGNAL WINDOWS
    % Author: Vinay Shankar | vinay@tfaworld.org | https://tfaworld.org/
    % Each enabled channel receives its own UIFigure/UIAxes by design.
    % ---------------------------------------------------------------------
    function createIndependentSignalWindows(cfg)
        closeSignalWindows();
        n = numel(cfg.labels);
        if n == 0
            windowStatusLabel.Text = 'Signal windows: 0';
            statusLabel.Text = 'Enable one or more channels, then rebuild signal windows.';
            return;
        end

        S.plotFigures = gobjects(n,1);
        S.axesHandles = gobjects(n,1);
        S.lineHandles = gobjects(n,1);
        S.valueLabels = gobjects(n,1);
        S.tareLabels = gobjects(n,1);

        scr = get(0,'ScreenSize');
        screenW = scr(3);
        screenH = scr(4);
        winW = min(720,max(520,floor(screenW*0.42)));
        winH = min(340,max(260,floor(screenH*0.33)));
        gap = 22;
        left0 = max(20,screenW-winW-40);
        top0 = max(60,screenH-winH-80);

        for ii = 1:n
            col = mod(ii-1,2);
            row = floor((ii-1)/2);
            left = max(20,left0-col*(winW+gap));
            top = max(40,top0-row*(winH+gap));

            titleText = sprintf('NI V4 — %s [%s] — %s/%s — Vinay Shankar', ...
                char(cfg.labels(ii)),char(cfg.units(ii)), ...
                char(cfg.devices(ii)),char(cfg.channelIDs(ii)));

            pf = uifigure( ...
                'Name',titleText, ...
                'Position',[left top winW winH], ...
                'CloseRequestFcn',@(src,evt)closeOneSignalWindow(src,ii));

            pg = uigridlayout(pf,[2 1]);
            pg.RowHeight = {34,'1x'};
            pg.Padding = [8 6 8 8];
            pg.RowSpacing = 4;

            header = uigridlayout(pg,[1 3]);
            header.Layout.Row = 1;
            header.ColumnWidth = {'1x',180,220};
            header.Padding = [0 0 0 0];
            uilabel(header,'Text',sprintf('%s  [%s]',char(cfg.labels(ii)),char(cfg.units(ii))), ...
                'FontWeight','bold');
            tareLabel = uilabel(header,'Text','Tare: 0','HorizontalAlignment','right');
            latest = uilabel(header,'Text','Latest: --','HorizontalAlignment','right');

            ax = uiaxes(pg);
            ax.Layout.Row = 2;
            grid(ax,'on');
            box(ax,'on');
            xlabel(ax,'Elapsed time (s)');
            ylabel(ax,char(cfg.units(ii)),'Interpreter','none');
            title(ax,sprintf('%s / %s',char(cfg.devices(ii)),char(cfg.channelIDs(ii))), ...
                'Interpreter','none','FontWeight','normal');
            ax.XLim = [0 max(windowField.Value,1)];
            if cfg.autoY(ii)
                ax.YLimMode = 'auto';
            else
                ax.YLim = [cfg.yMin(ii) cfg.yMax(ii)];
            end

            ln = plot(ax,nan,nan,'LineWidth',1);

            S.plotFigures(ii) = pf;
            S.axesHandles(ii) = ax;
            S.lineHandles(ii) = ln;
            S.valueLabels(ii) = latest;
            S.tareLabels(ii) = tareLabel;
        end

        windowStatusLabel.Text = sprintf('Signal windows: %d independent',n);
        statusLabel.Text = sprintf('Opened %d completely separate signal window(s).',n);
    end

    function closeOneSignalWindow(src,ii)
        if isgraphics(src)
            delete(src);
        end
        if ii <= numel(S.plotFigures)
            S.plotFigures(ii) = gobjects(1);
        end
        updateOpenWindowCount();
    end

    function closeSignalWindows(varargin)
        for k = 1:numel(S.plotFigures)
            if isgraphics(S.plotFigures(k))
                try
                    delete(S.plotFigures(k));
                catch
                end
            end
        end
        S.plotFigures = gobjects(0);
        S.axesHandles = gobjects(0);
        S.lineHandles = gobjects(0);
        S.valueLabels = gobjects(0);
        S.tareLabels = gobjects(0);
        windowStatusLabel.Text = 'Signal windows: 0';
    end

    function updateOpenWindowCount()
        nOpen = 0;
        for k = 1:numel(S.plotFigures)
            if isgraphics(S.plotFigures(k))
                nOpen = nOpen + 1;
            end
        end
        windowStatusLabel.Text = sprintf('Signal windows: %d open',nOpen);
    end

    function startAcquisition(~,~)
        if S.running
            return;
        end
        try
            cfg = getEnabledConfig(true);
        catch ME
            uialert(controlFig,ME.message,'Configuration error','Icon','error');
            return;
        end

        if S.dirty && ~isempty(S.scaledData)
            choice = uiconfirm(controlFig, ...
                'Starting a new acquisition will clear unsaved data in memory.', ...
                'Unsaved data','Options',{'Start new','Cancel'}, ...
                'DefaultOption',2,'CancelOption',2);
            if strcmp(choice,'Cancel')
                return;
            end
        end

        saveAutoConfiguration();
        cleanupDAQ();
        resetAcquisitionBuffers();

        try
            dq = daq("ni");
            for ii = 1:numel(cfg.labels)
                ch = addinput(dq,cfg.devices(ii),cfg.channelIDs(ii),"Voltage");
                if cfg.terminals(ii) ~= "Default"
                    ch.TerminalConfig = cfg.terminals(ii);
                end
            end

            dq.Rate = cfg.requestedRate;
            S.actualRate = dq.Rate;

            % IMPORTANT (V4.0.2): Do not force ScansAvailableFcnCount to
            % Rate/20. MATLAB/NI enforces a lower bound of Rate/20 and
            % automatically chooses a valid default (normally Rate/10).
            % Leaving the property at its MATLAB-selected value avoids
            % boundary/coercion errors such as:
            %   "At the specified rate, the minimum count allowed is 500."
            S.callbackScanCount = double(dq.ScansAvailableFcnCount);
            dq.ScansAvailableFcn = @scansAvailable;
            dq.ErrorOccurredFcn = @daqErrorOccurred;

            S.dq = dq;
            S.labels = cfg.labels;
            S.units = cfg.units;
            S.devices = cfg.devices;
            S.channelIDs = cfg.channelIDs;
            S.scales = cfg.scales;
            S.offsets = cfg.offsets;
            S.tareOffsets = zeros(numel(cfg.labels),1);
            S.baselineMeans = nan(numel(cfg.labels),1);
            S.baselineDuration = NaN;
            S.tareTimestampUTCms = NaN;
            S.terminals = cfg.terminals;
            S.autoY = cfg.autoY;
            S.yMin = cfg.yMin;
            S.yMax = cfg.yMax;
            S.rawData = zeros(0,numel(cfg.labels));
            S.scaledData = zeros(0,numel(cfg.labels));
            S.timeSec = zeros(0,1);
            S.triggerUTCms = NaN;
            S.running = true;
            S.dirty = true;
            S.lastError = "";

            % Recreate signal windows from the exact channels being acquired.
            createIndependentSignalWindows(cfg);
            setRunningControls(true);
            runStatus.Text = 'RUNNING';
            statusLabel.Text = 'Acquiring...';
            scanStatus.Text = 'Scans: 0';
            rateStatus.Text = sprintf('Actual rate: %.3f Hz',S.actualRate);

            start(dq,"continuous");
            refreshBaselineScreen();
        catch ME
            cleanupDAQ();
            S.running = false;
            S.dirty = false;
            setRunningControls(false);
            uialert(controlFig,ME.message,'DAQ start failed','Icon','error');
            statusLabel.Text = 'DAQ start failed';
        end
    end

    function scansAvailable(src,~)
        if isempty(S.dq)
            return;
        end
        try
            % The callback only fires after ScansAvailableFcnCount scans
            % are buffered. Read exactly that valid MATLAB-selected block.
            nToRead = double(src.ScansAvailableFcnCount);
            [chunk,timestamps,triggerTime] = read(src,nToRead,OutputFormat="Matrix");
            ingestChunk(chunk,timestamps,triggerTime);
        catch ME
            S.lastError = string(ME.message);
            statusLabel.Text = ['Read error: ' ME.message];
        end
    end

    function ingestChunk(chunk,timestamps,triggerTime)
        if isempty(chunk)
            return;
        end
        if size(chunk,2) ~= numel(S.labels)
            error('Received %d channels but V4 expected %d.',size(chunk,2),numel(S.labels));
        end

        if isnan(S.triggerUTCms)
            S.triggerUTCms = triggerTimeToUTCms(triggerTime);
        end

        timestamps = double(timestamps(:));
        calibrated = chunk .* reshape(S.scales,1,[]) + reshape(S.offsets,1,[]);
        if numel(S.tareOffsets) ~= numel(S.labels)
            S.tareOffsets = zeros(numel(S.labels),1);
        end
        scaled = calibrated + reshape(S.tareOffsets,1,[]);

        S.rawData = [S.rawData; chunk]; %#ok<AGROW>
        S.scaledData = [S.scaledData; scaled]; %#ok<AGROW>
        S.timeSec = [S.timeSec; timestamps]; %#ok<AGROW>

        scanStatus.Text = sprintf('Scans: %d',size(S.scaledData,1));
        updateLiveSignalWindows();
    end

    function utcMs = triggerTimeToUTCms(triggerTime)
        % With OutputFormat="Matrix", MathWorks returns triggerTime as a
        % datenum double and timestamps as seconds relative to the first scan.
        dt = datetime(triggerTime,'ConvertFrom','datenum','TimeZone','local');
        dt.TimeZone = 'UTC';
        utcMs = posixtime(dt) * 1000;
    end

    function updateLiveSignalWindows()
        if isempty(S.scaledData) || isempty(S.timeSec)
            return;
        end

        tEnd = S.timeSec(end);
        tStart = max(0,tEnd-windowField.Value);
        i0 = find(S.timeSec >= tStart,1,'first');
        if isempty(i0), i0 = 1; end
        idx = i0:numel(S.timeSec);
        step = max(1,ceil(numel(idx)/S.maxPlotPoints));
        idxPlot = idx(1:step:end);
        x = S.timeSec(idxPlot);

        if tEnd > windowField.Value
            xl = [tEnd-windowField.Value,tEnd];
        else
            xl = [0,max(windowField.Value,tEnd+eps)];
        end

        for ii = 1:numel(S.labels)
            if ii <= numel(S.lineHandles) && isgraphics(S.lineHandles(ii))
                S.lineHandles(ii).XData = x;
                S.lineHandles(ii).YData = S.scaledData(idxPlot,ii);
            end
            if ii <= numel(S.axesHandles) && isgraphics(S.axesHandles(ii))
                S.axesHandles(ii).XLim = xl;
                if S.autoY(ii)
                    S.axesHandles(ii).YLimMode = 'auto';
                else
                    S.axesHandles(ii).YLim = [S.yMin(ii) S.yMax(ii)];
                end
            end
            if ii <= numel(S.tareLabels) && isgraphics(S.tareLabels(ii))
                tareVal = 0;
                if ii <= numel(S.tareOffsets), tareVal = S.tareOffsets(ii); end
                S.tareLabels(ii).Text = sprintf('Tare: %+.6g %s',tareVal,char(S.units(ii)));
            end
            if ii <= numel(S.valueLabels) && isgraphics(S.valueLabels(ii))
                S.valueLabels(ii).Text = sprintf('Latest: %.6g %s', ...
                    S.scaledData(end,ii),char(S.units(ii)));
            end
        end
        drawnow limitrate nocallbacks;
    end

    function updateSignalWindowXAxis()
        for ii = 1:numel(S.axesHandles)
            if isgraphics(S.axesHandles(ii)) && isempty(S.timeSec)
                S.axesHandles(ii).XLim = [0 max(windowField.Value,1)];
            end
        end
    end

    function stopAcquisition(~,~)
        if ~S.running || isempty(S.dq)
            return;
        end
        statusLabel.Text = 'Stopping...';
        drawnow;
        try
            stop(S.dq);
        catch ME
            S.lastError = string(ME.message);
        end

        % Read any scans still buffered after stop.
        try
            [chunk,timestamps,triggerTime] = read(S.dq,"all",OutputFormat="Matrix");
            if ~isempty(chunk)
                ingestChunk(chunk,timestamps,triggerTime);
            end
        catch ME
            S.lastError = string(ME.message);
        end

        S.running = false;
        setRunningControls(false);
        runStatus.Text = 'STOPPED';
        if isempty(S.scaledData)
            saveButton.Enable = 'off';
            statusLabel.Text = 'Stopped. No samples acquired.';
        else
            saveButton.Enable = 'on';
            statusLabel.Text = sprintf('Stopped. %d scans in memory.',size(S.scaledData,1));
        end
        refreshBaselineScreen();
    end

    function daqErrorOccurred(~,evt)
        try
            msg = string(evt.Error.Message);
        catch
            msg = "DAQ error occurred.";
        end
        S.lastError = msg;
        statusLabel.Text = char(msg);
    end

    function clearDisplays(~,~)
        for ii = 1:numel(S.lineHandles)
            if isgraphics(S.lineHandles(ii))
                S.lineHandles(ii).XData = nan;
                S.lineHandles(ii).YData = nan;
            end
            if ii <= numel(S.tareLabels) && isgraphics(S.tareLabels(ii))
                tareVal = 0;
                if ii <= numel(S.tareOffsets), tareVal = S.tareOffsets(ii); end
                S.tareLabels(ii).Text = sprintf('Tare: %+.6g %s',tareVal,char(S.units(ii)));
            end
            if ii <= numel(S.valueLabels) && isgraphics(S.valueLabels(ii))
                S.valueLabels(ii).Text = 'Latest: --';
            end
        end
    end

    % ---------------------------------------------------------------------
    % BASELINE / TARE IMPLEMENTATION
    % Author: Vinay Shankar | vinay@tfaworld.org | https://tfaworld.org/
    % TARE is stored separately from physical calibration Scale/Offset.
    % ---------------------------------------------------------------------
    function openBaselineScreen(~,~)
        if isgraphics(S.baselineFig)
            S.baselineFig.Visible = 'on';
            refreshBaselineScreen();
            return;
        end

        S.baselineFig = uifigure( ...
            'Name',['Baseline / TARE — NI Recorder ' char(APP_VERSION) ' — Vinay Shankar'], ...
            'Position',[180 140 850 520], ...
            'CloseRequestFcn',@closeBaselineScreen);

        bg = uigridlayout(S.baselineFig,[5 1]);
        bg.RowHeight = {55,46,'1x',52,32};
        bg.Padding = [10 10 10 10];
        bg.RowSpacing = 8;

        info = uilabel(bg, ...
            'Text',['TARE subtracts the mean of the most recent baseline window from selected channels. ' ...
                    'It does not change the channel Scale or calibration Offset.  Recorder author: Vinay Shankar (vinay@tfaworld.org).'], ...
            'WordWrap','on');
        info.Layout.Row = 1;

        controls = uigridlayout(bg,[1 5]);
        controls.Layout.Row = 2;
        controls.ColumnWidth = {145,110,130,130,'1x'};
        controls.Padding = [0 0 0 0];
        uilabel(controls,'Text','Baseline duration (s)');
        S.baselineDurationField = uieditfield(controls,'numeric', ...
            'Value',baselineDurationSetting,'Limits',[0.05 Inf], ...
            'ValueChangedFcn',@baselineDurationChanged);
        uibutton(controls,'push','Text','TARE SELECTED', ...
            'FontWeight','bold','ButtonPushedFcn',@tareSelectedChannels);
        uibutton(controls,'push','Text','CLEAR SELECTED', ...
            'ButtonPushedFcn',@clearSelectedTare);
        uilabel(controls,'Text','Use a quiet/stable baseline before pressing TARE.', ...
            'HorizontalAlignment','right');

        S.baselineTable = uitable(bg);
        S.baselineTable.Layout.Row = 3;
        S.baselineTable.ColumnName = { ...
            'Tare','Channel','Unit','Baseline mean (pre-tare)','Tare correction','Zeroed mean'};
        S.baselineTable.ColumnEditable = [true false false false false false];
        S.baselineTable.ColumnWidth = {55,180,90,155,145,125};
        S.baselineTable.ColumnFormat = {'logical','char','char','numeric','numeric','numeric'};

        buttons = uigridlayout(bg,[1 3]);
        buttons.Layout.Row = 4;
        buttons.ColumnWidth = {170,170,'1x'};
        buttons.Padding = [0 0 0 0];
        uibutton(buttons,'push','Text','Select all', ...
            'ButtonPushedFcn',@(src,evt)setBaselineSelection(true));
        uibutton(buttons,'push','Text','Select none', ...
            'ButtonPushedFcn',@(src,evt)setBaselineSelection(false));
        uilabel(buttons,'Text','Tare is runtime/session-specific and is not saved as a reusable configuration.', ...
            'HorizontalAlignment','right');

        S.baselineStatusLabel = uilabel(bg,'Text','');
        S.baselineStatusLabel.Layout.Row = 5;
        refreshBaselineScreen();
    end

    function baselineDurationChanged(src,~)
        baselineDurationSetting = src.Value;
        saveAutoConfiguration();
        refreshBaselineScreen();
    end

    function setBaselineSelection(value)
        if ~isgraphics(S.baselineTable)
            return;
        end
        d = S.baselineTable.Data;
        for rr = 1:size(d,1)
            d{rr,1} = logical(value);
        end
        S.baselineTable.Data = d;
    end

    function refreshBaselineScreen()
        if ~isgraphics(S.baselineFig) || ~isgraphics(S.baselineTable)
            return;
        end

        previousSelection = [];
        oldData = S.baselineTable.Data;
        if iscell(oldData) && ~isempty(oldData)
            try
                previousSelection = cellfun(@logical,oldData(:,1));
            catch
                previousSelection = [];
            end
        end

        if S.running && ~isempty(S.labels)
            labelsNow = S.labels;
            unitsNow = S.units;
            n = numel(labelsNow);
            tareNow = S.tareOffsets;
            meansNow = S.baselineMeans;
        else
            try
                cfg = getEnabledConfig(false);
                labelsNow = cfg.labels;
                unitsNow = cfg.units;
                n = numel(labelsNow);
            catch
                labelsNow = strings(0,1);
                unitsNow = strings(0,1);
                n = 0;
            end
            tareNow = zeros(n,1);
            meansNow = nan(n,1);
        end

        if numel(tareNow) ~= n, tareNow = zeros(n,1); end
        if numel(meansNow) ~= n, meansNow = nan(n,1); end

        d = cell(n,6);
        for ii = 1:n
            if numel(previousSelection) == n
                d{ii,1} = logical(previousSelection(ii));
            else
                d{ii,1} = true;
            end
            d{ii,2} = char(labelsNow(ii));
            d{ii,3} = char(unitsNow(ii));
            d{ii,4} = meansNow(ii);
            d{ii,5} = tareNow(ii);
            if isfinite(meansNow(ii))
                d{ii,6} = meansNow(ii) + tareNow(ii);
            else
                d{ii,6} = NaN;
            end
        end
        S.baselineTable.Data = d;

        if isgraphics(S.baselineDurationField)
            S.baselineDurationField.Value = baselineDurationSetting;
        end
        if isgraphics(S.baselineStatusLabel)
            if ~S.running
                S.baselineStatusLabel.Text = 'Start acquisition to collect baseline samples. The TARE screen may remain open.';
            elseif isempty(S.rawData)
                S.baselineStatusLabel.Text = 'Acquiring... waiting for baseline samples.';
            else
                available = max(0,S.timeSec(end)-S.timeSec(1));
                S.baselineStatusLabel.Text = sprintf( ...
                    'Running. %.3f s of data currently available; requested baseline = %.3f s.', ...
                    available,baselineDurationSetting);
            end
        end
    end

    function tareSelectedChannels(~,~)
        if ~S.running || isempty(S.rawData) || isempty(S.timeSec)
            uialert(S.baselineFig,'Start acquisition and collect baseline data before TARE.', ...
                'No baseline data','Icon','warning');
            return;
        end
        if ~isgraphics(S.baselineTable)
            return;
        end

        duration = baselineDurationSetting;
        if isgraphics(S.baselineDurationField)
            duration = S.baselineDurationField.Value;
            baselineDurationSetting = duration;
        end
        if ~isfinite(duration) || duration <= 0
            uialert(S.baselineFig,'Baseline duration must be greater than 0 seconds.', ...
                'Invalid duration','Icon','error');
            return;
        end

        available = S.timeSec(end)-S.timeSec(1);
        if available + (1/max(S.actualRate,eps)) < duration
            uialert(S.baselineFig, ...
                sprintf('Only %.3f s of data are available. Collect at least %.3f s before TARE.',available,duration), ...
                'Need more baseline','Icon','warning');
            return;
        end

        d = S.baselineTable.Data;
        applyMask = false(numel(S.labels),1);
        for ii = 1:min(size(d,1),numel(S.labels))
            applyMask(ii) = logical(d{ii,1});
        end
        if ~any(applyMask)
            uialert(S.baselineFig,'Select at least one channel in the Tare column.', ...
                'No channels selected','Icon','warning');
            return;
        end

        tEnd = S.timeSec(end);
        idx = S.timeSec >= (tEnd-duration);
        calibratedBaseline = S.rawData(idx,:) .* reshape(S.scales,1,[]) + reshape(S.offsets,1,[]);
        means = reshape(mean(calibratedBaseline,1,'omitnan'),[],1);

        S.tareOffsets(applyMask) = -means(applyMask);
        S.baselineMeans(applyMask) = means(applyMask);
        S.baselineDuration = duration;
        S.tareTimestampUTCms = S.triggerUTCms + tEnd*1000;

        recomputeTaredData();
        S.dirty = true;
        updateLiveSignalWindows();
        refreshBaselineScreen();
        statusLabel.Text = sprintf('TARE applied to %d channel(s) using %.3f s baseline.', ...
            nnz(applyMask),duration);
        if isgraphics(S.baselineStatusLabel)
            S.baselineStatusLabel.Text = sprintf( ...
                'TARE complete: %d channel(s), %.3f s baseline. Zeroed mean should be approximately 0.', ...
                nnz(applyMask),duration);
        end
    end

    function clearSelectedTare(~,~)
        if isempty(S.labels)
            return;
        end
        if ~isgraphics(S.baselineTable)
            return;
        end
        d = S.baselineTable.Data;
        clearMask = false(numel(S.labels),1);
        for ii = 1:min(size(d,1),numel(S.labels))
            clearMask(ii) = logical(d{ii,1});
        end
        if ~any(clearMask)
            return;
        end

        S.tareOffsets(clearMask) = 0;
        S.baselineMeans(clearMask) = NaN;
        if ~any(abs(S.tareOffsets) > 0)
            S.baselineDuration = NaN;
            S.tareTimestampUTCms = NaN;
        end
        recomputeTaredData();
        updateLiveSignalWindows();
        refreshBaselineScreen();
        statusLabel.Text = sprintf('Cleared TARE from %d channel(s).',nnz(clearMask));
    end

    function recomputeTaredData()
        if isempty(S.rawData)
            S.scaledData = zeros(0,numel(S.labels));
            return;
        end
        calibrated = S.rawData .* reshape(S.scales,1,[]) + reshape(S.offsets,1,[]);
        if numel(S.tareOffsets) ~= numel(S.labels)
            S.tareOffsets = zeros(numel(S.labels),1);
        end
        S.scaledData = calibrated + reshape(S.tareOffsets,1,[]);
    end

    function closeBaselineScreen(varargin)
        if isgraphics(S.baselineFig)
            try
                delete(S.baselineFig);
            catch
            end
        end
        S.baselineFig = gobjects(0);
        S.baselineTable = gobjects(0);
        S.baselineDurationField = gobjects(0);
        S.baselineStatusLabel = gobjects(0);
    end

    % ---------------------------------------------------------------------
    % DATA EXPORT / PROVENANCE
    % Author: Vinay Shankar | vinay@tfaworld.org | https://tfaworld.org/
    % Saved MAT metadata records project authorship and contact information.
    % ---------------------------------------------------------------------
    function saveAcquisition(~,~)
        if isempty(S.scaledData) || isempty(S.timeSec) || isnan(S.triggerUTCms)
            uialert(controlFig,'There is no timestamped acquisition in memory.','Nothing to save','Icon','warning');
            return;
        end

        [file,path] = uiputfile({'*.csv','CSV file (*.csv)';'*.mat','MAT-file (*.mat)'}, ...
            'Save V4 acquisition');
        if isequal(file,0)
            return;
        end
        fullName = fullfile(path,file);
        [~,~,ext] = fileparts(fullName);
        if isempty(ext)
            fullName = [fullName '.csv'];
            ext = '.csv';
        end

        sampleStartUTCms = S.triggerUTCms + S.timeSec*1000;
        metadata = buildMetadata();

        try
            if strcmpi(ext,'.mat')
                rawData = S.rawData; %#ok<NASGU>
                scaledData = S.scaledData; %#ok<NASGU>
                save(fullName,'sampleStartUTCms','rawData','scaledData','metadata');
            else
                T = table(sampleStartUTCms,'VariableNames',{'SampleStartUTC_ms'});
                usedNames = {'SampleStartUTC_ms'};
                for ii = 1:numel(S.labels)
                    base = matlab.lang.makeValidName(char(S.labels(ii) + "_" + sanitizeUnitForName(S.units(ii))));
                    candidate = matlab.lang.makeUniqueStrings(base,usedNames);
                    usedNames{end+1} = candidate; %#ok<AGROW>
                    T.(candidate) = S.scaledData(:,ii);
                end
                writetable(T,fullName);
            end
            S.dirty = false;
            statusLabel.Text = ['Saved: ' fullName];
        catch ME
            uialert(controlFig,ME.message,'Save failed','Icon','error');
        end
    end

    function s = sanitizeUnitForName(unitText)
        s = string(unitText);
        s = replace(s,"/","_per_");
        s = replace(s,"%","percent");
        s = replace(s,"°","deg");
        s = regexprep(s,'[^A-Za-z0-9_]+','_');
        if strlength(s) == 0
            s = "unit";
        end
    end

    function metadata = buildMetadata()
        metadata = struct();
        metadata.App = "NI_MultiChannel_Recorder_v4_03";
        metadata.AppVersion = APP_VERSION;
        metadata.Author = AUTHOR_NAME;
        metadata.AuthorEmail = AUTHOR_EMAIL;
        metadata.AuthorWebsite = AUTHOR_WEBSITE;
        metadata.ProjectRepository = PROJECT_REPOSITORY;
        metadata.License = PROJECT_LICENSE;
        metadata.Device = S.devices;
        metadata.ChannelID = S.channelIDs;
        metadata.Label = S.labels;
        metadata.Unit = S.units;
        metadata.Scale = S.scales;
        metadata.Offset = S.offsets; % calibration offset (backward-compatible field)
        metadata.CalibrationOffset = S.offsets;
        metadata.TareOffset = S.tareOffsets;
        metadata.BaselineMean_PreTare = S.baselineMeans;
        metadata.BaselineDuration_s = S.baselineDuration;
        metadata.TareUTC_ms = S.tareTimestampUTCms;
        metadata.OutputDefinition = "rawVoltage .* Scale + CalibrationOffset + TareOffset";
        metadata.Terminal = S.terminals;
        metadata.AutoY = S.autoY;
        metadata.YMin = S.yMin;
        metadata.YMax = S.yMax;
        metadata.ActualRate_Hz = S.actualRate;
        metadata.TimeColumn = "SampleStartUTC_ms";
        metadata.TriggerUTC_ms = S.triggerUTCms;
        metadata.TimestampDefinition = "TriggerUTC_ms + relative scan timestamp seconds * 1000";
    end

    function saveConfigurationAs(~,~)
        config = collectConfiguration(); %#ok<NASGU>
        [file,path] = uiputfile('*.mat','Save V4 configuration','NI_V4_Config.mat');
        if isequal(file,0)
            return;
        end
        try
            save(fullfile(path,file),'config');
            statusLabel.Text = ['Saved V4 configuration: ' fullfile(path,file)];
        catch ME
            uialert(controlFig,ME.message,'Configuration save failed','Icon','error');
        end
    end

    function loadConfigurationFromFile(~,~)
        [file,path] = uigetfile('*.mat','Load V4 configuration');
        if isequal(file,0)
            return;
        end
        try
            x = load(fullfile(path,file),'config');
            if ~isfield(x,'config')
                error('Selected MAT-file does not contain a variable named config.');
            end
            applyConfiguration(x.config);
            saveAutoConfiguration();
            if ~S.running
                rebuildSignalWindowsFromTable();
            end
            statusLabel.Text = ['Loaded V4 configuration: ' fullfile(path,file)];
        catch ME
            uialert(controlFig,ME.message,'Configuration load failed','Icon','error');
        end
    end

    % ---------------------------------------------------------------------
    % CONFIGURATION PERSISTENCE
    % Author: Vinay Shankar | vinay@tfaworld.org | https://tfaworld.org/
    % Hardware/channel configuration persists; session TARE does not.
    % ---------------------------------------------------------------------
    function config = collectConfiguration()
        config = struct();
        config.Version = APP_VERSION;
        config.Author = AUTHOR_NAME;
        config.AuthorEmail = AUTHOR_EMAIL;
        config.AuthorWebsite = AUTHOR_WEBSITE;
        config.ProjectRepository = PROJECT_REPOSITORY;
        config.ChannelTableData = channelTable.Data;
        config.DefaultDevice = deviceField.Value;
        config.SampleRate = rateField.Value;
        config.PlotWindow = windowField.Value;
        config.BaselineDuration = baselineDurationSetting;
    end

    function applyConfiguration(config)
        if isfield(config,'ChannelTableData')
            rows = upgradeRowsToV4(config.ChannelTableData);
            channelTable.Data = rows;
        end
        if isfield(config,'DefaultDevice')
            deviceField.Value = char(string(config.DefaultDevice));
        end
        if isfield(config,'SampleRate') && isnumeric(config.SampleRate) && isfinite(config.SampleRate)
            rateField.Value = config.SampleRate;
        end
        if isfield(config,'PlotWindow') && isnumeric(config.PlotWindow) && isfinite(config.PlotWindow)
            windowField.Value = config.PlotWindow;
        end
        if isfield(config,'BaselineDuration') && isnumeric(config.BaselineDuration) && ...
                isscalar(config.BaselineDuration) && isfinite(config.BaselineDuration) && config.BaselineDuration > 0
            baselineDurationSetting = double(config.BaselineDuration);
        end
    end

    function rows = upgradeRowsToV4(rows)
        % Allows manually loaded older table layouts to be upgraded, while
        % the automatic V4 config remains completely separate.
        if istable(rows)
            rows = table2cell(rows);
        end
        if ~iscell(rows)
            error('ChannelTableData must be a cell array or table.');
        end
        n = size(rows,1);
        oldCols = size(rows,2);
        if oldCols < 11
            upgraded = defaultChannelRows(string(deviceField.Value),max(n,16));
            for r = 1:n
                for c = 1:min(oldCols,8)
                    upgraded{r,c} = rows{r,c};
                end
                if oldCols >= 9
                    upgraded{r,9} = rows{r,9};
                end
            end
            rows = upgraded;
        elseif oldCols > 11
            rows = rows(:,1:11);
        end
    end

    function saveAutoConfiguration()
        if ~isgraphics(controlFig)
            return;
        end
        try
            config = collectConfiguration(); %#ok<NASGU>
            save(AUTO_CONFIG_FILE,'config');
        catch
            % Automatic persistence should never interrupt acquisition/UI.
        end
    end

    function loadAutoConfiguration()
        if ~isfile(AUTO_CONFIG_FILE)
            return;
        end
        try
            x = load(AUTO_CONFIG_FILE,'config');
            if isfield(x,'config')
                applyConfiguration(x.config);
            end
        catch
            % If a prior V4 config is corrupted, retain defaults.
        end
    end

    function setRunningControls(isRunning)
        if isRunning
            startButton.Enable = 'off';
            stopButton.Enable = 'on';
            saveButton.Enable = 'off';
            channelTable.Enable = 'off';
            rateField.Enable = 'off';
            deviceField.Enable = 'off';
            applyDeviceButton.Enable = 'off';
            refreshButton.Enable = 'off';
            resetButton.Enable = 'off';
            loadCfgButton.Enable = 'off';
            openWindowsButton.Enable = 'off';
        else
            startButton.Enable = 'on';
            stopButton.Enable = 'off';
            channelTable.Enable = 'on';
            rateField.Enable = 'on';
            deviceField.Enable = 'on';
            applyDeviceButton.Enable = 'on';
            refreshButton.Enable = 'on';
            resetButton.Enable = 'on';
            loadCfgButton.Enable = 'on';
            openWindowsButton.Enable = 'on';
            if isempty(S.scaledData)
                saveButton.Enable = 'off';
            else
                saveButton.Enable = 'on';
            end
        end
    end

    function resetAcquisitionBuffers()
        S.rawData = zeros(0,0);
        S.scaledData = zeros(0,0);
        S.timeSec = zeros(0,1);
        S.triggerUTCms = NaN;
        S.actualRate = NaN;
        S.tareOffsets = zeros(0,1);
        S.baselineMeans = zeros(0,1);
        S.baselineDuration = NaN;
        S.tareTimestampUTCms = NaN;
        S.dirty = false;
        scanStatus.Text = 'Scans: 0';
        rateStatus.Text = 'Actual rate: -- Hz';
    end

    function cleanupDAQ()
        if ~isempty(S.dq)
            try
                if S.dq.Running
                    stop(S.dq);
                end
            catch
            end
        end
        S.dq = [];
    end

    % ---------------------------------------------------------------------
    % APPLICATION LIFECYCLE
    % Maintained by Vinay Shankar | vinay@tfaworld.org | https://tfaworld.org/
    % ---------------------------------------------------------------------
    function closeApplication(~,~)
        if S.running
            try
                stop(S.dq);
            catch
            end
            S.running = false;
        end
        if S.dirty && ~isempty(S.scaledData)
            choice = uiconfirm(controlFig, ...
                'Acquired data are still unsaved. Close V4 anyway?', ...
                'Unsaved data','Options',{'Close','Cancel'}, ...
                'DefaultOption',2,'CancelOption',2);
            if strcmp(choice,'Cancel')
                return;
            end
        end
        saveAutoConfiguration();
        cleanupDAQ();
        closeSignalWindows();
        closeBaselineScreen();
        delete(controlFig);
    end
end
