# We need to import the AWS SDK (boto3) and other standard libraries
import boto3
import json
import os
import uuid
from datetime import datetime

# Get the service clients
ses = boto3.client('ses')
dynamodb = boto3.resource('dynamodb')

# Get the names of our resources from Environment Variables
# We will set these variables in our Terraform code
TABLE_NAME = os.environ['TABLE_NAME']
VERIFIED_EMAIL = os.environ['VERIFIED_EMAIL']

def handler(event, context):
    """
    This is the main function that Lambda runs.
    'event' contains all the data from the API Gateway.
    'context' contains runtime information.
    """

    print(f"Received event: {json.dumps(event)}")

    try:
        # 1. Parse the incoming data
        # The 'body' from API Gateway is a JSON string, so we parse it
        body = json.loads(event['body'])
        
        # Extract the fields from the form
        name = body['name']
        email = body['email']
        message = body['message']
        
        # Simple validation
        if not name or not email or not message:
            raise ValueError("Missing required fields (name, email, or message)")

        # 2. Generate a unique ID and timestamp
        item_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()

        # 3. Save the message to DynamoDB
        table = dynamodb.Table(TABLE_NAME)
        table.put_item(
            Item={
                'id': item_id,
                'name': name,
                'email': email,
                'message': message,
                'createdAt': timestamp
            }
        )
        print(f"Successfully saved item {item_id} to DynamoDB.")

        # 4. Format the email to send
        email_subject = f"New Contact Form Submission from {name}"
        email_body = f"""
        You received a new message from your website contact form:
        ------------------------------------------------------------
        Name:    {name}
        Email:   {email}
        Message:
        {message}
        ------------------------------------------------------------
        """
        
        # 5. Send the email using SES
        ses.send_email(
            Source=VERIFIED_EMAIL,  # The "From" address (must be verified)
            Destination={
                'ToAddresses': [VERIFIED_EMAIL]  # The "To" address
            },
            Message={
                'Subject': {'Data': email_subject},
                'Body': {'Text': {'Data': email_body}}
            }
        )
        print(f"Successfully sent email notification.")

        # 6. Send a "Success" response back to the frontend
        return {
            'statusCode': 200,
            # We must add CORS headers to allow our website to call the API
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST,OPTIONS'
            },
            'body': json.dumps({'message': 'Form submitted successfully!'})
        }

    except Exception as e:
        # If anything goes wrong, log the error
        print(f"Error: {str(e)}")
        
        # Send an "Error" response back to the frontend
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST,OPTIONS'
            },
            'body': json.dumps({'message': 'An error occurred. Please try again.'})
        }