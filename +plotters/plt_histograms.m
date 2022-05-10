function [] = plt_histograms( recovery, plot_dir )
% Plot all realizations of building level recovery as a histogram
%
% Parameters
% ----------
% recovery: structure
%   data structure containing building-level recovery data from the 
%   functional recovery assessment
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

%% Plot Histograms
fnc_states = fieldnames(recovery);
for fs = 1:length(fnc_states)
    histogram(recovery.functional.building_level.recovery_day)
    fnc_lab = [upper(fnc_states{fs}(1)) fnc_states{fs}(2:end) ' Recovery'];
    xlabel([fnc_lab ' Time (days)'])
    ylabel('Number of Realizatons')
    box on
    saveas(gcf,[plot_dir filesep fnc_states{fs}],'png')
    close
end

end

