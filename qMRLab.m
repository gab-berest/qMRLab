function varargout = qMRLab(varargin)
% qmrlab MATLAB code for qMRLab.fig
% GUI to simulate/fit qMRI data

% ----------------------------------------------------------------------------------------------------
% Written by: Jean-Fran�ois Cabana, 2016
%
% -- MTSAT functionality: P. Beliveau, 2017
% -- File Browser changes: P. Beliveau 2017
% ----------------------------------------------------------------------------------------------------
% If you use qMRLab in your work, please cite :

% Cabana, JF. et al (2016).
% Quantitative magnetization transfer imaging made easy with qMRLab
% Software for data simulation, analysis and visualization.
% Concepts in Magnetic Resonance Part A
% ----------------------------------------------------------------------------------------------------

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name', mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @qMRLab_OpeningFcn, ...
    'gui_OutputFcn',  @qMRLab_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before qMRLab is made visible.
function qMRLab_OpeningFcn(hObject, eventdata, handles, varargin)
if ~isfield(handles,'opened') % qMRI already opened?
    handles.opened = 1;
    clc;
    % startup;
    qMRLabDir = fileparts(which(mfilename()));
    addpath(genpath(qMRLabDir));
    handles.root = qMRLabDir;
    handles.methodfiles = '';
    handles.CurrentData = [];
    handles.FitDataDim = [];
    handles.FitDataSize = [];
    handles.FitDataSlice = [];
    handles.dcm_obj = [];
    MethodList = {}; SetAppData(MethodList);
    handles.output = hObject;
    guidata(hObject, handles);
        
    
    % SET WINDOW AND PANELS
    movegui(gcf,'center')
    CurrentPos = get(gcf, 'Position');
    NewPos     = CurrentPos;
    NewPos(1)  = CurrentPos(1) - 40;
    set(gcf, 'Position', NewPos);
    
    % Fill Menu with models
    handles.ModelDir = [qMRLabDir filesep 'Models'];
    guidata(hObject, handles);
    addModelMenu(hObject, eventdata, handles);
    
    % Fill FileBrowser with buttons
    MethodList = getappdata(0, 'MethodList');
    MethodList = strrep(MethodList, '.m', '');
    flist = findall(0,'type','figure');
    for iMethod=1:length(MethodList)
        
        Modelfun = str2func(MethodList{iMethod});
        Model = Modelfun();
        close(setdiff(findall(0,'type','figure'),flist)); % close figures that might open when calling models
        MRIinputs = Model.MRIinputs;
        % create file browser uicontrol with specific inputs
        FileBrowserList(iMethod) = MethodBrowser(handles.FitDataFileBrowserPanel,handles,{MethodList{iMethod} MRIinputs{:}});
        FileBrowserList(iMethod).Visible('off');
        
    end

    SetAppData(FileBrowserList);
    
    % LOAD DEFAULTS
    if ~isempty(varargin)
        Model = varargin{1};
        SetAppData(Model);
        Method = class(Model);
        if length(varargin)>1
            data=varargin{2};
            for ff=fieldnames(data)';
                FileBrowserList(strcmp([FileBrowserList.MethodID],Method)).setFileName(ff{1}, data.(ff{1}))
            end
        end
    else
        load(fullfile(handles.root,'Common','Parameters','DefaultMethod.mat'));
    end
    
    % Set Default
    methods = sct_tools_ls([handles.ModelDir filesep '*.m'], 0,0,2,1);
    i = 1;
    while ~strcmp(Method, methods{i})
        i = i+1;
    end  
    set(handles.MethodSelection, 'Value', i);
    
    
    MethodMenu(hObject, eventdata, handles, Method);
else
    OpenOptionsPanel_Callback(hObject, eventdata, handles)
end

% Outputs from this function are returned to the command line.
function varargout = qMRLab_OutputFcn(hObject, eventdata, handles)
varargout{1} = handles.output;
wh=findall(0,'tag','TMWWaitbar');
delete(wh);

