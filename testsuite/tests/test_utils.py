#!/usr/bin/env python

"""test utils

This module is imported by all testcase. It parse the command lines options
and provide some useful functions.

You should never call this module directly. To run a single testcase, use
 ./testsuite.py NAME_OF_TESTCASE
"""

from e3.env import Env
from e3.fs import mkdir
from e3.os.fs import which, touch
from e3.os.process import Run, STDOUT, get_rlimit

from subprocess import Popen
from time import sleep

import os
import re
import sys

POLYORB_CONF = "POLYORB_CONF"

RLIMIT = int(os.environ['RLIMIT'])
TEST_NAME = os.environ['TEST_NAME']


# Main testsuite source dir
SRC_DIR = os.environ["SRC_DIR"]

# All executable tests path are relative to PolyORB testsuite build dir

BASE_DIR = os.path.join(os.environ["BUILD_DIR"], 'testsuite')

# The next function is from a recommended migration technique for Python 3.12.
# See https://docs.python.org/3/whatsnew/3.12.html#imp.
import importlib.util
import importlib.machinery

def load_source(modname, filename):
    loader = importlib.machinery.SourceFileLoader(modname, filename)
    spec = importlib.util.spec_from_file_location(modname, filename, loader=loader)
    module = importlib.util.module_from_spec(spec)
    # The module is always executed and not cached in sys.modules.
    # Uncomment the following line to cache the module.
    # sys.modules[module.__name__] = module
    loader.exec_module(module)
    return module

# Import config module, which is generated by configure in the testsuite
# build directory (so not on the Python search path).
config = load_source('config', os.path.join(BASE_DIR, 'tests', 'config.py'))

# Shared configuration files are in tests/conf
CONF_DIR = os.path.join(SRC_DIR, 'tests', 'confs')

EXE_EXT = Env().target.os.exeext

test_path_dirs = TEST_NAME.split("__")
OUTPUT_DIR = os.path.join(os.environ["LOG_DIR"], TEST_NAME)
OUTPUT_FILENAME = os.path.join(OUTPUT_DIR, TEST_NAME)

COVERAGE = (os.environ["COVERAGE"] == "True")
VERBOSE = os.environ["VERBOSE"] == "True"

USE_INSTALLED = config.use_installed == "yes"

def assert_exists(filename):
    """Assert that the given filename exists"""
    assert os.path.exists(filename), f"{filename} not found"


def terminate(handle):
    """Terminate safely a process spawned using Popen"""

    if sys.platform.startswith('win'):
        try:
            handle.terminate()
        except WindowsError:
            # We got a WindowsError exception. This might occurs when we try to
            # terminate a process that is already dead. In that case we check
            # if the process is still alive. If yes we reraise the exception.
            # Otherwise we ignore it.
            is_alive = True
            for index in (1, 2, 3):
                is_alive = handle.poll() is None
                if not is_alive:
                    break
                sleep(0.1)
            if is_alive:
                # Process is still not terminated so reraise the exception
                raise
    elif handle is not None:
        handle.terminate()

def get_conf_path(conf_filename):
    if not conf_filename:
        return None

    if os.path.isabs(conf_filename):
        assert_exists(conf_filename)
        return conf_filename

    for d in (CONF_DIR, os.path.join(SRC_DIR, TEST_NAME)):
        p = os.path.join (d, conf_filename)
        if os.path.exists(p):
            return p

    assert False, f"{conf_filename} not found"

def get_tool_path(tool_dir, tool_name):
    """Return tool_dir and tool_name joined, unless we are using an installed
    version of PolyORB, in which case locate it on PATH."""

    if USE_INSTALLED:
        tool_path = which(tool_name)
        if tool_path == "":
            raise Exception(f'failed to locate {tool_name} on PATH')
        return tool_path
    else:
        return os.path.join(tool_dir, tool_name)

def add_extension(exe_name):
    '''Add EXE_EXT if exe_name doesn't already carry it (case insensitive)'''

    if not exe_name.lower().endswith(EXE_EXT):
        exe_name = exe_name + EXE_EXT
    return exe_name

