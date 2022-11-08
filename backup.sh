if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

backupfile="backup.$(date "+%Y.%m.%d-%H.%M.%S").tar.gz"
backupdir="/backups"
backuppath="$backupdir/$backupfile"

read -p "Start system backup to $backuppath? [y/n]" -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd / # THIS CD IS IMPORTANT THE FOLLOWING LONG COMMAND IS RUN FROM /
    tar -cvpzf $backuppath \
        --exclude=/backups \
        --exclude=/proc \
        --exclude=/tmp \
        --exclude=/mnt \
        --exclude=/dev \
        --exclude=/sys \
        --exclude=/run \
        --exclude=/media \
        /
fi

