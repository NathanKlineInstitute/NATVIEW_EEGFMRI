#!/usr/bin/env python
# extract the information from the json file 
# Usage: python ccs_prep_bids_json2txt.py -i input.json -o output.txt -key SliceTiming -f "%.8f"
# Ting Xu
import os, sys
import argparse
import json
import numpy as np

if __name__=='__main__':
    NoneType=type(None)
    # Argument
    parser=argparse.ArgumentParser(description='ExtractJsonInfo', formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    optional=parser._action_groups.pop()
    required=parser.add_argument_group('required arguments')
    # Required Option
    required.add_argument('-i', '--in_json', required=True, type=str, help='Path of the BIDS json file')
    required.add_argument('-o', '--out', required=True, type=str, help='Path of text file to save the json infomation')
    required.add_argument('-key', '--key', required=True, type=str, help='Keyword of attribute to extract, e.g.  SliceTiming')
    required.add_argument('-f', '--format', required=True, type=str, help='Format to save the json info to the text file, e.g. %.8f')


    parser._action_groups.append(optional)
    if len(sys.argv)==1:
        parser.print_help()
        sys.exit(1)
    args = parser.parse_args()

    print("+>> Extract %s Info" % args.key)
    print(args.in_json)

    with open(args.in_json, 'r') as json_file:
        jhdr = json.load(json_file)
    a = jhdr[ ('%s' % args.key) ]

    if type(a) != list:
        a = [a]

    x = np.array(a)
    np.savetxt(args.out, x, fmt=('%s' % args.format))
