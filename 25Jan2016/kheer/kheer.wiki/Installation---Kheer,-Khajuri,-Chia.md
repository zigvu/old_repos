### Operating system

Requires Ubuntu 12.04 but might work on other -nix variants.

### Dependencies for Chia

	# -------------------------------------------

	# Remove old PPAs:
	sudo add-apt-repository -r ppa:ubuntu-toolchain-r/test
	sudo add-apt-repository -r ppa:apokluda/boost1.53

	# Update
	sudo apt-get update

	# Unfortunately, build-essential installs GCC 4.6.4 where as Ubuntu Gfortran only supports GCC 4.6.3
	# so, get that first
	sudo apt-get remove build-essential libopenblas-dev
	sudo apt-get install gfortran
	# Now that gfortran is installed, it will also have installed GCC 4.6.3

	# -------------------------------------------

	# Install libraries
	sudo apt-get install libboost-all-dev python-dev git libprotobuf-dev libleveldb-dev libsnappy-dev libhdf5-serial-dev unzip cmake

	# Set up space for other libraries
	RPATH="/var/opt/ffmpeg"
	sudo mkdir $RPATH
	cd /var/opt
	sudo chown ubuntu ffmpeg

	# GLOG
	cd $RPATH
	wget https://google-glog.googlecode.com/files/glog-0.3.3.tar.gz
	tar xzvf glog-0.3.3.tar.gz
	cd glog-0.3.3
	./configure
	make
	sudo make install
    
	# gflags
	cd $RPATH
	wget https://github.com/schuhschuh/gflags/archive/master.zip
	unzip master.zip
	cd gflags-master
	mkdir build && cd build
	export CXXFLAGS="-fPIC" && cmake .. && make VERBOSE=1
	sudo make 
	sudo make install
    
	# LMDB
	cd $RPATH
	git clone git://git.openldap.org/openldap.git mdb.master
	cd /var/opt/ffmpeg/mdb.master/libraries/liblmdb
	make
	sudo make install

	# OpenBlas
	cd $RPATH
	git clone git://github.com/xianyi/OpenBLAS
	cd OpenBLAS
	make FC=gfortran
	sudo make PREFIX=/usr/local/ install
	# Update alternatives to point to the newly installed blas
	sudo update-alternatives --install /usr/lib/libblas.so libblas.so /usr/local/lib/libopenblas.so 40
	sudo update-alternatives --install /usr/lib/libblas.so.3gf libblas.so.3gf /usr/local/lib/libopenblas.so 40


	# CUDA
	cd $RPATH
	wget http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1204/x86_64/cuda-repo-ubuntu1204_6.0-37_amd64.deb
	sudo dpkg -i cuda-repo-ubuntu1204_6.0-37_amd64.deb
	sudo apt-get update
	sudo apt-get install cuda

	# Update ~/.profile  [Note: might obviate the need to update exports to ~/.profile later on]
	export PATH=/usr/local/cuda-6.0/bin:$PATH
	export LD_LIBRARY_PATH=/usr/local/cuda-6.0/lib64:/var/opt/ffmpeg/ffmpeg_build/lib:$LD_LIBRARY_PATH
	export PKG_CONFIG_PATH="/var/opt/ffmpeg/ffmpeg_build/lib/pkgconfig:$PKG_CONFIG_PATH"
	export PATH="$PATH:/var/opt/ffmpeg/bin:/var/opt/ffmpeg/ffmpeg_build/lib"
	export CPLUS_INCLUDE_PATH=/usr/include/python2.7
	export PYTHONPATH=home/ubuntu/chia/caffe/python:$PYTHONPATH

	# Install Caffe (install OpenCV first, see below)
	<we will install caffe that is inside the chia repo, however, for first-time installation, test from BVLC>
	mkdir /home/ubuntu/temp
	cd /home/ubuntu/temp
	git clone https://github.com/BVLC/caffe.git
	cd caffe
	cp Makefile.config.example Makefile.config
	<Edit Makefile.config>
	sudo apt-get install protobuf-compiler # (if no protoc found)
	sudo apt-get install bc # (if not found)
	make
	<if make is successful, ready to install from chia repo>
	cd /home/ubuntu
	git clone https://github.com/zigvu/chia.git
	cd chia
	git pull origin development
	cp /home/ubuntu/temp/caffe/Makefile.config /home/ubuntu/chia/caffe/.
	make -j <no. of cores>
	rm -rf /home/ubuntu/temp
	# install python requirements and expose python interface
	sudo pip install -r /home/ubuntu/chia/caffe/python/requirements.txt
	make pycaffe

