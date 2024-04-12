"""
Log Consumers deployment Script

This script must accomplish the following steps: 

1 - Create stack in one ore more accounts on AWS for the creation of the resources listed under the /infra directory.
2 - Setup the secret that will be used on the lambda for posting events into Splunk HEC

3 - Add bucket notification for when there is a new object on logging bucket
"""
import sys
import joblib
import os 
import json 
import boto3
import time 
import logging  
from botocore.exceptions import ClientError 

def stack_validation(app_name, account_profile, region): 

    """Validates the status of the cloudformation actions performed on stack setup function.
    :param app_name: string from parameters.json file that specifies the organization
    :param account_profile: the target accountid/profile to be used 
    :param region: String region to create bucket in, e.g., 'us-east-1'
    :return: True if stacks were created, else False
    """

    GetStatus = os.popen('aws cloudformation describe-stacks --stack-name cloudsecops-{0}-cloudtrail-logs-to-siem --profile {1} --region {2}'.format(app_name, account_profile, region)).read()
        
    ResourceStatus = json.loads(GetStatus)

    time.sleep(45)
    print("[INFO] - Current Stack Status is: {0}".format(ResourceStatus["Stacks"][0]["StackStatus"]))
    print("[INFO] - Waiting for the stack to be completely created in {0}".format(account_profile))

    if ResourceStatus["Stacks"][0]["StackStatus"] == "CREATE_FAILED" or ResourceStatus["Stacks"][0]["StackStatus"] == "ROLLBACK_COMPLETE" or ResourceStatus["Stacks"][0]["StackStatus"] == "ROLLBACK_IN_PROGRESS" or ResourceStatus["Stacks"][0]["StackStatus"] == "IMPORT_ROLLBACK_COMPLETE" or ResourceStatus["Stacks"][0]["StackStatus"] == "IMPORT_ROLLBACK_IN_PROGRESS" or ResourceStatus["Stacks"][0]["StackStatus"] == "IMPORT_ROLLBACK_FAILED" or ResourceStatus["Stacks"][0]["StackStatus"] == "UPDATE_ROLLBACK_COMPLETE" or ResourceStatus["Stacks"][0]["StackStatus"] == "UPDATE_ROLLBACK_IN_PROGRESS" or ResourceStatus["Stacks"][0]["StackStatus"] == "UPDATE_ROLLBACK_FAILED" or ResourceStatus["Stacks"][0]["StackStatus"] == "UPDATE_FAILED" or ResourceStatus["Stacks"][0]["StackStatus"] == "IMPORT_FAILED":
        print("[ERROR] - Stack setup step failed with status {0}".format(ResourceStatus["Stacks"][0]["StackStatus"]))
        return False
    elif  ResourceStatus["Stacks"][0]["StackStatus"] == "CREATE_COMPLETE":
        print("[INFO] - Current Stack Status is: {0}".format(ResourceStatus["Stacks"][0]["StackStatus"]))
    return ResourceStatus

