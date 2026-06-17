#!/usr/bin/env python3
"""Migration script to add download_speed and download_speed_type columns to nodes table"""

import os
import psycopg2

def migrate():
    # Get database connection info from environment (same as app.py)
    db_user = os.getenv('DB_USER', 'subforge')
    db_password = os.getenv('DB_PASSWORD', 'subforge123')
    db_host = os.getenv('DB_HOST', 'localhost')
    db_port = os.getenv('DB_PORT', '5432')
    db_name = os.getenv('DB_NAME', 'subforge')

    try:
        conn = psycopg2.connect(
            host=db_host,
            port=int(db_port),
            database=db_name,
            user=db_user,
            password=db_password
        )
    except Exception as e:
        print(f"Failed to connect to database: {e}")
        return

    cursor = conn.cursor()

    # Check if columns already exist
    cursor.execute("""
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = 'nodes' AND column_name IN ('download_speed', 'download_speed_type')
    """)
    existing = [col[0] for col in cursor.fetchall()]

    if 'download_speed' not in existing:
        print("Adding download_speed column...")
        cursor.execute("ALTER TABLE nodes ADD COLUMN download_speed DOUBLE PRECISION DEFAULT 0")
        print("Added download_speed column")

    if 'download_speed_type' not in existing:
        print("Adding download_speed_type column...")
        cursor.execute("ALTER TABLE nodes ADD COLUMN download_speed_type VARCHAR(20) DEFAULT ''")
        print("Added download_speed_type column")

    conn.commit()
    cursor.close()
    conn.close()
    print("Migration completed successfully")

if __name__ == '__main__':
    migrate()
