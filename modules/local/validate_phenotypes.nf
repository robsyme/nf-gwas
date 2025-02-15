process VALIDATE_PHENOTYPES {

  publishDir "${params.outdir}/logs", mode: 'copy', pattern: '*log'
  publishDir "${params.outdir}/validated_input/", mode: 'copy', pattern: '*validated.txt'

  input:
    path phenotypes_file

  output:
    path "${phenotypes_file.baseName}.validated.txt", emit: phenotypes_file_validated
    path "${phenotypes_file.baseName}.validated.log", emit: phenotypes_file_validated_log

  """
  java -jar /opt/RegenieValidateInput.jar --input ${phenotypes_file} --output  ${phenotypes_file.baseName}.validated.txt --type phenotype
  """
  }
