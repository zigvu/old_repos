### Running logs

1. Start EC2 instance as at least a "small" - since logging framework requires more memory than available in "micro" instance. Note EC2 web address
2. Open terminal and run script:
# /opt/logstash/logStart.sh
3. In latest browser (firefox, chrome supported), type in URL:
EC2WebAddr:8000/index.html#/dashboard/file/logstash.json
4. Filter and browse logs
5. When done with logging kill script from step 2 to free up system resources

Allow at least 5 minutes between step 2 and 3 if using a slow machine. You can create different dashboard and save them for later access. In such a case, you'll need to enter different URL in step 3.

### Setting up

* Add gem for rails JSON log output to Gemfile

> gem 'logstasher'

Source: https://github.com/shadabahmed/logstasher
Base tutorial: http://shadabahmed.com/blog/2013/04/30/logstasher-for-awesome-rails-logging
(do not follow tutorial, follow below instead.)

* Make new folder:

> sudo mkdir /opt/logstash
> chmod 777 /opt/logstash
> cd /opt/logstash

* Download old version of logstasher and kibana

> wget https://download.elasticsearch.org/logstash/logstash/logstash-1.1.10-flatjar.jar
> wget http://download.elasticsearch.org/kibana/kibana/kibana-latest.zip
> unzip kibana-latest.zip

* Create simple configuration file:

> nano logstash-config.conf

Content:

		input {
		  file {
		    type => "rails"
		    format => "json_event"
		    path => "/var/www/current/log/logstash_production.log"
		  }
		  #file {
		  #  type => "nginx_web"
		  #  path => ["/opt/nginx/logs/access.log", "/opt/nginx/logs/error.log"]
		  #}
		}

		#filter {
		#  grok {
		#    type => "nginx_web"
		#    pattern => "%{IP:clientip} (?:%{HOST:clienthost}|-) (?:%{USER:clientuser}|-) \[%{HTTPDATE:time}\] \"(?:%{WORD:verb} %{URIPATHPARAM:request} HTTP/%{NUMBER:httpversion}|%{DATA:unparsedrq})\" %{NUMBER:response} (?:%{NUMBER:bytes}|-) %{QUOTEDSTRING:httpreferrer} %{QUOTEDSTRING:httpuseragent}"
		#  }
		#}

		output {
		  stdout { }
		  elasticsearch { embedded => true }
		}


* Create simple start script:

> nano logStart.sh

Content:

		#!/bin/bash
		java -jar /opt/logstash/logstash-1.1.10-flatjar.jar agent -f /opt/logstash/logstash-config.conf --log /opt/logstash/logstash.log

> chmod +x logStart.sh

* Modify web server

> nano /opt/nginx/conf/nginx.conf

Add one more server directive under http:


		#
		# Nginx proxy for Elasticsearch + Kibana
		#
		# In this setup, we are password protecting the saving of dashboards. You may
		# wish to extend the password protection to all paths.
		#
		# Even though these paths are being called as the result of an ajax request, the
		# browser will prompt for a username/password on the first request
		#
		# If you use this, you'll want to point config.js at http://FQDN:8000/ instead of
		# http://FQDN:9200
		#
		server {
		    listen *:8000 ;

		    server_name localhost;
		    access_log /var/www/current/log/logstash_production.log;

		    location / {
		        root /opt/logstash/kibana-latest;
		        index index.html index.htm;
		    }
		}

* Restart server:

> sudo service nginx restart

