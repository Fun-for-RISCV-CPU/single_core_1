#/bin/bash

cd sim

if [ ! -f sim.log ] || grep -iq 'error\|warning' sim.log; then
    echo -e "\033[0;31mSim failed:\033[0m"
    grep -i 'error\|warning' sim.log
    exit 1
else
    echo -e "\033[0;32mSim Successful \033[0m"
fi

exit 0
