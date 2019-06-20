#!/bin/sh
### BEGIN INIT INFO
# Provides: start DroneBridge
# Required-Start: $remote_fs $syslog $local_fs
# Required-Stop:
# Default-Start: 3 5
# Default-Stop: 3 5
# Short-Description: Inits the wifi adapters, starts OSD & modules
# Description:  Helper & auto start script for DroneBridge. Placed in /etc/init.d/ to handle DroneBridge on system boot
### END INIT INFO

declare -a DBModuleNames=(
"osd" "video_air" "video_gnd" "db_pi_player" "db_pi_player_30" "db_pi_player_48"
"db_pi_player_240" "status" "proxy" "control_air" "control_ground" "db_ip_checker.py" "db_communication_air.py"
"db_communication_gnd.py" "init_wifi.py" "start_db_modules.py"
)

RED='\033[0;31m'
GRN='\033[1;32m'
NC='\033[0m' # No Color


function start_osd() {
  echo
  dos2unix -n /boot/osdconfig.txt /boot/osdconfig.txt
  echo
  cd /root/DroneBridge/osd
  echo Building OSD:
  make -j2 || {
    echo -e "${RED}ERROR: Could not build OSD, check osdconfig.txt!${NC}"
  }
  cd /tmp
  ./osd &
}

function stop_db_modules() {
  echo "Stopping DroneBridge modules"
  for DB_MODULE in in ${DBModuleNames[@]}; do
    pkill -9 -n -x -f "$DB_MODULE"
  done
}

function init_dronebridge() {
    if vcgencmd get_throttled | nice grep -q -v "0x0"; then
    TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
    TEMP_C=$(($TEMP / 1000))
    if [[ "$TEMP_C" -lt 75 ]]; then # it must be under-voltage
      mount -o remount,ro /boot
      echo "1" >/tmp/undervolt
      echo -e "${RED}Under-voltage detected. Please check your power supply!${NC}"
    else
      echo "0" >/tmp/undervolt
    fi
  else
    echo "0" >/tmp/undervolt
  fi

  CAM=$(/usr/bin/vcgencmd get_camera | nice grep -c detected=1)

  if [[ "$CAM" == "0" ]]; then
    echo "Welcome to DroneBridge v0.6 Beta (GND) - "
    python3.7 /root/DroneBridge/startup/init_wifi.py -g
    start_osd
    python3.7 /root/DroneBridge/startup/start_db_modules.py -g
  else
    echo "Welcome to DroneBridge v0.6 Beta (UAV) - "
    python3.7 /root/DroneBridge/startup/init_wifi.py
    python3.7 /root/DroneBridge/startup/start_db_modules.py
  fi
}

case "$1" in
  start)
    init_dronebridge
    ;;
  stop)
    stop_db_modules
    ;;
  restart)
    stop_db_modules
    start_db_modules
    ;;
  force-reload)
    stop_db_modules
    init_dronebridge
    ;;
  status)
    echo "Status of DroneBridge applications"
    for DB_MODULE in in ${DBModuleNames[@]}; do
      if pgrep -x "$DB_MODULE" >/dev/null
      then
          echo -e "$DB_MODULE ${GRN}running${NC}"
      else
          echo -e "$DB_MODULE ${RED}stopped${NC}"
      fi 
    done
    ;;
  *)
    echo "Usage: /etc/init.d/start_db {start|stop|restart|force-reload|status}"
    exit 1
    ;;
esac
 
exit 0