% Executes when user attempts to close qMRLab.
function qMRLab_CloseRequestFcn(hObject, eventdata, handles)
h = findobj('Tag','OptionsGUI');
delete(findobj('Tag','Simu'))
delete(h);
delete(hObject);
% cd(handles.root);
AppData = getappdata(0);
Fields = fieldnames(AppData);
for k=1:length(Fields)
    rmappdata(0, Fields{k});
end

function MethodSelection_Callback(hObject, eventdata, handles)
Method = GetMethod(handles);
MethodMenu(hObject,eventdata,handles,Method);

function addModelMenu(hObject, eventdata, handles)
methods = sct_tools_ls([handles.ModelDir filesep '*.m'],0,0,2,1);
methodsM = strcat(sct_tools_ls([handles.ModelDir filesep '*.m'],0,0,2,1),'.m'); 
MethodList = GetAppData('MethodList');
MethodList = {MethodList{:} methodsM{:}};
SetAppData(MethodList)


%###########################################################################################
%                                 COMMON FUNCTIONS
%###########################################################################################

% METHODSELECTION
function MethodMenu(hObject, eventdata, handles, Method)

% Display all the options in the popupmenu
list = sct_tools_ls([handles.ModelDir filesep '*.m'],1,0,2,1);
choices = strrep(list{1},[handles.ModelDir filesep],'');
for i = 2:length(list)
    choices = strvcat(choices, strrep(list{i},[handles.ModelDir filesep],''));
end
set(handles.MethodSelection,'String',choices);


SetAppData(Method)

% Start by updating the Model object
if isappdata(0,'Model') && strcmp(class(getappdata(0,'Model')),Method) % if same method, load the current class with parameters
    Model = getappdata(0,'Model');
else % otherwise create a new object of this method
    modelfun  = str2func(Method);
    Model = modelfun();
end
SetAppData(Model)


% Now create Simulation panel
handles.methodfiles = fullfile(handles.root,'Models_Functions',[Method 'fun']);
% find the Simulation functions of the selected Method
Methodfun = methods(Method);
Simfun = Methodfun(~cellfun(@isempty,strfind(Methodfun,'Sim_')));
% Update Options Panel
set(handles.SimPanel,'Visible','off') % hide the simulation panel for qMT methods
if isempty(Simfun)
    set(handles.SimPanel,'Visible','off') % hide the simulation panel
else
    set(handles.SimPanel,'Visible','on') % show the simulation panel
    delete(setdiff(findobj(handles.SimPanel),handles.SimPanel))
    
    N = length(Simfun); %
    Jh = min(0.14,.8/N);
    J=1:max(N,6); J=(J-1)/max(N,6)*0.85; J=1-J-Jh-.01;
    for i = 1:N
        if exist([Simfun{i} '_GUI'],'file')
            uicontrol('Style','pushbutton','String',strrep(strrep(Simfun{i},'Sim_',''),'_',' '),...
                'Parent',handles.SimPanel,'Units','normalized','Position',[.04 J(i) .92 Jh],...
                'HorizontalAlignment','center','FontWeight','bold','Callback',...
                @(x,y) SimfunGUI([Simfun{i} '_GUI']));
        end
    end
    
end


% Update Options Panel
h = findobj('Tag','OptionsGUI');
if ~isempty(h)
    delete(h);
end
OpenOptionsPanel_Callback(hObject, eventdata, handles)

% Show FileBrowser
FileBrowserList = GetAppData('FileBrowserList');
MethodNum = find(strcmp([FileBrowserList.MethodID],Method));
for i=1:length(FileBrowserList)
    FileBrowserList(i).Visible('off');
end
FileBrowserList(MethodNum).Visible('on');

guidata(hObject, handles);

function SimfunGUI(functionName)
Model = getappdata(0,'Model');
SimfunGUI = str2func(functionName);
SimfunGUI(Model);


