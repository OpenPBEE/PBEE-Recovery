# PBEE-Recovery
Matlab codebase for quantifying building-specific functional recovery and reoccupancy based on a probabilistic performance-based earthquake engineering framework.

### Method Description
The method for quantifying building-specific functional recovery is based on the performance-based earthquake engineering framework. To quantify building function, the method maps component-level damage to system-level performance, and system-level performance to building function using a series of fault trees that describe the interdependencies between the functions of various building components. The method defines the recovery of function and occupancy at the tenant unit level, where a building can be made up of one-to-many tenant units, each with a possible unique set of requirements to regain building function; the recovery state of the building is defined as an aggregation of all the tenant units within the building. The method propagates uncertainty through the assessment using a Monte Carlo simulation. Details of the method are fully described in Cook, Liel, Haselton, and Koliou, 2022. "A Framework for Operationalizing the Assessment of Post Earthquake Functional Recovery of Buildings", Earthquake Spectra.

### Implementation Details
The method is developed as part of the consequence module of the Performance-Based Earthquake Engineering framework and uses simulations of component damage from the FEMA P-58 method as an fundamental input. Therefore, this implementation will not perform a FEMA P-58 assessment, and instead, expects the simulations of component damage, from a FEMA P-58 assessment to be provided as inputs. Along with other information about the building, the buildings tenant units, and some analysis options, this implementation will perform the functional recovery assessment method, and provide simulated recovery times for each realization provided. The implementation runs an assessment for a single building at a single intensity level. The implementation of the method does not handle demo and replace conditions and predicts building function based on component damage simulation and recovery times assuming damage will be repaired in-kind. Building failure, demo, and replacement conditions can be handled as a post-process by either overwriting realizations where global failure occurs or only inputting realizations that are scheduled for repair.

The method is built using Matlab v2017a; running this implementation using other versions Matlab may not perform as expected.

## Running an Assessment
 - **Step 1**: Build the inputs matlab data file of simulated inputs. Title the file "simulated_inputs.mat" and place it in a directory of the model name within the "inputs" drirectory. This matlab data file can either be constructed manually following the inputs schema or using the build script as discussed in the _Building the Inputs File section_ below.
 - **Step 2**: Open the matlab file "driver_PBEErecovery.m" and set the "model_name", "model_dir", and "outputs_dir" variables.
 - **Step 3**: Run the script
 - **Step 4**: Simulated assessment outputs will be saved as a Matlab data file in a directory of your choice

## Example Inputs
Several example inputs are provided to help illustrate both the construction of the inputs file and the implementation. These files are located in the inputs/example_inputs directory and can be run through the assessment by setting the variable names accordingly in **step 2** above.

## Definition of I/O
A brief description of the various input and output variables are provided below. A detailed schema of all expected input and output subfields is provided in the PBEE-Recovery/schema directory.

### Inputs
  - **impedance_options**: [_struct_]
   data structure containing optional method inputs for the assessment of impeding factors
 - **repair_time_options**: [_struct_]
   data structure containing optional method inputs for the assessment of the repair schedule
 - **functionality_options**: [_struct_]
   data structure containing optional method inputs for the assessment of building function, such as functionality limit state thresholds
 - **regional_impact**: [_struct_] 
   general inputs that quantify regional impact on individual building performance
 - **building_model**: [_struct_]
   data structure containing general information about the building such as the number of stories and the building area
 - **damage**: [_struct_]
   data structure containing simulated damage, simulated repair time, and component attribute data associated with each component's damages state in the building
 - **damage_consequences**: [_struct_]
   data structure containing simulated building consequences, such as red tags and repair costs ratios
 - **functionality.utilities**: [_struct_]
   data structure containing simulated utility downtimes
 - **tenant_units**: [_table_]
   datatable that contains the attributes and functional requirements of each tenant unit in the building

### Outputs
 - **functionality.recovery**: [_struct_]
   data structure containing the simulated tenant- and building-level functional recovery and reoccupancy outcomes
 - **functionality.building_repair_schedule**: [_struct_]
   data structure containing the simulated building repair schedule
 - **functionality.worker_data**: [_struct_]
   data structure containing the simulation of allocated workers throughout the repair process
 - **functionality.impeding_factors**: [_struct_]
   data structure containing the simulated impeding factors delaying the start of system repair

## Building the Inputs File
Instead of manually defining the inputs matlab data file based on the inputs schema, the inputs file can be built from a simpler set of building inputs, taking advantage of default assessment assumptions and component, system, and tenant attributes contained within the _static_tables_ directory.

### Instructions
 - **Step 1**: Copy the scripts build_inputs.m and optional_inputs.m from the _Inputs2Copy_ directory to the directory where you want to build the simulated_inputs.mat inputs file.
 - **Step 2**: Add the requried building specific input files listed below to the same directory
 - **Step 3**: Modify the optional_inputs.m file as needed.
 - **Step 4**: Make sure the variable _static_data_dir_ in build_inputs.m is correctly pointing to the location of the static data directory
 - **Step 5**: Run the build script

