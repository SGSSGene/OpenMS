#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: Workflow

label: Peptide and Protein ID using OpenMS tools

doc: |
  Adapted from https://gxy.io/GTN:T00228
  1. Florian Christoph Sigloch, Björn Grüning, Peptide and Protein ID using OpenMS tools (Galaxy Training Materials).
     https://training.galaxyproject.org/training-material/topics/proteomics/tutorials/protein-id-oms/tutorial.html Online; accessed Thu Jul 13 2023
  2. Hiltemann, Saskia, Rasche, Helena et al., 2023 Galaxy Training: A Powerful Framework for Teaching! PLOS Computational Biology 10.1371/journal.pcbi.1010752
  3. Batut et al., 2018 Community-Driven Data Analysis Training for Biology Cell Systems 10.1016/j.cels.2018.05.012

inputs:
  mzml: File
  protein_database:
   type: File
   label: Human database including cRAP contaminants and decoys

steps:
  pick_peaks:
    label: Also known as "centroiding".
    run: ../tools/PeakPickerHiRes.cwl
    in:
      in: mzml
      out:
        default: peaks.mzml
      algorithm__ms_levels:
        default: [ 2 ]
    out: [ out ]
  peptide_identification:
    label: Compare the MS2 spectrums to theoretical spectrums generated from a protein database
    run: ../tools/XTandemAdapter.cwl
    in:
      in: pick_peaks/out
      out:
        default: peptides.idXML
      database: protein_database
      xtandem_executable:
        default: tandem
      fragment_mass_tolerance:
        default: 10.0
      fragment_error_units:
        default: ppm
    out: [ out ]
  psms_file_info:
    run: ../tools/FileInfo.cwl
    in:
      in: peptide_identification/out
      out:
        default: peptides.txt
    out: [ out ]
  add_target_decoy_information:
    label: annotate the identified peptides to determine which of them are decoys
    run: ../tools/PeptideIndexer.cwl
    in:
      in: peptide_identification/out
      out:
        default: peptides_with_marked_decoys.idXML
      fasta: protein_database
      write_protein_sequence:
        default: true
      write_protein_description:
        default: true
      enzyme__specificity:
        default: none
    out: [ out ]
  estimate_probabilities:
    label: calculate peptide posterior error probabilities (PEPs)
    run: ../tools/IDPosteriorErrorProbability.cwl
    in:
      in: add_target_decoy_information/out
      out:
        default: peptide_probabilities.idXML
      prob_correct:
        default: true
    out: [ out ]
  filter_psms:
    label: filter PSMs for 1% FDR
    run: ../tools/FalseDiscoveryRate.cwl
    in:
      in: estimate_probabilities/out
      out:
        default: filtered_peptide_probabilities.idXML
      PSM:
        default: true
      protein:
        default: false
      FDR__PSM:
        default: 0.01
      algorithm__add_decoy_peptides:
        default: true
    out: [ out ]
  reset_scores_to_PEP:
    label: set the score back to PEP for the remaining PSMs
    run: ../tools/IDScoreSwitcher.cwl
    in:
      in: filter_psms/out
      out:
        default: filtered_psms.idXML
      proteins:
        default: false
      new_score:
        default: "Posterior Probability_score"
      new_score_orientation:
        default: higher_better
    out: [ out ]
  summarize_filtered_psms:
    label: get basic information about the identified peptides
    run: ../tools/FileInfo.cwl
    in:
      in: reset_scores_to_PEP/out
      out:
        default: filtered_psms.txt
    out: [ out ]
  infer_proteins_from_peptides:
    run: ../tools/FidoAdapter.cwl
    in:
      in: reset_scores_to_PEP/out
      out:
        default: proteins.idXML
      fido_executable:
        default: Fido
      fidocp_executable:
        default: FidoChooseParameters
      greedy_group_resolution:
        default: true
    out: [ out ]
  filter_proteins:
    label: filter proteins for 1% FDR
    run: ../tools/FalseDiscoveryRate.cwl
    in:
      in: infer_proteins_from_peptides/out
      out:
        default: filtered_proteins.idXML
      PSM:
        default: false
      protein:
        default: true
      FDR__protein:
        default: 0.01
    out: [ out ]
  summarize_filtered_proteins:
    label: get basic information about the identified proteins
    run: ../tools/FileInfo.cwl
    in:
      in: filter_proteins/out
      out:
        default: filtered_proteins.txt
    out: [ out ]
  convert_idXML_to_tabular:
    label: convert the idXML output to a human-readable tabular file
    run: ../tools/TextExporter.cwl
    in:
      in: filter_proteins/out
      out:
        default: filtered_proteins.tsv
    out: [ out ]
  find_contaminants:
    run: grep-tabular.cwl
    in:
      tabular_data: convert_idXML_to_tabular/out
      pattern:
        default: CONTAMINANT
    out: [ matches ]
  find_contaminants_human:
    label: remove all non human proteins (e.g. bovine)
    run: grep-tabular.cwl
    in:
      tabular_data: convert_idXML_to_tabular/out
      pattern:
        default: HUMAN
    out: [ matches ]
outputs:
  peaks:
    type: File
    outputSource: pick_peaks/out
  peaks_annotations:
    label: Peptide-Spectrum-Matches (PSMs)
    type: File
    outputSource: peptide_identification/out
  peaks_annotation_info:
    type: File
    outputSource: psms_file_info/out
  peaks_annotations_with_targets_decoys:
    type: File
    outputSource: add_target_decoy_information/out
  psm_with_probabilities:
    label: Peptide-Spectrum-Matches annotated with Posterior Error Probablities
    type: File
    outputSource: estimate_probabilities/out
  filtered_psms:
    label: Peptide-Spectrum-Matches after filtering for 1% false-discovery rate
    type: File
    outputSource: filter_psms/out
  filtered_psms_with_pep_scores:
    label: PSMs after filtering for 1% false-discovery rate, with PEP scores
    type: File
    outputSource: reset_scores_to_PEP/out
  filtered_psms_info:
    label: basic information about the indetified peptides
    type: File
    outputSource: summarize_filtered_psms/out
  protein_groups:
    doc: |
     The protein groups and accompanying posterior probabilities inferred by Fido
     are stored as "indistinguishable protein groups", attached to the protein
     identification run(s) of the input data. Also attached are meta values
     recording the Fido parameters (Fido_prob_protein, Fido_prob_peptide, Fido_prob_spurious).
    type: File
    outputSource: infer_proteins_from_peptides/out
  filtered_protein_groups:
    label: Proteins after filtering for 1% false-discovery-rate
    type: File
    outputSource: filter_proteins/out
  filtered_proteins_info:
    label: basic information about the identified proteins
    type: File
    outputSource: summarize_filtered_proteins/out
  tabular_filtered_protein_groups:
    label: Proteins after filtering for 1% false-discovery-rate, in human-readable tabular form
    type: File
    outputSource: convert_idXML_to_tabular/out
  contaminants:
    type: File
    outputSource: find_contaminants/matches
  contaminants_human:
    type: File
    outputSource: find_contaminants_human/matches
