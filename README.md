## lxc-puppet-tech-talk

#### Run host provisioning:
```
curl -L https://raw.githubusercontent.com/hoshsadiq/lxc-puppet-tech-talk/master/scripts/setup.sh | bash
```

#### Useful commands:

Get ip address of a container and ssh into it (requires openssh installed and set up, see `./scripts/start.sh`) 
```bash
$ ssh root@$(lxc-info --name "puppet.tesco.com" --ips --no-humanize)
$ ssh root@$(lxc-info --name "agent01.tesco.com" --ips --no-humanize)
```

Install specific puppet module
```
$ puppet module install puppetlabs-stdlib
```

Manually run puppet agent one time
```
$ puppet agent --verbose --no-daemonize --onetime
```


Edit main puppet manifest (this is the puppet file that gets run if none specified)
```
$ vim /etc/puppet/manifests/site.pp
```

We can add the following to install screen
```
package { 'screen':
	ensure => 'latest'
}
```

Run puppet agent one (see above). Afterwards, screen should be installed

```
$ screen
```

Now we're getting an error because a file does not have correct permissions. Let's fix that with puppet by adding the following to our manifest:
```
file { '/var/run/screen':
	ensure => 'present',
	mode   => 0777
}
```

Now we run puppet again (see above).


Great! So now we can run screen.

Let's create a more useful example. Let's install the module puppet-nginx on our master
```
puppet module install puppet-nginx
```

And then let's set up a virtual host in nginx by adding the following to our manifest.
```
include nginx

nginx::resource::vhost { 'my-service.tesco.com':
  listen_port => 80,
  proxy       => 'http://localhost:5601',
}
```

Then run puppet again, we should have an nginx virtual host available now.

This is all great, but having all our code in one file doesn't sound maintainable, so let's create a module.

```
$ mkdir -p /etc/puppet/modules/accounts/{manifests,templates}
$ vim /etc/puppet/modules/accounts/manifests/init.pp
```
And we add the following code:
```
class accounts {

  $user = 'hosh'

  class { 'accounts::groups':
    user => "$user"
  }

  user { "$user":
    ensure      => present,
    home        => "/home/$user",
    shell       => '/bin/bash',
    managehome  => true,
    gid         => "$user",
    password    => '$1$MgUtwr1T$ufVv.QK69.Vq9Y7AmIAA0/',
    require     => Group["$user"]
  }

}
```

```
$ vim /etc/puppet/modules/accounts/manifests/groups.pp
```
With the following code:
```
class accounts::groups (
  $user = undef
) {

  validate_string($user)
        
  group { "$user":
    ensure  => present,
  }

}
```

Then we call the new module in our main manifest
```
include accounts
```

And we run the puppet agent again. This should create us a user and a group that we desire. In this case it's just "hosh".

Let's welcome this new user by creating a welcome file in their home directory. We'll puppet template files.
```
$ vim /etc/puppet/modules/accounts/manifests/init.pp
```
We're going to add the following code:
```
  $weapons = ['fear', 'surprise', 'ruthless efficiency', 'an almost fanatical devotion to the Pope']


  file { "/home/$user/welcome.txt":
    mode    => 0644,
    owner   => "$user",
    group   => "$user",
    content => template("accounts/welcome.txt.erb"),
    require => User["$user"]
  }
```

And we create the actual template.

```
$ vim /etc/puppet/modules/accounts/templates/welcome.txt.erb
```
With the following contents:
```

Nobody expects the Spanish Inquisition!

Our three weapons are <%=@weapons[0..-3].join(", ")%> and <%=@weapons[-2]%>... and <%=@weapons[-1]%>.

```


So let's use puppet-hiera for environment specific values (see `./scripts/start.sh` for info on how to setup hiera correctly).
```
$ vim /etc/puppet/hieradata/node/agent01.tesco.com.yaml
```
With the contents
```
my_var: test

other::var: test
```

We can query the yaml value from command line (e.g. for debugging)
```
$ hiera my_var ::fqdn=agent01.tesco.com --debug
$ hiera other::var ::fqdn=agent01.tesco.com --debug
```

Great! We've got values!

Let's create a bunch of users rather than individual users.
```
$ vim /etc/puppet/hieradata/common.yaml
```
We add an array of users
```
accounts::users:
    - hosh
```

Then update the accounts module with the following:
```
$users = hiera_array('accounts::users'); // hiera(), hiera_hash()

$users.each |$user| {
  class { 'accounts::groups':
    user => "$user"
  }

  user { "$user":
    ensure      => present,
    home        => "/home/$user",
    shell       => '/bin/bash',
    managehome  => true,
    gid         => "$user",
    password    => '$1$MgUtwr1T$ufVv.QK69.Vq9Y7AmIAA0/',
    require     => Group["$user"]
  }
}
```


What does ps look like?
Check in Master and Agent and Host
```
$ ps aux | grep -F '/sbin/init'
$ ps aux | grep -F 'screen'
```