#### Option for Customizing Static Data 
If you would like to modify the static data tables listed below for a specifc model, simply copy the static data tables listed below to the build script directory, modify the files, and set the _static_data_dir_ vairable to the point to the location of the modified files (same directory as the build script).

### Required Building Specific Data
Each file listed below contains data specific to the building performance model and simulated damage given for a specific level of shaking. Each file listed will need to be created for each unique assessment and saved in the root directory of the build script. Data are contained in either json structures or csv tables.
 - **building_model.json**: Basic properties of the building and performance model. Contains all variables within the _building_model_ structure defined in the inputs schema.
 - **tenant_unit_list.csv**: Table that lists each tenant unit within the building; one row per tenant unit. This table requires the following attributes:
     - id: [int or string] unique identifier for this tenant unit
     - story: [int] building story where this tenant unit is located (ground floor is listed at 1)
     - area: [number] total gross plan area of the tenant unit, in square feet
     - perim_area: [number] total exterior perimeter area (elevation) of the tenant unit, is square feet
     - occupancy_id: [int] foreign key to the _occupancy_id_ attribute of the tenant_function_requirements.csv table in the _static_tables_ directory
 - **comp_ds_list.csv**: Table that lists each component and damage state populated in the building performance model; one row per each component's damage state. This table requires the following attributes:
     - comp_id: [string] unique FEMA P-58 component identifier
     - ds_seq_id: [int] interger index of the sequential parent damage state (i.e., damage state 1, 2, 3, 4);
     - ds_sub_id: [int] interger index for the mutually exlusive of simeltaneous sub damage state; use 1 to indicate a sequential damage state with no sub damage state.
 - **damage_consequences.json**: Building-level and story-level simulated properties of building damage. Contains all variables within the _damage_consequences_ structure defined in the inputs schema.
 - **simulated_damage.json**: Component-level simulated damage properties. Contains all variables within the _damage.tenant_units_ structure defined in the inputs schema. Each variable containing realization of component damage should be defined uniquely for each tenant unit (shown as "tu" below). Each tenant_unit cell should contain the following variables:
     - tenant_unit{tu}.qnt_damaged: [array: simulations × damage states] The number of damaged components in each component damage state for each realization of the simulation.
     - tenant_unit{tu}.worker_days: [array: simulations × damage states] The number of single worker days required to repair all damage to this damage state of this component at this story for each realization.
     - tenant_unit{tu}.qnt_damaged_side_1: [array: simulations × damage states] The number of damaged components in each component damage state assocaited with side 1 of the building; set to zero if not associated with a particular side. This is only for exterior cladding components.
     - tenant_unit{tu}.qnt_damaged_side_2: [array: simulations × damage states] The number of damaged components in each component damage state assocaited with side 2 of the building; set to zero if not associated with a particular side. This is only for exterior cladding components.
     - tenant_unit{tu}.qnt_damaged_side_3: [array: simulations × damage states] The number of damaged components in each component damage state assocaited with side 3 of the building; set to zero if not associated with a particular side. This is only for exterior cladding components.
     - tenant_unit{tu}.qnt_damaged_side_4: [array: simulations × damage states] The number of damaged components in each component damage state associated with side 4 of the building; set to zero if not associated with a particular side. This is only for exterior cladding components.
     - tenant_unit{tu}.num_comps: [array: 1 × damage states] The total number of components associated with each damage state (should be uniform for damage state of the same component stack).

### Optional Building Specific Data
The file(s) listed below contain data that is optional for the assessment. If the files do not exist, the method will make simplifying assumptions to account for the missing data (as noted below). Save in the root directory of the build script.
 - **utility_downtime.json**: Regional utility simulated downtimes for gas, water, and electrical power networks. Contains all variables within the _functionality.utilities_ structure defined in the inputs schema.

### Default Optional Inputs
The matlab file listed below defines additional assessment inputs based on set of default values. Copy the file from the _Inputs2Copy_ directory, place it in the root directory of the build script, and modify it as you see if (or build the script programmatically)
 - **optional_inputs.m**: Defines default variables for the impedance_options, repair_time_options, functionality_options, and regional_impact variables listed in the inputs schema.

### Static Data
The csv tables listed below contain default componet, damage state, system, and tenant function attributes that can be used to populate the required assessment inputs according to the methodology. Either point the _static_data_dir_ variable in build_inputs.m to the location of these tables in the _static_tables_ directory, or copy and modify them as you see fit and place them in the root directory of the build script.
 - **component_attributes.csv**: Attributes of components in the FEMA P-58 fragility database that are required for the functional recovery assessment.
 - **damage_state_attribute_mapping.csv**: Attributes of damage state in the FEMA P-58 fragility database and their affect on function and reoccupancy.
 - **subsystems.csv**: Attributes of each default subsystem considered in the method.
 - **tenant_function_requirements.csv**: Default tenant requirements for function for various occupancy classes.
