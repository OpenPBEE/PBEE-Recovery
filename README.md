# PBEE-Recovery
Matlab codebase for quantifying building-specific functional recovery and reoccupancy based on a probabilistic performance-based earthquake engineering framework.

### Method Description
The method for quantifying building-specific functional recovery is based on the performance-based earthquake engineering framework. To quantify building function, the method maps component-level damage to system-level performance, and system-level performance to building function using a series of fault trees that describe the interdependencies between the functions of various building components. The method defines the recovery of function and occupancy at the tenant unit level, where a building can be made up of one-to-many tenant units, each with a possible unique set of requirements to regain building function; the recovery state of the building is defined as an aggregation of all the tenant units within the building. The method propagates uncertainty through the assessment using a Monte Carlo simulation. Details of the method are fully described in Cook, Liel, Haselton, and Koliou, 2022. "A Framework for Operationalizing the Assessment of Post Earthquake Functional Recovery of Buildings", Earthquake Spectra, Accepted.

### Implementation Details
The method is developed as part of the consequence module of the Performance-Based Earthquake Engineering framework and uses simulations of component damage from the FEMA P-58 method as an fundamental input. Therefore, this implementation will not perform a FEMA P-58 assessment, and instead, expects the simulations of component damage, from a FEMA P-58 assessment to be provided as inputs. Along with other information about the building, the buildings tenant units, and some analysis options, this implementation will perform the functional recovery assessment method, and provide simulated recovery times for each realization provided. The implementation runs an assessment for a single building at a single intensity level. The implementation of the method does not handle demo and replace conditions and predicts building function based on component damage simulation and recovery times assuming damage will be repaired in-kind. Building failure, demo, and replacement conditions can be handled as a post-process by either overwriting realizations where global failure occurs or only inputting realizations that are scheduled for repair.

The method is built using Matlab v2017a; running this implementation using other versions Matlab may not perform as expected.

## Running an Assessment
 - **Step 1**: Build the inputs matlab data file of simulated inputs. Title the file "simulated_inputs.mat" and place it in a directory of the model name within the "inputs" drirectory.
 - **Step 2**: Open the matlab file "driver_PBEErecovery.m" and set the "model_name", "model_dir", and "outputs_dir" variables.
 - **Step 3**: Run the script
 - **Step 4**: Simulated assessment outputs will be saved as a Matlab data file in a directory of your choice

## Example Inputs
Several example inputs are provided to help illustrate both the construction of the inputs file and the implementation. These files are located in the inputs/example_inputs directory and can be run through the assessment by setting the variable names accordingly in **step 2** above.

## Definition of I/O
A brief description of the various input and output variables are provided below. A detailed schema of all expected input and output subfields is provided in the PBEE-Recovery/schema directory.

### Inputs
 - **repair_time_options**: [_struct_]
   data structure containing optional method inputs for the assessment of recovery time, such as repair schedule, impedance, and mitigation factor optional inputs
 - **functionality_options**: [_struct_]
   data structure containing optional method inputs for the assessment of building function, such as functionality limit state thresholds
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
