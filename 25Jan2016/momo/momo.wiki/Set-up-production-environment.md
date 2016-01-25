#### Introduction

This guide documents steps to reproduce production environment for rails server. Remote refers to EC2 instance while local refers to development machine.

It is recommended to use at least a small instance since compiling passenger requires 1GB of memory.

#### Remote: Remove Apache or other webserver
If it conflicts with port 80, then remove it.

#### Remote: Create new user
> sudo adduser railsuser

> sudo visudo

Add permissions as root: `%railsuser    ALL=(ALL) NOPASSWD: ALL`

> sudo cat /etc/sudoers

> sudo -i -u railsuser

> cd

> mkdir .ssh

> cd .ssh

> touch authorized_keys

> sudo nano authorized_keys


Copy paste public SSH keys from local machine to `authorized_keys`

> sudo chown -hR railsuser .ssh

> exit

> exit

Now, login as railsuser - if set up is correct, should be able to login.

#### RDS: Set up database

Add database to existing RDS instance or create new RDS database

#### Remote: Install software

> sudo apt-get install libmysqlclient-dev

> sudo apt-get install curl

> curl -L get.rvm.io | bash -s stable --auto


Copy/paste as per instructions

> nano .bash_profile

> . ~/.bash_profile

> rvm requirements

> sudo apt-get install build-essential openssl libreadline6 libreadline6-dev curl git-core zlib1g zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt-dev autoconf libc6-dev ncurses-dev automake libtool bison  subversion pkg-config

> rvm install 2.0.0

> rvm use 2.0.0

> gem install rails --no-rdoc --no-ri -v 4.0.0

> gem install rvm-capistrano

> gem install mysql


For passenger integration with SSL, we'll need to download latest nginx source:

> wget http://nginx.org/download/nginx-1.4.1.tar.gz

> tar -zxf nginx-1.4.1.tar.gz

> gem install passenger

> rvmsudo passenger-install-nginx-module

Now, choose advanced setup and when asked to point to the gunziped directory with source. Ensure that --with-ssl-* option is specified before compilation.

Set up services for nginx:

> wget -O init-deb.sh http://library.linode.com/assets/660-init-deb.sh

> sudo mv init-deb.sh /etc/init.d/nginx

> sudo chmod +x /etc/init.d/nginx

> sudo /usr/sbin/update-rc.d -f nginx defaults

> sudo service nginx start 


Set up nginx to work with rails by editing server information at:

> sudo nano /opt/nginx/conf/nginx.conf

Additions to above file - in the "http" section:

        #gzip  on;
        client_max_body_size 1024M;

Additions to above file - in the "server" section (others should be commented out):

        listen       443;
        server_name  localhost;
        root /var/www/current/public;

        ssl on;
        ssl_certificate /home/railsuser/certificate/server.crt;
        ssl_certificate_key /home/railsuser/certificate/server.key;
        
        passenger_enabled on;
        passenger_set_cgi_param HTTPS on;
        passenger_set_cgi_param HTTP_X_FORWARDED_PROTO https;
        #rewrite     ^   https://$server_name$request_uri? permanent;

Note: when we have our own server address, replace the rewrite line above so that it redirects all HTTP requests to HTTPS.

> sudo chown -hR railsuser /var/www

> sudo service ssh restart

> sudo service nginx restart


Now HTTP access to EC2 address should return a 401 not found.

#### Remote: Securitize passwords

Storing passwords and other sensitive information in github is unsafe. Also, hard-coding passwords in source file might expose commands that might unintentionally delete production database.

First, store all passwords and sensitive information in a separate file called `passwords.yml`. We can read the variables from this file in other yml files as follows:

        <%= YAML.load_file("#{Rails.root}/config/passwords.yml")[Rails.env]["aws_access_key_id"] %>

We will put this file in `.gitignore` and track file `passwords.yml.sanitized` instead which reads the sensitive information from environment variables:

        aws_access_key_id: <%= ENV['RAILS_AWS_ACCESS_KEY_ID'] %>
        aws_secret_access_key: <%= ENV['RAILS_SECRET_ACCESS_KEY'] %>

To work well with capistrano in production environment, we have to put the non-sanitized `passwords.yml` file in `shared/config` folder in the remote machine. Additionally, we have to instruct capistrano to create a soft link between `config/passwords.yml` and `shared/config/passwords.yml`:

		namespace(:customs) do
		   task :symlink_passwords, :roles => :app do
		    run <<-CMD
		      ln -nfs #{shared_path}/config/passwords.yml #{release_path}/config/passwords.yml
		    CMD
		  end
		end
		after "deploy:update_code", "customs:symlink_passwords"

Note: For the loading sequence of tasks to work, need to move `load 'deploy/assets'` to end of `deploy.rb` file.
To export the environment variables for development put variables in a new file:

> sudo nano /etc/profile.d/rails_environment.sh

        export RAILS_AWS_ACCESS_KEY_ID ; RAILS_AWS_ACCESS_KEY_ID='<access key>'
        export RAILS_SECRET_ACCESS_KEY ; RAILS_SECRET_ACCESS_KEY='<secret key>'

During development phase, when doing a `git pull`, we need to also move sanitized file:

> mv config/password.yml.sanitized config/password.yml


#### Local: Set up use for capistrano

> gem install rvm-capistrano

Follow guide: 

> https://help.github.com/articles/deploying-with-capistrano

> https://github.com/capistrano/capistrano/wiki/2.x-from-the-beginning


Related guides:

> http://www.debuntu.org/how-to-create-a-mysql-database-and-set-privileges-to-a-user/

> http://robmclarty.com/blog/how-to-deploy-a-rails-4-app-with-git-and-capistrano


At this point, should be able to see the whole application up and running. To access rails console in remote try:

> RAILS_ENV=production bundle exec rails console

After each commit in local, push to origin, set up EC2 variable in shell:

> export AWS_SERVER="aws-address"

and run `cap deploy` from same shell

If adding new gem, capistrano should update the bundle install in remote automatically. To reset production database:

> RAILS_ENV=production bundle exec rake db:reset
