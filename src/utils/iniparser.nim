##
## A simple INI string parser

import std/strutils

## INI Data
type INIData* = seq[tuple[section : string, name : string, data : string]]

## Get info from a string
proc parseINI*(file : string) : INIData =

    # Create data
    var data : INIData

    # Read line by line
    var currentSection = ""
    for line2 in file.splitLines():

        # Remove comments
        var line = line2
        var commentIdx = line.find("#")
        if commentIdx != -1:
            line = line[0 ..< commentIdx]

        # Skip empty lines
        if line == "":
            continue

        # Check if section
        if line.startsWith("[") and line.endsWith("]"):
            currentSection = line[1 ..< ^1]
            continue

        # Find separator '='
        var separator = line.find("=")
        if separator == -1:
            continue

        # Split the key and value
        var key = line[0 .. separator - 1].strip
        var value = line[separator + 1 ..< ^0].strip

        # If value is quoted, remove the quotes
        if value.startsWith("\"") and value.endsWith("\""):
            value = value[1 ..< ^1]

        # Store it
        data.add((currentSection, key, value))

    # Done
    return data


## Get a property
proc get*(data : INIData, name : string, section : string = "", defaultValue : string = "") : string =

    # Find it
    let lowercaseSection = section.toLower
    let lowercaseName = name.toLower
    for (s, n, d) in data:

        # Skip if section doesn't match
        if s.toLower != lowercaseSection:
            continue

        # Skip if name doesn't match
        if n.toLower != lowercaseName:
            continue

        # Found it
        return d

    # Not found
    return defaultValue