def stack_setup(region, account_profile, app_name, params_values):
    """Creates a CloudFormation Stack in a specified region, importing a 
    trail bucket and configuring notifications on it.

    :param region: String region to create bucket in, e.g., 'us-west-2'
    :param account_profile: the target accountid/profile to be used 
    :param app_name: string from parameters.json file that specifies the organization
    :param params_values: json parameters to be used in cloudformation
    :return: True if stacks were created, else False
    """
    try:
        #Issue de AWS CLI commands for creating a stack, importing a resource into it and updating the previous imported resource 

        print("[INFO] - Starting stack deployment in {0} this might take a while".format(account_profile))
        
        session = boto3.Session(profile_name=account_profile)
        cloudformation_client = session.client('cloudformation', region_name=region)

        StackNameCfn = 'cloudsecops-{0}-cloudtrail-logs-to-siem'.format(app_name)

        with open('infra/template-step-1.yml', 'r') as first_cfn_file:
            template = first_cfn_file.read()
            cloudformation_client.create_stack(StackName=StackNameCfn,
                                          TemplateBody=template,
                                          Parameters=[
                                            {
                                                'ParameterKey': params_values[0]['ParameterKey'],
                                                'ParameterValue': params_values[0]['ParameterValue']
                                            },
                                            {
                                                'ParameterKey': params_values[1]['ParameterKey'],
                                                'ParameterValue': params_values[1]['ParameterValue']
                                            },
                                            {
                                                'ParameterKey': params_values[2]['ParameterKey'],
                                                'ParameterValue': params_values[2]['ParameterValue']
                                            },
                                            {
                                                'ParameterKey': params_values[3]['ParameterKey'],
                                                'ParameterValue': params_values[3]['ParameterValue']
                                            },
                                            {
                                                'ParameterKey': params_values[4]['ParameterKey'],
                                                'ParameterValue': params_values[4]['ParameterValue']
                                            },
                                            {
                                                'ParameterKey': params_values[5]['ParameterKey'],
                                                'ParameterValue': params_values[5]['ParameterValue']
                                            },
                                            {
                                                'ParameterKey': params_values[6]['ParameterKey'],
                                                'ParameterValue': params_values[6]['ParameterValue']
                                            },
                                            {
                                                'ParameterKey': params_values[7]['ParameterKey'],
                                                'ParameterValue': params_values[7]['ParameterValue']
                                            },
                                            {
                                                'ParameterKey': params_values[8]['ParameterKey'],
                                                'ParameterValue': params_values[8]['ParameterValue']
                                            },
                                            ],
                                          DisableRollback=False,
                                          Tags=[
                                            {
                                                "Key": "AppName",
                                                "Value": "{0}--cloudtrail-logs-to-siem".format(app_name)
                                            },
                                            {
                                                "Key": "team-contact-email",
                                                "Value": "CLOUD_Publica_Seguranca_Ops@correio.itau.com.br"
                                            }
                                          ])

        stackStatus = stack_validation(app_name, account_profile, region)
        time.sleep(3)

        while stackStatus["Stacks"][0]["StackStatus"] != "CREATE_COMPLETE": 
            stackStatus = stack_validation(app_name, account_profile, region)
            if stackStatus["Stacks"][0]["StackStatus"] == "CREATE_COMPLETE": 
                print("[INFO] - Stack completely created in {0}".format(account_profile))
            elif stackStatus == False: 
                print("[ERROR] - Stack could not be created")
        
        print("[INFO] - Stack successfuly deployed in {0} ".format(account_profile))
    
    except ClientError as e:
        logging.error(e)
        return False 
    return True  
    
def put_secret_value(region, account_profile, app_name):
    """Updates the secret value from the secret previously created in the stack 

    :param region: String region to create bucket in, e.g., 'us-west-2'
    :param account_profile: the target accountid/profile to be used 
    :param app_name: string from parameters.json file that specifies the organization
    :return: True if secrete was configured, else False
    """
    # Create bucket
    try:
        print("[INFO] - Configuring secret in {0}".format(account_profile))
        session = boto3.Session(profile_name=account_profile)
        secret_client = session.client('secretsmanager', region_name=region)
        secret = os.environ.get('SPLUNK_TOKEN_SECRET')
        secret_client.update_secret(
                                    SecretId='{0}-cloudtrail-logs-lambda-secret'.format(app_name),
                                    SecretString=secret
                                    )
        print(print("[SUCCESS] - Secret configured in {0}".format(account_profile)))
    except ClientError as e:
        logging.error(e)
        return False
    return True

def put_bucket_notification(region, account_profile):
    
    try:
        session = boto3.Session(profile_name=account_profile)
        s3_client = session.client('s3', region_name=region)
        response = s3_client.put_bucket_notification()
    except ClientError as e:
        logging.error(e)
        return False 
    return True 

def deploy(): 
    with open('{0}'.format(sys.argv[1]), 'r') as profile_list:
        for profile in profile_list:
            profile_name = profile.strip() 

            params_file = open('infra/{0}.json'.format(profile_name), 'r') 
            params_values = json.load(params_file) 
            app_name = params_values[8]['ParameterValue']
            region = sys.argv[2]

            print("[INFO] - Starting Deployment")

            if region == "sa-east-1" or region == "us-east-1":
                if app_name == "stackspot" or app_name == "controltower" or app_name == "landing-zone":
                    stack_deploy = stack_setup(region, profile_name, app_name, params_values)
                    if stack_deploy == True: 
                        secret_config = put_secret_value(region, profile_name, app_name)
                        if secret_config == True:
                            print('[SUCCESS] - Splunk Secret configured {0}'.format(profile_name))
                        else: 
                            print('[ERROR] - Could not configurate splunk secret in {0}'.format(profile_name))
                    else: 
                        print('[ERROR] - Could not setup stack in {0}'.format(profile_name))
                else:
                    print('{0} is not a valid organization'.format(app_name)) 
            else:
                print("{0} is not a valid region".format(region))

print(joblib.Parallel(n_jobs=2)(joblib.delayed(deploy())))
