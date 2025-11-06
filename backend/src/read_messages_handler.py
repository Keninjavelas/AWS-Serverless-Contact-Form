import boto3
import json
import os
from decimal import Decimal

# Helper class to convert DynamoDB's Decimal type to a standard number
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

# Get the service clients
dynamodb = boto3.resource('dynamodb')

# Get the table name from the environment variable
TABLE_NAME = os.environ['TABLE_NAME']
table = dynamodb.Table(TABLE_NAME)

def handler(event, context):
    """
    This function reads all items from the DynamoDB table
    and returns them as a JSON list.
    """
    
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # 1. Scan the DynamoDB table
        # 'scan' is the operation to read all items.
        response = table.scan()
        
        items = response.get('Items', [])
        
        # Sort items by 'createdAt' timestamp, newest first
        items.sort(key=lambda x: x.get('createdAt', ''), reverse=True)
        
        print(f"Found {len(items)} items.")

        # 2. Send a "Success" response back to the frontend
        return {
            'statusCode': 200,
            # CRITICAL: We must include CORS headers in this response
            # so the browser will allow our frontend to read it.
            'headers': {
                'Access-Control-Allow-Origin': '*', # We'll lock this down later
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'GET,OPTIONS'
            },
            # Use our custom encoder to handle any Decimal numbers
            'body': json.dumps(items, cls=DecimalEncoder)
        }

    except Exception as e:
        # 5. If anything goes wrong, log the error
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'GET,OPTIONS'
            },
            'body': json.dumps({'message': 'An error occurred. Please try again.'})
        }