### Dependencies for Khajuri

It is recommended that you type below section-by-section and so that failures are easier to debug.

	# -------------------------------------------

	# Update
	sudo apt-get update

	# Get new packages
	sudo apt-get install checkinstall pkg-config system-config-samba git htop curl libopencv-dev libtiff4-dev libjpeg-dev libjasper-dev libdc1394-22-dev libxine-dev libgstreamer0.10-dev libgstreamer-plugins-base0.10-dev libv4l-dev libtbb-dev libqt4-dev libgtk2.0-dev imagemagick libmagickcore-dev python-pip graphviz python-joblib

	# Remove original installation
	sudo apt-get remove ffmpeg x264 libav-tools libvpx-dev libx264-dev yasm libavcodec-dev libavformat-dev libswscale-dev youtube-dl

	# -------------------------------------------

	# Latest FFMPEG
	# https://trac.ffmpeg.org/wiki/UbuntuCompilationGuide

	sudo apt-get update
	sudo apt-get -y install autoconf automake build-essential libass-dev libgpac-dev libsdl1.2-dev libtheora-dev libtool libva-dev libvdpau-dev libvorbis-dev libx11-dev libxext-dev libxfixes-dev pkg-config texi2html zlib1g-dev libmp3lame-dev

	RPATH="/var/opt/ffmpeg"

	cd $RPATH
	wget http://www.tortall.net/projects/yasm/releases/yasm-1.2.0.tar.gz
	tar xzvf yasm-1.2.0.tar.gz
	cd yasm-1.2.0
	./configure --prefix="$RPATH/ffmpeg_build" --bindir="$RPATH/bin"
	make
	make install
	make distclean
	export "PATH=$PATH:$RPATH/bin"

	cd $RPATH
	wget http://download.videolan.org/pub/x264/snapshots/last_x264.tar.bz2
	tar xjvf last_x264.tar.bz2
	cd x264-snapshot*
	./configure --prefix="$RPATH/ffmpeg_build" --bindir="$RPATH/bin" --enable-shared
	make
	make install
	make distclean

	cd $RPATH
	wget -O fdk-aac.zip https://github.com/mstorsjo/fdk-aac/zipball/master
	unzip fdk-aac.zip
	cd mstorsjo-fdk-aac*
	autoreconf -fiv
	./configure --prefix="$RPATH/ffmpeg_build" --enable-shared
	make
	make install
	make distclean

	cd $RPATH
	wget http://downloads.xiph.org/releases/opus/opus-1.1.tar.gz
	tar xzvf opus-1.1.tar.gz
	cd opus-1.1
	./configure --prefix="$RPATH/ffmpeg_build" --enable-shared
	make
	make install
	make distclean

	cd $RPATH
	wget http://webm.googlecode.com/files/libvpx-v1.3.0.tar.bz2
	tar xjvf libvpx-v1.3.0.tar.bz2
	cd libvpx-v1.3.0
	./configure --prefix="$RPATH/ffmpeg_build" --disable-examples --enable-shared
	make
	make install
	make clean

	cd $RPATH
	wget http://www.linuxtv.org/downloads/v4l-utils/v4l-utils-0.8.4.tar.bz2
	tar -xvf v4l-utils-0.8.4.tar.bz2
	cd v4l-utils-0.8.4/
	make
	sudo make install

	cd $RPATH
	wget http://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2
	tar xjvf ffmpeg-snapshot.tar.bz2
	cd ffmpeg
	export "PKG_CONFIG_PATH=$RPATH/ffmpeg_build/lib/pkgconfig"
	export "PATH=$PATH:$RPATH/bin:$RPATH/ffmpeg_build/lib"

	./configure --prefix="$RPATH/ffmpeg_build" --extra-cflags="-I$RPATH/ffmpeg_build/include" --extra-ldflags="-L$RPATH/ffmpeg_build/lib" --bindir="$RPATH/bin" --extra-libs=-ldl --enable-gpl --enable-libass --enable-libfdk-aac --enable-libmp3lame --enable-libopus --enable-libtheora --enable-libvorbis --enable-libvpx --enable-libx264 --enable-nonfree --enable-x11grab --enable-shared --enable-pic
	make
	make install
	make distclean
	hash -r

	echo "MANPATH_MAP $RPATH/bin $RPATH/ffmpeg_build/share/man" >> ~/.manpath
	echo "export PKG_CONFIG_PATH=\"$RPATH/ffmpeg_build/lib/pkgconfig\"" >> ~/.bash_profile
	echo "PATH=\"\$PATH:$RPATH/bin:$RPATH/ffmpeg_build/lib\"" >> ~/.bash_profile
	. ~/.profile
	. ~/.bash_profile

	sudo touch /etc/ld.so.conf.d/ffmpeg.conf
	sudo echo “$RPATH/ffmpeg_build/lib” >> /etc/ld.so.conf.d/ffmpeg.conf # (if fails, add by editing)
	sudo ldconfig

	# -------------------------------------------

	# Remove native paths so that Ubuntu update doesn't mess our setup

	sudo rm /usr/bin/ffmpeg /usr/bin/X11/ffmpeg
	sudo ln "$RPATH/bin/ffmpeg" /usr/bin/X11/ffmpeg
	sudo ln "$RPATH/bin/ffmpeg" /usr/bin/ffmpeg

	sudo rm /usr/bin/ffprobe /usr/bin/X11/ffprobe
	sudo ln "$RPATH/bin/ffprobe" /usr/bin/X11/ffprobe
	sudo ln "$RPATH/bin/ffprobe" /usr/bin/ffprobe

	# -------------------------------------------

	# Install OpenCV
	CVPATH="/var/opt/ffmpeg/opencv"
	mkdir $CVPATH

	cd $CVPATH
	wget -O opencv-2.4.8.zip http://sourceforge.net/projects/opencvlibrary/files/opencv-unix/2.4.8/opencv-2.4.8.zip/download
	unzip opencv-2.4.8.zip 
	cd opencv-2.4.8
	mkdir build
	cd build
	cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D WITH_TBB=ON -D BUILD_NEW_PYTHON_SUPPORT=ON -D WITH_V4L=ON -D INSTALL_C_EXAMPLES=ON -D INSTALL_PYTHON_EXAMPLES=ON -D BUILD_EXAMPLES=ON -D WITH_QT=ON -D WITH_OPENGL=ON ..
	make
	sudo make install
	sudo touch /etc/ld.so.conf.d/opencv.conf
	sudo echo “/usr/local/lib” >> /etc/ld.so.conf.d/opencv.conf # (if fails, add by editing)
	sudo ldconfig


	# -------------------------------------------

	# Python
	cd $RPATH
	sudo apt-get install python-pip python-dev python-numpy python-scipy python-matplotlib python-yaml libfreetype6-dev libpng-devel libgeos-dev
	sudo pip install -U cython
	sudo pip install -U six
	sudo pip install -U scikit-image
	sudo pip install -U scikit-learn
	sudo pip install numpy --upgrade
	sudo pip install --upgrade youtube_dl

	sudo pip install 'Shapely==1.4.3'
	sudo pip install protobuf
	sudo pip install python-snappy

	# Delete old opencv python bindings
	sudo rm /usr/lib/pymodules/python2.7/cv*

	# delete downloaded compressed files (if not needed)
	rm -f *.zip *.tar.* *.deb

	# -------------------------------------------

	# Set up python boto for khajuri
	sudo pip install -U boto
	sudo pip install -U paramiko
	sudo pip install -U yapsy

	# -------------------------------------------

	# Database
	sudo apt-get install libmysqlclient-dev mysql-server mysql-client


	# -------------------------------------------

	# Clean up unused
	sudo apt-get autoremove

	# -------------------------------------------


