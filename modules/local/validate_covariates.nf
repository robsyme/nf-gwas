process VALIDATE_COVARIATES {

  publishDir "${params.outdir}/logs", mode: 'copy', pattern: '*log'
  publishDir "${params.outdir}/validated_input/", mode: 'copy', pattern: '*validated.txt'

  input:
    path covariates_file

  output:
    path "${covariates_file.baseName}.validated.txt", emit: covariates_file_validated
    path "${covariates_file.baseName}.validated.log", emit: covariates_file_validated_log

  """
  java -jar /opt/RegenieValidateInput.jar --input ${covariates_file} --output  ${covariates_file.baseName}.validated.txt --type covariate
  """
  }