function MethodSelection_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% SET DEFAULT METHODSELECTION
function DefaultMethodBtn_Callback(hObject, eventdata, handles)
Method = GetMethod(handles);
setappdata(0, 'Method', Method);
save(fullfile(handles.root,'Common','Parameters','DefaultMethod.mat'),'Method');

function PanelOn(panel, handles)
eval(sprintf('set(handles.%sPanel, ''Visible'', ''on'')', panel));

function PanelOff(panel, handles)
eval(sprintf('set(handles.%sPanel, ''Visible'', ''off'')', panel));

% OPEN OPTIONS
function OpenOptionsPanel_Callback(hObject, eventdata, handles)
Method = GetAppData('Method');
Model = getappdata(0,'Model');
Custom_OptionsGUI(gcf,Model);


% UPDATE OPTIONS
function UpdateOptions(Sim,Prot,FitOpt)
h = findobj('Tag','OptionsGUI');
if ~isempty(h)
    OptionsGUIhandles = guidata(h);
    set(OptionsGUIhandles.SimFileName,   'String',  Sim.FileName);
    set(OptionsGUIhandles.ProtFileName,  'String',  Prot.FileName);
    set(OptionsGUIhandles.FitOptFileName,'String',  FitOpt.FileName);
end


% GETAPPDATA
function varargout = GetAppData(varargin)
for k=1:nargin; varargout{k} = getappdata(0, varargin{k}); end

%SETAPPDATA
function SetAppData(varargin)
for k=1:nargin; setappdata(0, inputname(k), varargin{k}); end

% RMAPPDATA
function RmAppData(varargin)
for k=1:nargin; rmappdata(0, varargin{k}); end

% ##############################################################################################
%                                    FIT DATA
% ##############################################################################################

% FITDATA GO
function FitGO_Callback(hObject, eventdata, handles)
Method = GetMethod(handles);
setappdata(0, 'Method', Method);
FitGo_FitData(hObject, eventdata, handles);


% Original FitGo function
function FitGo_FitData(hObject, eventdata, handles)

% Get data
data =  GetAppData('Data');
Method = GetAppData('Method');
Model = getappdata(0,'Model');

if strcmp(Method,'SPGR') && (strcmp(Model.options.Model,'SledPikeCW') || strcmp(Model.options.Model,'SledPikeRP'))
    if isempty(fieldnames(Model.ProtSfTable))
        errordlg('An SfTable needs to be computed for this protocol prior to fitting. Please use the option panel to do so.','Missing SfTable');
        return;
    end
end

% Do the fitting
FitResults = FitData(data,Model,1);
FitResults.Model = Model;


% Save info with results
FileBrowserList = GetAppData('FileBrowserList');
MethodList = getappdata(0, 'MethodList');
MethodList = strrep(MethodList, '.m', '');
MethodCount = numel(MethodList);

for i=1:MethodCount
    if FileBrowserList(i).IsMethodID(Method)
        MethodID = i;
    end
end
FitResults.StudyID = FileBrowserList(MethodID).getStudyID;
FitResults.WD = FileBrowserList(MethodID).getWD;
if isempty(FitResults.WD), FitResults.WD = pwd; end
FitResults.Files = FileBrowserList(MethodID).getFileName;
SetAppData(FitResults);

% Kill the waitbar in case of a problem occured
wh=findall(0,'tag','TMWWaitbar');
delete(wh);

% Save fit results
if(~isempty(FitResults.StudyID))
    filename = strcat(FitResults.StudyID,'.mat');
else
    filename = 'FitResults.mat';
end
if ~exist(fullfile(FitResults.WD,'FitResults','dir')), mkdir(fullfile(FitResults.WD,'FitResults')); end
save(fullfile(FitResults.WD,'FitResults',filename),'-struct','FitResults');
set(handles.CurrentFitId,'String','FitResults.mat');

