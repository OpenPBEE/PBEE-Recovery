function [ red_tag, red_tag_impact, inspection_tag ] = ...
    fn_red_tag( calculate_red_tag, damage, comps, simulated_replacement, red_tag_options )
% Perform the ATC-138 functional recovery time assessement given similation
% of component damage for a single shaking intensity
%
% Parameters
% ----------
% calculate_red_tag: logical
%   flag to indicate whether on not to calculate red tags based on
%   component damage. Typically assumed to be FALSE for small wood light
%   frame type structures.
% damage: struct
%   contains per damage state damage and loss data for each component in the building
% comps: struct
%   data structure component population info
% simulated_replacement: array [num reals x 1]
%   Time 
%
% Returns
% -------
% red_tag: logical array [num_reals x 1]
%   indicates the realizations that have a red tag
% red_tag_impact: logical array [num_reals x num_comp_ds]
%   indicates the realizations of various component damage states that
%   contribute to the cause of red tag
% inspection_tag: logical array [num_reals x 1]
%   indicates the realizations that require inspection

%% Initial Setup
% Check to see if any components need the red tag check
% if none of the components are assinged to structuctural systems, then
% skip the red tag calc
if ~any(comps.comp_table.structural_system)
    calculate_red_tag = false;
end

%% Method
if calculate_red_tag
    % Simulate Red Tags
    sc_ids = [1 2 3 4];
    sc_thresholds = [0.5 0.25 0.1 0];
    [ red_tag, red_tag_impact ] = simulate_tagging( damage, comps, sc_ids, sc_thresholds, red_tag_options );

    % Inspection is flagged for 50% of the red tag thresholds
    [ inspection_tag, ~ ] = simulate_tagging( damage, comps, sc_ids, 0.5*sc_thresholds, red_tag_options );
else
    % Do not calculate red tags based on component damage
    [num_reals,num_comp_ds] = size(damage.tenant_units{1}.qnt_damaged);
    red_tag = false(num_reals,1);
    red_tag_impact = zeros(num_reals,num_comp_ds);
    inspection_tag = false(num_reals,1);
end

% Account for global red tag cases
replace_case = ~isnan(simulated_replacement);
red_tag(replace_case) = 1;

end

function [ red_tag, red_tag_impact ] = simulate_tagging( damage, comps, sc_ids, sc_thresholds, red_tag_options )

% Simulate uncertainty in inspector threhsold
[num_reals,~] = size(damage.story{1}.qnt_damaged_dir_1);
% sc_beta = [0.5 0.5 0.5 0.5];
% sc_mins = [0.05 0.05 0.05 0];
% sc_max = [0.75 0.75 0.75 0.75];
% p_inpsector = rand(num_reals,1); % Simulate inspector "conservatism"
% sc_sim = max(min(logninv(p_inpsector,log(sc_thresholds),sc_beta),sc_max),sc_mins);

red_tag_impact = zeros(size(damage.tenant_units{1}.qnt_damaged)); % num reals by num comp_ds
red_tag_impact_cb = zeros(size(damage.tenant_units{1}.qnt_damaged)); % num reals by num comp_ds

