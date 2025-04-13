#!/usr/bin/env python3
"""
Parallel chromosome-wise variant annotation script.

Converts '#CHROM POS ID allele1 allele2' to '#CHROM POS ID REF ALT' using reference genome.
The script processes chromosomes in parallel, validates input/output files, and provides
detailed logging capabilities.

Example:
    $ python variant_annotator.py -i input.tsv -o output.vcf -d refs/
    $ python variant_annotator.py -i data.tsv -o results.vcf -d refs/ -p 8 --log-file run.log
"""

import argparse
import sys
import os
import time
import logging
import logging.handlers
from multiprocessing import Pool, cpu_count
from typing import List
import pandas as pd
import pysam
import re


def setup_logging(log_file: str = "./logs/annotation.log") -> logging.Logger:
    """Configure logging to both console and file with rotation.

    Args:
        log_file: Path to log file. If None, only console logging is enabled.

    Returns:
        Configured root logger instance.

    Example:
        >>> logger = setup_logging("annotation.log")
        >>> logger.info("Logging configured")
    """
    log_formatter = logging.Formatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)  # Set root to lowest level

    # Console handler (always present)
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(log_formatter)
    console_handler.setLevel(logging.INFO)  # Default console level
    logger.addHandler(console_handler)

    # File handler (if log file specified)
    if log_file:
        # Create directory if needed
        log_dir = os.path.dirname(os.path.abspath(log_file))
        os.makedirs(log_dir, exist_ok=True)

        # Rotating file handler (5MB per file, keep 3 backups)
        file_handler = logging.handlers.RotatingFileHandler(
            filename=log_file,
            maxBytes=5 * 1024 * 1024,  # 5MB
            backupCount=3,
            encoding="utf-8",
        )
        file_handler.setFormatter(log_formatter)
        file_handler.setLevel(logging.DEBUG)  # File gets all levels
        logger.addHandler(file_handler)

    return logger


def parse_args():
    """Parse and validate command line arguments.

    Returns:
        Namespace containing validated arguments.

    Raises:
        argparse.ArgumentTypeError: If invalid arguments are provided.
        FileNotFoundError: If input files/directories don't exist.
        PermissionError: If file permissions are insufficient.

    Example:
        >>> args = parse_args()
        >>> print(args.input)
    """
    parser = argparse.ArgumentParser(
        description="Parallel variant annotation using chromosome-split reference",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        epilog="Example:\n"
        "  %(prog)s -i input.tsv -o annotated.vcf -d /path/to/references/\n"
        "  %(prog)s -i data.tsv -o results.vcf -d refs/ -p 8 --log-level DEBUG",
    )

    # Required arguments
    required = parser.add_argument_group("required arguments")
    required.add_argument(
        "-i",
        "--input",
        required=True,
        type=str,
        help="Input TSV file (columns: #CHROM POS ID allele1 allele2)",
    )
    required.add_argument(
        "-o",
        "--output",
        required=True,
        type=str,
        help="Output TSV file (columns: #CHROM POS ID REF ALT)",
    )
    required.add_argument(
        "-d",
        "--ref-dir",
        required=True,
        type=str,
        help="Directory with reference chromosomes (chr1.fa, chr2.fa, etc.)",
    )

    # Optional arguments
    parser.add_argument(
        "-p",
        "--processes",
        type=int,
        default=cpu_count(),
        help="Number of parallel processes",
    )
    parser.add_argument(
        "--skip-header-check",
        action="store_true",
        help="Skip input file header validation",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        help="Set the logging level",
    )
    parser.add_argument(
        "--log-file",
        type=str,
        default="./logs/annotation.log",
        help="Path to log file (default: ./logs/annotation.log)",
    )
    parser.add_argument(
        "--log-file-level",
        default="DEBUG",
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        help="Log level for file output",
    )
    parser.add_argument(
        "--max-variants-per-chrom",
        type=int,
        default=None,
        help="Limit variants per chromosome (for testing)",
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Only validate input without processing",
    )

    # Parse and post-process arguments
    args = parser.parse_args()

    # Process number validation and limitation
    max_allowed_processes = cpu_count() * 2
    if args.processes < 1:
        raise argparse.ArgumentTypeError(
            f"Process count must be ≥1 (got {args.processes})"
        )
    if args.processes > max_allowed_processes:
        print(
            f"Warning: Reducing processes from {args.processes} to system limit {max_allowed_processes}",
            file=sys.stderr,
        )
        args.processes = max_allowed_processes

    # Path normalization
    args.input = os.path.abspath(args.input)
    args.output = os.path.abspath(args.output)
    args.ref_dir = os.path.abspath(args.ref_dir)

    # Early validation if requested
    if args.validate_only:
        validate_file_paths(args)
        try:
            with open(args.input, "r") as f:
                if not args.skip_header_check:
                    validate_header(f.readline())
            print("Validation successful - input appears valid", file=sys.stderr)
            sys.exit(0)
        except Exception as e:
            print(f"Validation failed: {str(e)}", file=sys.stderr)
            sys.exit(1)

    return args


