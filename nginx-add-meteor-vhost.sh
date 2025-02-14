#!/bin/bash -
#===============================================================================
#
#          FILE: nginx-add-meteor-vhost
#
#         USAGE: nginx-add-meteor-vhost -u user -h host [-v]
#                nginx-add-meteor-vhost --user user --host host [--verbose]
#
#   DESCRIPTION: This script will add a virtual host configuration file to
#                 the Nginx sites-available/ directory and then creates a
#                 symbolic link to that file in sites-enabled/.
#                The file is named <host>.conf and will be configured to run
#                 under the supplied user name using the app bundle in their
#                 ~/www/bundle directory.  It will be handled by Passenger
#                 and served on via regular HTTP on port 80.
#               A user will be created and the home directory will have a
#                 symblolic link named www (~/www/) that leads to their web
#                 application directory, /var/www/<user>.  Note that on my
#                 Amazon Meteor Server 1 AMI, /var/www/ is a symbolic link
#                 to /opt/www/.
#               The app will be given a Mongo database @ localhost:27017/<user>.
#       OPTIONS:
#                -u | --user
#                   The name of the system account the host will be attributed to.
#                -h | --host
#                   The fully qualified domain name of the virtual host.
#                -v | --verbose
#                   If passed, will show all commands executed.
#  REQUIREMENTS: Nginx, Passenger, Node 0.10.40 managed by N, Mongo, ~/www/,
#                 /etc/nginx/sites-available/, /etc/nginx/sites-enabled/,
#                 /var/www/, sudo privileges.
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Jason White (Jason@iDoAWS.com),
#  ORGANIZATION: @iDoAWS
#       CREATED: 04/15/2016 15:33
#      REVISION:  001
#          TODO: Add -s option to enable commented lines and do certificate work
#===============================================================================

# Strict mode
set -euo pipefail
IFS=$'\n\t'

# Check for arguments or provide help
if [ ! -n "$1" ] ; then
  echo "Usage:"
  echo "  $0 -u user -h host [-v]"
  echo "  $0 --user user --host host [--verbose]"
  exit 0
fi

# Parse command line arguments into variables
while :
do
    case "$1" in
      -h | --host)
    HOST="$2"
    shift 2
    ;;
      -s | --ssl)
    SSL=true
    shift 1
    ;;
      -u | --user)
    USERNAME="$2"
    shift 2
    ;;
      -v | --verbose)
    VERBOSE=true
    shift 1
    ;;
      -*)
    echo "Error: Unknown option: $1" >&2
    exit 1
    ;;
      *)  # No more options
    break
    ;;
    esac
done

# Validate required arguments
if [ ! $USERNAME ] ; then
  echo 'User name is required.'
  exit 1
fi
if [ ! $HOST ] ; then
  echo 'Host name is required.'
  exit 1
fi

# Check verbosity
if [ -n "$VERBOSE" ] ; then
  set -v
fi

# Add $USERNAME and setup home dir
# TODO: Skip things that exist
sudo adduser $USERNAME -G wheel
sudo mkdir /home/$USERNAME/.ssh
sudo mkdir /var/www/$USERNAME
sudo cp ~/.ssh/authorized_keys /home/$USERNAME/.ssh/
sudo git clone https://github.com/idometeor/amazon-scripts /home/$USERNAME/bin
sudo ln -s /var/www/$USERNAME /home/$USERNAME/www
sudo chown -R $USERNAME: /home/$USERNAME/
sudo chown -R $USERNAME: /var/www/$USERNAME

# Create /etc/nginx/sites-available/$HOST.conf
echo "server {
    server_name $HOST;
    root /var/www/$USERNAME/bundle/public;

    listen 80;
    # listen 443 ssl;

    passenger_enabled on;
    passenger_app_type node;
    passenger_startup_file main.js;
    passenger_nodejs /usr/local/n/versions/node/0.10.43/bin/node;
    passenger_sticky_sessions on;

    passenger_env_var MONGO_URL mongodb://localhost:27017/$USERNAME;
    passenger_env_var ROOT_URL http://$HOST;
    # passenger_env_var METEOR_SETTINGS ./settings.json

    # ssl_certificate      /etc/ssl/$HOST.crt;
    # ssl_certificate_key  /etc/ssl/$HOST.key;

}" | sudo tee /etc/nginx/sites-available/$HOST.conf

# Enable
sudo ln -s /etc/nginx/sites-available/$HOST.conf /etc/nginx/sites-enabled/$HOST.conf

# End
echo "Tasks complete.  Nginx will need to be restarted in order to take effect."
read -p "Would you like me to restart Nginx for you? [y/N] " -n 1 -r REPLY
if [[ $REPLY =~ "^[Yy]$" ]] ; then
  sudo service nginx restart
fi
exit 0