% Save nii maps
fn = fieldnames(FitResults.Files);
mainfile = FitResults.Files.(fn{1});
ii = 1;
while isempty(mainfile)
    ii = ii+1;
    mainfile = FitResults.Files.(fn{ii});
end    
for i = 1:length(FitResults.fields)
    map = FitResults.fields{i};
    file = strcat(map,'.nii');
    [~,~,ext]=fileparts(mainfile);
    if strcmp(ext,'.mat')
        save_nii_v2(make_nii(FitResults.(map)),fullfile(FitResults.WD,'FitResults',file),[],64);
    else
        save_nii_v2(FitResults.(map),fullfile(FitResults.WD,'FitResults',file),mainfile,64);
    end
end

SetAppData(FileBrowserList);
% Show results
handles.CurrentData = FitResults;
guidata(hObject,handles);
DrawPlot(handles);


% FITRESULTSSAVE
function FitResultsSave_Callback(hObject, eventdata, handles)
FitResults = GetAppData('FitResults');
[FileName,PathName] = uiputfile('*.mat');
if PathName == 0, return; end
save(fullfile(PathName,FileName),'-struct','FitResults');
set(handles.CurrentFitId,'String',FileName);


% FITRESULTSLOAD
function FitResultsLoad_Callback(hObject, eventdata, handles)
[FileName,PathName] = uigetfile('*.mat');
if PathName == 0, return; end
set(handles.CurrentFitId,'String',FileName);
FitResults = load(fullfile(PathName,FileName));
if isfield(FitResults,'Protocol')
    Prot   =  FitResults.Protocol;
else
    Prot   =  FitResults.Prot;
end
if isfield(FitResults,'FitOpt'), FitOpt =  FitResults.FitOpt; SetAppData(FitResults, Prot, FitOpt); Method = FitResults.Protocol.Method; end
if isfield(FitResults,'Model')
    Method = class(FitResults.Model);
    Model = FitResults.Model;
    SetAppData(FitResults,Model);
end

% find model value in the method menu list
methods = sct_tools_ls([handles.ModelDir filesep '*.m'], 0,0,2,1);
val = find(strcmp(methods,Method));
set(handles.MethodSelection,'Value',val)

MethodMenu(hObject, eventdata, handles,Method)
handles = guidata(hObject); % update handle
FileBrowserList = GetAppData('FileBrowserList');
% if isfield(FitResults,'WD'), FileBrowserList.setWD(FitResults.WD); end
% if isfield(FitResults,'StudyID'), FileBrowserList.setStudyID(FitResults.StudyID); end
% if isfield(FitResults,'Files'),
%     for ifile = fieldnames(FitResults.Files)'
%         FileBrowserList.setFileName(ifile{1},FitResults.Files.(ifile{1}))
%     end
% end

SetAppData(FileBrowserList);
handles.CurrentData = FitResults;
guidata(hObject,handles);
DrawPlot(handles);



% #########################################################################
%                            PLOT DATA
% #########################################################################

function ColorMapStyle_Callback(hObject, eventdata, handles)
val  =  get(handles.ColorMapStyle, 'Value');
maps =  get(handles.ColorMapStyle, 'String');
colormap(maps{val});

function Auto_Callback(hObject, eventdata, handles)
GetPlotRange(handles);
RefreshPlot(handles);

% SOURCE
function SourcePop_Callback(hObject, eventdata, handles)
GetPlotRange(handles);
RefreshPlot(handles);

% MIN
function MinValue_Callback(hObject, eventdata, handles)
min   =  str2double(get(hObject,'String'));
max = str2double(get(handles.MaxValue, 'String'));

