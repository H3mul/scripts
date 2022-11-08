#!/bin/bash
sleep 5; 
if [ "`qdbus org.freedesktop.ScreenSaver /org/freedesktop/ScreenSaver GetActive`" = "true" ]; then
   xset dpms force off
fi