def validate_file_paths(args):
    """Validate all file paths and permissions.

    Args:
        args: Parsed command line arguments.

    Raises:
        FileNotFoundError: If any path doesn't exist.
        PermissionError: If required permissions are missing.

    Example:
        >>> validate_file_paths(args)
    """
    # Input file checks
    if not os.path.exists(args.input):
        raise FileNotFoundError(f"Input file not found: {args.input}")
    if not os.access(args.input, os.R_OK):
        raise PermissionError(f"No read permission for input file: {args.input}")

    # Output file checks
    output_dir = os.path.dirname(os.path.abspath(args.output)) or "."
    if not os.path.exists(output_dir):
        raise FileNotFoundError(f"Output directory not found: {output_dir}")
    if os.path.exists(args.output) and not os.access(args.output, os.W_OK):
        raise PermissionError(f"No write permission for output file: {args.output}")
    if not os.access(output_dir, os.W_OK):
        raise PermissionError(f"No write permission for output directory: {output_dir}")

    # Reference directory checks
    if not os.path.exists(args.ref_dir):
        raise FileNotFoundError(f"Reference directory not found: {args.ref_dir}")
    if not os.access(args.ref_dir, os.R_OK):
        raise PermissionError(
            f"No read permission for reference directory: {args.ref_dir}"
        )


class VariantAnnotationError(Exception):
    """Base exception for annotation errors"""

    pass


class HeaderValidationError(VariantAnnotationError):
    """Raised when input file header validation fails.

    Attributes:
        line: The problematic header line (if available).
    """

    def __init__(self, message, line=None):
        super().__init__(message)
        self.line = line


class ChromosomeProcessingError(VariantAnnotationError):
    """Raised when processing of a specific chromosome fails.

    Attributes:
        chrom: The chromosome that failed processing.
    """

    def __init__(self, chrom, message):
        super().__init__(f"Chromosome {chrom}: {message}")
        self.chrom = chrom


def validate_header(header):
    """Validate input file header format.

    Args:
        header: First line of input file to validate.

    Raises:
        HeaderValidationError: If header format is invalid.

    Example:
        >>> validate_header("#CHROM\tPOS\tID\tallele1\tallele2")
    """
    expected = ["#CHROM", "POS", "ID", "allele1", "allele2"]

    try:
        actual = header.strip().split("\t")
        if len(actual) != len(expected):
            raise HeaderValidationError(
                f"Header has {len(actual)} columns, expected {len(expected)}",
                line=header,
            )

        mismatches = [
            (i + 1, exp, act)
            for i, (exp, act) in enumerate(zip(expected, actual))
            if exp != act
        ]

        if mismatches:
            errors = "\n".join(
                f"Column {col}: expected '{exp}', got '{act}'"
                for col, exp, act in mismatches
            )
            raise HeaderValidationError(
                f"Header column mismatches:\n{errors}", line=header
            )

    except Exception as e:
        if not isinstance(e, HeaderValidationError):
            raise HeaderValidationError(
                f"Header validation failed: {str(e)}", line=header
            )
        raise


