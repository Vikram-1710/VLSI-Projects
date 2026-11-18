setenv VCS_HOME /soft/ece_soft_1/synopsys/vcs_2021.09
#setenv VCS_HOME /soft/ece_soft_1/synopsys/vcs_2018.09
setenv LM_LICENSE_FILE /soft/ece_soft_1/synopsys/license/license.dat
source $VCS_HOME/bin/environ.csh

# will be removed once the IT peopel fix linux library issue
if ( $?LD_LIBRARY_PATH ) then
    setenv LD_LIBRARY_PATH "${LD_LIBRARY_PATH}:/project/F25-EE5327/libnsl_dir"
else
    setenv LD_LIBRARY_PATH /project/F25-EE5327/libnsl_dir
endif
