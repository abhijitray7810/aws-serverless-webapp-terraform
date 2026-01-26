import json
import os
import boto3
import uuid
from datetime import datetime
from decimal import Decimal

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb', region_name=os.environ.get('REGION', 'us-east-1'))
table = dynamodb.Table(os.environ.get('TABLE_NAME'))

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return str(obj)
        return super(DecimalEncoder, self).default(obj)

def handler(event, context):
    """
    Lambda handler for API Gateway requests
    """
    http_method = event.get('httpMethod', 'GET')
    path = event.get('path', '/')
    
    # CORS headers
    headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
    }
    
    try:
        if http_method == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({'message': 'OK'})
            }
        
        elif http_method == 'GET':
            # Scan DynamoDB table
            response = table.scan()
            items = response.get('Items', [])
            
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({
                    'items': items,
                    'count': len(items)
                }, cls=DecimalEncoder)
            }
        
        elif http_method == 'POST':
            # Parse request body
            body = json.loads(event.get('body', '{}'))
            
            # Create new item
            item = {
                'id': str(uuid.uuid4()),
                'created_at': datetime.utcnow().isoformat(),
                'data': body.get('data', 'No data provided')
            }
            
            # Put item in DynamoDB
            table.put_item(Item=item)
            
            return {
                'statusCode': 201,
                'headers': headers,
                'body': json.dumps({
                    'message': 'Item created successfully',
                    'item': item
                }, cls=DecimalEncoder)
            }
        
        else:
            return {
                'statusCode': 405,
                'headers': headers,
                'body': json.dumps({'error': 'Method not allowed'})
            }
            
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': str(e)})
        }