def get_chromosomes(input_file) -> List[str]:
    """Extract and sort chromosomes from input file.

    Args:
        input_file: Path to input TSV file.

    Returns:
        List of chromosome names sorted naturally (chr1, chr2, ..., chr10).

    Raises:
        ValueError: If input file cannot be read or parsed.

    Example:
        >>> chromosomes = get_chromosomes("variants.tsv")
        >>> print(chromosomes)
        ['chr1', 'chr2', ..., 'chrX']
    """
    try:
        # Detect line endings first
        with open(input_file, "rb") as f:
            content = f.read()
            line_ending = b"\r\n" if b"\r\n" in content else b"\n"
            logging.debug(f"Detected line endings: {repr(line_ending)}")
        # Read with explicit line ending handling
        df = pd.read_csv(input_file, sep="\t", engine="c")
        chromosomes: List[str] = df["#CHROM"].unique().tolist()

        # Natural sorting for chromosomes (chr1, chr2, ..., chr10, etc.)
        chromosomes.sort(
            key=lambda x: [
                int(c) if c.isdigit() else c for c in re.split("([0-9]+)", x)
            ]
        )
        return chromosomes

    except Exception as e:
        raise ValueError(f"Error reading input file: {str(e)}")


def process_chromosome(args):
    """Process variants for a single chromosome.

    Args:
        args: Tuple containing (chromosome, input_file, ref_dir, skip_header_check)

    Returns:
        Dictionary containing:
        - chrom: Chromosome name
        - results: DataFrame of processed variants (if successful)
        - processed: Number of successfully processed variants
        - skipped: Number of skipped variants
        - error: Error message (if processing failed)

    Raises:
        ChromosomeProcessingError: If chromosome processing fails.

    Example:
        >>> result = process_chromosome(("chr1", "input.tsv", "refs/", False))
        >>> print(result["processed"])
    """
    chrom, input_file, ref_dir, skip_header_check = args
    start_time = time.time()
    logger = logging.getLogger(f"{chrom}")
    last_report_time = start_time

    try:
        logger.info(f"Started processing chromosome {chrom}")

        # Load reference for this chromosome
        ref_path = os.path.join(
            ref_dir, f"chr{chrom}.fa" if not chrom.startswith("chr") else f"{chrom}.fa"
        )
        if not os.path.exists(ref_path):
            raise FileNotFoundError(f"Reference file not found: {ref_path}")
        if not os.path.exists(ref_path + ".fai"):
            raise FileNotFoundError(f"Index not found for {ref_path}")

        ref = pysam.FastaFile(ref_path)
        ref_name = ref.references[0]

        # Read variants for this chromosome
        variants = pd.read_csv(input_file, sep="\t")
        chrom_variants = variants[variants["#CHROM"] == chrom]

        if chrom_variants.empty:
            logger.warning(f"No variants found for {chrom}")
            ref.close()
            return {"chrom": chrom, "processed": 0, "skipped": 0}

        results = []
        skipped = 0

        for idx, (_, row) in enumerate(chrom_variants.iterrows(), 1):
            current_time = time.time()
            if current_time - last_report_time > 30:  # Report every 30 seconds
                progress = idx / len(chrom_variants) * 100
                logger.info(
                    f"Processing {chrom}: {idx}/{len(chrom_variants)} "
                    f"variants ({progress:.1f}%)"
                )
                last_report_time = current_time
            pos = row["POS"]
            ref_pos = pos - 1  # 0-based

            try:
                # Get reference base
                try:
                    ref_base = ref.fetch(ref_name, ref_pos, ref_pos + 1).upper()
                except Exception as e:
                    logger.warning(f"Could not fetch base for {chrom}:{pos} - {str(e)}")
                    skipped += 1
                    continue

                # Determine REF and ALT
                allele1 = str(row["allele1"]).upper()
                allele2 = str(row["allele2"]).upper()

                # Function to get reverse complement
                def reverse_complement(base):
                    complement = {'A': 'T', 'T': 'A', 'C': 'G', 'G': 'C', 'N': 'N'}
                    return ''.join([complement.get(b, b) for b in base[::-1]])

                # Check both original and reverse complement
                if allele1 == ref_base:
                    ref_allele = allele1
                    alt_allele = allele2
                elif allele2 == ref_base:
                    ref_allele = allele2
                    alt_allele = allele1
                elif reverse_complement(allele1) == ref_base:
                    ref_allele = reverse_complement(allele1)
                    alt_allele = reverse_complement(allele2)
                elif reverse_complement(allele2) == ref_base:
                    ref_allele = reverse_complement(allele2)
                    alt_allele = reverse_complement(allele1)
                else:
                    logger.warning(f"Neither allele matches reference (including reverse complement) at {chrom}:{pos}")
                    skipped += 1
                    continue

                results.append(
                    {
                        "#CHROM": row["#CHROM"],
                        "POS": pos,
                        "ID": row["ID"],
                        "REF": ref_allele,
                        "ALT": alt_allele,
                    }
                )

            except Exception as e:
                logger.warning(f"Error processing {chrom}:{pos} - {str(e)}")
                skipped += 1
                continue

        ref.close()

        elapsed = time.time() - start_time
        logger.info(
            f"Finished processing {chrom} in {elapsed:.2f}s - Processed: {len(results)}, Skipped: {skipped}"
        )

        return {
            "chrom": chrom,
            "results": pd.DataFrame(results),
            "processed": len(results),
            "skipped": skipped,
        }

    except Exception as e:
        logger.error(f"Failed at variant {idx} of {len(chrom_variants)}")
        raise ChromosomeProcessingError(chrom, str(e))


