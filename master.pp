#Puppet manifest for an SGE master node running Centos 6x
#This could probably be made to work on RHEL or Fedora with minimal modification

#See readme for more instructions

#REQUIRED LIBRARY: This manifest requires the stdlib module installed, as it uses the file_line resource from that library.

#Updates system; required to ensure SGE dependencies will be properly resolved, especially Java
exec { 'update':
        command=>'/usr/bin/yum -y update',
}

#etchosts-master.txt is generated by the build.sh script. This ensures that the master host is able to communicate with all the exec hosts
file { '/etc/hosts':
	ensure=>file,
        source=>'/home/centos/etchosts.txt',
	owner=>'root',
	group=>'root',
	mode=>0660,
}

#This places the SGE environment's private key into the master host, allowing it to ssh into the exec hosts
file { '/root/.ssh':
        ensure=>directory,
}

file { '/root/.ssh/id_rsa':
	ensure=>file,
        content=>'CLUSTER-PRIVATE-KEY',
	owner=>'root',
	group=>'root',
	mode=>0600,
	require=>File['/root/.ssh'],
}

#Jemalloc & perl-XML-Simple are two key dependencies for SGE that the rpms do not install! Will hopefully be fixed in the future
package { 'jemalloc':
        ensure=>latest,
	require=>Exec['update'],
}

package { 'perl-XML-Simple':
        ensure=>latest,
	require=>Exec['update'],
}

#Fetches the gridengine installation rpms and installs them. This manifest uses Son of Grid Engine 8.1.8
exec { 'gridengine-rpm':
        command=>'/usr/bin/yum -y install http://arc.liv.ac.uk/downloads/SGE/releases/8.1.8/gridengine-8.1.8-1.el6.x86_64.rpm http://arc.liv.ac.uk/downloads/SGE/releases/8.1.8/gridengine-qmaster-8.1.8-1.el6.x86_64.rpm http://arc.liv.ac.uk/downloads/SGE/releases/8.1.8/gridengine-execd-8.1.8-1.el6.x86_64.rpm http://arc.liv.ac.uk/downloads/SGE/releases/8.1.8/gridengine-guiinst-8.1.8-1.el6.noarch.rpm http://arc.liv.ac.uk/downloads/SGE/releases/8.1.8/gridengine-qmon-8.1.8-1.el6.x86_64.rpm',
	require=>[Package['perl-XML-Simple'],Package['jemalloc']],
}

#Runs the SGE install script that is placed by the rpm
exec { 'gridengine-install':
	command=>'/opt/sge/inst_sge -m -auto /home/centos/response-sge-install.conf',
	creates=>'/opt/sge/default/common/settings.sh',
	cwd=>'/opt/sge/',
	require=>Exec['gridengine-rpm'],
	notify=>Service['sgemaster.CLUSTER-NAME'],
}

#Writes lines into .bashrc to ensure proper startup of qmaster services at boot
file_line { 'bashrc':
	path=>'/etc/bashrc',
	line=>"#SGE settings\nexport SGE_ROOT=/opt/sge\nexport SGE_CELL=default\nif [ -e \$SGE_ROOT/\$SGE_CELL ]\nthen\n. \$SGE_ROOT/\$SGE_CELL/common/settings.sh\nfi",
	ensure=>present,
	require=>Exec['gridengine-install'],
}

#Writes lines into etc/profile to ensure proper startup of qmaster services at boot
file_line { 'profile':
	path=>'/etc/profile',
	line=>". /opt/sge/default/common/settings.sh",
	ensure=>present,
	require=>Exec['gridengine-install'],
}

