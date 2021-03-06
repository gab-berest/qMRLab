function SimRndResults = SimRnd(Model, RndParam, Opt)
%VaryRndParam Multi Voxel simulation of normally distributed parameters

fields = fieldnames(RndParam);
n = length(RndParam.(fields{1})); % number of voxels
for ii = 1:length(fields)
    SimRndResults.(fields{ii}) = zeros(n,1);
end

% Create waitbar
h = waitbar(0, sprintf('Data 0/%0.0f',n), 'Name', 'Simulating data',...
    'CreateCancelBtn', 'setappdata(gcbf,''canceling'',1)');
setappdata(h,'canceling',0)
setappdata(0,'Cancel',0);

tic;
for ii = 1:n
    for ix=1:length(Model.xnames)
        x(ix) = RndParam.(Model.xnames{ix})(ii);
    end
    Fit = Model.Sim_Single_Voxel_Curve(x,Opt,0);
    fields = fieldnames(Fit);
    
    for jj = 1:length(fields)
        SimRndResults.(fields{jj})(ii) = Fit.(fields{jj});
    end
        
    % Update waitbar
    if getappdata(h,'canceling');  break;  end
    waitbar(ii/n,h,sprintf('Data %0.0f/%0.0f',ii,n));
end

delete(h);
SimRndResults.time = toc
SimRndResults.fields = fields;
SimRndResults = AnalyzeResults(RndParam, SimRndResults);
end


function Results = AnalyzeResults(Input, Results)
Fields = intersect(fieldnames(Input), fieldnames(Results));
for ii = 1:length(Fields)
    n = length(Input.(Fields{ii}));
    Results.Error.(Fields{ii})    = Results.(Fields{ii}) - Input.(Fields{ii}) ;
    Results.PctError.(Fields{ii}) = 100*(Results.(Fields{ii}) - Input.(Fields{ii})) ./ Input.(Fields{ii});
    Results.MPE.(Fields{ii})      = 100/n*sum((Results.(Fields{ii}) - Input.(Fields{ii})) ./ Input.(Fields{ii}));
    Results.RMSE.(Fields{ii})     = sqrt(sum((Results.(Fields{ii}) - Input.(Fields{ii})).^2 )/n);
    Results.NRMSE.(Fields{ii})    = Results.RMSE.(Fields{ii}) / (max(Input.(Fields{ii})) - min(Input.(Fields{ii})));
end
end
