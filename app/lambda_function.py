import http.client as http_client
import logging
from gzip import GzipFile
from io import BytesIO
from json import dumps, loads
from os import environ
from traceback import format_exc as print_traceback
from urllib.parse import unquote_plus
from boto3 import client as client_boto3
from requests import packages, post
from urllib3 import disable_warnings
import threading
import queue

# Local logging setup
log = logging.getLogger(__name__)
log.setLevel(logging.INFO)
disable_warnings(packages.urllib3.exceptions.InsecureRequestWarning)

def send_data_to_splunk(payload: str, splunk_token: str, splunk_url: str) -> dict:
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
    dict
    """
    header = {'Authorization': 'Splunk ' + splunk_token}
    try:
        return post(splunk_url, headers=header, json=payload, verify=0, timeout=90).json()
    except Exception:
        logging.error(f'Error: {print_traceback()}')
        return {"statusCode": 400}

def fetch_and_decompress(s3_client, bucket: str, key: str, data_queue: queue.Queue):
    """Fetch and decompress files from S3.

    Parameters
    ----------
    s3_client : boto3.client
        The S3 client object.
    bucket : str
        The name of the S3 bucket.
    key : str
        The key of the S3 object.
    data_queue : queue.Queue
        A thread-safe queue to hold decompressed data.
    """
    response = s3_client.get_object(Bucket=bucket, Key=key)
    content = response['Body'].read()
    events = []
    with GzipFile(fileobj=BytesIO(content), mode='rb') as fh:
        for line in fh:
            line = loads(line)
            line = loads(dumps(line).encode('latin1').decode('unicode_escape'))
            events.append({"index": "aws_others", "sourcetype": "datamesh:aws_account", "event": line})
        data_queue.put(events)
    data_queue.put(None)  # Signal the end of data

def send_to_splunk_thread(splunk_token, splunk_url, data_queue):
    """Threaded function to send data to Splunk. 

    Parameters
    ----------
    splunk_token : str
        The token used to authenticate the communication.
    splunk_url : str
        The URL with the destination of the package.
    data_queue : queue.Queue
        A thread-safe queue containing the data to be sent.
    """
    chunk = []
    # Refactor this -> enum the data queue and while its filled activate it
    while True: # data_queue.empty() == False:
        event = data_queue.get()
        if event is None:
            if chunk:
                postrep = send_data_to_splunk(chunk, splunk_token, splunk_url)
                log.info(postrep)
            break
        chunk.append(event)
        if len(chunk) >= 100:  # Adjust chunk size as needed
            postrep = send_data_to_splunk(chunk, splunk_token, splunk_url)
            log.info(postrep)
            chunk = []

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
    splunk_token = secrets_client.get_secret_value(SecretId=environ['SPLUNK_HEC_TOKEN'])['SecretString']

    # The AWS S3 Client object
    s3_client = client_boto3('s3')
    # Create a thread-safe queue for passing data
    data_queue = queue.Queue()

    for record in event['Records']:
        bucket = loads(record['body'])['Records'][0]['s3']['bucket']['name']
        key = unquote_plus(loads(record['body'])['Records'][0]['s3']['object']['key'])

        try:
            # Start the fetch and decompress thread
            fetch_thread = threading.Thread(target=fetch_and_decompress, args=(s3_client, bucket, key, data_queue))
            fetch_thread.start()

            # Start the send to Splunk thread
            send_thread = threading.Thread(target=send_to_splunk_thread, args=(splunk_token, splunk_url, data_queue))
            send_thread.start()

            # Wait for both threads to complete
            fetch_thread.join()
            send_thread.join()

        except Exception:
            log.error(f"Failed while processing: File={key}")
            log.error(print_traceback())
            return {"statusCode": 500}

    # Return success to the Lambda execution
    return {"statusCode": 200}