% special treatment for MTSAT visualisation
CurMethod = getappdata(0, 'Method');
if strcmp(CurMethod, 'MTSAT')
    if n > 2
        Min = min(min(min(MTdata)));
        Max = max(max(max(MTdata)));
        ImSize = size(MTdata);
    else
        Min = min(min(MTdata));
        Max = max(max(MTdata));
    end
    set(handles.MinValue, 'Min', Min);
    set(handles.MinValue, 'Max', Max);
    set(handles.MinValue, 'Value', Min+1);
else
    lower =  0.5 * min;
    set(handles.MinSlider, 'Value', min);
    set(handles.MinSlider, 'min',   lower);
    caxis([min max]);
    % RefreshColorMap(handles);
end

function MinSlider_Callback(hObject, eventdata, handles)
maxi = str2double(get(handles.MaxValue, 'String'));
mini = min(get(hObject, 'Value'),maxi-eps);
set(hObject,'Value',mini)
set(handles.MinValue,'String',mini);
caxis([mini maxi]);
% RefreshColorMap(handles);

% MAX
function MaxValue_Callback(hObject, eventdata, handles)
mini = str2double(get(handles.MinValue, 'String'));
maxi = str2double(get(handles.MaxValue, 'String'));
upper =  1.5 * maxi;
set(handles.MaxSlider, 'Value', maxi)
set(handles.MaxSlider, 'max',   upper);
caxis([mini maxi]);
% RefreshColorMap(handles);

function MaxSlider_Callback(hObject, eventdata, handles)
mini = str2double(get(handles.MinValue, 'String'));
maxi = max(mini +eps,get(hObject, 'Value'));
set(hObject,'Value',maxi)
set(handles.MaxValue,'String',maxi);
caxis([mini maxi]);
% RefreshColorMap(handles);

% VIEW
function ViewPop_Callback(hObject, eventdata, handles)
UpdatePopUp(handles);
RefreshPlot(handles);
xlim('auto');
ylim('auto');

% SLICE
function SliceValue_Callback(hObject, eventdata, handles)
Slice = str2double(get(hObject,'String'));
set(handles.SliceSlider,'Value',Slice);
View =  get(handles.ViewPop,'Value');
handles.FitDataSlice(View) = Slice;
guidata(gcbf,handles);
RefreshPlot(handles);

function SliceSlider_Callback(hObject, eventdata, handles)
Slice = get(hObject,'Value');
Slice = max(1,round(Slice));
set(handles.SliceSlider, 'Value', Slice);
set(handles.SliceValue, 'String', Slice);
View =  get(handles.ViewPop,'Value');
handles.FitDataSlice(View) = Slice;
guidata(gcbf,handles);
RefreshPlot(handles);

% OPEN FIG
function PopFig_Callback(hObject, eventdata, handles)
xl = xlim;
yl = ylim;
figure();
xlim(xl);
ylim(yl);
RefreshPlot(handles);

% SAVE FIG
function SaveFig_Callback(hObject, eventdata, handles)
[FileName,PathName] = uiputfile(fullfile('FitResults','NewFig.fig'));
if PathName == 0, return; end
xl = xlim;
yl = ylim;
h = figure();
xlim(xl);
ylim(yl);
RefreshPlot(handles);
savefig(fullfile(PathName,FileName));
delete(h);

% HISTOGRAM FIG
function Histogram_Callback(hObject, eventdata, handles)
Data =  getappdata(0,'Data');
Map = getimage(handles.FitDataAxe);
% exclude the 0 from mask
if isfield(Data,'Mask')    
    if ~isempty(Data.Mask)
        Map(~rot90(Data.Mask)) = 0;
    end
end
SourceFields = cellstr(get(handles.SourcePop,'String'));
Source = SourceFields{get(handles.SourcePop,'Value')};
ii = find(Map);
nVox = length(ii);
data = reshape(Map(ii),1,nVox);
% figure
figure
hist(data,20);
xlabel(Source);
ylabel('Counts');
% statistics (mean and standard deviation)
Stats = sprintf('Mean: %4.3e \n   Std: %4.3e',mean(data),std(data));
text(0.77,0.94,Stats,'Units','normalized','FontWeight','bold','FontSize',12,'Color','black');

