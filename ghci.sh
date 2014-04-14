#!/bin/sh

# Colors
Red=`echo "\x1b[31m"`
Green=`echo "\x1b[92m"`
Yellow=`echo "\x1b[93m"`
Blue=`echo "\x1b[94m"`
Purple=`echo "\x1b[95m"`
Cyan=`echo "\x1b[96m"`

Reset=`echo "\x1b[0m"`

# Patterns
double_colon="s/::/${Red}&${Reset}/;"
rocket="s/=>/${Red}&${Reset}/;"
left_arrow="s/->/${Red}&${Reset}/;"
strings="s/\"[^\"]*\"/${Yellow}&${Reset}/g;"
chars="s/’[a-zA-Z]’/${Purple}&${Reset}/g;"
braces1="s/{/${Green}&${Reset}/g"
braces2="s/}/${Green}&${Reset}/g"
comma="s/,/$Cyan&\n$Reset/g"
bracket1="s/\[/$Purple&$Reset/g"
bracket2="s/\]/$Purple&$Reset/g"

exec "ghci"  ${1+"$@"}  |
sed -e "s/::/${Red}&${Reset}/g
$bracket1
$bracket2
$braces1
$braces2
$comma
$left_arrow
$rocket
$chars
$strings"
