import mysql.connector
from mysql.connector import Error
import os
from supabase import create_client, Client
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def get_db_connection():
    """
    Creates and returns a MySQL database connection.
    Update the connection parameters according to your MySQL setup.
    """
    try:
        connection = mysql.connector.connect(
            host='localhost',
            database='velare_ecommerce',
            user='root',  # Change this to your MySQL username
            password=''   # Change this to your MySQL password
        )
        
        if connection.is_connected():
            return connection
    except Error as e:
        print(f"Error connecting to MySQL: {e}")
        return None

def get_supabase_client():
    """
    Creates and returns a Supabase client for authentication and database operations.
    """
    try:
        url = os.getenv('SUPABASE_URL')
        key = os.getenv('SUPABASE_KEY')
        
        if not url or not key:
            print("❌ Supabase credentials not found in .env file")
            return None
        
        client = create_client(url, key)
        return client
    except Exception as e:
        print(f"❌ Error connecting to Supabase: {e}")
        return None

def execute_supabase_query(table_name, operation, **kwargs):
    """
    Helper function to execute Supabase queries with error handling.
    
    Args:
        table_name: Name of the table
        operation: 'select', 'insert', 'update', 'delete'
        **kwargs: Additional parameters for the operation
    
    Returns:
        Query result or None on error
    """
    try:
        client = get_supabase_client()
        if not client:
            return None
        
        query = client.table(table_name)
        
        if operation == 'select':
            if 'columns' in kwargs:
                query = query.select(kwargs['columns'])
            else:
                query = query.select('*')
            
            if 'filters' in kwargs:
                for key, value in kwargs['filters'].items():
                    query = query.eq(key, value)
            
            if 'order' in kwargs:
                query = query.order(kwargs['order'])
            
            if 'limit' in kwargs:
                query = query.limit(kwargs['limit'])
            
            return query.execute()
        
        elif operation == 'insert':
            return query.insert(kwargs['data']).execute()
        
        elif operation == 'update':
            query = query.update(kwargs['data'])
            if 'filters' in kwargs:
                for key, value in kwargs['filters'].items():
                    query = query.eq(key, value)
            return query.execute()
        
        elif operation == 'delete':
            if 'filters' in kwargs:
                for key, value in kwargs['filters'].items():
                    query = query.eq(key, value)
            return query.execute()
        
        return None
    except Exception as e:
        print(f"❌ Supabase query error: {e}")
        return None

def close_db_connection(connection, cursor=None):
    """
    Closes the database connection and cursor.
    """
    try:
        if cursor:
            cursor.close()
        if connection and connection.is_connected():
            connection.close()
    except Error as e:
        print(f"Error closing connection: {e}")
