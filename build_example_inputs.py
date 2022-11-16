"""
Go through example inputs and rebuild simulated input file
"""
import os
import shutil
import subprocess
import time

def build_inputs(input_dir, build_file_dir):
    """
    Parameters
    ----------
    input_dir: str
        location of the example input directories
    build_file_dir: str
        location of the build scripts to copy

    Returns
    -------
    None, writes simulated_inputs.m in each example inputs directory
    """

    # Define files to copy
    bld_script = build_file_dir + '/build_inputs.m'
    opt_script = build_file_dir + '/optional_inputs.m'

    # Go through each example input folder
    dirs = os.listdir(input_dir)
    for d in dirs:
        # Copy files over to example input directory
        shutil.copyfile(bld_script, input_dir + '/' + d + '/build_inputs.m')
        shutil.copyfile(opt_script, input_dir + '/' + d + '/optional_inputs.m')

        # Delete old simulated inputs file (if it exists)
        file_exists = os.path.exists(input_dir + '/' + d + '/simulated_inputs.mat')
        if file_exists:
            os.remove(input_dir + '/' + d + '/simulated_inputs.mat')

        # Execute Matlab build script
        bld_path = os.path.abspath(input_dir + '/' + d + '/build_inputs.m')
        exc_str = "run('" + bld_path + "'); exit;"
        p = subprocess.run(["matlab", "-nosplash", "-nodesktop", "-r", exc_str])

        time.sleep(60)  # low tech way of getting python to wait until matlab is finished

        # Check if the input file has been successfully created
        file_exists = os.path.exists(input_dir + '/' + d + '/simulated_inputs.mat')
        if file_exists:
            # Delete build scripts
            os.remove(input_dir + '/' + d + '/build_inputs.m')
            os.remove(input_dir + '/' + d + '/optional_inputs.m')
        else:
            raise Exception("Matlab process failed to build inputs")

if __name__ == '__main__':

    # Copy fragilities table over from original location to public repo (with some omissions)
    example_input_dir = 'inputs/example_inputs'
    build_file_dir = 'inputs/Inputs2Copy'
    build_inputs(example_input_dir, build_file_dir)
