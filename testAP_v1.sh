#!/bin/bash

# Confirm all required input is entered
if [ "$#" -ne "3" ]; then
  echo "ERROR: script needs 3 arguments, the firmware version, the friendly name of AP, and band (2G or 5G) being tested."
  echo
  exit 1
else
  firmwareVersion=$1
  apName=$2
  band=$3
fi 

# List of mobile clients
#declare -a clients=("iPhone7Plus")
#declare -a clients=("GalaxyS6EdgePlus" "iPhone7Plus" "iPadGen5" "MBP2014")
#declare -a clients=("25" "21" "23")
declare -a clients=("23")
ipPool="10.1.21." # To use as prefix later, in a for-loop

duration=30 # For quick tests
#duration=600  # Longer test, to give controller more than 5 minutes to gather data for test client

mkdir -p $firmwareVersion/$apName # Create new folders if needed
# Get today date for use in log file name
dtToday=$(TZ=":America/Los_Angeles" date '+%Y'-'%m'-'%d');
# Construct log file name
logFile=$dtToday-$firmwareVersion-$apName-$band.log
# Construct log file location
logLocation=$firmwareVersion/$apName/$logFile
# Show the location and name of log file
echo "Logging results in $logLocation"

baseCommand="" # Start with empty string, to build an iPerf3 command

# Main loop that sets direction of iPerf3 tests
# Need to remember that tests are controlled/executed/run from server, but are executed for mobile clients
# DN is when the mobile client is sending to sever
# UP is when the mobile client is receiving from server
for direction in DN UP; do
  if [ $direction == DN ]; then
    # The -R sets the reverse direction, so the mobile client generates and sends the data
    baseCommand="iperf3 --forceflush -t$duration -i5 -V -R -c"
  else
    baseCommand="iperf3 --forceflush -t$duration -i5 -V -c"
  fi
  echo $direction #display direction on screen
  # Insert some lines for better visibility and readability of log
  echo "_________________________________________________________________" >> $logLocation
  echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^" >> $logLocation
 
  echo $direction >> $logLocation # Insert direction into log
  for client in "${clients[@]}"; do
    # We need more detailed time info for tests
    dtNow=$(TZ=":America/Los_Angeles" date '+%Y %m %d %H:%M:%S');
    echo "$dtNow"
    echo "$dtNow" >> $logLocation

    # Secondary loop that controls the number of parallel streams
    for streams in {1..10}; do
      # Final iperf3 command
      finalCommand="$baseCommand $ipPool$client -P$streams"
      echo "Executing $finalCommand" # Show current command on screen
      echo $finalCommand >> $logLocation 
      $finalCommand >> $logLocation # Insert current command into log

      # Depending on the direction, grab either the sender or receiver line of the iperf3 summary
      # Important to know that the tests are executed from the server, so it is important to understand the receiver and sender roles

      if [ $direction == DN ]; then # For DN direction, mobile client is the sender, so we log that
	     tail -n10 $logLocation | awk '/\[/ && /sender/ {if($1~"[SUM]") {a=$6;b=$7} else {a=$7;b=$8}} END{print "Throughput: "a,b}' 
      fi
      if [ $direction == UP ]; then # For UP direction, mobile client is the receiver, so we log that
        tail -n10 $logLocation | awk '/\[/ && /receiver/ {if($1~"[SUM]") {a=$6;b=$7} else {a=$7;b=$8}} END{print "Throughput: "a,b}' 
      fi
      sleep 5s
    done # Streams loop
    echo # Show empty line
  done # Clients loop
done # Direction loop

echo # Show empty line
echo "See $logLocation for details." # Show location of log