### Ruby & Rails

More instruction [Here.](http://ryanbigg.com/2010/12/ubuntu-ruby-rvm-rails-and-you/)

`curl -L get.rvm.io | bash -s stable`

Add to ~/.bash_profile

	[[ -s "$HOME/.profile" ]] && source "$HOME/.profile"
	[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

`source ~/.rvm/scripts/rvm`

Add RVM to PATH for scripting

`export PATH="$PATH:$HOME/.rvm/bin"`

Install Ruby

	rvm install 2.0.0
	rvm use 2.0.0
	ruby -v

Install Rails

	gem install rails --no-rdoc --no-ri
	gem install mysql2

[Note: If starting the server in the next step doesn't work, you might have to install mysql as well.]

### Clone repos
Khajuri and Kheer repos are in github - install them in directory where you will have plenty of space.

	git clone https://github.com/zigvu/kheer.git
	git clone https://github.com/zigvu/khajuri.git

Set up Kheer to talk to Momo and Khajuri:

Edit `khajuri` `root_path` in file `kheer/config/kheer_config.yml` to point to the absolute path of the khajuri directory.

Edit `username` and `password` in file `kheer/config/passwords.yml` to use in Momo server communication.

### Enable TMPFS

Khajuri potentially has a lot of IO - a workaround is to use RAM as a file system. While each video pipeline reads/writes <20MB during processing, to be on the safe side, we will use 50MB per number of parallel video pipeline jobs we plan to use. (Example: If you have a 4 core machine and plan to start 6 pipelines in parallel, set aside 6*50MB = 300MB for TMPFS. Khajuri requires TMPFS to be mounted at `/mnt/tmp`.)

	sudo mkdir -p /mnt/tmp
	gksudo gedit /etc/fstab

In the end of the file, type in EXACTLY:

	# TMPFS
	tmpfs /mnt/tmp tmpfs size=100M,mode=0777 0 0

where you can replace 100M with the amount of space you need for TMPFS. Now, you can reload fstab by:

	sudo mount -a

At this point, check to ensure that TEMPFS was successfully created

	df -h
	touch /mnt/tmp/test.txt
	rm /mnt/tmp/test.txt


### Test Khajuri

Get branch for kheer integration

	cd khajuri
	git pull origin master
	sudo python setup.py develop
	cd VideoReader
	./make_all.sh <number of cores>


Go to test set up to make sure that Khajuri works stand-alone. If it doesn't, contact Sudip.

	cd khajuri/test
	../VideoPipeline.py config.yaml videos/lUA7i4K2Sq8.mp4

Once done, you should see results in videos/5.json file.

### Test Kheer

Set up database and start server:

	cd kheer
	bundle install
	rake db:setup
	rails s

Now, in Firefox, open page localhost:3000. Sign up as a new user and login.

In a new terminal, start background jobs:

	cd kheer
	bin/delayed_job -n 4 start

Note that each worker thread takes about 1GB of memory. There is 1 manager thread and others are worker threads. To stop all threads:

	cd kheer
	bin/delayed_job -n 4 stop

You can monitor progress of threads in UI.

Contact Evan to understand the campaign workflow.

### Updating Kheer after code change

All code changes that are to be released are released under the "master" branch. Following steps are necessary to update existing Kheer setup in your machine:

	cd kheer
	git pull origin master
	bundle install
	rake db:migrate
	rails s

The above WILL NOT erase your database. Occasionally, you might want to reset your database. For that, following steps are necessary:

	cd kheer
	git pull origin master
	bundle install
	rake db:reset
	rm -rf public/data/*
	rails s

Note that this WILL erase your database. After each database reset, it is recommended that you also delete all data found in public/data folder. A UI method of managing database/files is in the todo-list: once that is online, database reset will rarely be necessary.