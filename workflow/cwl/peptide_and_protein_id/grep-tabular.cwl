#!/usr/bin/env cwl-runner
cwlVersion: v1.1
class: CommandLineTool

baseCommand: grep

inputs:
  tabular_data: File
  not_matching:
    type: boolean?
    inputBinding:
      prefix: -v
  pattern: string

arguments:
 - -P
 - $(inputs.pattern)
 - $(inputs.tabular_data.path)

stdout: $(inputs.tabular_data.nameroot)_matches.txt

outputs:
  matches: stdout
