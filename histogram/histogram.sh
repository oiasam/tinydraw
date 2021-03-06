#!/bin/bash
#
# histogram.sh -- Draw two row data in SVG with histogram
#
# Derive from (linux)/scripts/bootgraph.pl and FlameGraph.
#
# Author: Wu Zhangjin <wuzhangjin@gmail.com> of TinyLab.org
# Update: Sun Jan  5 22:15:20 CST 2014
#
# Licensed under GPLv2 and later
#

# Arguments
data_file=$1
graph_title=$2
data_info=$3

# Configuration
rect_width=10
x_start=10
y_start=60
svg_width=1200
svg_height=1200
text_width=200
text_offset=20
float_precision=3
font_size=8

# SVG file info
svg_file_info="<!-- Generated by TinyDraw/histogram/histogram.sh: http://www.tinylab.org/project/tinydraw/ -->"

function usage #error
{
	echo
	echo $1
	echo

	echo "* Usage:"
	echo "	$0 data_file [graph_title] [data_info]"
	echo
	echo "* Data format:"
	echo
	echo "string1 value1"
	echo "string2 value2"
	echo "string3 value3"
	echo "string4 value4"
	echo
	echo "* For example:"
	echo
	echo "A 5"
	echo "B 6.9"
	echo "C 3.0"
	echo
}

[ -z "$data_file" ] && usage "No data_file specified." && exit 1
[ ! -f "$data_file" ] && usage "No such file: $data_file" && exit 1
[ -z "$graph_title" ] && graph_title="Boot Graph"
[ -z "$data_info" ] && data_info="Function"

# Calculate the svg_height
count=$(wc -l $data_file | cut -d' ' -f1)
((svg_height=y_start*2 + rect_width*count))

# default order: [string, value], detect the real order
# If it is [value, string], set swap_input to 1
swap_input=1
cat $data_file | cut -d' ' -f1 | head -1 | egrep -q "[a-zA-Z_:]+"
[ $? -eq 0 ] && swap_input=0
cat $data_file | cut -d' ' -f1 | tail -1 | egrep -q "[a-zA-Z_:]+"
[ $? -eq 0 ] && swap_input=0

# Get the right value_row for the cut command
if [ $swap_input -eq 1 ]; then
    value_row=1
else
    value_row=2
fi

# Print the SVG header
#
# Based on Flame Graph: https://github.com/brendangregg/FlameGraph.git
#

cat <<EOF
<?xml version="1.0" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
$svg_file_info
<svg version="1.1" width="$svg_width" height="$svg_height" onload="init(evt)" viewBox="0 0 $svg_width $svg_height" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
<defs >
	<linearGradient id="background" y1="0" y2="1" x1="0" x2="0" >
		<stop stop-color="#eeeeee" offset="5%" />
		<stop stop-color="#eeeeb0" offset="95%" />
	</linearGradient>
</defs>
<style type="text/css">
	.func_g:hover { stroke:black; stroke-width:0.5; }
	.ruler_l {stroke:black;stroke-width:1;}
</style>
<script type="text/ecmascript">
<![CDATA[
	var details;
	function init(evt) { details = document.getElementById("details").firstChild; }
	function s(info) { details.nodeValue = "$data_info: " + info; }
	function c() { details.nodeValue = ' '; }
]]>
</script>

EOF

# Draw the canvas
cat <<EOF
    <rect x="0.0" y="0" width="1200.0" height="100%" fill="url(#background)"/>
EOF

# Draw the title
cat <<EOF
    <text text-anchor="middle" x="600" y="25" font-size="17" font-family="Verdana" fill="rgb(0,0,0)" >$graph_title</text>
EOF

# Draw the dynamic bar
cat <<EOF
    <text text-anchor="" x="10" y="50" font-size="12" font-family="Verdana" fill="rgb(0,0,0)" id="details"></text>
EOF

# Draw the data
((y= y_start + rect_width))

## Build the map between the max value with the SVG width
if [ $swap_input -eq 1 ]; then
    max_value=$(cat $data_file | tr -s ' ' | tr '\t' ' ' | sed -e 's/[[:space:]]*$//g' | sed -e 's/\(^[0-9\.]*\) .*/\1/g' | sort -g -r | head -1)
else
    max_value=$(cat $data_file | tr -s ' ' | tr '\t' ' ' | sed -e 's/[[:space:]]*$//g' | sed -e 's/.* \([0-9\.]*\)$/\1/g' | sort -g -r | head -1)
fi
mult=$(echo "scale=$float_precision; ($svg_width - $x_start - $text_width)/ $max_value" | bc)

while read line
do

# Parse string and value
if [ $swap_input -eq 1 ]; then
    string="${line#* }"
    value="${line%% *}"
else
    string="${line% *}"
    value="${line##* }"
fi

# Drop the chars: ",',),(,<,>
string=$(echo "$string" | tr -d "'|\"|>|<")

## Generate the color
((r = $RANDOM % 255))
((g = $RANDOM % 255))
((b = $RANDOM % 255))

## Get the y axis
((y = y + rect_width))

## Get the height of the rectangle
height=$(echo "scale=$float_precision; ($mult * $value)" | bc)

## Get the position of the text
text_length=${#string}
text_x=$(echo "$height+$text_offset" | bc)
((text_y = y + rect_width/2 + rect_width/3))

echo "    <g class=\"func_g\" onmouseover=\"s('$string($value)')\" onmouseout=\"c()\">"
echo "        <rect x=\"$x_start\" y=\"$y\" width=\"$height\" height=\"$rect_width\" fill=\"rgb($r,$g,$b)\" rx=\"2\" ry=\"2\"/>"
echo "        <text text-anchor=\"\" x=\"$text_x\" y=\"$text_y\" font-size=\"$font_size\" font-family=\"Verdana\" fill=\"rgb(0,0,0)\">$string($value)</text>"
echo "    </g>"

done < $data_file

# Draw the footer
echo
echo "</svg>"
