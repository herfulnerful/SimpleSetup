
#clean.sh - fixes up the file system so it can be saved back to a smaller image
# remove src
sudo rm -r ~/libopenmetaverse
sudo rm -r ~/opensim-libs
# clean up git
#sudo apt purge git-core
# autoremove is used to remove packages that were automatically installed to satisfy dependencies for some package and that are no more needed.
sudo apt-get autoremove
#removes the downloaded packages to free disk space
sudo apt-get clean

#usage shred:
#shred -n 1 -z -u -v filename #n=overwide n times instead of default 25, z=final overwrite with zeros, u=truncate and remove file after overwriting,v=show progress
#sudo find /var/log -type f -name "*.gz" -delete
#
shred -n 1 -z -u -v ~Opensimulator/opensim-0.8.2.0/bin/OpenSimConsoleHistory.txt
shred -n 1 -z -u -v ~Opensimulator/opensim-0.8.2.0/bin/OpenSim.log
shred -n 1 -z -u -v ~Opensimulator/opensim-0.8.2.0/bin/j2kDecodej2kDecodeCacheCache
shred -n 1 -z -u -v ~Opensimulator/opensim-0.8.2.0/bin/ScriptEngines
shred -n 1 -z -u -v ~Opensimulator/opensim-0.8.2.0/bin/assetcache

#
shred -n 1 -z -u -v ~/.nano_history
shred -n 1 -z -u -v ~/.mysql_history
shred -n 1 -z -u -v ~/.bash_history
#
sudo shred -n 1 -z -u -v /var/log/kern.log
sudo shred -n 1 -z -u -v /var/log/mysql.log
sudo shred -n 1 -z -u -v /var/log/dpkg.log
sudo shred -n 1 -z -u -v /var/log/alternatives.log
sudo shred -n 1 -z -u -v /var/log/bootstrap.log
sudo shred -n 1 -z -u -v /var/log/daemon.log
sudo shred -n 1 -z -u -v /var/log/messages
sudo shred -n 1 -z -u -v /var/log/debug
sudo shred -n 1 -z -u -v /var/log/regen_ssh_keys.log
sudo shred -n 1 -z -u -v /var/log/syslog
sudo shred -n 1 -z -u -v /var/log/auth.log
sudo shred -n 1 -z -u -v /var/log/fontconfig.log
#
sudo shred -n 1 -z -u -v /var/log/apt/history.log
sudo shred -n 1 -z -u -v /var/log/apt/term.log
sudo shred -n 1 -z -u -v /var/log/mysql/error.log

