#!/bin/bash
THIS_DIR=$( cd "$( dirname "$0" )" && pwd )
cd $THIS_DIR && ./example_player holdem.nolimit.2p.reverse_blinds.game $1 $2
