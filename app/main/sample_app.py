import sys
import argparse
import logging
from pyspark.sql import DataFrame, SparkSession, functions
import os


class SampleApp(object):
    def __init__(self, top: int) -> None:
        self.top_results = top
        self.spark_session = SparkSession.builder.appName('SampleAppOnK8s').getOrCreate()

    def _read(self) -> DataFrame:
        return self.spark_session\
            .read\
            .option('header', 'true')\
            .option('inferSchema', 'true')\
            .csv(f'file://{os.path.abspath("../resources/data/input.csv")}')

    def _transform(self, df: DataFrame) -> DataFrame:
        return df.groupBy(functions.col('age')).agg(functions.avg(functions.col('age')))

    def _write(self, df: DataFrame) -> None:
        df.write.text(os.path.abspath('../resources/output'))

    def main(self) -> None:
        try:
            logging.info('Starting sample app')
            input_df = self.read()
            logging.info(f'Obtained input df with {input_df.rdd.getNumPartitions()} partitions')
            transformed_df = self._transform(input_df)
            logging.info('Dataframe transformed')
            self._write(transformed_df)
            logging.info('Dataframe stored')
            logging.info('SampleApp completed successfully')
        except Exception as ex:
            logging.fatal(f'An exception occurred {ex}')
            logging.info('SampleApp completed with errors')
        finally:
            self.spark_session.stop()
            logging.info('Spark session ended')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Pyspark on k8s sample application')
    parser.add_argument('--top', help='Top results to display', type=int)
    args = parser.parse_args(sys.argv[1:])

    SampleApp(args.top).main()
