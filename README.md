# PBEE-Recovery
Matlab codebase for quantifying building-specific functional recovery and reoccupancy based on a probabilistic performance-based earthquake engineering framework

### Method Description
The method for quantifying building-specific functional recovery is based on the performance-based framework and maps component-level damage to system-level performance, and system-level performance to building recovery using a series of fault trees. The method defines the recovery of function and occupancy at the tenant unit level, where a building can be made up of one-to-many tenant units, each with a possible unique set of requirements to regain building function; the recovery state of the building is defined as an aggregation of all the tenant units within the building. The method propogates uncertainty through the assesment using a Monte Carlo simulation. Details of the method are fully descrived in Cook 2021.

### Implementation Details
The method is developed as part of the consequence module of the Performance-Based Earthquake Engineering framework and uses simulations of component damage from the FEMA P-58 method as an fundamental input. THerefore, this implementation will not perform a FEMA P-58 assessment, and instead, expects the simulations of component damage, from a FEMA P-58 assessment to be provided as inputs. Along with other information about the building, the buildings tenant units, and some analysis options, this implementation with perform the functional recovery assessmnet method, and provide simulated recovery times for each realization provided. The implementation runs an assessment for a single building at a sigle intesity level.

The method is built using Matlab v2017a; running this implementation using other versions matlab may not perform as expected.

## Running an Assessment
 - **Step 1**: Build the inputs matlab data file of simulated inputs. Title the file "simulated_inputs.mat" and place it in a directory of the model name.
 - **Step 2**: Open the matlab file "driver_PBEErecovery.m" and set the "model_name", "model_dir", and "outputs_dir" variables.
 - **Step 3**: Run the script
 - **Step 4**: Simulated assessment outputs will be saved as a matlab data file in a directory of your choice

## Example Inputs
Several example input matlab data files are provided to help illustrate both the construciton of the inputs file and the implementation. These files are located in the inputs/example_inputs directory and can be run through the assessment by setting the variable names accordingly in **step 2** above.

## Definition of Inputs


## Definition of Outputs
