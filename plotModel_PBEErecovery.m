% Plot Functional Recovery Plots For a Single Model and Single Intensity
clear all
close all
clc
rehash

%% Define User inputs
model_name = '16-story_RCSW_475yr_Example'; % Name of the model;
                     % inputs are expected to be in a directory with this name
                     % outputs will save to a directory with this name
outputs_dir = ['outputs' filesep model_name]; % Directory where the assessment outputs are saved
plot_dir = [outputs_dir filesep 'plots']; % Directory where the plots will be saved
p_gantt = 50; % percentile of functional recovery time to plot for the gantt chart
              % e.g., 50 = 50th percentile of functional recovery time

%% Import Packages
import plotters.main_plot_functionality

%% Load Assessment Output Data
load([outputs_dir filesep 'recovery_outputs.mat'])


%% Create plots for UBC Study
data_RO = functionality.recovery.reoccupancy;
data_FR = functionality.recovery.functional;
mkdir(plot_dir)

% Functional Recovery Histogram
histogram(data_FR.building_level.recovery_day,'Normalization','probability')
ylabel('Percent of Relizations')
xlabel('Days after earthquake')
saveas(gcf,[plot_dir filesep 'FR_hist.png'])
close

% Recovery Trajectory
hold on
plot(data_FR.recovery_trajectory.recovery_day,data_FR.recovery_trajectory.percent_recovered,'color',[0.8 0.8 0.8],'linewidth',0.5)
plot(median(data_FR.recovery_trajectory.recovery_day),data_FR.recovery_trajectory.percent_recovered,'-k','linewidth',1.5)
plot(prctile(data_FR.recovery_trajectory.recovery_day,10),data_FR.recovery_trajectory.percent_recovered,'--k','linewidth',1.5)
plot(prctile(data_FR.recovery_trajectory.recovery_day,90),data_FR.recovery_trajectory.percent_recovered,'--k','linewidth',1.5)
box on
ylabel('Percent of Functional Tenant Units')
xlabel('Days after earthquake')
saveas(gcf,[plot_dir filesep 'Recovery_trajectory.png'])
close

% Table
outs = table;
outs.Return_Period = 475;
outs.Median_Downtime_FR = median(data_FR.building_level.recovery_day);
outs.Robustness_RO = mean(data_RO.building_level.recovery_day == 0);
outs.Robustness_FR = mean(data_FR.building_level.recovery_day == 0);
outs.Rapidity_RO = mean(data_RO.building_level.recovery_day <= 120); % less than 4 months ~ 120 days
outs.Rapidity_FR = mean(data_FR.building_level.recovery_day <= 120); % less than 4 months ~ 120 days
writetable(outs, [plot_dir filesep 'summary_outs.csv'])

% %% Create plot for single intensity assessment of PBEE Recovery
% main_plot_functionality( functionality, plot_dir, p_gantt )



