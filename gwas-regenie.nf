params.project = "test-gwas"
params.output = "tests/output/${params.project}"

params.genotypes_typed = "tests/input/example.{bim,bed,fam}"
params.genotypes_imputed = "tests/input/example.bgen"
params.genotypes_imputed_format = "bgen"

params.phenotypes_filename = "tests/input/phenotype.txt"
params.phenotypes_binary_trait = false
params.phenotypes_columns = ["Y1","Y2"]

params.qc_maf = "0.01"
params.qc_mac = "100"
params.qc_geno = "0.1"
params.qc_hwe = "1e-15"
params.qc_mind = "0.1"

params.regenie_step1_bsize = 100
params.regenie_step2_bsize = 200
params.regenie_pvalue_threshold = 0.01

gwas_report_template = file("$baseDir/reports/gwas_report_template.Rmd")


Channel.fromFilePairs("${params.genotypes_typed}", size: 3).set {genotyped_plink_files_ch}
Channel.fromFilePairs("${params.genotypes_typed}", size: 3).set {genotyped_plink_files_ch2}
imputed_files_ch =  Channel.fromPath("${params.genotypes_imputed}")
phenotype_file_ch = file(params.phenotypes_filename)
phenotype_file_ch2 = file(params.phenotypes_filename)

//TODO: if params.genotypes_imputed_format == "vcf" --> define process to convert to bgen or bed?

process qualityControl {

  publishDir "$params.output/01_quality_control", mode: 'copy'

  input:
    set genotyped_plink_filename, file(genotyped_plink_file) from genotyped_plink_files_ch

  output:
    file "${genotyped_plink_filename}.qc.*" into genotyped_plink_files_qc_ch

  """
  plink2 \
    --bfile ${genotyped_plink_filename} \
    --maf ${params.qc_maf} \
    --mac ${params.qc_mac} \
    --geno ${params.qc_geno} \
    --hwe ${params.qc_hwe} \
    --mind ${params.qc_mind} \
    --write-snplist --write-samples --no-id-header \
    --out ${genotyped_plink_filename}.qc
  """

}

process regenieStep1 {

  publishDir "$params.output/02_regenie_step1", mode: 'copy'

  input:
    set genotyped_plink_filename, file(genotyped_plink_file) from genotyped_plink_files_ch2
    file phenotype_file from phenotype_file_ch
    file qcfiles from genotyped_plink_files_qc_ch.collect()

  output:
    file "fit_bin_out*" into fit_bin_out_ch

  """

  regenie \
    --step 1 \
    --bed ${genotyped_plink_filename} \
    --extract ${genotyped_plink_filename}.qc.snplist \
    --keep ${genotyped_plink_filename}.qc.id \
    --phenoFile ${phenotype_file} \
    --phenoColList  ${params.phenotypes_columns.join(',')} \
    --bsize ${params.regenie_step1_bsize} \
    ${params.phenotypes_binary_trait == true ? '--bt' : ''} \
    --lowmem \
    --lowmem-prefix tmp_rg \
    --out fit_bin_out
  """

}


process regenieStep2 {

  publishDir "$params.output/03_regenie_step2", mode: 'copy'

  input:
    file imputed_file from imputed_files_ch
    file phenotype_file from phenotype_file_ch2
    file fit_bin_out from fit_bin_out_ch.collect()

  output:
    file "gwas_results.*regenie" into gwas_results_ch

  """
  regenie \
    --step 2 \
    --bgen ${imputed_file} \
    --phenoFile ${phenotype_file} \
    --phenoColList  ${params.phenotypes_columns.join(',')} \
    --bsize ${params.regenie_step2_bsize} \
    ${params.phenotypes_binary_trait ? '--bt' : ''} \
    --firth --approx \
    --pThresh ${params.regenie_pvalue_threshold} \
    --pred fit_bin_out_pred.list \
    --out gwas_results.${imputed_file.baseName}

  """

}

process mergeRegenie {

publishDir "$params.output/04_regenie_merged", mode: 'copy'

  input:
  file regenie_chromosomes from gwas_results_ch.collect()

  output:
  file "merged.regenie" into merged_ch

  """
  ls -1v ${regenie_chromosomes} | head -n 1 | xargs cat | zgrep -hE 'CHROM' > header.txt
  ls -1v ${regenie_chromosomes} | xargs cat | zgrep -hE '^[0-9]' > chromosomes_data.regenie
  cat header.txt chromosomes_data.regenie > merged.regenie
  """

}

process gwasReport {

publishDir "$params.output", mode: 'copy'

  input:
  file regenie_merged from merged_ch
  file gwas_report_template

  output:
  file "*.html" into report_ch

  """
  Rscript -e "require( 'rmarkdown' ); render('${gwas_report_template}',
    params = list(
      project = '${params.project}',
      regenie_merged = '${regenie_merged}',
      phenotype='${params.phenotypes_columns.join(',')}'
    ), knit_root_dir='\$PWD', output_file='\$PWD/05_gwas_report.html')"
  """
}


//TODO: process annotate

workflow.onComplete {
    println "Pipeline completed at: $workflow.complete"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}
