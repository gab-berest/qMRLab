function SimVaryResults = SimVary(obj, SNR, runs, OptTable)

if ~exist('OptTable','var'), OptTable = obj; end % use fitting boundaries

fx = [OptTable.fx];
st = [OptTable.st];
lb = [OptTable.lb];
ub = [OptTable.ub];

for pp=1:length(OptTable)
    if ~fx(pp)
        Sens.x = linspace(lb(pp),ub(pp),10);
        % Create waitbar
        h = waitbar(0, sprintf('Data 0/%0.0f',length(Sens.x)), 'Name', sprintf('Simulating %s sensitivity data', obj.xnames{pp}));
        setappdata(h,'canceling',0);
        setappdata(0,'Cancel',0);
        
        for ii=1:length(Sens.x)
            x = st; x(pp)=Sens.x(ii);
            for N=1:runs
                Fittmp = obj.Sim_Single_Voxel_Curve(x, SNR,0);
                if ~isfield(Sens,'fit')
                    Sens.fit = Fittmp;
                else
                    for ff=fieldnames(Fittmp)'
                        Sens.fit.(ff{1})(ii,N) = Fittmp.(ff{1});
                    end
                end
                %if getappdata(h,'canceling'); setappdata(0,'Cancel',1); return; end
            end
            if ishandle(h)
                waitbar(ii/length(Sens.x),h,sprintf('Data %0.0f/%0.0f',ii,length(Sens.x)));
            end
        end
        delete(h)       % DELETE the waitbar; don't try to CLOSE it.
        
        for ff=fieldnames(Sens.fit)'
            Sens.(ff{1}).mean = mean(Sens.fit.(ff{1}),2);
            Sens.(ff{1}).std = std(Sens.fit.(ff{1}),0,2);
            Sens.(ff{1}).GroundTruth = st(strcmp(obj.xnames,ff{1}));
        end
        SimVaryResults.(obj.xnames{pp})=Sens;
    end
end