import psycopg
from os import getenv
from dotenv import load_dotenv

load_dotenv()
DATABASE_NAME = getenv("DATABASE_NAME")
DATABASE_USER = getenv("DATABASE_USER")
DATABASE_PASSWORD = getenv("DATABASE_PASSWORD")
DATABASE_HOST = getenv("DATABASE_HOST")
DATABASE_PORT = getenv("DATABASE_PORT")


def get_connection():
    try:
        connection = psycopg.connect(
            dbname=DATABASE_NAME,
            user=DATABASE_USER,
            password=DATABASE_PASSWORD,
            host=DATABASE_HOST,
            port=DATABASE_PORT,
        )
        return connection
    except psycopg.OperationalError:
        print(
            "Database connection failed. Check database name, user, password, host, port, or PostgreSQL service."
        )
        return None
    except Exception as error:
        print("Unexpected database error: ", error)
        return None