% PLOT DATA FIT
function ViewDataFit_Callback(hObject, eventdata, handles)
% Get data
data =  getappdata(0,'Data'); MRIinput = fieldnames(data); MRIinput(strcmp(MRIinput,'hdr'))=[];
[Method, Prot, FitOpt] = GetAppData('Method','Prot','FitOpt');

% Get selected voxel
S = size(data.(MRIinput{1}));
if isempty(handles.dcm_obj) || isempty(getCursorInfo(handles.dcm_obj))
    helpdlg('Select a voxel in the image using cursor')
else
    info_dcm = getCursorInfo(handles.dcm_obj);
    x = info_dcm.Position(1);
    y = 1+ S(2) - info_dcm.Position(2);
    z = str2double(get(handles.SliceValue,'String'));
    index = sub2ind(S,x,y,z);
    
    for ii=1:length(MRIinput)
        if ~isempty(data.(MRIinput{ii}))
            data.(MRIinput{ii}) = squeeze(data.(MRIinput{ii})(x,y,z,:));
        end
    end
    if isfield(data,'Mask'), data.Mask = []; end
    
    Sim.Opt.AddNoise = 0;
    % Create axe
    figure(68)
    set(68,'Name',['Fitting results of voxel [' num2str([x y z]) ']'],'NumberTitle','off');
    haxes = get(68,'children'); haxes = haxes(strcmp(get(haxes,'Type'),'axes'));
    
    if ~isempty(haxes)
        % turn gray old plots
        haxes = get(haxes(min(end,2)),'children');
        set(haxes,'Color',[0.8 0.8 0.8]);
        hAnnotation = get(haxes,'Annotation');
        % remove their legends
        for ih=1:length(hAnnotation)
            if iscell(hAnnotation), hAnnot = hAnnotation{ih}; else hAnnot = hAnnotation; end
            hLegendEntry = get(hAnnot,'LegendInformation');
            set(hLegendEntry,'IconDisplayStyle','off');
        end
    end
    hold on;
    
    % Do the fitting
    Model = getappdata(0,'Model');
    if Model.voxelwise==0,  warndlg('Not a voxelwise model'); return; end
    if ~ismethod(Model,'plotmodel'), warndlg('No plotting methods in this model'); return; end
    Fit = Model.fit(data); % Display fitting results in command window
    Model.plotmodel(Fit,data);
    
    % update legend
    legend('Location','NorthEast')
end


% OPEN VIEWER
function Viewer_Callback(hObject, eventdata, handles)
SourceFields = cellstr(get(handles.SourcePop,'String'));
Source = SourceFields{get(handles.SourcePop,'Value')};
file = fullfile(handles.root,strcat(Source,'.nii'));
Data = handles.CurrentData;
nii = make_nii(Data.(Source));
save_nii(nii,file);
nii_viewer(file);


% PAN
function PanBtn_Callback(hObject, eventdata, handles)
pan;
set(handles.ZoomBtn,'Value',0);
set(handles.CursorBtn,'Value',0);
zoom off;
datacursormode off;

% ZOOM
function ZoomBtn_Callback(hObject, eventdata, handles)
zoom;
set(handles.PanBtn,'Value',0);
set(handles.CursorBtn,'Value',0);
pan off;
datacursormode off;

% CURSOR
function CursorBtn_Callback(hObject, eventdata, handles)
datacursormode;
set(handles.ZoomBtn,'Value',0);
set(handles.PanBtn,'Value',0);
zoom off;
pan off;
fig = gcf;
handles.dcm_obj = datacursormode(fig);
guidata(gcbf,handles);