def main():
    """Main entry point for variant annotation script."""
    args = parse_args()

    # Configure logging with file output if specified
    setup_logging(args.log_file)
    logger = logging.getLogger("main")

    for handler in logging.getLogger().handlers:
        if isinstance(handler, logging.StreamHandler):
            handler.setLevel(args.log_level)

    try:
        logger.info(
            f"Starting variant annotation (logging to {args.log_file or 'console'})"
        )

        validate_file_paths(args)  # New validation

        start_time = time.time()
        logger.info("Starting parallel variant annotation")

        # Validate input file
        if not os.path.exists(args.input):
            logger.error(f"Input file not found: {args.input}")
            sys.exit(1)

        # Validate reference directory
        if not os.path.isdir(args.ref_dir):
            logger.error(f"Reference directory not found: {args.ref_dir}")
            sys.exit(1)

        # Check header if not skipped
        if not args.skip_header_check:
            try:
                with open(args.input, "r") as f:
                    first_line = f.readline()
                    validate_header(first_line)
                logger.info("Header validation passed")
            except ValueError as e:
                logger.error(f"Invalid file header: {str(e)}")
                sys.exit(1)

        # Get chromosomes to process
        try:
            chromosomes = get_chromosomes(args.input)
            if not chromosomes:
                logger.error("No chromosomes found in input file")
                sys.exit(1)
            logger.info(f"Found {len(chromosomes)} chromosomes to process")
        except Exception as e:
            logger.error(f"Failed to get chromosomes: {str(e)}")
            sys.exit(1)

        # Prepare tasks for parallel processing
        tasks = [
            (chrom, args.input, args.ref_dir, args.skip_header_check)
            for chrom in chromosomes
        ]

        # Process in parallel
        logger.info(f"Starting {args.processes} parallel processes")
        processed = 0
        skipped = 0
        all_results = []

        with Pool(processes=args.processes) as pool:
            for result in pool.imap(process_chromosome, tasks):
                # Collect results
                if "results" in result:
                    all_results.append(result["results"])
                    processed += result["processed"]
                    skipped += result["skipped"]
                elif "error" in result:
                    logger.error(
                        f"Failed to process {result['chrom']}: {result['error']}"
                    )

        # Combine and save results with natural chromosome sorting
        if all_results:
            try:
                final_df = pd.concat(all_results, ignore_index=True)
                # Sort by chromosome (natural order) and then by position

                final_df.to_csv(args.output, sep="\t", index=False)
                logger.info(f"Saved sorted results to {args.output}")
            except Exception as e:
                logger.error(f"Failed to save results: {str(e)}")
                sys.exit(1)
        else:
            logger.error("No variants were processed successfully")
            sys.exit(1)

        # Print summary
        total_time = time.time() - start_time
        logger.info("Processing complete")
        logger.info(f"  Total variants processed: {processed}")
        logger.info(f"  Total variants skipped: {skipped}")
        logger.info(f"  Time elapsed: {total_time:.2f} seconds")

    except VariantAnnotationError as e:
        logger.error(str(e))
        if hasattr(e, "line"):
            logger.debug(f"Problematic line: {e.line}")
        sys.exit(1)
    except Exception as e:
        logger.critical(f"Unexpected error: {str(e)}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    import re  # Required for natural sorting

    main()
