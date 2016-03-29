##
#
# This script will generate a docker-compose yml file
# to ensure correct version being used, and then starts
# the containers.
#
##

# Printing welcome msg
echo "
##                                                                            ##
#                                                                              #
#  Starting STACI - Support Tracking and Continuous Integration.               #
#                                                                              #
#  - If you need to build images, use ./functions/build.f/buildAll             #
#  - If you need to push images to docker hub, use ./bin/push-to-dockerhub.sh  #
#      (You might want to implement it first)                                  #
##                                                                            ##
"

# Create needed directories
mkdir -p compose
mkdir -p logs

# Sourcing env setup
source setEnv.sh
source $STACI_HOME/functions/tools.f
source $STACI_HOME/functions/build.f

# Find out, if we should create a cluster or not
cluster=$(getProperty "createCluster")
#provider_type=$(getProperty "provider_type")

# Show directory for data
volume_dir=$(getProperty "volume_dir")
echo " - Using $volume_dir for persistance"

# Show backup folder
backup_folder=$(getProperty "backup_folder")
echo " - Using $backup_folder for backup"

# Create folders for persistant container data, if not existing
# But only if run locally
if [ ! -d "$volume_dir" ] && [ "$cluster" == 0 ]; then
  mkdir -p "$volume_dir"
  mkdir -p "$volume_dir/jira"
  mkdir -p "$volume_dir/confluence"
  mkdir -p "$volume_dir/bamboo"
  mkdir -p "$volume_dir/atlassiandb"
  mkdir -p "$volume_dir/bitbucket"
  mkdir -p "$volume_dir/crowd"
  mkdir -p "$volume_dir/crucible"
  echo " - Created $volume_dir folder."
fi

read -p "
 - Press [Enter] key to continue...
"

if [ "$cluster" == 1 ]; then
   source functions/dockermachine.f
   createSwarm
fi

echo "
 - Building images"
buildAll

# Generate a new compose yml, and put it in the compose folder
echo -n " - Generating docker-compose.yml - "
./bin/generateCompose.sh > ./compose/docker-compose.yml
if [ $? -ne 0 ]; then
   echo "ERROR"
else
   echo "OK"
fi

# Start the containers with docker-compose
echo -n " - Starting containers, using docker-compose :
"

if [ "$cluster" == 1 ]; then
  node_prefix=$(getProperty "clusterNodePrefix")
  eval $(docker-machine env --swarm $node_prefix-mysql)
fi
docker-compose -f compose/docker-compose.yml up -d > $STACI_HOME/logs/docker-compose.log 2>&1 &


# Generate System Information html
./bin/generateSystemInfo.sh > $STACI_HOME/SystemInfo.html

# Open tools and System Information websites
use_browser=$(getProperty "use_browser")
if [ "$use_browser" == "1" ]; then
  browser_cmd=$(getProperty "browser_cmd")
  $browser_cmd "$STACI_HOME/SystemInfo.html" &>/dev/null &
fi

start_mysql=$(getProperty "start_mysql")
if [ ! -z $start_mysql ];then
  # TODO: Need to wait for MySQL to start, before continuing, instead of sleep
  sleep 20

  # Setup database
  ./bin/init-mysql.sh
fi

echo '
 - To view logs, execute "docker-compose -f compose/docker-compose.yml logs"
 - To stop, execute "./stop.sh"
 - To start again later, execute "./start.sh"
'