function RefreshPlot(handles)
Current = GetCurrent(handles);
xl = xlim;
yl = ylim;
% imagesc(flipdim(Current',1));
imagesc(rot90(Current));
axis equal off;
RefreshColorMap(handles)
xlim(xl);
ylim(yl);


% ##############################################################################################
%                                    ROI
% ##############################################################################################

% DRAW
function RoiDraw_Callback(hObject, eventdata, handles)
set(gcf,'Pointer','Cross');
set(findall(handles.ROIPanel,'-property','enable'), 'enable', 'off')
contents = cellstr(get(hObject,'String'));
model = contents{get(hObject,'Value')};
switch model
    case 'Ellipse'
        draw = imellipse();
    case 'Polygone'
        draw = impoly();
    case 'Rectangle'
        draw = imrect();
    case 'FreeHand'
        draw = imfreehand();
    otherwise
        warning('Choose a Drawing Method');
end
Press = waitforbuttonpress;
while Press == 0
    Press = waitforbuttonpress;
end
if Press == 1
    Map = getimage(handles.FitDataAxe);
    handles.ROI = double(draw.createMask());
    handles.NewMap = (Map(:,:,1,1)).*(handles.ROI);
    guidata(gcbo, handles); 
    % figure
    set(handles.FitDataAxe);
    imagesc(handles.NewMap);
    axis equal off;
    colorbar('south','YColor','white');
end
set(findall(handles.ROIPanel,'-property','enable'), 'enable', 'on');
set(gcf,'Pointer','Arrow');

% THRESHOLD
function RoiThreshMin_Callback(hObject, eventdata, handles)
handles.threshMin = str2double(get(hObject, 'String'));
if ~isempty(get(handles.RoiThreshMax, 'String'))
    handles.threshMax = str2double(get(handles.RoiThreshMax, 'String'));
else
    handles.threshMax = str2double(get(handles.MaxValue, 'String'));
end
handles.NewMap = getimage(handles.FitDataAxe);
handles.NewMap(handles.NewMap<handles.threshMin) = 0;
handles.NewMap(handles.NewMap>handles.threshMax) = 0;
handles.ROI = handles.NewMap;
handles.ROI(handles.ROI~=0) = 1;
guidata(gcbo, handles); 
% figure
set(handles.FitDataAxe);
imagesc(handles.NewMap);
axis equal off;
colorbar('south','YColor','white');
function RoiThreshMax_Callback(hObject, eventdata, handles)
handles.threshMax = str2double(get(hObject, 'String'));
if ~isempty(get(handles.RoiThreshMin, 'String'))
    handles.threshMin = str2double(get(handles.RoiThreshMin, 'String'));
else
    handles.threshMin = str2double(get(handles.MinValue, 'String'));
end
handles.NewMap = getimage(handles.FitDataAxe);
handles.NewMap(handles.NewMap<handles.threshMin) = 0;
handles.NewMap(handles.NewMap>handles.threshMax) = 0;
handles.ROI = handles.NewMap;
handles.ROI(handles.ROI~=0) = 1;
guidata(gcbo, handles); 
% figure
set(handles.FitDataAxe);
imagesc(handles.NewMap);
axis equal off;
colorbar('south','YColor','white');

% SAVE
function RoiSave_Callback(hObject, eventdata, handles)
% Get the WD
Method = GetAppData('Method');
FileBrowserList = GetAppData('FileBrowserList');
MethodList = getappdata(0, 'MethodList');
MethodList = strrep(MethodList, '.m', '');
MethodCount = numel(MethodList);
for i=1:MethodCount
    if FileBrowserList(i).IsMethodID(Method)
        MethodID = i;
    end
end
WD = FileBrowserList(MethodID).getWD;
Mask = rot90(handles.ROI,-1);
if ~isempty(WD)
    if exist(fullfile(WD, 'Mask.mat'),'file') || exist(fullfile(WD, 'Mask.nii'),'file')
        choice = questdlg('Replace the old mask?','A mask exist!','Yes','No','No');
        switch choice
            case 'Yes'
                FullPathName = fullfile(WD, 'Mask');
                save(FullPathName,'Mask');                 
            case 'No'
                [FileName, PathName] = uiputfile({'*.mat'},'Save as');
                FullPathName = fullfile(PathName, FileName);
                if FileName ~= 0
                    save(FullPathName,'Mask');
                end
        end
    else
        FullPathName = fullfile(WD, 'Mask');
        save(FullPathName,'Mask');
    end
else
    [FileName, PathName] = uiputfile({'*.mat'},'Save as');
    FullPathName = fullfile(PathName, FileName);
    if FileName ~= 0
        save(FullPathName,'Mask');
    end  
end

% LOAD
function RoiLoad_Callback(hObject, eventdata, handles)
[FileName,PathName] = uigetfile;
FullPathName = fullfile(PathName, FileName);
Tmp = load(FullPathName);
Roi = rot90(Tmp.Mask);
Map = getimage(handles.FitDataAxe);
handles.NewMap = Map.*Roi;
% figure
set(handles.FitDataAxe);
imagesc(handles.NewMap);
axis equal off;
colorbar('south','YColor','white');


% ######################## CREATE FUNCTIONS ##############################
function SimVaryOptRuns_CreateFcn(hObject, eventdata, handles)
function SimVaryPlotX_CreateFcn(hObject, eventdata, handles)
function SimVaryPlotY_CreateFcn(hObject, eventdata, handles)
function SimVaryOptTable_CellEditCallback(hObject, eventdata, handles)
function SimRndOptVoxels_CreateFcn(hObject, eventdata, handles)
function SimRndPlotX_CreateFcn(hObject, eventdata, handles)
function SimRndPlotY_CreateFcn(hObject, eventdata, handles)
function SimRndPlotType_CreateFcn(hObject, eventdata, handles)
function CurrentFitId_CreateFcn(hObject, eventdata, handles)
function ColorMapStyle_CreateFcn(hObject, eventdata, handles)
function SourcePop_CreateFcn(hObject, eventdata, handles)
function View_CreateFcn(hObject, eventdata, handles)
function MinValue_CreateFcn(hObject, eventdata, handles)
function MaxValue_CreateFcn(hObject, eventdata, handles)
function MinSlider_CreateFcn(hObject, eventdata, handles)
function MaxSlider_CreateFcn(hObject, eventdata, handles)
function SliceSlider_CreateFcn(hObject, eventdata, handles)
function SliceValue_CreateFcn(hObject, eventdata, handles)
function ViewPop_CreateFcn(hObject, eventdata, handles)
function FitDataAxe_CreateFcn(hObject, eventdata, handles)
function edit35_Callback(hObject, eventdata, handles)
function edit35_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function uibuttongroup1_SizeChangedFcn(hObject, eventdata, handles)
function Method_Selection_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function pushbutton173_Callback(hObject, eventdata, handles)
function pushbutton174_Callback(hObject, eventdata, handles)
function pushbutton175_Callback(hObject, eventdata, handles)
function pushbutton170_Callback(hObject, eventdata, handles)
function pushbutton171_Callback(hObject, eventdata, handles)
function pushbutton172_Callback(hObject, eventdata, handles)
function slider4_Callback(hObject, eventdata, handles)
function slider4_CreateFcn(hObject, eventdata, handles)
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end
function slider5_Callback(hObject, eventdata, handles)
function slider5_CreateFcn(hObject, eventdata, handles)
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end
function RoiDraw_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function RoiThreshMin_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function RoiThreshMax_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
function MethodqMT_Callback(hObject, eventdata, handles)
function ChooseMethod_Callback(hObject, eventdata, handles)

function pushbutton169_Callback(hObject, eventdata, handles)
function pushbutton168_Callback(hObject, eventdata, handles)
function pushbutton167_Callback(hObject, eventdata, handles)
function pushbutton166_Callback(hObject, eventdata, handles)

%----------------------------------------- END ------------------------------------------%
