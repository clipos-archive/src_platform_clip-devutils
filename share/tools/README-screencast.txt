How to make a screencast out of multiple screenshot
===================================================

Dependencies
------------

- Image Magick
- mpv (fork of mplayer)

Performing the screencast
-------------------------

Making a screencast on CLIP can be a bit tricking. You roughtly (it'll probably need some adjustment) need to:
- perform screen captures in loop
 $ chvt 7 && for i in $(seq 1000); do ./screenshot.sh; done && chvt 2
- copy the screenshots to a different computer (with the video editing tools)
- add the mouse pointer to all the images (using add-pointer-multi.sh)
- merge all the resulting images in a video
 $ mpv *-with-pointer.jpg -mf-fps=9 -mf-type=jpg -of=webm -ovc libvpx -ovcopts qmin=4,b=1000000k -of webm --ofps=9 --oneverdrop -o output-video.webm
 (here 9 corresponds to the number of screen capture that can be performed by seconds, you'll
  probably need to tweak this value)

Using this setup, a good quality screen recording takes about 4MB/min of video (without sound).
