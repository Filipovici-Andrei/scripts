#!/bin/sh -x
echo "Checking for available host..."
if test -z $HOST || ! grep -q "$HOST" <<< "$(floaty list --active)"
then
    echo 'Getting new machine'
    sleep 3
    beaker init -h windows2019-64a -o config/aio/options.rb
    export HOST=`beaker provision | grep 'Using available host' | awk {'print $4'} | xargs`

    echo 'Runinng tests on ' $HOST
    sleep 3

    export BP_ROOT=/Users/andrei.filipovici/projects/beaker-puppet
    echo 'Puppet Agent SHA is ' $SHA
    export SHA=`curl --fail --silent GET --url http://builds.delivery.puppetlabs.net/passing-agent-SHAs/puppet-agent-master`
    
    echo 'Starting pre-suite'
    sleep 3
    
    bundle exec beaker exec pre-suite --pre-suite $BP_ROOT/setup/common/000-delete-puppet-when-none.rb,$BP_ROOT/setup/aio/010_Install_Puppet_Agent.rb
    
    echo 'Setting Facter 4 repo on machine ' $HOST
    sleep 3

    ssh Administrator@$HOST "cmd /c puppet config set facterng true &&
        cd /cygdrive/c/Program\ Files/Puppet\ Labs/Puppet/bin &&
        mv facter-eng.bat facter.bat &&
        facter_ng_version=`cmd /c facter-ng --version | tr -d '\r'`
        cd /cygdrive/c/Program\ Files/Puppet\ Labs/Puppet/puppet/lib/ruby/gems/2.5.0/gems/facter-ng-$facter_ng_version &&
        git init &&
        git remote add origin https://github.com/puppetlabs/facter-ng.git &&
        git fetch &&
        git reset --hard origin/fix_acceptance"
fi
# ssh Administrator@$HOST "facter_ng_version=`cmd /c facter-ng --version | tr -d '\r'`
#         cd /cygdrive/c/Program\ Files/Puppet\ Labs/Puppet/puppet/lib/ruby/gems/2.5.0/gems/facter-ng-$facter_ng_version &&
#         git fetch &&
#         git reset --hard origin/FACT-3434"
echo 'Runinng tests on ' $HOST
current_time=$(date +"%F:%T")
log="$current_time.log"
fails="$current_time.fails"
beaker exec tests 2>&1 | tee $log
sed -n '/Failed Tests Cases:/,/Skipped Tests Cases:/p' $log | grep 'Test Case' | awk {'print $3'} > $fails
diff --suppress-common-lines -y master_fails $fails