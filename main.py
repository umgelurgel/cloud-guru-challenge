import csv
import os
from dateutil import parser

import requests
import psycopg2
from psycopg2.extras import execute_values

new_york_times_data_uri = (
    "https://raw.githubusercontent.com/nytimes/covid-19-data/master/us.csv"
)
john_hopkins_data_url = "https://raw.githubusercontent.com/datasets/covid-19/master/data/time-series-19-covid-combined.csv"


def fetch_csv(uri):
    response = requests.get(uri)
    response.raise_for_status()
    # converting the file to lowercase to remove discrepancies in header names
    file_content = response.text.lower().split("\n")
    return file_content


def get_data():
    # fetch the data and parse it
    nyt_raw_data = csv.DictReader(fetch_csv(new_york_times_data_uri))
    jh_raw_data = csv.DictReader(fetch_csv(john_hopkins_data_url))

    # process the nyt data, casting the date strings to date objects
    # create a list of dicts with the relevant data
    nyt_data = [
        {
            "cases": int(elem["cases"]),
            "deaths": int(elem["deaths"]),
            "date": parser.parse(elem["date"]).date(),
        }
        for elem in nyt_raw_data
    ]
    # process the nyt data, casting the date strings to date objects and keeping only entries for the US
    # create a dict, mapping date the the number of recoveries
    jh_data = {
        parser.parse(elem["date"]).date(): int(elem["recovered"])
        for elem in jh_raw_data
        if elem["country/region"] == "us"
    }
    # combine the data from both sources, with case and death count coming from nyt
    # and recovery count from john hopkins
    # (shame the datasets are not equal length, would be a great candidate to zip both lists)
    combined_data = [
        {
            "date": elem["date"],
            "cases": elem["cases"],
            "deaths": elem["deaths"],
            # If number of recoveries not available for any date, default to 0
            "recoveries": jh_data.get(elem["date"], 0),
        }
        for elem in nyt_data
    ]

    return combined_data


def get_db_connection_params():
    dbname = os.environ["POSTGRES_DB"]
    dbpass = os.environ["POSTGRES_PASSWORD"]
    dbuser = os.environ["POSTGRES_USER"]
    dbhost = os.environ["POSTGRES_HOST"]
    dbport = os.environ["POSTGRES_PORT"]

    return dbname, dbuser, dbpass, dbhost, dbport


def load_data(data, dbname, dbuser, dbpass, dbhost, dbport):
    # connect to the database
    conn = psycopg2.connect(
        dbname=dbname,
        user=dbuser,
        password=dbpass,
        host=dbhost,
        port=dbport,
    )

    try:
        # create the tables if they don't already exist
        with conn.cursor() as curs:
            curs.execute(
                """
                CREATE TABLE IF NOT EXISTS covid (
                    id SERIAL PRIMARY KEY,
                    update_date date NOT NULL UNIQUE,
                    cases integer NOT NULL,
                    deaths integer NOT NULL,
                    recoveries integer NOT NULL
                );"""
            )

        # upsert data records
        data_for_upsert = [
            [elem["date"], elem["cases"], elem["deaths"], elem["recoveries"]]
            for elem in data
        ]
        with conn.cursor() as curs:
            # order of data elements must match the order of elements in the insert statement
            results = execute_values(
                curs,
                """INSERT INTO covid (update_date, cases, deaths, recoveries)
                VALUES %s
                ON CONFLICT (update_date) DO
                UPDATE SET cases = EXCLUDED.cases, deaths = EXCLUDED.deaths, recoveries = EXCLUDED.recoveries
                WHERE covid.cases != EXCLUDED.cases OR covid.deaths != EXCLUDED.deaths OR covid.recoveries != EXCLUDED.recoveries
                RETURNING xmax;""",
                data_for_upsert,
                fetch=True,
            )
    finally:
        # commit changes and close connection
        conn.close()

    # result is a list of tuples, where the first element of the tuple is the one we need.
    # the aggregation could have been done in SQL as well, but it would lead to less readable code
    # https://stackoverflow.com/questions/38851217/postgres-9-5-upsert-to-return-the-count-of-updated-and-inserted-rows
    results = [int(x[0]) for x in results]
    insert_count = len([x for x in results if x == 0])
    update_count = len([x for x in results if x > 0])

    return insert_count, update_count


def main():
    dbname, dbuser, dbpass, dbhost, dbport = get_db_connection_params()
    data = get_data()
    inserts, updates = load_data(data, dbname, dbuser, dbpass, dbhost, dbport)
    print(f"There were {inserts} inserts and {updates} updates")


if __name__ == "__main__":
    main()