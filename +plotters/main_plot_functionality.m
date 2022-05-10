function [] = main_plot_functionality(functionality, save_dir, p_gantt)
% Plot function and occupancy loss and recovery at for a single model at a 
% single intensity levels
%
% Parameters
% ----------
% functionality: structure
%   main output data strcuture of the functional recovery assessment. 
%   Loaded directly from the output mat file.
% save_dir: str
%   Save directory for plots. Plots will save directly to this location as
%   png files.
% p_gantt: int
%   percentile of functional recovery time to plot gantt chart
%
% Returns
% -------
% 

%% Initial Setup
% Import Packages
import plotters.*

% Set plot variables to use
recovery = functionality.recovery;
impede = functionality.impeding_factors.breakdowns;
schedule = functionality.building_repair_schedule;
workers = functionality.worker_data;
full_repair_time = max(schedule.repair_complete_day.per_story,[],2);

%% Plot Performance Objective Grid for system and component breakdowns
plot_dir = [save_dir filesep 'breakdowns'];
plt_heatmap_breakdowns( recovery, plot_dir )

%% Plot Performance Target Distribution Across all Realizations
plot_dir = [save_dir filesep 'histograms'];
plt_histograms( recovery, plot_dir )

%% Plot Mean Recovery Trajectories
plot_dir = [save_dir filesep 'recovery trajectories'];
plt_recovery_trajectory( recovery, full_repair_time, plot_dir)

%% Plot Gantt Charts
plot_dir = [save_dir filesep 'gantt_charts'];
fr_time = functionality.recovery.functional.building_level.recovery_day;
p_idx = find(fr_time == prctile(fr_time,p_gantt),1); % Find the index of the first realization that matches the selected percentile
plot_name = ['prt_' num2str(p_gantt)];
plt_gantt_chart( p_idx, recovery, full_repair_time, workers, schedule, impede, plot_dir, plot_name )

end