% Go through each structural system and calc the realizations where the
% building is red tagged
for sc = 1:length(sc_ids)
    % make sure the coupl;ing beam thing resets for every safety class (otherwise the damage is
    % checked against every threshold)
    coupling_beam_dmg = zeros(num_reals,3); % three directions
    coupling_beam_qty = zeros(1,3); % three directions
    
    red_tag_impact_cb_sc = zeros(size(damage.tenant_units{1}.qnt_damaged)); % num reals by num comp_ds
    
    for s = 1:length(damage.story)
        sc_filt = damage.comp_ds_table.safety_class' >= sc_ids(sc);
        
        for dir = 1:3 % Fix assume there are three direction, where direction 3 = nondirectional
            sc_dmg = damage.story{s}.(['qnt_damaged_dir_' num2str(dir)]) .* sc_filt;
            num_comps = comps.story{s}.(['qty_dir_' num2str(dir)]);

            % For each structural system
            structural_systems = unique([damage.comp_ds_table.structural_system; damage.comp_ds_table.structural_system_alt]);
            structural_systems(structural_systems == 0) = []; % do not include components not assigned to a structural system
            
            if red_tag_options.ignore_coupling_beam_for_red_tag
                % just ignore system 12 (coupling beams)
                structural_systems(structural_systems == 12) = [];
            end
            
            for sys = 1:length(structural_systems)
                ss_filt_ds = damage.comp_ds_table.structural_system' == structural_systems(sys) | damage.comp_ds_table.structural_system_alt' == structural_systems(sys);
                ss_filt_comp = comps.comp_table.structural_system' == structural_systems(sys) | comps.comp_table.structural_system_alt' == structural_systems(sys);

                % Check damage among each series within this structural system
                
                % Initialize so the sub-series is reset for each structural system
                ser_dmg = [];
                ser_qty = [];
                
                series = unique(damage.comp_ds_table.structural_series_id(ss_filt_ds));
                for ser = 1:length(series)
                    ser_filt_ds = damage.comp_ds_table.structural_series_id' == series(ser); 
                    ser_filt_comp = comps.comp_table.structural_series_id' == series(ser); 

                    % Total damage within this series and system
                    ser_dmg(:,ser) = sum(sc_dmg(:,ser_filt_ds & ss_filt_ds),2); 

                    % Total number of components within this series and system
                    ser_qty(:,ser) = sum(num_comps(:,ser_filt_comp & ss_filt_comp),2); 
                end

                if structural_systems(sys) == 12  && red_tag_options.tag_coupling_beams_over_height
                    % HARED CODED CHECK FOR COUPLING BEAMS
                    % just do counts for now instead of adding to red tag per story check
                    coupling_beam_dmg(:, dir) = coupling_beam_dmg(:,dir) + max(ser_dmg,[],2);
                    coupling_beam_qty(1, dir) = coupling_beam_qty(1,dir) + max(ser_qty,[],2);
                    red_tag_impact_cb_sc = max(red_tag_impact_cb_sc, ss_filt_ds .* sc_filt .* (sc_dmg>0));
                    
                else
                    % Check if this system is causing a red tag
                    sys_dmg = max(ser_dmg,[],2);
                    sys_qty = max(ser_qty,[],2);
                    sys_ratio = sys_dmg ./ sys_qty;
                    sys_tag(:,sys) = sys_ratio > sc_thresholds(sc);
    %                 sys_tag(:,sys) = sys_ratio > sc_sim(:,sc); % when using simulated safety class thresholds
                    
                    % Calculate the impact that each component has on red tag
                    % (boolean, 1 = affects red tag, 0 = does not affect)
                    % Take all damage that is part of this system at this story
                    % in this direction that is damaged to this safety class
                    % level, only where damage exceeds tagging threshold
                    red_tag_impact = max(red_tag_impact, sys_tag(:,sys) .* ss_filt_ds .* sc_filt .* (sc_dmg>0));
                end
            end
            
            % Combine across all systems in this direction
            dir_tag(:,dir) = max(sys_tag,[],2);
        end

        % Combine across all directions at this story
        story_tag(:,s) = max(dir_tag,[],2);
    end
    
    % Combine across all stories for this safety class
    sc_tag(:,sc) = max(story_tag,[],2);

    %%%%%% CHECK FOR COUPLING BEAMS %%%%%%%%%%%%%%%%%%
    if any(damage.comp_ds_table.structural_system == 12)
        % CB_damage_ratio = coupling_beam_dmg(:,coupling_beam_qty > 0) ./ coupling_beam_qty(coupling_beam_qty > 0);
        CB_damage_ratio = coupling_beam_dmg ./ coupling_beam_qty;
        CB_tag_sc = nanmax(CB_damage_ratio,[],2) > sc_thresholds(sc);
        sc_tag(:,sc) = max(sc_tag(:,sc), CB_tag_sc); % add it back to sum
        red_tag_impact_cb = max(red_tag_impact_cb, red_tag_impact_cb_sc .* sc_tag(:,sc));
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end

red_tag_impact = max(red_tag_impact, red_tag_impact_cb);

% Combine all safety class checks into one simulated red tag
red_tag =  max(sc_tag,[],2);

end

