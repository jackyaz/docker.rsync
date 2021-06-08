#!/bin/sh

################################################################################
# INIT
################################################################################

mkdir -p /root/.ssh
> /root/.ssh/authorized_keys
chmod go-rwx /root/.ssh/authorized_keys
sed -i "s/.*PasswordAuthentication .*/PasswordAuthentication no/g" /etc/ssh/sshd_config
sed -i 's/root:!/root:*/' /etc/shadow

# Provide SSH_AUTH_KEY_* via environment variable
for item in `env`; do
   case "$item" in
       SSH_AUTH_KEY*)
            ENVVAR=`echo $item | cut -d \= -f 1`
            printenv $ENVVAR >> /root/.ssh/authorized_keys
            ;;
   esac
done

# Provide CRON_TASK_* via environment variable
> /etc/crontabs/root
for item in `env`; do
   case "$item" in
       CRON_TASK*)
            ENVVAR=`echo $item | cut -d \= -f 1`
            printenv $ENVVAR >> /etc/crontabs/root
            echo "root" > /etc/crontabs/cron.update
            ;;
   esac
done

# Implemented changes from https://github.com/eea/eea.docker.rsync/issues/4
# All credit to https://github.com/leopignataro for these changes
# Mount your persistent storage to /ssh_host_keys/
# Check if we already have our keys mounted 
if [ -e /ssh-keys/root/id_rsa.pub ]; then
  echo "Copying existing keys" 
  cp /ssh-keys/host/* /etc/ssh/ 
  cp /ssh-keys/root/* /root/.ssh/
# Check if Host SSH keys exists in our mounted folder /ssh-keys
elif [ ! -e /ssh-keys/host/ssh_host_rsa_key.pub ]; then
  mkdir /ssh-keys/host/
  mkdir /ssh-keys/root/
  echo "Generating SSH host keys"
  ssh-keygen -A
  echo "Copying SSH host keys to persistent storage"
  cp -u /etc/ssh/ssh_host_* /ssh-keys/host/ 
  ssh-keygen -q -N "" -f /root/.ssh/id_rsa
  echo "Copying SSH host keys to persistent storage"
  cp -u /root/.ssh/id_rsa* /ssh-keys/root/ 
fi


################################################################################
# START as SERVER
################################################################################

if [ "$1" == "server" ]; then
  AUTH=`cat /root/.ssh/authorized_keys`
  if [ -z "$AUTH" ]; then
    echo "=================================================================================="
    echo "ERROR: No SSH_AUTH_KEY provided, you'll not be able to connect to this container. "
    echo "=================================================================================="
    exit 1
  fi

  SSH_PARAMS="-D -e -p ${SSH_PORT:-22} $SSH_PARAMS"
  echo "================================================================================"
  echo "Running: /usr/sbin/sshd $SSH_PARAMS                                             "
  echo "================================================================================"

  exec /usr/sbin/sshd -D $SSH_PARAMS
fi

echo "Please add this ssh key to your server /home/user/.ssh/authorized_keys        "
echo "================================================================================"
echo "`cat /root/.ssh/id_rsa.pub`"
echo "================================================================================"

################################################################################
# START as CLIENT via crontab
################################################################################

if [ "$1" == "client" ]; then
  exec /usr/sbin/crond -f
fi

################################################################################
# Anything else
################################################################################
exec "$@"
