% Plot Functional Recovery Plots For a Single Model and Single Intensity
clear all
close all
clc
rehash

%% Define User inputs
model_name = 'ICSB'; % Name of the model;
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

%% Create plot for single intensity assessment of PBEE Recovery
main_plot_functionality( functionality, plot_dir, p_gantt )



