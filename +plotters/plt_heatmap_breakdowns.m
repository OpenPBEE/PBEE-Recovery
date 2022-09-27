function [] = plt_heatmap_breakdowns( recovery, plot_dir )
% Plot the time and percent of realizations that each system and/or 
% component is impeding function as a heatmap
%
% Parameters
% ----------
% recovery: structure
%   data structure containing recovery breakdown data from the functional
%   recovery assessment
% plot_dir: str
%   Save directory for plots. Plots will save directly to this location as
%   png files.
%
% Returns
% -------
% 
%% Initial Setup
if ~exist(plot_dir,'dir')
    mkdir(plot_dir)
end

perform_targ_labs = {'Immediately', '>3 Days', '>7 Days', '>2 Weeks', '>1 Month', '>2 Months', '>3 Months', '>4 Months', '>6 Months', '>9 Months', '>1 Year'};

var = {'component_breakdowns', 'system_breakdowns'};
labs = {'comp_names', 'system_names'};
plt_ht = [550, 350];

%% Plot Heatmaps
fnc_states = fieldnames(recovery);
for fs = 1:length(fnc_states)
    for v = 1:length(var)
        y_labs = recovery.(fnc_states{fs}).breakdowns.(labs{v});
        data = recovery.(fnc_states{fs}).breakdowns.(var{v});

        h = heatmap(perform_targ_labs, strrep(y_labs,'_',' '), round(data,2));
        h.MissingDataColor = 1-h.MissingDataColor;
        fnc_lab = [upper(fnc_states{fs}(1)) fnc_states{fs}(2:end) ' Recovery'];
        title(['Fraction of Realizations Affecting Building ' fnc_lab])
        xlabel('Recovery Time After Earthquake')
        set(gca,'fontname','times')
        set(gcf,'position',[10,10,650,plt_ht(v)])
        saveas(gcf,[plot_dir filesep var{v} '_' fnc_states{fs}],'png')
        close
    end
end

end

