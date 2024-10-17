import boto3
import configparser
import datetime
import pandas as pd
import smtplib
import os
import logging
from dotenv import load_dotenv
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email.mime.text import MIMEText
from email import encoders
from botocore.exceptions import NoCredentialsError, PartialCredentialsError, BotoCoreError

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def get_profiles():
    all_profiles = {}
    config = configparser.ConfigParser()
    config.read(os.path.expanduser('~/.aws/config'))  # Use a relative path

    for profile in config.sections():
        profile_region = config.get(profile, 'region', fallback=config.get('default', 'region'))
        all_profiles[profile] = profile_region

    return all_profiles

def get_instance_metrics(profile, region, instance_id):
    session = boto3.Session(profile_name=profile, region_name=region)
    cloudwatch_client = session.client('cloudwatch')

    end_time = datetime.datetime.utcnow()
    start_time = end_time - datetime.timedelta(minutes=10)  # Last 10 minutes
    period = 60  # Data every minute

    # Get CPU Utilization
    cpu_utilization = get_metric_statistics(cloudwatch_client, instance_id, 'CPUUtilization', 'AWS/EC2', period, start_time, end_time)

    # Get Memory Utilization (Requires CloudWatch Agent)
    memory_utilization = get_metric_statistics(cloudwatch_client, instance_id, 'mem_used_percent', 'CWAgent', period, start_time, end_time)

    # Get Number of Threads (Requires CloudWatch Agent)
    threads_running = get_metric_statistics(cloudwatch_client, instance_id, 'procstat_threads', 'CWAgent', period, start_time, end_time)

    # Get Number of Processes (Requires CloudWatch Agent)
    processes_running = get_metric_statistics(cloudwatch_client, instance_id, 'procstat_processes', 'CWAgent', period, start_time, end_time)

    return {
        'CPU Utilization': cpu_utilization,
        'Memory Utilization': memory_utilization,
        'Threads Running': threads_running,
        'Processes Running': processes_running,
    }

def get_metric_statistics(cloudwatch_client, instance_id, metric_name, namespace, period, start_time, end_time):
    try:
        response = cloudwatch_client.get_metric_statistics(
            Namespace=namespace,
            MetricName=metric_name,
            Dimensions=[
                {
                    'Name': 'InstanceId',
                    'Value': instance_id
                },
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=period,
            Statistics=['Average']
        )
        
        if 'Datapoints' in response and response['Datapoints']:
            return response['Datapoints'][0].get('Average', 'N/A')
        else:
            return 'N/A'
    except (NoCredentialsError, PartialCredentialsError) as e:
        logging.error(f"Credential error for instance {instance_id}: {e}")
        return 'N/A'
    except BotoCoreError as e:
        logging.error(f"Error accessing AWS for instance {instance_id}: {e}")
        return 'N/A'

def print_metrics(instance_id, metrics):
    logging.info(f"Metrics for Instance ID: {instance_id}")
    logging.info(f"CPU Utilization: {metrics['CPU Utilization']}")
    logging.info(f"Memory Utilization: {metrics['Memory Utilization']}")
    logging.info(f"Threads Running: {metrics['Threads Running']}")
    logging.info(f"Processes Running: {metrics['Processes Running']}\n")

def get_all_instances(profile, region):
    session = boto3.Session(profile_name=profile, region_name=region)
    ec2_client = session.client('ec2')
    try:
        # Retrieve information about EC2 instances
        response = ec2_client.describe_instances()
        instances = []
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                instances.append(instance['InstanceId'])
        return instances
    except (NoCredentialsError, PartialCredentialsError) as e:
        logging.error(f"Credential error for profile {profile}: {e}")
        return []
    except BotoCoreError as e:
        logging.error(f"Error accessing AWS for profile {profile}: {e}")
        return []

def export_to_excel(data, filename='ec2_metrics_report.xlsx'):
    # Create a DataFrame from the data
    df = pd.DataFrame(data)
    
    # Save the DataFrame to an Excel file
    df.to_excel(filename, index=False)
    logging.info(f"Data exported to {filename}")
    return filename

def send_email(subject, body, to_email, attachment_file):
    # Email configuration
    load_dotenv()
    
    from_email = os.getenv('EMAIL_SOURCE')  # Set in your environment
    from_password = os.getenv('EMAIL_PASSWORD')  # Set in your environment
    smtp_server = 'smtp.gmail.com'
    smtp_port = 587

    logging.info(f"Sending email from: {from_email} to: {to_email}")

    # Create the email
    msg = MIMEMultipart()
    msg['From'] = from_email
    msg['To'] = to_email
    msg['Subject'] = subject

    # Attach the email body
    msg.attach(MIMEText(body, 'plain'))

    # Attach the Excel file
    with open(attachment_file, 'rb') as attachment:
        part = MIMEBase('application', 'octet-stream')
        part.set_payload(attachment.read())
        encoders.encode_base64(part)
        part.add_header('Content-Disposition', f'attachment; filename={os.path.basename(attachment_file)}')
        msg.attach(part)

    # Send the email
    with smtplib.SMTP(smtp_server, smtp_port) as server:
        server.starttls()  # Upgrade the connection to a secure encrypted SSL/TLS connection
        server.login(from_email, from_password)
        server.send_message(msg)
    
    logging.info(f"Email sent to {to_email} with attachment: {attachment_file}")

if __name__ == "__main__":
    all_profiles = get_profiles()
    metrics_report = []

    for profile, region in all_profiles.items():
        logging.info(f"Checking metrics for profile: {profile} in region: {region}")
        instance_ids = get_all_instances(profile, region)
        
        for instance_id in instance_ids:
            metrics = get_instance_metrics(profile, region, instance_id)
            print_metrics(instance_id, metrics)

            # Append the metrics to the report
            metrics_report.append({
                'Profile': profile,
                'Region': region,
                'Instance ID': instance_id,
                'CPU Utilization': metrics['CPU Utilization'],
                'Memory Utilization': metrics['Memory Utilization'],
                'Threads Running': metrics['Threads Running'],
                'Processes Running': metrics['Processes Running'],
            })

    # Export the metrics report to Excel
    report_file = export_to_excel(metrics_report)

    # Send the report via email
    email_body = "Please find attached the EC2 metrics report."
    recipient_email = os.getenv('EMAIL_RECIPIENT')  # Recipient email should also be an environment variable
    send_email("EC2 Metrics Report", email_body, recipient_email, report_file)
