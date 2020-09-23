import csv
from dateutil import parser

import requests

new_york_times_data_uri = 'https://raw.githubusercontent.com/nytimes/covid-19-data/master/us.csv'
john_hopkins_data_url = 'https://raw.githubusercontent.com/datasets/covid-19/master/data/time-series-19-covid-combined.csv'


def fetch_csv(uri):
    response = requests.get(uri)
    response.raise_for_status()
    # converting the file to lowercase to remove discrepancies in header names
    file_content = response.text.lower().split('\n')
    return file_content


def process_data():
    # fetch the data and parse it
    nyt_raw_data = csv.DictReader(fetch_csv(new_york_times_data_uri))
    jh_raw_data = csv.DictReader(fetch_csv(john_hopkins_data_url))

    # process the nyt data, casting the date strings to date objects
    # create a list of dicts with the relevant data
    nyt_data = [
        {
            'cases': int(elem['cases']),
            'deaths': int(elem['deaths']),
            'date': parser.parse(elem['date']).date(),
        }
        for elem in nyt_raw_data
    ]
    # process the nyt data, casting the date strings to date objects and keeping only entries for the US
    # create a dict, keyed by the date
    jh_data = {
        parser.parse(elem['date']).date(): int(elem['recovered'])
        for elem in jh_raw_data if elem['country/region'] == 'us'
    }
    # combine the data from both sources, with case and death count coming from nyt
    # and recovery count from john hopkins
    # (shame the datasets are not equal length, would be a great candidate to zip both lists)
    combined_data = [
        {
            'date': elem['date'],
            'cases': elem['cases'],
            'deaths': elem['deaths'],
            'recoveries': jh_data.get(elem['date'], 0),
        } for elem in nyt_data
    ]

    return combined_data


def load_data(data):
    pass


def main():
    data = process_data()
    load_data(data)


if __name__ == "__main__":
    main()
