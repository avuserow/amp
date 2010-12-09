#!/bin/sh

# "stream" below is the name of the Acoustics player ID that we use
# if you want to change the name, copy this file, change that value
# and edit your ezstream configuration to point to the new file.

`dirname $0`/acoustics player-song_iterate stream | tail -1
