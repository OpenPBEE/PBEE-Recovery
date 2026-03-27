# Field Name Summary
This file gives descriptions of the fields in all the data files.

### File: component_attributes.csv

Field                | Description
---                  | ---
fragility_id         | Reference name for the fragility **
description          | Description of the fragility **
unit_qty             | The quantity associated with one unit of the fragility **
unit                 | The unit used to populate the fragility **
name                 | Name that the fragility is referred to as **
name_short           | An abbreviated version of the fragility name
group                | The group that the fragility belongs to (broad grouping)
author               | Author of the fragility **
is_official_p58      | If the fragility is part of the FEMA P-58 database or created by another organization
system_id            | Integer corresponding to a system in _system.csv_
subsystem_id         | Integer corresponding to a subsystem in _subsystem.csv_
service_location     | If the component serves the 'building' or a single tenant 'unit'
structural_system    | If a structural component, this is the structural system that the component belongs to
structural_series_id | If a LRFS structural system consists of multiple components to be considered separately, this provides a distinction between the systems.

** from the FEMA P-58 database (when the fragility is part of the official P-58 database)


### File: component_attributes.csv

This file handles the per-damage state attribute assignments for the ATC-138 fields required for the fault tree 


The metadata:

Field                     | Description
---                       | ---
fragility_id_regex        | Regular Expression to match fragility IDs in this line
component_type            | Brief description of what this group of components are
spirit_of_damage          | A description of what damage this is intended to cover
ds_index                  | Index of the damage state that this corresponds to for the components matching the fragility_id_regex
sub_ds_index              | Index of the sub-damage state (fro DS1a, DS1b, etc.) that this corresponds to for the components matching the fragility_id_regex
is_sim_ds                 | If the damage state is simultaneous (should be deprecated? Can be determined from the damage state consequences themselves)
time_lower_quantity       | should be deprecated, used for debugging only
time_upper_quantity       | should be deprecated, used for debugging only
original_fft              | should be deprecated, was used in development, not intended for production use

Property assignments:

Field                     | Description
---                       | ---
safety_class              | The safety class for red tagging (1, 2, 3)
affects_envelope_safety   | If this damage will affect the safety of the envelope (keeping people from falling out)
exterior_falling_hazard   | If this damage will pose a falling hazard to those immediately outside the building
interior_falling_hazard   | If this damage will cause a falling hazard to occupants inside the building
global_hazardous_material | If this is damage posing a hazmat threat to the whole building
local_hazardous_material  | If this is damage posing a hazmat threat to just the tenant unit that it's in
affects_access            | If this damage affects access/egress to the building/story (mainly for stairs)
damages_envelope_seal     | If this damage makes the seal of the envelope is not "weather tight" (functionality check, not safety check)
obstructs_interior_space  | If this damage will inhibit use is some prortion of the interior space
impairs_system_operation  | If this damage will cause the system that it is a part of to not operate adequately
fraction_area_affected    | The fraction of the area associated with the `area _affected_unit`
area_affected_unit        | The unit associated with `fraction_area_affected` ('bay', 'building', 'component')
crew_size                 | The size of crew that is required to permanently fix this damage
permit_type               | The type of permit required to permanently fix this damage ('full', 'rapid')
redesign                  | If this damage requires en engineer to design/check the repair of the component
long_lead                 | If this component requires a long lead time to fix this damage
requires_shoring          | If this damage requires temporary shoring
resolved_by_scaffolding   | If scaffolding can resolve the danger/loss of function caused by this damage (e.g. exterior falling hazards)
tmp_repair_class          | The temporary repair class id (see **temp_repair_class.csv**)
tmp_repair_time_lower     | Repair time for low quantity temporary repairs (the low/high quantity thresholds are the same as the regular repair time)
tmp_repair_time_upper     | Repair time for high quantity temporary repairs (the low/high quantity thresholds are the same as the regular repair time)
tmp_crew_size             | The crew size for temporary repairs


### File: impeding_factors.csv

This handles the definition of the (non-contractor) impedance times.
Contractor times are hard coded in the repo.

Field                     | Description
---                       | ---
factor                    | The impeding factor
category                  | A mitigation condition/option of the impeding factor 
time_days                 | The median amount of time (in days) that the impedance takes in the recovery calculation 


### File: systems.csv

These are the systems that are considered in the fault tree analysis.

Field                    | Description
---                      | ---
id                       | The id used to reference this system in other files
name                     | Name of the structural system in words
priority                 | The priority in the repair schedule relative to other systems
num_du_per_crew          | The number of damaged units that a single crew can handle 
max_crews_per_comp_type  | The maximum number of crews that can be used in the repair process
imped_design_min_days    | Minimum (median) days that are required for the engineering design 
imped_design_max_days    | Maximum (median) days that are required for the engineering design


### File: subsystems.csv

These are the subsystems that are considered in the fault tree analysis.

Field                    | Description
---                      | ---
id                       | The id used to reference this subsystem in other files
name                     | The name of the sub system
parallel_operation       | If the components of this subsystem can operate independently (in parallel)
redundancy_threshold     | The damage threshold (ratio of damaged components) above which the subsystem can no longer operate
n1_redundancy            | If there is an n+1 redundancy in this sub system (number of units needed for normal function + 1 extra) 


### File: temp_repair_class.csv

This defines the different temporary repair types.

Field                       | Description
---                         | ---
id                          | The id used to reference this repair class in other files
name                        | The name of this repair class
priority                    | The relative priority in the repair process for each repair class
num_du_per_crew             | The number of damaged units that a single crew can handle
max_crews_per_comp_type     | The maximum number of crews that can be deployed per unique component type in the system (different fragility ids)
impeding_time               | The number of days it takes to get the temporary repair crew on site
impeding_time_no_contractor | The number of days it takes to get the temporary repair crew on site if there is no existing relationship with a contractor


### File: tenant_function_requirements.csv

This defines the default requirements for a given occupancy type to function within a tenant unit.

Field                        | Description
---                          | ---
id                           | The id used to reference this tenant requirement in other files/code
occupancy_id                 | The id of the occupancy (SP3) that corresponds to this tenant type
occupancy_name               | Name of the occupancy
exterior                     | The ratio of exterior perimeter area (of the tenant unit) affected by damage above which the exterior is no longer considered functional
interior                     | The ratio of interior plan area (of the tenant unit) affected by damage above which the tenant unit is no longer considered functional
occ_per_elev                 | The number of occupants needed to be served per elevator to be considered functional 
is_elevator_required         | If the elevator is required for function
max_walkable_story           | The highest story at which people can be expected to walk if the elevator is out of service
is_electrical_required       | If electricity system operation is required for the tenant unit to be considered functional
is_water_potable_required    | If potable water system operation is required for the tenant unit to be considered functional
is_water_sanitary_required   | If sanitary piping system operation is required for the tenant unit to be considered functional
is_hvac_ventilation_required | If HVAC ventilation system operation is required for the tenant unit to be considered functional
is_hvac_heating_required     | If heating system operation is required for the tenant unit to be considered functional
is_hvac_cooling_required     | If cooling system operation is required for the tenant unit to be considered functional
is_hvac_exhaust_required     | If HVAC exhaust system operation is required for the tenant unit to be considered functional
