#########
# about #
#########
__version__ = '0.1.0'
__author__ = ['Nikos Karaiskos', 'Tamas Ryszard Sztanka-Toth']
__licence__ = 'GPL'
__email__ = ['nikolaos.karaiskos@mdc-berlin.de', 'tamasryszard.sztanka-toth@mdc-berlin.de']

downsampled_sample_root = downsample_root + '/{ratio}'
downsampled_bam = downsampled_sample_root + '/final_downsampled_{ratio}.bam'
downsampled_readcounts = downsampled_sample_root + '/out_readcounts.txt.gz'
downsampled_top_barcodes = downsampled_sample_root + '/topBarcodes.txt'

# dges
downsample_dge_root = downsampled_sample_root + '/downsampled_dge'
downsample_dge_out_prefix = downsample_dge_root + '/downsampled_dge{dge_type}'
downsample_dge_out = downsample_dge_out_prefix + '.txt.gz'
downsample_dge_out_summary = downsample_dge_out_prefix + '_summary.txt'
downsample_dge_types = ['_exon', '_intron', '_all', 'Reads_exon', 'Reads_intron', 'Reads_all']

downsample_qc_sheet = downsampled_sample_root + '/qc_sheet/qc_sheet_{sample}_{puck}_downsampled_{ratio}.pdf'

downsample_saturation_analysis = downsample_root + '/saturation_analysis.pdf'

downsample_saturation_script = repo_dir + '/saturation_analysis.Rmd'

rule downsample_bam:
    input:
        dropseq_final_bam
    output:
        downsampled_bam
    params:
        downsample_dir = downsampled_sample_root
    threads: 4
    shell:
        """
        mkdir -p {params.downsample_dir}

        sambamba view -o {output} -f bam -t {threads} -s 0.{wildcards.ratio} {input}
        """

rule downsample_bam_tag_histogram:
    input:
        downsampled_bam
    output:
        downsampled_readcounts
    shell:
        """
        {dropseq_tools}/BamTagHistogram \
        I= {input} \
        O= {output}\
        TAG=XC
        """

rule create_downsampled_top_barcodes_file:
    input:
        downsampled_readcounts
    output:
        downsampled_top_barcodes
    shell:
        "zcat {input} | cut -f2 | head -100000 > {output}"
        
rule create_downsample_dge:
    input:
        reads=downsampled_bam,
        top_barcodes=downsampled_top_barcodes
    output:
        downsample_dge=downsample_dge_out,
        downsample_dge_summary=downsample_dge_out_summary
    params:
        downsample_dge_root = downsample_dge_root,
        downsample_dge_extra_params = lambda wildcards: get_dge_extra_params(wildcards)     
    shell:
        """
        mkdir -p {params.downsample_dge_root}

        {dropseq_tools}/DigitalExpression \
        I= {input.reads}\
        O= {output.downsample_dge} \
        SUMMARY= {output.downsample_dge_summary} \
        CELL_BC_FILE={input.top_barcodes} \
        {params.downsample_dge_extra_params}
        """

rule create_downsample_qc_sheet:
    input:
        star_log = star_log_file,
        reads_type_out=reads_type_out,
        parameters_file=qc_sheet_parameters_file,
        read_counts = dropseq_out_readcounts,
        dge_all_summary = downsample_dge_root + '/downsampled_dge_all_summary.txt'
    output:
        downsample_qc_sheet
    script:
        "qc_sequencing_create_sheet.py"


def get_saturation_analysis_input(wildcards):
    # first create downsampling for 10, 20 .. 90
    downsampling_ratios = range(10,100,10)

    # create dictionary with the right downsampling files where ratio is the key
    dge_summaries = {
        'downsampled_' + str(x): expand(downsample_dge_out_summary,
        project = wildcards.project,
        sample = wildcards.sample,
        dge_type = '_all',
        ratio = x)[0] for x in range(10, 100, 10)
    }
    
    dge_summaries['downsampled_100'] = expand(dge_out_summary,
        project = wildcards.project,
        sample = wildcards.sample,
        dge_type = '_all')

    return dge_summaries

rule create_saturation_analysis:
    input:
        unpack(get_saturation_analysis_input),
        parameters_file=qc_sheet_parameters_file,
        star_log = star_log_file,
        reads_type_out=reads_type_out
    output:
        downsample_saturation_analysis
    script:
        "saturation_analysis.Rmd"