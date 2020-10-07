import responses

from utils import new_york_times_data_uri, john_hopkins_data_url, fetch_csv, get_data

NYT_DATA_EXTRACT = """date,cases,deaths
2020-01-21,1,0
2020-01-22,1,0
2020-01-23,1,0
2020-01-24,2,0
2020-01-25,3,0
2020-01-26,5,0
2020-01-27,5,0
2020-01-28,5,0"""

JH_DATA_EXTRACT = """Date,Country/Region,Province/State,Lat,Long,Confirmed,Recovered,Deaths
2020-10-04,Turkey,,38.9637,35.2433,324443,285050,8441
2020-10-05,Turkey,,38.9637,35.2433,326046,286370,8498
2020-10-06,Turkey,,38.9637,35.2433,327557,287599,8553
2020-01-22,US,,40.0,-100.0,1,0,0
2020-01-23,US,,40.0,-100.0,1,0,0
2020-01-24,US,,40.0,-100.0,2,0,0
2020-01-25,US,,40.0,-100.0,2,0,0
2020-01-26,US,,40.0,-100.0,5,0,0
2020-01-27,US,,40.0,-100.0,5,0,0
2020-01-28,US,,40.0,-100.0,5,0,0"""


@responses.activate
def test_fetch_csv():
    responses.add(responses.GET, new_york_times_data_uri, body=NYT_DATA_EXTRACT)

    csv_lines = fetch_csv(new_york_times_data_uri)

    assert "\n".join(csv_lines).islower()
    assert "\n".join(csv_lines) == NYT_DATA_EXTRACT


@responses.activate
def test_get_data():
    responses.add(responses.GET, new_york_times_data_uri, body=NYT_DATA_EXTRACT)
    responses.add(responses.GET, john_hopkins_data_url, body=JH_DATA_EXTRACT)

    data = get_data()

    # Check the off by one data point handling works as expected
    assert len(data) == len(NYT_DATA_EXTRACT.split("\n")) - 1

    # Check all keys exist in the record
    assert "date" in data[0]
    assert "cases" in data[0]
    assert "deaths" in data[0]
    assert "recoveries" in data[0]
