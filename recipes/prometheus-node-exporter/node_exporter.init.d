#!/bin/sh
# Init script for node_exporter
# Maintained by Sören König <soeren.koenig@zalando.de>
# Generated by pleaserun.
# Implemented based on LSB Core 3.1:
#   * Sections: 20.2, 20.3
#
### BEGIN INIT INFO
# Provides:          node_exporter
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Prometheuse Node Exporter
### END INIT INFO

PATH=/sbin:/usr/sbin:/bin:/usr/bin
export PATH

name=node_exporter
program=/usr/bin/node_exporter
pidfile="/var/run/$name.pid"
user="root"
group="root"
chroot="/"
chdir="/"
nice=""
collectors_enabled="diskstats,entropy,filesystem,meminfo,netdev,netstat,sockstat,stat,textfile,uname,vmstat,bonding,megacli"
textfile_directory="/var/cache/$name"


# If this is set to 1, then when `stop` is called, if the process has
# not exited within a reasonable time, SIGKILL will be sent next.
# The default behavior is to simply log a message "program stop failed; still running"
KILL_ON_STOP_TIMEOUT=0

[ -r /etc/default/node_exporter ] && . /etc/default/node_exporter
[ -r /etc/sysconfig/node_exporter ] && . /etc/sysconfig/node_exporter

[ -z "$nice" ] && nice=0

trace() {
  logger -t "/etc/init.d/node_exporter" "$@"
}

emit() {
  trace "$@"
  echo "$@"
}

start() {

  # Ensure the log directory is setup correctly.
  [ ! -d "/var/log/node_exporter" ] && mkdir "/var/log/node_exporter"
  chown "$user":"$group" "/var/log/node_exporter"
  chmod 755 "/var/log/node_exporter"

  # Ensure the textfile directory is setup correctly.
  [ ! -d "$textfile_directory" ] && mkdir "$textfile_directory"
  chown "$user":"$group" "$textfile_directory"
  chmod 755 "$textfile_directory"


  # Run the program!

  chroot --userspec "$user":"$group" "$chroot" sh -c "

    cd \"$chdir\"
    exec \"$program\" -collectors.enabled $collectors_enabled -collector.textfile.directory $textfile_directory
  " >> /var/log/node_exporter/node_exporter-stdout.log 2>> /var/log/node_exporter/node_exporter-stderr.log &

  # Generate the pidfile from here. If we instead made the forked process
  # generate it there will be a race condition between the pidfile writing
  # and a process possibly asking for status.
  echo $! > $pidfile

  emit "$name started"
  return 0
}

stop() {
  # Try a few times to kill TERM the program
  if status ; then
    pid=$(cat "$pidfile")
    trace "Killing $name (pid $pid) with SIGTERM"
    kill -TERM $pid
    # Wait for it to exit.
    for i in 1 2 3 4 5 ; do
      trace "Waiting $name (pid $pid) to die..."
      status || break
      sleep 1
    done
    if status ; then
      if [ "$KILL_ON_STOP_TIMEOUT" -eq 1 ] ; then
        trace "Timeout reached. Killing $name (pid $pid) with SIGKILL.  This may result in data loss."
        kill -KILL $pid
        emit "$name killed with SIGKILL."
      else
        emit "$name stop failed; still running."
      fi
    else
      emit "$name stopped."
    fi
  fi
}

status() {
  if [ -f "$pidfile" ] ; then
    pid=$(cat "$pidfile")
    if ps -p $pid > /dev/null 2> /dev/null ; then
      # process by this pid is running.
      # It may not be our pid, but that's what you get with just pidfiles.
      # TODO(sissel): Check if this process seems to be the same as the one we
      # expect. It'd be nice to use flock here, but flock uses fork, not exec,
      # so it makes it quite awkward to use in this case.
      return 0
    else
      return 2 # program is dead but pid file exists
    fi
  else
    return 3 # program is not running
  fi
}

force_stop() {
  if status ; then
    stop
    status && kill -KILL $(cat "$pidfile")
  fi
}


case "$1" in
  force-start|start|stop|force-stop|restart)
    trace "Attempting '$1' on node_exporter"
    ;;
esac

case "$1" in
  force-start)
    PRESTART=no
    exec "$0" start
    ;;
  start)
    status
    code=$?
    if [ $code -eq 0 ]; then
      emit "$name is already running"
      exit $code
    else
      start
      exit $?
    fi
    ;;
  stop) stop ;;
  force-stop) force_stop ;;
  status)
    status
    code=$?
    if [ $code -eq 0 ] ; then
      emit "$name is running"
    else
      emit "$name is not running"
    fi
    exit $code
    ;;
  restart)

    stop && start
    ;;
  *)
    echo "Usage: $SCRIPTNAME {start|force-start|stop|force-start|force-stop|status|restart}" >&2
    exit 3
  ;;
esac

exit $?