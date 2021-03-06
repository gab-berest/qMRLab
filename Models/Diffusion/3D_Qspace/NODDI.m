classdef NODDI
%-----------------------------------------------------------------------------------------------------
% NODDI :  Neurite Orientation Dispersion and Density Imaging
%          Three-compartment model for fitting multi-shell DWI
%           
%-----------------------------------------------------------------------------------------------------
%-------------%
% ASSUMPTIONS %
%-------------% 
% (1) neuronal fibers (axons) are impermeable sticks (Dperp = 0)
% (2) Presence of orientation dispersion of the fibers (Watson distribution). Note that NODDI is more robust to
% crossing fibers that DTI  (Campbell, NIMG 2017)
% and isotropic diffusion coefficient (parameters di and diso)
%
% Intra-cellular Model:
% (3) Fixed diffusion coefficient (parameter di)
%
% Extra-cellular Model:
% (4) Tortuosity model. Parallel diffusivity is equal to
% intra-diffusivity.Perpendicular diffusivity is proportional to fiber
% density
% (5) No time dependence of the diffusion
%
%
%-----------------------------------------------------------------------------------------------------
%--------%
% INPUTS %
%--------%
%   DiffusionData: 4D diffusion weighted dataset
%
%-----------------------------------------------------------------------------------------------------
%---------%
% OUTPUTS %
%---------%
%       * di            : Diffusion coefficient in the restricted compartment.
%       * ficvf         : Fraction of water in the restricted compartment.
%       * diso (fixed)  : diffusion coefficient of the isotropic compartment (CSF)
%       * kappa         : Orientation dispersion index                               
%       * b0            : Signal at b=0
%       * theta         : angle of the fibers
%       * phi           : angle of the fibers
%
%      
%-----------------------------------------------------------------------------------------------------
%----------%
% PROTOCOL %
%----------%
%   Multi-shell diffusion-weighted acquisition : 
%       - at least 2 non-zeros bvalues)
%       - at least 5 b=0 (used to compute noise standard deviation)
%
%-----------------------------------------------------------------------------------------------------
%---------%
% OPTIONS %
%---------%
%   Model Name: Model part of NODDI. WatsonSHStickTortIsoVIsoDot_B0 is a
%   four model compartment used for ex-vivo datasets
%
%-----------------------------------------------------------------------------------------------------
% Written by: Tanguy Duval
% Reference: Zhang, H., Schneider, T., Wheeler-Kingshott, C.A., Alexander, D.C., 2012. NODDI: practical in vivo neurite orientation dispersion and density imaging of the human brain. Neuroimage 61, 1000?1016.
%-----------------------------------------------------------------------------------------------------    
    
    properties
        MRIinputs = {'DiffusionData','Mask'};
        xnames = { };
        voxelwise = 1;
        
        % fitting options
        st           = [ ]; % starting point
        lb           = [ ]; % lower bound
        ub           = [ ]; % upper bound
        fx           = [ ]; % fix parameters
        
        % Protocol
        Prot = struct('DiffusionData',struct('Format',{{'Gx' 'Gy'  'Gz'   '|G|'  'Delta'  'delta'  'TE'}},...
                                      	     'Mat',   txt2mat(fullfile(fileparts(which('qMRLab.m')),'Data', 'NODDI_DTI_demo', 'Protocol.txt')))); % You can define a default protocol here.
        
        % Model options
        buttons = {'model name',{'WatsonSHStickTortIsoV_B0','WatsonSHStickTortIsoVIsoDot_B0'}};
        options= struct();
        
    end
    
    methods
        function obj = NODDI
            obj.options = button2opts(obj.buttons);
            obj = UpdateFields(obj);
        end
        
        function obj = UpdateFields(obj)
            if exist('MakeModel.m','file') ~= 2, errordlg('Please add the NODDI Toolbox to your Matlab Path: http://www.nitrc.org/projects/noddi_toolbox','NODDI is not installed properly'); return; end;
            model  = MakeModel(obj.options.modelname);
            Pindex =~ ismember(model.paramsStr,{'b0','theta','phi'});
            obj.xnames = model.paramsStr(Pindex);
            obj.fx     = model.GD.fixed(Pindex);
            grid  = GetSearchGrid(obj.options.modelname, model.tissuetype, false(1,sum(Pindex)), false(1,sum(Pindex)));
            scale = GetScalingFactors(obj.options.modelname);
            obj.st     = model.GD.fixedvals(Pindex).*scale(Pindex);
            obj.lb     = min(grid,[],2)'.*scale(Pindex);
            obj.ub     = max(grid,[],2)'.*scale(Pindex);
        end
        
        function [Smodel, fibredir] = equation(obj, x)
            if isstruct(x) % if x is a structure, convert to vector
                if isfield(x,'ODI'), x = rmfield(x,'ODI'); end
                x = struct2array(x);
            end
            
            model = MakeModel(obj.options.modelname);
            if length(x)<length(model.GD.fixedvals)-2, x(end+1) = 1; end % b0
            if length(x)<length(model.GD.fixedvals)-1, x(end+1) = 0; x(end+1)=0; end % phi and theta
            
            scale = GetScalingFactors(obj.options.modelname);
            if (strcmp(obj.options.modelname, 'ExCrossingCylSingleRadGPD') ||...
                strcmp(obj.options.modelname, 'ExCrossingCylSingleRadIsoDotTortIsoV_GPD_B0'))
                xsc      = x(1:(end-4))./scale(1:(end-1));
                theta    = [x(end-3) x(end-1)]';
                phi      = [x(end-2) x(end)]';
                fibredir = [cos(phi).*sin(theta) sin(phi).*sin(theta) cos(theta)]';
            else
                xsc      = x(1:(end-2))./scale(1:(end-1));
                theta    = x(end-1);
                phi      = x(end);
                fibredir = [cos(phi)*sin(theta) sin(phi)*sin(theta) cos(theta)]';
            end
            constants.roots_cyl = BesselJ_RootsCyl(30);
            
            Smodel = SynthMeas(obj.options.modelname, xsc, SchemeToProtocol(obj.Prot.DiffusionData.Mat), fibredir, constants);
            
        end
        
        function FitResults = fit(obj,data)
            if exist('MakeModel.m','file') ~= 2, errordlg('Please add the NODDI Toolbox to your Matlab Path: http://www.nitrc.org/projects/noddi_toolbox','NODDI is not installed properly'); return; end
            % load model
            model = MakeModel(obj.options.modelname);
            Pindex =~ ismember(model.paramsStr,{'b0','theta','phi'});            
            model.GD.fixed(Pindex) = obj.fx; % gradient descent
            model.GS.fixed(Pindex) = obj.fx; % grid search
            scale = GetScalingFactors(obj.options.modelname);
            model.GS.fixedvals(Pindex) = obj.st./scale(Pindex);
            model.GD.fixedvals(Pindex) = obj.st./scale(Pindex);
            
            protocol = SchemeToProtocol(obj.Prot.DiffusionData.Mat);
            
            % fit
            [xopt] = ThreeStageFittingVoxel(double(max(eps,data.DiffusionData)), protocol, model);

            % Outputs
            xnames = model.paramsStr;
            xnames{end+1} = 'ODI';
            xopt(end+1) = atan2(1, xopt(3)*10)*2/pi;
            FitResults = cell2struct(mat2cell(xopt(:),ones(length(xopt),1)),xnames,1);
        end
        
        function plotmodel(obj, x, data)
            [Smodel, fibredir] = obj.equation(x);
            Prot = ConvertProtUnits(obj.Prot.DiffusionData.Mat);
                        
            % plot
            if exist('data','var')
                h = scd_display_qspacedata3D(data.DiffusionData,Prot,fibredir);
                hold on
                % remove data legends
                for iD = 1:length(h)
                    hAnnotation = get(h(iD),'Annotation');
                    hLegendEntry = get(hAnnotation','LegendInformation');
                    set(hLegendEntry,'IconDisplayStyle','off');
                end
            end
            
            % plot fitting curves
            scd_display_qspacedata3D(Smodel,Prot,fibredir,'none','-');
           
            hold off
            
        end
        
        function plotProt(obj)
            % round bvalue
            Prot      = obj.Prot.DiffusionData.Mat;
            Prot(:,4) = round(scd_scheme2bvecsbvals(Prot)*100)*10;
            % display
            scd_scheme_display(Prot)
            subplot(2,2,4)
            scd_scheme_display_3D_Delta_delta_G(ConvertProtUnits(obj.Prot.DiffusionData.Mat))
        end

        function FitResults = Sim_Single_Voxel_Curve(obj, x, Opt,display)
            if ~exist('display','var'), display=1; end
            [Smodel, fibredir] = equation(obj, x);
            sigma = max(Smodel)/Opt.SNR;
            data.DiffusionData = random('rician',Smodel,sigma);
            FitResults = fit(obj,data);
            if display
                plotmodel(obj, FitResults, data);
                hold on
                Prot = ConvertProtUnits(obj.Prot.DiffusionData.Mat);
                h = scd_display_qspacedata3D(Smodel,Prot,fibredir,'o','none');
                set(h,'LineWidth',.5)
            end
        end
        
        function SimVaryResults = Sim_Sensitivity_Analysis(obj, SNR, runs, OptTable)
            % SimVaryGUI
            SimVaryResults = SimVary(obj, SNR, runs, OptTable);
            
        end
        
    end
end


function protocol = SchemeToProtocol(Prot)
%
% Reads a Camino Version 1 schemefile into a protocol object
%
% function protocol = SchemeToProtocol(schemefile)
%
% author: Daniel C Alexander (d.alexander@ucl.ac.uk)
%         Gary Hui Zhang     (gary.zhang@ucl.ac.uk)
%

Prot = Prot';

% Create the protocol
protocol.pulseseq  = 'PGSE';
protocol.grad_dirs = Prot(1:3,:)';
protocol.G         = Prot(4,:);
protocol.delta     = Prot(5,:);
protocol.smalldel  = Prot(6,:);
protocol.TE        = Prot(7,:);
protocol.totalmeas = length(Prot);

% Find the B0's
bVals = GetB_Values(protocol);
protocol.b0_Indices = find(bVals==0);

end

function Prot = ConvertProtUnits(Prot)
% convert units
Prot(:,4)   = Prot(:,4).*sqrt(sum(Prot(:,1:3).^2,2))*1e-3; % G mT/um
Prot(:,1:3) = Prot(:,1:3)./repmat(sqrt(Prot(:,1).^2+Prot(:,2).^2+Prot(:,3).^2),1,3); Prot(isnan(Prot))=0;
Prot(:,5)   = Prot(:,5)*10^3; % DELTA ms
Prot(:,6)   = Prot(:,6)*10^3; % delta ms
Prot(:,7)   = Prot(:,7)*10^3; % TE ms
gyro = 42.57; % kHz/mT
Prot(:,8)   = gyro*Prot(:,4).*Prot(:,6); % um-1

% Find different shells
list_G = unique(round(Prot(:,[4 5 6 7])*1e5)/1e5,'rows');
nnn    = size(list_G,1);
for j = 1 : nnn
    for i = 1 : size(Prot,1)
        if  min(round(Prot(i,[4 5 6 7])*1e5)/1e5 == list_G(j,:))
            Prot(i,9) = j;
        end
    end
end
Prot(ismember(Prot(:,9),find(list_G(:,1)==0)),9) = find(list_G(:,1)==0,1,'first');
end
