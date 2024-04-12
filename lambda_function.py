import http.client as http_client
import logging
from gzip import GzipFile
from io import BytesIO
from json import dumps, load, loads
from os import environ
from traceback import format_exc as print_traceback
from urllib.parse import unquote_plus
from boto3 import client as client_boto3
from requests import packages, post
from urllib3 import disable_warnings

# Local logging setup
log = logging.getLogger(__name__)
log.setLevel(logging.INFO)
disable_warnings(packages.urllib3.exceptions.InsecureRequestWarning)

def send_data_to_splunk(payload: str,
                            splunk_token: str,
                            splunk_url: str) -> dict:
        """Send the data to the Splunk cluster.

        Parameters
        ----------
        payload : str
            A string with a JSON object that will be sent.
        splunk_token : str
            The token used to authenticate the communication.
        splunk_url : str
            The URL with the destination of the package.

        Returns
        -------
        None
        """
        header = {'Authorization': 'Splunk ' + splunk_token}
        try:
            return post(splunk_url,
                        headers=header,
                        json=payload,
                        verify=0,
                        timeout=90).json()
        except Exception:
            logging.error(f'Error: {print_traceback()}')
            return {"statusCode": 400}

def lambda_handler(event, context):
    """Execute the main code.

    Parameters
    ----------
    event : string
        Contains a JSON with the message and the metadata.
    context : string
        Contains a JSON with the context of the execution.

    Returns
    -------
    dict
        A JSON with a friendly message.
    """
    
    # The Splunk URL
    splunk_url = environ['SPLUNK_HEC_URL']
    # The AWS SecretsManager Client object
    secrets_client = client_boto3('secretsmanager')
    # The Splunk Token
    splunk_token = secrets_client.get_secret_value(
        SecretId=environ['SPLUNK_HEC_TOKEN'])['SecretString']

    # The AWS S3 Client object
    s3_client = client_boto3('s3')
    # Get the objects in the bucket
    for record in event['Records']:
        bucket = loads(record['body'])['Records'][0]['s3']['bucket']['name']
        key = unquote_plus(loads(record['body'])['Records'][0]['s3']['object']['key'])
        # Download the  from the S3
        response = s3_client.get_object(Bucket=bucket, Key=key)
        # Read the object
        content = response['Body'].read()
        # GUnzip the downloaded object
        with GzipFile(fileobj=BytesIO(content), mode='rb') as fh:
            # Try to load the JSON content and group the events to reduce network requests
            try:
                result = []
                for line in fh:
                    # Here we change the encoding for keeping special characters 
                    line = loads(line)
                    line = loads(dumps(line).encode('latin1').decode('unicode_escape'))
                    result.append({"index": "aws_others",
                                "sourcetype": "datamesh:aws_account",
                                "event": line})
                postrep = send_data_to_splunk(result, splunk_token, splunk_url)
            except Exception:
                log.error(f"Failed while reading: File={key}")
                log.error(print_traceback())
                return {"statusCode": 500}
        log.info(postrep)
    # Return success to the Lambda execution
    return {"statusCode": 200}
