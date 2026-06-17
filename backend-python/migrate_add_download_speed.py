#!/usr/bin/env python3
"""Migration script to add download_speed and download_speed_type columns to nodes table"""

import sqlite3
import os

def migrate():
    # Find the database file
    db_path = os.environ.get('DATABASE_URL', 'sqlite:///./subforge.db')
    if db_path.startswith('sqlite:///'):
        db_path = db_path[9:]

    if not os.path.exists(db_path):
        print(f"Database file not found: {db_path}")
        print("Creating new columns will be handled by create_all()")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Check if columns already exist
    cursor.execute("PRAGMA table_info(nodes)")
    columns = [col[1] for col in cursor.fetchall()]

    if 'download_speed' not in columns:
        print("Adding download_speed column...")
        cursor.execute("ALTER TABLE nodes ADD COLUMN download_speed FLOAT DEFAULT 0")
        print("Added download_speed column")

    if 'download_speed_type' not in columns:
        print("Adding download_speed_type column...")
        cursor.execute("ALTER TABLE nodes ADD COLUMN download_speed_type VARCHAR(20) DEFAULT ''")
        print("Added download_speed_type column")

    conn.commit()
    conn.close()
    print("Migration completed successfully")

if __name__ == '__main__':
    migrate()
