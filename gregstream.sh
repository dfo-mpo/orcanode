#!/bin/bash
# Script for live DASH/HLS streaming lossy audio as AAC and/or archiving lossless audio as FLAC  
# Some environmental variables set by local .env file; others here:

# Pre-requisite
# s3fs/blobfuse file system at $RAWFS with appropriate permissions for current user, to store raw audio
# s3fs/blobfuse file system at $WEBFS with appropriate permissions for current user, to host HLS/encoded streaming
# folder at $TMP with read/write for current user

RAWFS=/pbsorca
WEBFS=/pbsorcaweb
TMP=/mnt/orcatmp
SEGMENT_DURATION=30
FLAC_DURATION=30
LAG_SEGMENTS=6
LAG=$(( LAG_SEGMENTS*SEGMENT_DURATION ))
CHOP_M3U8_LINES=$(( LAG_SEGMENTS*(-2) ))
NODE_NAME=GREGNODE
SAMPLE_RATE=48000
STREAM_RATE=22050
CHANNELS=2
AUDIO_HW_ID=0

# Get current timestamp
timestamp=$(date +%s)

#### Set up local output directories
mkdir -p $RAWFS/$NODE_NAME
mkdir -p $RAWFS/$NODE_NAME/raw
mkdir -p $WEBFS/$NODE_NAME/streaming

# Output timestamp for this (latest) stream
echo $timestamp > $RAWFS/$NODE_NAME/last-started.txt

echo "Node started at $timestamp"
echo "Node is named $NODE_NAME"

echo "Sampling from $AUDIO_HW_ID at $SAMPLE_RATE Hz..."
echo "Asking ffmpeg to write $FLAC_DURATION second $SAMPLE_RATE Hz lo-res flac files while streaming in both DASH and HLS..." 

## Streaming HLS segments and FLAC archive

ffmpeg -f pulse -ac 2 -ar $SAMPLE_RATE -thread_queue_size 1024 -i $AUDIO_HW_ID -ac $CHANNELS -ar $SAMPLE_RATE -sample_fmt s32 -acodec flac \
-f segment -segment_time "00:00:$FLAC_DURATION.00" -strftime 1 "$RAWFS/$NODE_NAME/raw/%Y%m%d_%H%M%S_$NODE_NAME.flac" \
-f segment -segment_list "$WEBFS/$NODE_NAME/streaming/live.m3u8" -segment_wrap 10 -segment_list_flags +live -segment_time $SEGMENT_DURATION -segment_format mpegts -ar $STREAM_RATE -ac $CHANNELS -acodec aac "$WEBFS/$NODE_NAME/streaming/live%03d.ts"