#Adds exceptions to ip-tables to allow both NFS file sharing & SGE processes through the firewall
file_line { 'ip-tables':
        path=>'/etc/sysconfig/iptables',
        match=>"OUTPUT ACCEPT",
        line=>":OUTPUT ACCEPT [0:0]\n-A INPUT -m state --state NEW -m tcp -p tcp --dport 6444 -j ACCEPT\n-A INPUT -m state --state NEW -m tcp -p tcp --dport 6445 -j ACCEPT\n-A INPUT -s CLUSTER-NET-CIDR -p udp -m state --state NEW -m multiport --dports 111,892,2049,32769 -j ACCEPT\n-A INPUT -s CLUSTER-NET-CIDR -p tcp -m state --state NEW -m multiport --dports 111,892,2049,32803 -j ACCEPT",
        require=>Exec['gridengine-install'],
}

#Configures NFS file sharing. NFS is used to sync configuration files for the cluster between all the nodes
file_line { 'nfs-setup':
        path=>'/etc/exports',
        line=>'/opt/sge/default CLUSTER-NET-CIDR(rw,no_root_squash)',
        ensure=>present,
        require=>Exec['gridengine-install'],
}

#Ensure nfs is up and running, and configured to startup at boot
service { 'nfs':
	ensure=>running,
	enable=>true,
	subscribe=>File_Line['nfs-setup'],
}

#rpcbind service is required for NFS to work, so make sure its running and starting up at boot
service { 'rpcbind':
	ensure=>running,
	enable=>true,
	subscribe=>File_Line['nfs-setup'],
}

#Restart iptables to ensure the new rules are present
service { 'iptables':
	ensure=>running,
	enable=>true,
	subscribe=>File_Line['ip-tables'],
}

#Ensure that the SGE qmaster service is up and running and configured to startup at boot
service { 'sgemaster.CLUSTER-NAME':
	ensure=>running,
	enable=>true,
}

#Set the hostgroup data.
#qconf-hostgroup.txt is generated by build.sh. See readme for details
exec { 'qconf-add-hostgroup':
        command=>'/opt/sge/bin/lx-amd64/qconf -Mhgrp qconf-hostgroup.txt',
        environment=>'SGE_ROOT=/opt/sge',
        cwd=>'/home/centos',
        require=>Exec['gridengine-install'],
}

#Set the parallel environment data for smp.
#qconf-pe.txt is generated by build.sh. See readme for details
exec { 'qconf-add-pe-smp':
        command=>'/opt/sge/bin/lx-amd64/qconf -Mp qconf-pe-smp.txt',
        environment=>'SGE_ROOT=/opt/sge',
        cwd=>'/home/centos',
        require=>Exec['gridengine-install'],
}

#Set the parallel environment data for mpi.
#qconf-pe.txt is generated by build.sh. See readme for details
exec { 'qconf-add-pe-mpi':
        command=>'/opt/sge/bin/lx-amd64/qconf -Mp qconf-pe-mpi.txt',
        environment=>'SGE_ROOT=/opt/sge',
        cwd=>'/home/centos',
        require=>Exec['gridengine-install'],
}

#Set the queue data.
#qconf-queue.txt is generated by build.sh. See readme for details
exec { 'qconf-add-queue':
        command=>'/opt/sge/bin/lx-amd64/qconf -Mq qconf-queue.txt',
        environment=>'SGE_ROOT=/opt/sge',
        cwd=>'/home/centos',
        require=>[Exec['qconf-add-pe-smp'],Exec['qconf-add-pe-mpi'],Exec['qconf-add-hostgroup']],
}

#Ensure that the 'centos' user can submit jobs
exec { 'qconf-add-user':
        command=>'/opt/sge/bin/lx-amd64/qconf -au centos users',
        environment=>'SGE_ROOT=/opt/sge',
        cwd=>'/home/centos',
        require=>Exec['gridengine-install'],
}

#Ensure that the 'root'user can submit jobs
exec { 'root-job-submit':
        command=>'/bin/sed -i -re "s/min_uid\s+100/min_uid 0/g" /opt/sge/default/common/configuration; /bin/sed -i -re "s/min_gid\s+100/min_gid 0/g" /opt/sge/default/common/configuration',
        cwd=>'/home/centos',
	require=>[Exec['qconf-add-pe-smp'],Exec['qconf-add-pe-mpi'],Exec['qconf-add-hostgroup']],
}