def client_server(client_cmd, client_conf, server_cmd, server_conf):
    """Run a client server testcase

    Run server_cmd and extract the IOR string.
    Run client_cmd with the server IOR string
    Check for "END TESTS................   PASSED"
    if found return True
    """
    print(
        f"Running client {client_cmd} (config={client_conf})\n"
        f"server {server_cmd} (config={server_conf})"
    )
    client = add_extension(os.path.join(BASE_DIR, client_cmd))
    server = add_extension(os.path.join(BASE_DIR, server_cmd))

    # Check that files exist
    assert_exists(client)
    assert_exists(server)

    server_env = os.environ.copy()
    if server_conf:
        server_env[POLYORB_CONF] = get_conf_path(server_conf)
    server_handle = None
    try:
        # Run the server command and retrieve the IOR string
        p_cmd_server = [get_rlimit(), str(RLIMIT), server]
        server_output_name = OUTPUT_FILENAME + '.server'
        mkdir(OUTPUT_DIR)
        touch(server_output_name)
        server_handle = Popen(p_cmd_server,
	                      stdout=open(server_output_name, "wb"),
			      env=server_env)
        if server_conf:
            print(
                f'RUN server: POLYORB_CONF= {server_env[POLYORB_CONF]} '
                f'{" ".join(p_cmd_server)}'
            )
        else:
            print(f'RUN server: {" ".join(p_cmd_server)}')
        server_out = open(server_output_name, "r")
        while server_handle.returncode == None:
            # Loop on readline() until we have a complete line
            line = ""

            while server_handle.returncode == None:
                server_handle.poll()
                line = line + server_out.readline()
                if len(line) > 0 and line[-1] in "\n\r":
                    break
                sleep(0.1)

            if "IOR:" in line:
                try:
                    IOR_str = re.match(r".*(IOR:[a-z0-9]+)['|\n\r]",line).groups()[0]
                    break
                except:
                    print(f"Malformed IOR line {line}")
                    raise

        # Print the server output for debug purposes
        print(server_out.read())

        if server_handle.returncode != None:
            print ("server died")
            return

        server_out.close()
        # Remove eol and '
        IOR_str = IOR_str.strip()
        print(IOR_str)

        # Run the client with the IOR argument
        p_cmd_client = [client, IOR_str]

        if client_conf:
            client_env = os.environ.copy()
            client_env[POLYORB_CONF] = get_conf_path(client_conf)
            print(
                f'RUN client: POLYORB_CONF={client_env[POLYORB_CONF]} '
                f'{" ".join(p_cmd_client)}'
            )
        else:
            client_env = None
            print(f'RUN client: {" ".join(p_cmd_client)}')

        Run(make_run_cmd([client, IOR_str], COVERAGE),
            output=OUTPUT_FILENAME + '.client', error=STDOUT, env=client_env, timeout=RLIMIT)
        if COVERAGE:
            for elmt in [client, server]:
                run_coverage_analysis(elmt)


    except Exception as e:
        print(e)
    finally:
        terminate(server_handle)

    return _check_output(OUTPUT_FILENAME + '.client')


def local(cmd, config_file, args=None):
    """Run a local test

    Execute the given command.
    Check for "END TESTS................   PASSED"
    if found return True

    PARAMETERS:
        cmd: the command to execute
        config_file: to set POLYORB_CONF
        args: list of additional parameters
    """
    args = args or []
    print(f'Running {cmd} {" ".join(args)} (config={config_file})')
    if config_file:
        assert_exists(os.path.join(CONF_DIR, config_file))
    os.environ[POLYORB_CONF] = config_file

    command = add_extension(os.path.join(BASE_DIR, cmd))
    assert_exists(command)

    p_cmd = [command] + args

    if VERBOSE:
        if config_file:
            print(f'RUN: POLYORB_CONF={config_file} {" ".join(p_cmd)}')
        else:
            print(f'RUN: {" ".join(p_cmd)}')

    mkdir(OUTPUT_DIR)
    Run(make_run_cmd(p_cmd, COVERAGE),
        output=OUTPUT_FILENAME + 'local', error=STDOUT,
        timeout=RLIMIT)
    if COVERAGE:
        run_coverage_analysis(command)


    return _check_output(OUTPUT_FILENAME + 'local')


def _check_output(output_file):
    """Check that END TESTS....... PASSED is contained in the output"""
    if os.path.exists(output_file):
        with open(output_file, 'rb') as test_outfile:
            test_out = test_outfile.read()

        print(test_out)

        if re.search(rb"END TESTS.*PASSED", test_out):
            print(f"{TEST_NAME} PASSED")
            return True
        else:
            print(f"{TEST_NAME} FAILED")
            return False


def make_run_cmd(cmd, coverage=False):
    """Create a command line for Run in function of coverage

    Returns command and arguments list
    """
    L = []
    if coverage:
        L.extend(['xcov', '--run', '--target=i386-linux', '-o',
                  cmd[0] + '.trace', cmd[0]])
        if len(cmd) > 1:
            L.append('-eargs')
            L.extend(cmd[1:])
    else:
        L.extend(cmd)
    return L


def run_coverage_analysis(command):
    """Run xcov with appropriate arguments to retrieve coverage information

    Returns an object of type run
    """
    return Run(['xcov', '--coverage=branch', '--annotate=report',
                command + ".trace"],
               output=OUTPUT_FILENAME + '.trace', error=STDOUT,
               timeout=RLIMIT)


def fail():
    print("TEST FAILED")
    sys.exit(1)
