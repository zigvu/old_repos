#### Requirements

* Firefox version 26 or higher (will NOT work in lower versions)

#### Download and install

* If previous version of `anarsa` is installed, uninstall as explained in the Uninstall section below
* Go to `anarsa/release/` and click on the zip file with the latest date version
* Click on `view raw` option -- this will download a zip file
* Unzip downloaded file to get `anarsa.xpi` -- double click to install in Firefox
* Restart Firefox
* If install was successful, you will see a new icon on the bottom right Firefox window. (You might need to enable the addon bar if there is no bar at the bottom of Firefox window)

        Note: If you encounter problems, first try disabling other addons 
        and retry above steps - if that doesn't work, then please file a bug.

#### Connect with Momo

* Open EC2 instance and start Momo
* Log into Momo using username/password
* Checkout a model for which you are collecting images
* Click on the "Red server" icon on the addon bar. This will popup a panel to enter Momo URL
* IMPORTANT: Enter the full base URL for Momo. This includes the `http://` reference and the port number. Do not include anything after the port number - this part is fairly brittle right now. Example:
`http://ec2-54-202-77-121.us-west-2.compute.amazonaws.com:3000`
* Click `Submit`
* Upon success, the popup panel displays the logged in UserId and checked out ModelId. The icons on the addon bar will also change colors indicating that the addon is connected and active. In addition a sidebar will popup - this provides a way to track file uploads to momo
* If there are no errors, then click outside the popup panel to dismiss it

#### Collect Images

* In the same Firefox window, open a new tab. IMPORTANT: Momo login information may not be carried over from one Firefox "window" to the next - but will persist across tabs in the same window
* Type in URL of the image web site. You can do your regular browsing here to look for images.
* If the size of the source image (vs. the actual display size) is at least 600 pixel in at least one dimension, Momo can use those images. To find all such images in the current tab, click on the green "rescan" button in the sidebar. (Alternatively, you can press `ctrl+e`.) All usable images are highlighted with red and have a `Save` button on top of them
* To save an image click on the `Save` button - the URL for the image is sent to Momo and save status is shown in the side bar

		Note: Most image sites (including Google, Bing, Flickr) use Javascript to 
		show/hide images. This typically means that when images are outside of the 
		viewport (visible area of Firefox window), the HTML image tags are undefined 
		or have dummy links. Hence, when there is an image of interest, it is always 
		a good idea to rescan for images. For web sites that dynamically load images 
		(infinite scroll), it is a good idea to work on maximized Firefox window 
		(since Javascript will `GET` the correct size image from server) and rescan 
		every-so-often (since Javascript also changes image position leading to incorrect
		position of the `Save` button). Additionally, it might be necessary to click on an
		image to enlarge it before rescanning so that correct image version is used by
		website Javascript. (The websites really really want to protect their images and
		Javascript seems to be the weapon of choice.)

#### Use Collected Images

* All saved images are placed in `Clipboard` of current user. A quick glance at these images is required before copy/pasting to positive/negative albums since some websites may not always provide the same image when viewed from different client instances

#### Change Momo State

* If a new model is checked out in Momo, it is a good idea to re-submit a connect request to the Momo server using connection panel. The ModelId of the new model should be displayed
* If logging out of Momo, click on `Reset` button on connection panel - the addon state re-initializes its state and prevents images from being sent to Momo

#### Uninstall addon

* Reset any connection with Momo by clicking on `Reset` button on connection panel
* Go to Addon menu and remove addon
* Restart Firefox