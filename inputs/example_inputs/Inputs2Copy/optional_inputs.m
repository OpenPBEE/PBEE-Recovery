% Impedance Time Options
impedance_options.include_impedance.inspection = true;
impedance_options.include_impedance.financing = true;
impedance_options.include_impedance.permitting = true;
impedance_options.include_impedance.engineering = true;
impedance_options.include_impedance.contractor = true;
impedance_options.system_design_time.f = 0.04;
impedance_options.system_design_time.r = 175; 
impedance_options.system_design_time.t = 1.3;
impedance_options.system_design_time.w = 8;
impedance_options.mitigation.is_essential_facility = false;
impedance_options.mitigation.is_borp_equivalent = false;
impedance_options.mitigation.is_engineer_on_retainer = false;
impedance_options.mitigation.contractor_relationship = 'good';
impedance_options.mitigation.contractor_retainer_time = 3;
impedance_options.mitigation.funding_source = 'private';
impedance_options.mitigation.capital_available_ratio = 0.1;
impedance_options.impedance_beta = 0.6;
impedance_options.impedance_truncation = 2;

% Repair Schedule Options
repair_time_options.temp_repair_beta = 0.6;
repair_time_options.max_workers_per_sqft_story = 0.001;
repair_time_options.max_workers_per_sqft_building = 0.00025;
repair_time_options.max_workers_building_min = 20;
repair_time_options.max_workers_building_max = 260;

% Functionality Assessment Options
functionality_options.red_tag_clear_time = 7;
functionality_options.door_racking_repair_day = 3;
functionality_options.egress_threshold = 0.5;
functionality_options.egress_threshold_wo_fs = 0.75;
functionality_options.fire_watch = true;
functionality_options.min_egress_paths = 2;
functionality_options.required_ratio_operating_hvac_main = 0.6667;
functionality_options.required_ratio_operating_hvac_unit = 0.6667;
functionality_options.exterior_safety_threshold = 0.1;
functionality_options.interior_safety_threshold = 0.25;
functionality_options.door_access_width_ft = 9;

% Regional Impact
regional_impact.surge_factor = 1;