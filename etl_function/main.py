import os
import logging

import boto3

from utils import main

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def send_success_message(inserts, updates):
    client = boto3.client("sns")
    response = client.publish(
        TopicArn=os.environ["SUCCESS_SNS_TOPIC_ARN"],
        Message=f"There were {inserts} inserts and {updates} updates",
        Subject="ETL Lambda Succeeded",
    )
    logger.info(f"send_success_message::{response}")


def lambda_handler(event, context):
    inserts, updates = main()
    send_success_message(inserts, updates)
