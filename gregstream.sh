#!/bin/bash
# Script for live DASH/HLS streaming lossy audio as AAC and/or archiving lossless audio as FLAC  
# Some environmental variables set by local .env file; others here:

# Pre-requisite
# s3fs/blobfuse file system at $CLOUDFS with appropriate permissions for current user
# folder at $TMP with read/write for current user

CLOUDFS=/pbsorca
TMP=/mnt/orcatmp
SEGMENT_DURATION=30
FLAC_DURATION=10
LAG_SEGMENTS=6
LAG=$(( LAG_SEGMENTS*SEGMENT_DURATION ))
CHOP_M3U8_LINES=$(( LAG_SEGMENTS*(-2) ))
NODE_NAME=GREGNODE
SAMPLE_RATE=48000
STREAM_RATE=48000
CHANNELS=2
AUDIO_HW_ID=0

# Get current timestamp
timestamp=$(date +%s)

#### Set up local output directories
mkdir -p $TMP/m3u8tmp
mkdir -p $TMP/hls
mkdir -p $TMP/hls/$timestamp
mkdir -p $TMP/m3u8tmp/$timestamp
mkdir -p $CLOUDFS/$NODE_NAME
mkdir -p $CLOUDFS/$NODE_NAME/hls
mkdir -p $CLOUDFS/$NODE_NAME/hls/$timestamp

# Output timestamp for this (latest) stream
echo $timestamp > $CLOUDFS/$NODE_NAME/last-started.txt

echo "Node started at $timestamp"
echo "Node is named $NODE_NAME"

echo "Sampling from $AUDIO_HW_ID at $SAMPLE_RATE Hz..."
echo "Asking ffmpeg to write $FLAC_DURATION second $SAMPLE_RATE Hz lo-res flac files while streaming in both DASH and HLS..." 
## Streaming HLS segments and FLAC archive direct to /mnt directories, but live.m3u8 via /tmp
#nice -n -10
ffmpeg -f pulse -ac 2 -ar $SAMPLE_RATE -thread_queue_size 1024 -i $AUDIO_HW_ID -ac $CHANNELS -ar $SAMPLE_RATE -sample_fmt s32 -acodec flac \
-f segment -segment_time "00:00:$FLAC_DURATION.00" -strftime 1 "$CLOUDFS/$NODE_NAME/%Y-%m-%d_%H-%M-%S_$NODE_NAME-$SAMPLE_RATE-$CHANNELS.flac" \
-f segment -segment_list "$TMP/m3u8tmp/$timestamp/live.m3u8" -segment_list_flags +live -segment_time $SEGMENT_DURATION -segment_format mpegts -ar $STREAM_RATE -ac $CHANNELS -acodec aac "$TMP/hls/live%03d.ts"


#### Stream with test engine live tools
## May need to adjust segment length in config_audio.json to match $SEGMENT_DURATION...
#nice -n -7 ./test-engine-live-tools/bin/live-stream -c ./config_audio.json udp://127.0.0.1:1234 &


#sleep $LAG

#while true; do
    #echo "In while loop copying aged m3u8 for $NODE_NAME with lag of $LAG_SEGMENTS segments, or $LAG seconds..."
    #head -n $CHOP_M3U8_LINES $TMP/m3u8tmp/$timestamp/live.m3u8 > $TMP/$NODE_NAME/hls/$timestamp/live.m3u8
    #cp $TMP/$NODE_NAME/hls/$timestamp/live.m3u8 $CLOUDFS/$NODE_NAME/hls/$timestamp/live.m3u8
    #sleep $SEGMENT_DURATION
#done
