#Puppet manifest for an SGE exec node running Centos 6x
#This may work on RHEL and Fedora, however this is untested and may require some adaptation

#See readme for more instructions
#REQUIRED LIBRARY: This manifest requires the stdlib module installed, as it uses the file_line resource from that library.

#etchosts-exec.txt is generated by the build.sh script. This ensures that the exec host is able to communicate with the master host
file { '/etc/hosts':
	ensure=>file,
        source=>'/home/centos/etchosts.txt',
	owner=>'root',
	group=>'root',
	mode=>0660,
}

#Ensure /opt/sge/default directory exists; this is important as the SGE configuration is NFS mounted to here
file { '/opt/sge':
        ensure=>directory,
}

file { '/opt/sge/default':
        ensure=>directory,
	require=>File['/opt/sge'],
}

#This places the SGE environment's public key into the exec host
#Ensures that the master host can SSH into the exec host
ssh_authorized_key { 'root@MASTER-HOSTNAME':
	user=>'root',
	type=>'ssh-rsa',
	key=>'CLUSTER-PUBLIC-KEY',
}

#Updates system; required to ensure SGE dependencies will be properly resolved, especially Java
exec { 'update':
        command=>'/usr/bin/yum -y update',
}

#NFS Mount the SGE configuration from the host
mount { 'nfs-mount':
	name=>"/opt/sge/default",
	device=>"MASTER-HOSTNAME:/opt/sge/default/",
	fstype=>"nfs",
	options=>"rw,suid,dev,exec,auto,nouser,async",
	ensure=>mounted,
	atboot=>true,
	require=>[File['/etc/hosts'],File['/opt/sge/default']],
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
	command=>'/opt/sge/inst_sge -x -noremote -auto /home/centos/response-sge-install.conf',
	cwd=>'/opt/sge/',
	require=>[Exec['gridengine-rpm'],Mount['nfs-mount']],
	notify=>Service['sgeexecd.CLUSTER-NAME'],
}

#Ensure that the SGE exec service is up and running and will startup at boot
service { 'sgeexecd.CLUSTER-NAME':
	ensure=>running,
	enable=>true,
}

#Writes lines into .bashrc to ensure proper startup of Exec services at boot
file_line { 'bashrc':
	path=>'/etc/bashrc',
	line=>"#SGE settings\nexport SGE_ROOT=/opt/sge\nexport SGE_CELL=default\nif [ -e \$SGE_ROOT/\$SGE_CELL ]\nthen\n. \$SGE_ROOT/\$SGE_CELL/common/settings.sh\nfi",
	ensure=>present,
	require=>Exec['gridengine-install'],
}

#Writes lines into etc/profile to ensure proper startup of Exec services at boot
file_line { 'profile':
	path=>'/etc/profile',
	line=>". /opt/sge/default/common/settings.sh",
	ensure=>present,
	require=>Exec['gridengine-install'],
}
